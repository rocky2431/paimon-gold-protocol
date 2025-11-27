// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IInsuranceFund
/// @notice Interface for the InsuranceFund contract
interface IInsuranceFund {
    // ============ Structs ============

    /// @notice Pending emergency withdrawal data
    struct PendingWithdrawal {
        address token;
        uint256 amount;
        address recipient;
        uint256 executeTime;
        bool executed;
        bool cancelled;
    }

    // ============ Events ============

    /// @notice Emitted when funds are deposited
    event Deposit(address indexed token, address indexed from, uint256 amount);

    /// @notice Emitted when bad debt is covered
    event BadDebtCovered(
        address indexed token,
        uint256 amount,
        address indexed recipient
    );

    /// @notice Emitted when emergency withdrawal is queued
    event EmergencyWithdrawQueued(
        bytes32 indexed withdrawId,
        address indexed token,
        uint256 amount,
        address recipient,
        uint256 executeTime
    );

    /// @notice Emitted when emergency withdrawal is executed
    event EmergencyWithdrawExecuted(
        bytes32 indexed withdrawId,
        address indexed token,
        uint256 amount,
        address recipient
    );

    /// @notice Emitted when emergency withdrawal is cancelled
    event EmergencyWithdrawCancelled(bytes32 indexed withdrawId);

    /// @notice Emitted when liquidation engine is set
    event LiquidationEngineSet(address indexed oldEngine, address indexed newEngine);

    // ============ Errors ============

    /// @notice Thrown when amount is zero
    error ZeroAmount();

    /// @notice Thrown when address is zero
    error ZeroAddress();

    /// @notice Thrown when balance is insufficient
    error InsufficientBalance();

    /// @notice Thrown when caller is not authorized
    error Unauthorized();

    /// @notice Thrown when withdrawal timelock has not passed
    error WithdrawNotReady();

    /// @notice Thrown when withdrawal has expired (>48h after ready)
    error WithdrawExpired();

    /// @notice Thrown when withdrawal ID is not found
    error WithdrawNotFound();

    /// @notice Thrown when withdrawal was already executed or cancelled
    error WithdrawAlreadyProcessed();

    // ============ Functions ============

    /// @notice Deposit funds into the insurance fund
    /// @param token The token address to deposit
    /// @param amount The amount to deposit
    function deposit(address token, uint256 amount) external;

    /// @notice Cover bad debt from a liquidation
    /// @param token The token to pay out
    /// @param amount The amount of bad debt to cover
    /// @param recipient The address to receive the funds
    /// @dev Only callable by LiquidationEngine
    function coverBadDebt(address token, uint256 amount, address recipient) external;

    /// @notice Queue an emergency withdrawal (starts timelock)
    /// @param token The token to withdraw
    /// @param amount The amount to withdraw
    /// @param recipient The address to receive funds
    /// @return withdrawId The unique ID for this withdrawal
    function queueEmergencyWithdraw(
        address token,
        uint256 amount,
        address recipient
    ) external returns (bytes32 withdrawId);

    /// @notice Execute a queued emergency withdrawal after timelock
    /// @param withdrawId The withdrawal ID
    function executeEmergencyWithdraw(bytes32 withdrawId) external;

    /// @notice Cancel a queued emergency withdrawal
    /// @param withdrawId The withdrawal ID
    function cancelEmergencyWithdraw(bytes32 withdrawId) external;

    /// @notice Get the balance of a token in the fund
    /// @param token The token address
    /// @return balance The token balance
    function getBalance(address token) external view returns (uint256 balance);

    /// @notice Get the coverage ratio for a token
    /// @param token The token address
    /// @param totalLiability The total potential liability
    /// @return ratio The coverage ratio (18 decimals, 1e18 = 100%)
    function getCoverageRatio(address token, uint256 totalLiability)
        external
        view
        returns (uint256 ratio);

    /// @notice Get pending withdrawal details
    /// @param withdrawId The withdrawal ID
    /// @return withdrawal The pending withdrawal data
    function getPendingWithdrawal(bytes32 withdrawId)
        external
        view
        returns (PendingWithdrawal memory withdrawal);

    /// @notice Get the timelock duration
    /// @return duration The timelock duration in seconds
    function getTimelockDuration() external view returns (uint256 duration);

    /// @notice Set the liquidation engine address
    /// @param engine The new liquidation engine address
    function setLiquidationEngine(address engine) external;
}
