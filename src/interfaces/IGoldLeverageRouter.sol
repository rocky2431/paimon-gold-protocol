// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPositionManager} from "./IPositionManager.sol";
import {ILiquidityPool} from "./ILiquidityPool.sol";

/// @title IGoldLeverageRouter
/// @notice Interface for the GoldLeverageRouter contract - unified entry point for the protocol
interface IGoldLeverageRouter {
    // ============ Events ============

    /// @notice Emitted when PositionManager address is updated
    event PositionManagerSet(address indexed oldManager, address indexed newManager);

    /// @notice Emitted when LiquidityPool address is updated
    event LiquidityPoolSet(address indexed oldPool, address indexed newPool);

    /// @notice Emitted when CollateralVault address is updated
    event CollateralVaultSet(address indexed oldVault, address indexed newVault);

    /// @notice Emitted when protocol is paused
    event EmergencyPause(address indexed pauser, uint256 timestamp);

    /// @notice Emitted when protocol is unpaused
    event EmergencyUnpause(address indexed admin, uint256 timestamp);

    // ============ Errors ============

    /// @notice Thrown when address is zero
    error ZeroAddress();

    /// @notice Thrown when amount is zero
    error ZeroAmount();

    /// @notice Thrown when contract is not properly initialized
    error NotInitialized();

    /// @notice Thrown when caller lacks required role
    error UnauthorizedRole();

    // ============ Trading Functions ============

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

    /// @notice Add margin to an existing position
    /// @param positionId The position ID
    /// @param amount Amount of collateral to add
    function addMargin(uint256 positionId, uint256 amount) external;

    /// @notice Remove margin from an existing position
    /// @param positionId The position ID
    /// @param amount Amount of collateral to remove
    function removeMargin(uint256 positionId, uint256 amount) external;

    // ============ LP Functions ============

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

    // ============ View Functions ============

    /// @notice Get position details
    /// @param positionId The position ID
    /// @return position The position data
    function getPosition(uint256 positionId) external view returns (IPositionManager.Position memory position);

    /// @notice Get all position IDs for an owner
    /// @param owner The owner address
    /// @return positionIds Array of position IDs
    function getUserPositions(address owner) external view returns (uint256[] memory positionIds);

    /// @notice Get the current health factor of a position
    /// @param positionId The position ID
    /// @return healthFactor The health factor (18 decimals, 1e18 = 100%)
    function getHealthFactor(uint256 positionId) external view returns (uint256 healthFactor);

    /// @notice Calculate current PnL for a position
    /// @param positionId The position ID
    /// @return pnl The current PnL (can be negative)
    function calculatePnL(uint256 positionId) external view returns (int256 pnl);

    /// @notice Get user's pending fee rewards
    /// @param user User address
    /// @return pendingFees Pending fee amount
    function getPendingFees(address user) external view returns (uint256 pendingFees);

    /// @notice Get user liquidity info
    /// @param user User address
    /// @return info User liquidity info
    function getUserLPInfo(address user) external view returns (ILiquidityPool.UserInfo memory info);

    /// @notice Get total pool value
    /// @return totalValue Total pool value
    function getPoolTVL() external view returns (uint256 totalValue);

    // ============ Admin Functions ============

    /// @notice Set the PositionManager contract address
    /// @param manager New PositionManager address
    function setPositionManager(address manager) external;

    /// @notice Set the LiquidityPool contract address
    /// @param pool New LiquidityPool address
    function setLiquidityPool(address pool) external;

    /// @notice Set the CollateralVault contract address
    /// @param vault New CollateralVault address
    function setCollateralVault(address vault) external;

    /// @notice Pause the protocol
    function pause() external;

    /// @notice Unpause the protocol
    function unpause() external;

    // ============ Getters ============

    /// @notice Get the PositionManager address
    function positionManager() external view returns (address);

    /// @notice Get the LiquidityPool address
    function liquidityPool() external view returns (address);

    /// @notice Get the CollateralVault address
    function collateralVault() external view returns (address);
}
