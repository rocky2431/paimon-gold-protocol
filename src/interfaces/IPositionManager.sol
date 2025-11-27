// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IPositionManager
/// @notice Interface for the PositionManager contract
interface IPositionManager {
    // ============ Structs ============

    /// @notice Position data structure
    struct Position {
        uint256 id;              // Unique position ID
        address owner;           // Position owner
        address collateralToken; // Collateral token address
        uint256 collateralAmount;// Amount of collateral (18 decimals)
        uint256 size;            // Position size in USD (18 decimals)
        uint256 entryPrice;      // Entry price from oracle (18 decimals)
        uint256 leverage;        // Leverage multiplier (2-20)
        bool isLong;             // True for long, false for short
        uint256 openedAt;        // Timestamp when position opened
        uint256 openBlock;       // Block number when opened (flash loan protection)
    }

    // ============ Events ============

    /// @notice Emitted when a new position is opened
    event PositionOpened(
        uint256 indexed positionId,
        address indexed owner,
        address indexed collateralToken,
        uint256 collateralAmount,
        uint256 size,
        uint256 entryPrice,
        uint256 leverage,
        bool isLong
    );

    /// @notice Emitted when a position is closed
    event PositionClosed(
        uint256 indexed positionId,
        address indexed owner,
        uint256 exitPrice,
        int256 pnl,
        uint256 payout
    );

    /// @notice Emitted when position is partially closed
    event PositionPartialClosed(
        uint256 indexed positionId,
        uint256 closedSize,
        uint256 remainingSize,
        int256 pnl,
        uint256 payout
    );

    // ============ Errors ============

    /// @notice Thrown when leverage is outside valid range (2-20x)
    error InvalidLeverage();

    /// @notice Thrown when position size is below minimum ($10)
    error PositionTooSmall();

    /// @notice Thrown when position does not exist
    error PositionNotFound();

    /// @notice Thrown when caller is not position owner
    error NotPositionOwner();

    /// @notice Thrown when trying to close position too early (flash loan protection)
    error PositionTooNew();

    /// @notice Thrown when close amount exceeds position size
    error InvalidCloseAmount();

    /// @notice Thrown when collateral token is not supported
    error UnsupportedCollateral();

    // ============ Functions ============

    /// @notice Open a new leveraged position
    /// @param collateralToken Token used as collateral
    /// @param collateralAmount Amount of collateral to deposit
    /// @param leverage Leverage multiplier (2-20)
    /// @param isLong True for long position, false for short
    /// @return positionId The ID of the newly created position
    function openPosition(
        address collateralToken,
        uint256 collateralAmount,
        uint256 leverage,
        bool isLong
    ) external returns (uint256 positionId);

    /// @notice Close an existing position (full or partial)
    /// @param positionId The ID of the position to close
    /// @param closeAmount Amount of position size to close (use type(uint256).max for full close)
    /// @return payout Amount returned to the user
    function closePosition(
        uint256 positionId,
        uint256 closeAmount
    ) external returns (uint256 payout);

    /// @notice Get position details
    /// @param positionId The position ID
    /// @return position The position data
    function getPosition(uint256 positionId) external view returns (Position memory position);

    /// @notice Get all position IDs for an owner
    /// @param owner The owner address
    /// @return positionIds Array of position IDs
    function getPositionsByOwner(address owner) external view returns (uint256[] memory positionIds);

    /// @notice Calculate current PnL for a position
    /// @param positionId The position ID
    /// @return pnl The current PnL (can be negative)
    function calculatePnL(uint256 positionId) external view returns (int256 pnl);

    /// @notice Get the current health factor of a position
    /// @param positionId The position ID
    /// @return healthFactor The health factor (18 decimals, 1e18 = 100%)
    function getHealthFactor(uint256 positionId) external view returns (uint256 healthFactor);
}
