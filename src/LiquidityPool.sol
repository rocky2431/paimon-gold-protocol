// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILiquidityPool} from "./interfaces/ILiquidityPool.sol";
import {ILPToken} from "./interfaces/ILPToken.sol";

/// @title LiquidityPool
/// @notice Pool for liquidity providers to deposit assets and earn fees from trading
/// @dev Uses MasterChef-style fee accumulation for fair distribution
contract LiquidityPool is ILiquidityPool, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Constants ============

    /// @notice Precision for fee calculations
    uint256 public constant PRECISION = 1e18;

    /// @notice Fee split percentage for LPs (70%)
    uint256 public constant LP_FEE_SHARE = 70;

    /// @notice Fee split percentage for protocol (30%)
    uint256 public constant PROTOCOL_FEE_SHARE = 30;

    /// @notice Default cooldown period (24 hours)
    uint256 public constant DEFAULT_COOLDOWN = 24 hours;

    // ============ State Variables ============

    /// @notice LP token contract
    address public immutable lpToken;

    /// @notice Primary token for the pool (e.g., USDC)
    address public immutable primaryToken;

    /// @notice Primary token decimals
    uint8 public immutable primaryTokenDecimals;

    /// @notice Protocol treasury address
    address public protocolTreasury;

    /// @notice Accumulated fee per share (scaled by PRECISION)
    uint256 private _accFeePerShare;

    /// @notice Total LP tokens in circulation (for tracking)
    uint256 private _totalLPSupply;

    /// @notice Total deposited assets (excludes fee reserves)
    uint256 private _totalAssets;

    /// @notice Cooldown period in seconds
    uint256 private _cooldownPeriod;

    /// @notice Mapping of user address to their info
    mapping(address => UserInfo) private _userInfo;

    /// @notice Mapping of whitelisted tokens
    mapping(address => bool) private _whitelistedTokens;

    /// @notice Mapping of authorized trading contracts
    mapping(address => bool) private _tradingContracts;

    // ============ Constructor ============

    /// @notice Initialize the liquidity pool
    /// @param lpToken_ LP token address
    /// @param primaryToken_ Primary token address (e.g., USDC)
    /// @param treasury_ Protocol treasury address
    constructor(
        address lpToken_,
        address primaryToken_,
        address treasury_
    ) Ownable(msg.sender) {
        if (lpToken_ == address(0)) revert ZeroAddress();
        if (primaryToken_ == address(0)) revert ZeroAddress();
        if (treasury_ == address(0)) revert ZeroAddress();

        lpToken = lpToken_;
        primaryToken = primaryToken_;
        protocolTreasury = treasury_;
        _cooldownPeriod = DEFAULT_COOLDOWN;

        // Get decimals for primary token
        // Try to call decimals(), default to 18 if it fails
        try IERC20Metadata(primaryToken_).decimals() returns (uint8 decimals_) {
            primaryTokenDecimals = decimals_;
        } catch {
            primaryTokenDecimals = 18;
        }

        // Whitelist primary token by default
        _whitelistedTokens[primaryToken_] = true;
    }

    // ============ External Functions ============

    /// @inheritdoc ILiquidityPool
    function addLiquidity(
        address token,
        uint256 amount
    ) external nonReentrant returns (uint256 lpAmount) {
        if (amount == 0) revert ZeroAmount();
        if (!_whitelistedTokens[token]) revert TokenNotSupported();

        // Convert amount to primary token value if different token
        uint256 valueInPrimary = _convertToPrimary(token, amount);

        // Calculate LP tokens to mint BEFORE transferring tokens
        uint256 totalSupply = _totalLPSupply;
        if (totalSupply == 0) {
            // First depositor: 1:1 ratio (scaled to 18 decimals)
            lpAmount = _scaleTo18Decimals(valueInPrimary);
        } else {
            // Subsequent depositors: proportional to pool share (use _totalAssets, not balance)
            lpAmount = (valueInPrimary * totalSupply) / _totalAssets;
        }

        // Transfer tokens from user
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Update state
        _totalLPSupply += lpAmount;
        _totalAssets += valueInPrimary;

        // Update user info
        UserInfo storage user = _userInfo[msg.sender];

        // Claim any pending fees before updating balance
        if (user.lpBalance > 0) {
            uint256 pending = _calculatePending(user);
            if (pending > 0) {
                _safeTransferFees(msg.sender, pending);
            }
        }

        user.lpBalance += lpAmount;
        user.rewardDebt = (user.lpBalance * _accFeePerShare) / PRECISION;
        user.depositTime = block.timestamp;

        // Mint LP tokens
        ILPToken(lpToken).mint(msg.sender, lpAmount);

        emit LiquidityAdded(msg.sender, token, amount, lpAmount);
    }

    /// @inheritdoc ILiquidityPool
    function removeLiquidity(
        uint256 lpAmount
    ) external nonReentrant returns (uint256 assetAmount, uint256 feeReward) {
        if (lpAmount == 0) revert ZeroAmount();

        UserInfo storage user = _userInfo[msg.sender];
        if (user.lpBalance < lpAmount) revert InsufficientBalance();
        if (block.timestamp < user.depositTime + _cooldownPeriod) revert CooldownNotPassed();

        // Calculate fee reward
        feeReward = _calculatePending(user);

        // Calculate asset amount to return (based on _totalAssets, not balance)
        assetAmount = (lpAmount * _totalAssets) / _totalLPSupply;

        // Update state
        _totalLPSupply -= lpAmount;
        _totalAssets -= assetAmount;
        user.lpBalance -= lpAmount;
        user.rewardDebt = (user.lpBalance * _accFeePerShare) / PRECISION;

        // Burn LP tokens
        ILPToken(lpToken).burn(msg.sender, lpAmount);

        // Transfer assets and fees
        IERC20(primaryToken).safeTransfer(msg.sender, assetAmount);
        if (feeReward > 0) {
            _safeTransferFees(msg.sender, feeReward);
        }

        emit LiquidityRemoved(msg.sender, lpAmount, assetAmount, feeReward);
    }

    /// @inheritdoc ILiquidityPool
    function claimFees() external nonReentrant returns (uint256 feeAmount) {
        UserInfo storage user = _userInfo[msg.sender];

        feeAmount = _calculatePending(user);

        if (feeAmount > 0) {
            user.rewardDebt = (user.lpBalance * _accFeePerShare) / PRECISION;
            _safeTransferFees(msg.sender, feeAmount);

            emit FeesClaimed(msg.sender, feeAmount);
        }
    }

    /// @inheritdoc ILiquidityPool
    function depositFees(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!_tradingContracts[msg.sender]) revert Unauthorized();
        if (_totalLPSupply == 0) revert PoolEmpty();

        // Transfer tokens from trading contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Convert to primary token value
        uint256 valueInPrimary = _convertToPrimary(token, amount);

        // Split fees: 70% to LPs, 30% to protocol
        uint256 lpShare = (valueInPrimary * LP_FEE_SHARE) / 100;
        uint256 protocolShare = valueInPrimary - lpShare;

        // Transfer protocol share to treasury
        IERC20(primaryToken).safeTransfer(protocolTreasury, protocolShare);

        // Update accumulated fee per share for LP portion
        _accFeePerShare += (lpShare * PRECISION) / _totalLPSupply;

        emit FeesDeposited(token, amount, lpShare, protocolShare);
    }

    // ============ View Functions ============

    /// @inheritdoc ILiquidityPool
    function pendingFees(address user) external view returns (uint256) {
        UserInfo storage userInfo_ = _userInfo[user];
        return _calculatePending(userInfo_);
    }

    /// @inheritdoc ILiquidityPool
    function getUserInfo(address user) external view returns (UserInfo memory info) {
        return _userInfo[user];
    }

    /// @inheritdoc ILiquidityPool
    function getTotalPoolValue() public view returns (uint256 totalValue) {
        // Return tracked total assets (excludes fee reserves)
        totalValue = _totalAssets;
    }

    /// @inheritdoc ILiquidityPool
    function getAccFeePerShare() external view returns (uint256) {
        return _accFeePerShare;
    }

    /// @inheritdoc ILiquidityPool
    function getCooldownPeriod() external view returns (uint256) {
        return _cooldownPeriod;
    }

    /// @inheritdoc ILiquidityPool
    function isTokenWhitelisted(address token) external view returns (bool) {
        return _whitelistedTokens[token];
    }

    /// @notice Check if address is an authorized trading contract
    /// @param account Address to check
    /// @return isAuthorized Whether the address is authorized
    function isTradingContract(address account) external view returns (bool isAuthorized) {
        return _tradingContracts[account];
    }

    // ============ Admin Functions ============

    /// @inheritdoc ILiquidityPool
    function setCooldownPeriod(uint256 cooldown) external onlyOwner {
        uint256 oldCooldown = _cooldownPeriod;
        _cooldownPeriod = cooldown;
        emit CooldownUpdated(oldCooldown, cooldown);
    }

    /// @inheritdoc ILiquidityPool
    function setProtocolTreasury(address treasury) external onlyOwner {
        if (treasury == address(0)) revert ZeroAddress();

        address oldTreasury = protocolTreasury;
        protocolTreasury = treasury;

        emit ProtocolTreasurySet(oldTreasury, treasury);
    }

    /// @inheritdoc ILiquidityPool
    function setTokenWhitelist(address token, bool whitelisted) external onlyOwner {
        _whitelistedTokens[token] = whitelisted;
        emit TokenWhitelisted(token, whitelisted);
    }

    /// @notice Set trading contract authorization
    /// @param tradingContract Address of trading contract
    /// @param authorized Whether to authorize
    function setTradingContract(address tradingContract, bool authorized) external onlyOwner {
        _tradingContracts[tradingContract] = authorized;
    }

    // ============ Internal Functions ============

    /// @notice Calculate pending fees for a user
    /// @param user User info struct
    /// @return pending Pending fee amount
    function _calculatePending(UserInfo storage user) internal view returns (uint256 pending) {
        if (user.lpBalance == 0) return 0;

        uint256 accumulatedFees = (user.lpBalance * _accFeePerShare) / PRECISION;
        pending = accumulatedFees - user.rewardDebt;
    }

    /// @notice Scale amount to 18 decimals
    /// @param amount Amount in primary token decimals
    /// @return scaled Amount in 18 decimals
    function _scaleTo18Decimals(uint256 amount) internal view returns (uint256 scaled) {
        if (primaryTokenDecimals < 18) {
            scaled = amount * (10 ** (18 - primaryTokenDecimals));
        } else if (primaryTokenDecimals > 18) {
            scaled = amount / (10 ** (primaryTokenDecimals - 18));
        } else {
            scaled = amount;
        }
    }

    /// @notice Convert token amount to primary token value
    /// @dev For now, assumes 1:1 conversion for whitelisted tokens
    /// @param token Token address
    /// @param amount Token amount
    /// @return value Value in primary token
    function _convertToPrimary(address token, uint256 amount) internal view returns (uint256 value) {
        if (token == primaryToken) {
            return amount;
        }
        // For other tokens, would need oracle integration
        // For now, revert if not primary token
        revert TokenNotSupported();
    }

    /// @notice Safely transfer fees to user
    /// @param to Recipient address
    /// @param amount Amount to transfer
    function _safeTransferFees(address to, uint256 amount) internal {
        uint256 balance = IERC20(primaryToken).balanceOf(address(this));
        if (amount > balance) {
            amount = balance;
        }
        if (amount > 0) {
            IERC20(primaryToken).safeTransfer(to, amount);
        }
    }
}

/// @notice Interface for ERC20 with decimals
interface IERC20Metadata {
    function decimals() external view returns (uint8);
}
