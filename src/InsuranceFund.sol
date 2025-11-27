// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IInsuranceFund} from "./interfaces/IInsuranceFund.sol";

/// @title InsuranceFund
/// @notice Insurance fund to cover bad debt from underwater liquidations
/// @dev Implements timelock for emergency withdrawals to protect against malicious governance
contract InsuranceFund is IInsuranceFund, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Constants ============

    /// @notice Timelock duration for emergency withdrawals (24 hours)
    uint256 public constant TIMELOCK_DURATION = 24 hours;

    /// @notice Expiry window after timelock (48 hours)
    uint256 public constant EXPIRY_WINDOW = 48 hours;

    /// @notice Precision for ratio calculations
    uint256 private constant PRECISION = 1e18;

    // ============ State Variables ============

    /// @notice Authorized liquidation engine
    address public liquidationEngine;

    /// @notice Token balances
    mapping(address => uint256) private _balances;

    /// @notice Pending withdrawals
    mapping(bytes32 => PendingWithdrawal) private _pendingWithdrawals;

    /// @notice Counter for generating unique withdrawal IDs
    uint256 private _withdrawalNonce;

    // ============ Constructor ============

    constructor() Ownable(msg.sender) {}

    // ============ External Functions ============

    /// @inheritdoc IInsuranceFund
    function deposit(address token, uint256 amount) external nonReentrant {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        _balances[token] += amount;

        emit Deposit(token, msg.sender, amount);
    }

    /// @inheritdoc IInsuranceFund
    function coverBadDebt(
        address token,
        uint256 amount,
        address recipient
    ) external nonReentrant {
        if (msg.sender != liquidationEngine) revert Unauthorized();
        if (amount == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();
        if (_balances[token] < amount) revert InsufficientBalance();

        _balances[token] -= amount;
        IERC20(token).safeTransfer(recipient, amount);

        emit BadDebtCovered(token, amount, recipient);
    }

    /// @inheritdoc IInsuranceFund
    function queueEmergencyWithdraw(
        address token,
        uint256 amount,
        address recipient
    ) external onlyOwner returns (bytes32 withdrawId) {
        if (amount == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();

        _withdrawalNonce++;
        withdrawId = keccak256(
            abi.encodePacked(token, amount, recipient, block.timestamp, _withdrawalNonce)
        );

        uint256 executeTime = block.timestamp + TIMELOCK_DURATION;

        _pendingWithdrawals[withdrawId] = PendingWithdrawal({
            token: token,
            amount: amount,
            recipient: recipient,
            executeTime: executeTime,
            executed: false,
            cancelled: false
        });

        emit EmergencyWithdrawQueued(withdrawId, token, amount, recipient, executeTime);
    }

    /// @inheritdoc IInsuranceFund
    function executeEmergencyWithdraw(bytes32 withdrawId) external nonReentrant onlyOwner {
        PendingWithdrawal storage withdrawal = _pendingWithdrawals[withdrawId];

        if (withdrawal.executeTime == 0) revert WithdrawNotFound();
        if (withdrawal.executed || withdrawal.cancelled) revert WithdrawAlreadyProcessed();
        if (block.timestamp < withdrawal.executeTime) revert WithdrawNotReady();
        if (block.timestamp > withdrawal.executeTime + EXPIRY_WINDOW) revert WithdrawExpired();

        if (_balances[withdrawal.token] < withdrawal.amount) revert InsufficientBalance();

        withdrawal.executed = true;
        _balances[withdrawal.token] -= withdrawal.amount;

        IERC20(withdrawal.token).safeTransfer(withdrawal.recipient, withdrawal.amount);

        emit EmergencyWithdrawExecuted(
            withdrawId,
            withdrawal.token,
            withdrawal.amount,
            withdrawal.recipient
        );
    }

    /// @inheritdoc IInsuranceFund
    function cancelEmergencyWithdraw(bytes32 withdrawId) external onlyOwner {
        PendingWithdrawal storage withdrawal = _pendingWithdrawals[withdrawId];

        if (withdrawal.executeTime == 0) revert WithdrawNotFound();
        if (withdrawal.executed || withdrawal.cancelled) revert WithdrawAlreadyProcessed();

        withdrawal.cancelled = true;

        emit EmergencyWithdrawCancelled(withdrawId);
    }

    // ============ View Functions ============

    /// @inheritdoc IInsuranceFund
    function getBalance(address token) external view returns (uint256 balance) {
        return _balances[token];
    }

    /// @inheritdoc IInsuranceFund
    function getCoverageRatio(
        address token,
        uint256 totalLiability
    ) external view returns (uint256 ratio) {
        if (totalLiability == 0) {
            return type(uint256).max;
        }
        return (_balances[token] * PRECISION) / totalLiability;
    }

    /// @inheritdoc IInsuranceFund
    function getPendingWithdrawal(bytes32 withdrawId)
        external
        view
        returns (PendingWithdrawal memory withdrawal)
    {
        return _pendingWithdrawals[withdrawId];
    }

    /// @inheritdoc IInsuranceFund
    function getTimelockDuration() external pure returns (uint256 duration) {
        return TIMELOCK_DURATION;
    }

    // ============ Admin Functions ============

    /// @inheritdoc IInsuranceFund
    function setLiquidationEngine(address engine) external onlyOwner {
        if (engine == address(0)) revert ZeroAddress();

        address oldEngine = liquidationEngine;
        liquidationEngine = engine;

        emit LiquidationEngineSet(oldEngine, engine);
    }
}
