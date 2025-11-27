// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ILiquidityPool
/// @notice Interface for the LiquidityPool contract
interface ILiquidityPool {
    // ============ Structs ============

    /// @notice User liquidity info
    struct UserInfo {
        uint256 lpBalance;        // LP token balance
        uint256 rewardDebt;       // Fee reward debt (for MasterChef-style accounting)
        uint256 depositTime;      // Last deposit timestamp (for cooldown)
    }

    // ============ Events ============

    /// @notice Emitted when liquidity is added
    event LiquidityAdded(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 lpAmount
    );

    /// @notice Emitted when liquidity is removed
    event LiquidityRemoved(
        address indexed user,
        uint256 lpAmount,
        uint256 assetAmount,
        uint256 fees
    );

    /// @notice Emitted when fees are claimed
    event FeesClaimed(address indexed user, uint256 amount);

    /// @notice Emitted when fees are deposited to the pool
    event FeesDeposited(
        address indexed token,
        uint256 amount,
        uint256 lpShare,
        uint256 protocolShare
    );

    /// @notice Emitted when cooldown period is updated
    event CooldownUpdated(uint256 oldCooldown, uint256 newCooldown);

    /// @notice Emitted when protocol treasury is set
    event ProtocolTreasurySet(address indexed oldTreasury, address indexed newTreasury);

    /// @notice Emitted when a token is whitelisted
    event TokenWhitelisted(address indexed token, bool whitelisted);

    // ============ Errors ============

    /// @notice Thrown when amount is zero
    error ZeroAmount();

    /// @notice Thrown when address is zero
    error ZeroAddress();

    /// @notice Thrown when balance is insufficient
    error InsufficientBalance();

    /// @notice Thrown when cooldown period has not passed
    error CooldownNotPassed();

    /// @notice Thrown when caller is not authorized
    error Unauthorized();

    /// @notice Thrown when token is not supported
    error TokenNotSupported();

    /// @notice Thrown when pool has no liquidity
    error PoolEmpty();

    // ============ Functions ============

    /// @notice Add liquidity to the pool
    /// @param token Token to deposit
    /// @param amount Amount to deposit
    /// @return lpAmount Amount of LP tokens minted
    function addLiquidity(address token, uint256 amount) external returns (uint256 lpAmount);

    /// @notice Remove liquidity from the pool
    /// @param lpAmount Amount of LP tokens to burn
    /// @return assetAmount Amount of assets returned
    /// @return feeReward Amount of fee rewards claimed
    function removeLiquidity(uint256 lpAmount) external returns (uint256 assetAmount, uint256 feeReward);

    /// @notice Claim accumulated fees without removing liquidity
    /// @return feeAmount Amount of fees claimed
    function claimFees() external returns (uint256 feeAmount);

    /// @notice Deposit trading fees to the pool (called by trading contracts)
    /// @param token Fee token
    /// @param amount Fee amount
    function depositFees(address token, uint256 amount) external;

    /// @notice Get user's pending fee rewards
    /// @param user User address
    /// @return pendingFees Pending fee amount
    function pendingFees(address user) external view returns (uint256 pendingFees);

    /// @notice Get user info
    /// @param user User address
    /// @return info User liquidity info
    function getUserInfo(address user) external view returns (UserInfo memory info);

    /// @notice Get total pool value in primary token
    /// @return totalValue Total pool value
    function getTotalPoolValue() external view returns (uint256 totalValue);

    /// @notice Get accumulated fees per share
    /// @return accFeePerShare Accumulated fee per share (scaled by PRECISION)
    function getAccFeePerShare() external view returns (uint256 accFeePerShare);

    /// @notice Get cooldown period
    /// @return cooldown Cooldown period in seconds
    function getCooldownPeriod() external view returns (uint256 cooldown);

    /// @notice Set cooldown period
    /// @param cooldown New cooldown period
    function setCooldownPeriod(uint256 cooldown) external;

    /// @notice Set protocol treasury address
    /// @param treasury New treasury address
    function setProtocolTreasury(address treasury) external;

    /// @notice Whitelist a token for deposits
    /// @param token Token address
    /// @param whitelisted Whether to whitelist
    function setTokenWhitelist(address token, bool whitelisted) external;

    /// @notice Check if a token is whitelisted
    /// @param token Token address
    /// @return isWhitelisted Whether token is whitelisted
    function isTokenWhitelisted(address token) external view returns (bool isWhitelisted);
}
