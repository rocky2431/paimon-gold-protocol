// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ILiquidationEngine
/// @notice Interface for the LiquidationEngine contract
interface ILiquidationEngine {
    // ============ Events ============

    /// @notice Emitted when a position is fully liquidated
    event PositionLiquidated(
        uint256 indexed positionId,
        address indexed liquidator,
        address indexed owner,
        uint256 collateralLiquidated,
        uint256 keeperBonus,
        uint256 remainingCollateral
    );

    /// @notice Emitted when a position is partially liquidated
    event PartialLiquidation(
        uint256 indexed positionId,
        address indexed liquidator,
        uint256 percentage,
        uint256 collateralLiquidated,
        uint256 keeperBonus
    );

    // ============ Errors ============

    /// @notice Thrown when attempting to liquidate a healthy position
    error PositionNotLiquidatable();

    /// @notice Thrown when liquidation percentage is invalid (0 or >100)
    error InvalidLiquidationPercentage();

    /// @notice Thrown when a zero address is provided
    error ZeroAddress();

    /// @notice Thrown when position does not exist
    error PositionNotFound();

    /// @notice Thrown when caller is not authorized
    error Unauthorized();

    // ============ Functions ============

    /// @notice Liquidate a position that has health factor < 1.0
    /// @param positionId The ID of the position to liquidate
    /// @return collateralLiquidated Amount of collateral liquidated
    /// @return keeperBonus Bonus paid to the liquidator
    function liquidate(uint256 positionId)
        external
        returns (uint256 collateralLiquidated, uint256 keeperBonus);

    /// @notice Partially liquidate a large position
    /// @param positionId The ID of the position to liquidate
    /// @param percentage Percentage of position to liquidate (1-100)
    /// @return collateralLiquidated Amount of collateral liquidated
    /// @return keeperBonus Bonus paid to the liquidator
    function liquidatePartial(uint256 positionId, uint256 percentage)
        external
        returns (uint256 collateralLiquidated, uint256 keeperBonus);

    /// @notice Check if a position can be liquidated
    /// @param positionId The ID of the position to check
    /// @return True if position health factor is below liquidation threshold
    function isLiquidatable(uint256 positionId) external view returns (bool);

    /// @notice Get the health factor of a position
    /// @param positionId The ID of the position
    /// @return healthFactor The health factor (18 decimals, 1e18 = 100%)
    function getHealthFactor(uint256 positionId) external view returns (uint256 healthFactor);

    /// @notice Get the liquidation bonus percentage
    /// @return bonusPercentage The bonus percentage (18 decimals, 5e16 = 5%)
    function getLiquidationBonus() external view returns (uint256 bonusPercentage);

    /// @notice Get large position threshold for partial liquidation
    /// @return threshold Position size threshold in USD (18 decimals)
    function getLargePositionThreshold() external view returns (uint256 threshold);

    // ============ Chainlink Automation Functions ============

    /// @notice Check if upkeep is needed (Chainlink Automation compatible)
    /// @param checkData Data passed to the function (unused)
    /// @return upkeepNeeded True if there are positions to liquidate
    /// @return performData Encoded data for performUpkeep
    function checkUpkeep(bytes calldata checkData)
        external
        view
        returns (bool upkeepNeeded, bytes memory performData);

    /// @notice Perform the upkeep (Chainlink Automation compatible)
    /// @param performData Encoded position IDs to liquidate
    function performUpkeep(bytes calldata performData) external;
}
