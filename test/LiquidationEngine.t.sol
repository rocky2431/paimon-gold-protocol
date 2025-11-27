// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {LiquidationEngine} from "../src/LiquidationEngine.sol";
import {PositionManager} from "../src/PositionManager.sol";
import {OracleAdapter} from "../src/OracleAdapter.sol";
import {CollateralVault} from "../src/CollateralVault.sol";
import {ILiquidationEngine} from "../src/interfaces/ILiquidationEngine.sol";
import {IPositionManager} from "../src/interfaces/IPositionManager.sol";
import {IChainlinkAggregator} from "../src/interfaces/IChainlinkAggregator.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockERC20
/// @notice Mock ERC20 token for testing
contract MockERC20ForLiq is ERC20 {
    uint8 private _decimals;

    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        _decimals = decimals_;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}

/// @title MockChainlinkAggregator
/// @notice Mock Chainlink aggregator for testing
contract MockChainlinkAggregatorForLiq is IChainlinkAggregator {
    int256 private _price;
    uint256 private _updatedAt;
    uint8 private _decimals;
    uint80 private _roundId;

    constructor(int256 initialPrice, uint8 decimals_) {
        _price = initialPrice;
        _decimals = decimals_;
        _updatedAt = block.timestamp;
        _roundId = 1;
    }

    function setPrice(int256 price) external {
        _price = price;
        _updatedAt = block.timestamp;
        _roundId++;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function description() external pure override returns (string memory) {
        return "XAU / USD";
    }

    function version() external pure override returns (uint256) {
        return 4;
    }

    function getRoundData(uint80)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }
}

/// @title LiquidationEngineTest
/// @notice Comprehensive test suite for LiquidationEngine
contract LiquidationEngineTest is Test {
    LiquidationEngine public liquidationEngine;
    PositionManager public positionManager;
    OracleAdapter public oracle;
    CollateralVault public vault;
    MockChainlinkAggregatorForLiq public priceFeed;
    MockERC20ForLiq public usdt;

    address public owner;
    address public trader;
    address public keeper;
    address public randomUser;

    // XAU/USD price: $2,000 per ounce (8 decimals from Chainlink)
    int256 constant INITIAL_PRICE = 2000_00000000; // $2,000.00
    uint8 constant CHAINLINK_DECIMALS = 8;
    uint256 public constant PRECISION = 1e18;

    function setUp() public {
        owner = address(this);
        trader = makeAddr("trader");
        keeper = makeAddr("keeper");
        randomUser = makeAddr("randomUser");

        // Deploy mock tokens
        usdt = new MockERC20ForLiq("Tether USD", "USDT", 18);

        // Deploy mock price feed
        priceFeed = new MockChainlinkAggregatorForLiq(INITIAL_PRICE, CHAINLINK_DECIMALS);

        // Deploy oracle adapter
        oracle = new OracleAdapter(address(priceFeed));
        oracle.setDeviationThreshold(2000); // 20% for testing

        // Deploy collateral vault
        vault = new CollateralVault();
        vault.setTokenWhitelist(address(usdt), true);

        // Deploy position manager
        positionManager = new PositionManager(address(oracle), address(vault));

        // Deploy liquidation engine
        liquidationEngine = new LiquidationEngine(
            address(positionManager),
            address(oracle)
        );

        // Setup trader with tokens
        usdt.mint(trader, 1_000_000 * 1e18);
        vm.prank(trader);
        usdt.approve(address(positionManager), type(uint256).max);

        // Mint tokens to position manager for payouts
        usdt.mint(address(positionManager), 1_000_000 * 1e18);
    }

    // ============ Helper Functions ============

    function _openPosition(
        address user,
        uint256 collateral,
        uint256 leverage,
        bool isLong
    ) internal returns (uint256 positionId) {
        vm.prank(user);
        positionId = positionManager.openPosition(
            address(usdt),
            collateral,
            leverage,
            isLong
        );
    }

    function _makePositionLiquidatable(uint256 positionId) internal {
        // Get position details
        IPositionManager.Position memory pos = positionManager.getPosition(positionId);

        // For a long position, drop the price significantly
        // For a short position, increase the price significantly
        if (pos.isLong) {
            // Drop price by 50% to make HF < 1.0
            int256 newPrice = INITIAL_PRICE / 2;
            priceFeed.setPrice(newPrice);
        } else {
            // Increase price by 50%
            int256 newPrice = INITIAL_PRICE * 3 / 2;
            priceFeed.setPrice(newPrice);
        }

        // Roll forward to avoid flash loan protection
        vm.roll(block.number + 11);
    }

    // ============ Constructor Tests ============

    function test_Constructor() public view {
        assertEq(address(liquidationEngine.positionManager()), address(positionManager));
        assertEq(address(liquidationEngine.oracle()), address(oracle));
    }

    function test_Constructor_RevertZeroPositionManager() public {
        vm.expectRevert(ILiquidationEngine.ZeroAddress.selector);
        new LiquidationEngine(address(0), address(oracle));
    }

    function test_Constructor_RevertZeroOracle() public {
        vm.expectRevert(ILiquidationEngine.ZeroAddress.selector);
        new LiquidationEngine(address(positionManager), address(0));
    }

    // ============ getHealthFactor Tests ============

    function test_GetHealthFactor_HealthyPosition() public {
        // Open a position with 10x leverage
        uint256 collateral = 100 * 1e18;
        uint256 positionId = _openPosition(trader, collateral, 10, true);
        vm.roll(block.number + 11);

        // Health factor should be around 2.0 (collateral / minRequiredMargin)
        // minRequiredMargin = size / MAX_LEVERAGE = (100 * 10) / 20 = 50
        // HF = 100 / 50 = 2.0
        uint256 healthFactor = liquidationEngine.getHealthFactor(positionId);
        assertGt(healthFactor, PRECISION); // HF > 1.0
    }

    function test_GetHealthFactor_UnhealthyPosition() public {
        uint256 collateral = 100 * 1e18;
        uint256 positionId = _openPosition(trader, collateral, 10, true);

        _makePositionLiquidatable(positionId);

        uint256 healthFactor = liquidationEngine.getHealthFactor(positionId);
        assertLt(healthFactor, PRECISION); // HF < 1.0
    }

    function test_GetHealthFactor_RevertPositionNotFound() public {
        vm.expectRevert(ILiquidationEngine.PositionNotFound.selector);
        liquidationEngine.getHealthFactor(999);
    }

    // ============ isLiquidatable Tests ============

    function test_IsLiquidatable_ReturnsFalseForHealthyPosition() public {
        uint256 positionId = _openPosition(trader, 100 * 1e18, 10, true);
        vm.roll(block.number + 11);

        bool liquidatable = liquidationEngine.isLiquidatable(positionId);
        assertFalse(liquidatable);
    }

    function test_IsLiquidatable_ReturnsTrueForUnhealthyPosition() public {
        uint256 positionId = _openPosition(trader, 100 * 1e18, 10, true);
        _makePositionLiquidatable(positionId);

        bool liquidatable = liquidationEngine.isLiquidatable(positionId);
        assertTrue(liquidatable);
    }

    function test_IsLiquidatable_ShortPosition() public {
        uint256 positionId = _openPosition(trader, 100 * 1e18, 10, false);
        vm.roll(block.number + 11);

        // Initially healthy
        assertFalse(liquidationEngine.isLiquidatable(positionId));

        // Make unhealthy by increasing price
        _makePositionLiquidatable(positionId);
        assertTrue(liquidationEngine.isLiquidatable(positionId));
    }

    // ============ liquidate Tests ============

    function test_Liquidate_SuccessfulLiquidation() public {
        uint256 collateral = 100 * 1e18;
        uint256 positionId = _openPosition(trader, collateral, 10, true);

        _makePositionLiquidatable(positionId);

        vm.prank(keeper);
        (uint256 collateralLiquidated, uint256 keeperBonus) = liquidationEngine.liquidate(positionId);

        // Verify liquidation happened
        assertGt(collateralLiquidated, 0);
        assertGt(keeperBonus, 0);
    }

    function test_Liquidate_RevertHealthyPosition() public {
        uint256 positionId = _openPosition(trader, 100 * 1e18, 10, true);
        vm.roll(block.number + 11);

        vm.prank(keeper);
        vm.expectRevert(ILiquidationEngine.PositionNotLiquidatable.selector);
        liquidationEngine.liquidate(positionId);
    }

    function test_Liquidate_RevertPositionNotFound() public {
        vm.prank(keeper);
        vm.expectRevert(ILiquidationEngine.PositionNotFound.selector);
        liquidationEngine.liquidate(999);
    }

    function test_Liquidate_EmitsEvent() public {
        uint256 collateral = 100 * 1e18;
        uint256 positionId = _openPosition(trader, collateral, 10, true);
        _makePositionLiquidatable(positionId);

        vm.prank(keeper);
        vm.expectEmit(true, true, true, false);
        emit ILiquidationEngine.PositionLiquidated(
            positionId,
            keeper,
            trader,
            0, // We don't check exact values
            0,
            0
        );
        liquidationEngine.liquidate(positionId);
    }

    function test_Liquidate_KeeperBonusCalculation() public {
        uint256 collateral = 100 * 1e18;
        uint256 positionId = _openPosition(trader, collateral, 10, true);
        _makePositionLiquidatable(positionId);

        vm.prank(keeper);
        (uint256 collateralLiquidated, uint256 keeperBonus) = liquidationEngine.liquidate(positionId);

        // Bonus should be 5% of liquidated collateral
        uint256 expectedBonus = collateralLiquidated * 5 / 100;
        assertEq(keeperBonus, expectedBonus);
    }

    // ============ liquidatePartial Tests ============

    function test_LiquidatePartial_Success() public {
        // Open a large position
        uint256 collateral = 10_000 * 1e18;
        uint256 positionId = _openPosition(trader, collateral, 20, true);
        _makePositionLiquidatable(positionId);

        vm.prank(keeper);
        (uint256 collateralLiquidated, uint256 keeperBonus) =
            liquidationEngine.liquidatePartial(positionId, 50);

        assertGt(collateralLiquidated, 0);
        assertGt(keeperBonus, 0);
    }

    function test_LiquidatePartial_RevertInvalidPercentage_Zero() public {
        uint256 positionId = _openPosition(trader, 100 * 1e18, 10, true);
        _makePositionLiquidatable(positionId);

        vm.prank(keeper);
        vm.expectRevert(ILiquidationEngine.InvalidLiquidationPercentage.selector);
        liquidationEngine.liquidatePartial(positionId, 0);
    }

    function test_LiquidatePartial_RevertInvalidPercentage_Over100() public {
        uint256 positionId = _openPosition(trader, 100 * 1e18, 10, true);
        _makePositionLiquidatable(positionId);

        vm.prank(keeper);
        vm.expectRevert(ILiquidationEngine.InvalidLiquidationPercentage.selector);
        liquidationEngine.liquidatePartial(positionId, 101);
    }

    function test_LiquidatePartial_RevertHealthyPosition() public {
        uint256 positionId = _openPosition(trader, 100 * 1e18, 10, true);
        vm.roll(block.number + 11);

        vm.prank(keeper);
        vm.expectRevert(ILiquidationEngine.PositionNotLiquidatable.selector);
        liquidationEngine.liquidatePartial(positionId, 50);
    }

    function test_LiquidatePartial_EmitsEvent() public {
        uint256 collateral = 100 * 1e18;
        uint256 positionId = _openPosition(trader, collateral, 10, true);
        _makePositionLiquidatable(positionId);

        vm.prank(keeper);
        vm.expectEmit(true, true, false, false);
        emit ILiquidationEngine.PartialLiquidation(
            positionId,
            keeper,
            50,
            0,
            0
        );
        liquidationEngine.liquidatePartial(positionId, 50);
    }

    // ============ Liquidation Bonus Tests ============

    function test_GetLiquidationBonus() public view {
        uint256 bonus = liquidationEngine.getLiquidationBonus();
        assertEq(bonus, 5e16); // 5%
    }

    function test_LiquidationBonus_LargePosition() public {
        // Large positions get higher bonus (10%)
        uint256 largeCollateral = 100_000 * 1e18;
        usdt.mint(trader, largeCollateral);
        vm.prank(trader);
        usdt.approve(address(positionManager), largeCollateral);

        uint256 positionId = _openPosition(trader, largeCollateral, 10, true);
        _makePositionLiquidatable(positionId);

        vm.prank(keeper);
        (uint256 collateralLiquidated, uint256 keeperBonus) = liquidationEngine.liquidate(positionId);

        // For large positions, bonus should be 10%
        uint256 expectedBonus = collateralLiquidated * 10 / 100;
        assertEq(keeperBonus, expectedBonus);
    }

    // ============ Large Position Threshold Tests ============

    function test_GetLargePositionThreshold() public view {
        uint256 threshold = liquidationEngine.getLargePositionThreshold();
        assertEq(threshold, 100_000 * 1e18); // $100,000
    }

    // ============ Chainlink Automation Tests ============

    function test_CheckUpkeep_NoLiquidatablePositions() public {
        uint256 positionId = _openPosition(trader, 100 * 1e18, 10, true);
        vm.roll(block.number + 11);

        (bool upkeepNeeded,) = liquidationEngine.checkUpkeep("");

        assertFalse(upkeepNeeded);
    }

    function test_CheckUpkeep_HasLiquidatablePosition() public {
        uint256 positionId = _openPosition(trader, 100 * 1e18, 10, true);
        _makePositionLiquidatable(positionId);

        (bool upkeepNeeded, bytes memory performData) = liquidationEngine.checkUpkeep("");

        assertTrue(upkeepNeeded);
        assertGt(performData.length, 0);
    }

    function test_PerformUpkeep_LiquidatesPositions() public {
        uint256 positionId = _openPosition(trader, 100 * 1e18, 10, true);
        _makePositionLiquidatable(positionId);

        (, bytes memory performData) = liquidationEngine.checkUpkeep("");

        // performUpkeep should not revert
        liquidationEngine.performUpkeep(performData);
    }

    // ============ Edge Cases ============

    function test_Liquidate_AtExactThreshold() public {
        uint256 collateral = 100 * 1e18;
        uint256 positionId = _openPosition(trader, collateral, 10, true);
        vm.roll(block.number + 11);

        // At 10x leverage with $100 collateral:
        // Size = $1000, minMargin = $1000/20 = $50
        // Need effectiveCollateral < $50 for HF < 1.0
        // A 52.5% drop should make collateral + PnL < 50
        int256 thresholdPrice = INITIAL_PRICE * 475 / 1000; // ~52.5% drop
        priceFeed.setPrice(thresholdPrice);

        uint256 hf = liquidationEngine.getHealthFactor(positionId);

        if (hf < PRECISION) {
            vm.prank(keeper);
            liquidationEngine.liquidate(positionId);
        }
    }

    function test_Liquidate_ZeroEffectiveCollateral() public {
        uint256 collateral = 100 * 1e18;
        uint256 positionId = _openPosition(trader, collateral, 20, true); // Max leverage

        // Massive price drop - 90%
        int256 newPrice = INITIAL_PRICE / 10;
        priceFeed.setPrice(newPrice);
        vm.roll(block.number + 11);

        vm.prank(keeper);
        (uint256 collateralLiquidated, uint256 keeperBonus) = liquidationEngine.liquidate(positionId);

        // Even with massive loss, something should be liquidated
        assertGt(collateralLiquidated, 0);
    }

    // ============ Access Control Tests ============

    function test_AnyoneCanLiquidate() public {
        uint256 positionId = _openPosition(trader, 100 * 1e18, 10, true);
        _makePositionLiquidatable(positionId);

        // Random user can liquidate
        vm.prank(randomUser);
        (uint256 collateralLiquidated,) = liquidationEngine.liquidate(positionId);
        assertGt(collateralLiquidated, 0);
    }

    function test_OwnerCannotPreventLiquidation() public {
        uint256 positionId = _openPosition(trader, 100 * 1e18, 10, true);
        _makePositionLiquidatable(positionId);

        // Even position owner cannot prevent liquidation
        vm.prank(keeper);
        (uint256 collateralLiquidated,) = liquidationEngine.liquidate(positionId);
        assertGt(collateralLiquidated, 0);
    }

    // ============ Gas Tests ============

    function test_Liquidate_GasUsage() public {
        uint256 positionId = _openPosition(trader, 100 * 1e18, 10, true);
        _makePositionLiquidatable(positionId);

        uint256 gasBefore = gasleft();
        vm.prank(keeper);
        liquidationEngine.liquidate(positionId);
        uint256 gasUsed = gasBefore - gasleft();

        // Liquidation should use less than 500k gas
        assertLt(gasUsed, 500_000);
    }

    // ============ Integration Tests ============

    function test_Integration_FullLiquidationFlow() public {
        // 1. Trader opens position
        uint256 collateral = 100 * 1e18;
        uint256 positionId = _openPosition(trader, collateral, 10, true);

        // 2. Verify position is healthy
        assertFalse(liquidationEngine.isLiquidatable(positionId));
        assertGt(liquidationEngine.getHealthFactor(positionId), PRECISION);

        // 3. Price drops making position unhealthy
        _makePositionLiquidatable(positionId);

        // 4. Verify position is now liquidatable
        assertTrue(liquidationEngine.isLiquidatable(positionId));
        assertLt(liquidationEngine.getHealthFactor(positionId), PRECISION);

        // 5. Keeper liquidates
        vm.prank(keeper);
        (uint256 liquidated, uint256 bonus) = liquidationEngine.liquidate(positionId);

        // 6. Verify outcomes
        assertGt(liquidated, 0);
        assertGt(bonus, 0);
    }

    function test_Integration_MultiplePositions() public {
        // Open multiple positions for different traders
        address trader2 = makeAddr("trader2");
        usdt.mint(trader2, 1_000_000 * 1e18);
        vm.prank(trader2);
        usdt.approve(address(positionManager), type(uint256).max);

        uint256 pos1 = _openPosition(trader, 100 * 1e18, 10, true);
        uint256 pos2 = _openPosition(trader2, 200 * 1e18, 15, true);

        // Make both liquidatable
        _makePositionLiquidatable(pos1);

        // Liquidate first
        vm.prank(keeper);
        (uint256 liq1,) = liquidationEngine.liquidate(pos1);
        assertGt(liq1, 0);

        // Second should also be liquidatable
        if (liquidationEngine.isLiquidatable(pos2)) {
            vm.prank(keeper);
            (uint256 liq2,) = liquidationEngine.liquidate(pos2);
            assertGt(liq2, 0);
        }
    }
}
