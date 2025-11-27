// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IGoldLeverageRouter} from "./interfaces/IGoldLeverageRouter.sol";
import {IPositionManager} from "./interfaces/IPositionManager.sol";
import {ILiquidityPool} from "./interfaces/ILiquidityPool.sol";

/// @title GoldLeverageRouter
/// @notice Unified entry point for the Paimon Gold Protocol
/// @dev UUPS upgradeable with AccessControl and Pausable
contract GoldLeverageRouter is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    IGoldLeverageRouter
{
    // ============ Constants ============

    /// @notice Admin role - can update contract addresses and unpause
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Pauser role - can pause the protocol
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Keeper role - for automated operations
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    /// @notice Upgrader role - can upgrade the contract
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // ============ State Variables ============

    /// @notice PositionManager contract address
    address private _positionManager;

    /// @notice LiquidityPool contract address
    address private _liquidityPool;

    /// @notice CollateralVault contract address
    address private _collateralVault;

    // ============ Constructor ============

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ============ Initializer ============

    /// @notice Initialize the router
    /// @param positionManager_ PositionManager contract address
    /// @param liquidityPool_ LiquidityPool contract address
    /// @param collateralVault_ CollateralVault contract address
    function initialize(
        address positionManager_,
        address liquidityPool_,
        address collateralVault_
    ) external initializer {
        if (positionManager_ == address(0)) revert ZeroAddress();
        if (liquidityPool_ == address(0)) revert ZeroAddress();
        if (collateralVault_ == address(0)) revert ZeroAddress();

        __AccessControl_init();
        __Pausable_init();

        _positionManager = positionManager_;
        _liquidityPool = liquidityPool_;
        _collateralVault = collateralVault_;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    // ============ Trading Functions ============

    /// @inheritdoc IGoldLeverageRouter
    function openPosition(
        address collateralToken,
        uint256 collateralAmount,
        uint256 leverage,
        bool isLong
    ) external nonReentrant whenNotPaused returns (uint256 positionId) {
        if (collateralAmount == 0) revert ZeroAmount();

        positionId = IPositionManager(_positionManager).openPosition(
            collateralToken,
            collateralAmount,
            leverage,
            isLong
        );
    }

    /// @inheritdoc IGoldLeverageRouter
    function closePosition(
        uint256 positionId,
        uint256 closeAmount
    ) external nonReentrant whenNotPaused returns (uint256 payout) {
        payout = IPositionManager(_positionManager).closePosition(positionId, closeAmount);
    }

    /// @inheritdoc IGoldLeverageRouter
    function addMargin(uint256 positionId, uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        IPositionManager(_positionManager).addMargin(positionId, amount);
    }

    /// @inheritdoc IGoldLeverageRouter
    function removeMargin(uint256 positionId, uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        IPositionManager(_positionManager).removeMargin(positionId, amount);
    }

    // ============ LP Functions ============

    /// @inheritdoc IGoldLeverageRouter
    function addLiquidity(
        address token,
        uint256 amount
    ) external nonReentrant whenNotPaused returns (uint256 lpAmount) {
        if (amount == 0) revert ZeroAmount();
        lpAmount = ILiquidityPool(_liquidityPool).addLiquidity(token, amount);
    }

    /// @inheritdoc IGoldLeverageRouter
    function removeLiquidity(
        uint256 lpAmount
    ) external nonReentrant whenNotPaused returns (uint256 assetAmount, uint256 feeReward) {
        if (lpAmount == 0) revert ZeroAmount();
        (assetAmount, feeReward) = ILiquidityPool(_liquidityPool).removeLiquidity(lpAmount);
    }

    /// @inheritdoc IGoldLeverageRouter
    function claimFees() external nonReentrant whenNotPaused returns (uint256 feeAmount) {
        feeAmount = ILiquidityPool(_liquidityPool).claimFees();
    }

    // ============ View Functions ============

    /// @inheritdoc IGoldLeverageRouter
    function getPosition(
        uint256 positionId
    ) external view returns (IPositionManager.Position memory position) {
        return IPositionManager(_positionManager).getPosition(positionId);
    }

    /// @inheritdoc IGoldLeverageRouter
    function getUserPositions(
        address owner
    ) external view returns (uint256[] memory positionIds) {
        return IPositionManager(_positionManager).getPositionsByOwner(owner);
    }

    /// @inheritdoc IGoldLeverageRouter
    function getHealthFactor(uint256 positionId) external view returns (uint256 healthFactor) {
        return IPositionManager(_positionManager).getHealthFactor(positionId);
    }

    /// @inheritdoc IGoldLeverageRouter
    function calculatePnL(uint256 positionId) external view returns (int256 pnl) {
        return IPositionManager(_positionManager).calculatePnL(positionId);
    }

    /// @inheritdoc IGoldLeverageRouter
    function getPendingFees(address user) external view returns (uint256 pendingFees) {
        return ILiquidityPool(_liquidityPool).pendingFees(user);
    }

    /// @inheritdoc IGoldLeverageRouter
    function getUserLPInfo(
        address user
    ) external view returns (ILiquidityPool.UserInfo memory info) {
        return ILiquidityPool(_liquidityPool).getUserInfo(user);
    }

    /// @inheritdoc IGoldLeverageRouter
    function getPoolTVL() external view returns (uint256 totalValue) {
        return ILiquidityPool(_liquidityPool).getTotalPoolValue();
    }

    // ============ Admin Functions ============

    /// @inheritdoc IGoldLeverageRouter
    function setPositionManager(address manager) external onlyRole(ADMIN_ROLE) {
        if (manager == address(0)) revert ZeroAddress();

        address oldManager = _positionManager;
        _positionManager = manager;

        emit PositionManagerSet(oldManager, manager);
    }

    /// @inheritdoc IGoldLeverageRouter
    function setLiquidityPool(address pool) external onlyRole(ADMIN_ROLE) {
        if (pool == address(0)) revert ZeroAddress();

        address oldPool = _liquidityPool;
        _liquidityPool = pool;

        emit LiquidityPoolSet(oldPool, pool);
    }

    /// @inheritdoc IGoldLeverageRouter
    function setCollateralVault(address vault) external onlyRole(ADMIN_ROLE) {
        if (vault == address(0)) revert ZeroAddress();

        address oldVault = _collateralVault;
        _collateralVault = vault;

        emit CollateralVaultSet(oldVault, vault);
    }

    /// @inheritdoc IGoldLeverageRouter
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
        emit EmergencyPause(msg.sender, block.timestamp);
    }

    /// @inheritdoc IGoldLeverageRouter
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
        emit EmergencyUnpause(msg.sender, block.timestamp);
    }

    // ============ Getters ============

    /// @inheritdoc IGoldLeverageRouter
    function positionManager() external view returns (address) {
        return _positionManager;
    }

    /// @inheritdoc IGoldLeverageRouter
    function liquidityPool() external view returns (address) {
        return _liquidityPool;
    }

    /// @inheritdoc IGoldLeverageRouter
    function collateralVault() external view returns (address) {
        return _collateralVault;
    }

    // ============ Internal Functions ============

    /// @notice Authorize upgrade to new implementation
    /// @param newImplementation Address of new implementation
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}
}
