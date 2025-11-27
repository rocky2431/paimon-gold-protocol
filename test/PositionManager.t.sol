// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PositionManager} from "../src/PositionManager.sol";
import {IPositionManager} from "../src/interfaces/IPositionManager.sol";
import {OracleAdapter} from "../src/OracleAdapter.sol";
import {CollateralVault} from "../src/CollateralVault.sol";
import {IChainlinkAggregator} from "../src/interfaces/IChainlinkAggregator.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockERC20
/// @notice Mock ERC20 token for testing
contract MockERC20 is ERC20 {
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
contract MockChainlinkAggregator is IChainlinkAggregator {
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

/// @title PositionManagerTest
/// @notice Comprehensive test suite for PositionManager
contract PositionManagerTest is Test {
    PositionManager public positionManager;
    OracleAdapter public oracle;
    CollateralVault public vault;
    MockERC20 public usdt;
    MockChainlinkAggregator public mockAggregator;

    address public owner;
    address public user1;
    address public user2;

    // XAU/USD price: $2,000 per ounce (8 decimals from Chainlink)
    int256 constant INITIAL_PRICE = 2000_00000000; // $2,000.00
    uint8 constant CHAINLINK_DECIMALS = 8;

    uint256 constant INITIAL_BALANCE = 100_000 * 1e18; // 100k USDT
    uint256 constant COLLATERAL_AMOUNT = 1_000 * 1e18; // $1,000 collateral

    // Events
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

    event PositionClosed(
        uint256 indexed positionId,
        address indexed owner,
        uint256 exitPrice,
        int256 pnl,
        uint256 payout
    );

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy mock aggregator
        mockAggregator = new MockChainlinkAggregator(INITIAL_PRICE, CHAINLINK_DECIMALS);

        // Deploy oracle
        oracle = new OracleAdapter(address(mockAggregator));

        // Deploy vault
        vault = new CollateralVault();

        // Deploy mock USDT
        usdt = new MockERC20("Tether USD", "USDT", 18);

        // Whitelist USDT in vault
        vault.setTokenWhitelist(address(usdt), true);

        // Deploy PositionManager
        positionManager = new PositionManager(address(oracle), address(vault));

        // Setup vault permissions for PositionManager
        vault.setTokenWhitelist(address(usdt), true);

        // Mint tokens to users
        usdt.mint(user1, INITIAL_BALANCE);
        usdt.mint(user2, INITIAL_BALANCE);

        // Approve PositionManager for token transfers
        vm.prank(user1);
        usdt.approve(address(positionManager), type(uint256).max);

        vm.prank(user2);
        usdt.approve(address(positionManager), type(uint256).max);

        // Mint extra tokens to PositionManager for profit payouts (liquidity pool simulation)
        usdt.mint(address(positionManager), 100_000 * 1e18);
    }

    // ============ Functional Tests ============

    function test_OpenLongPosition() public {
        vm.prank(user1);
        uint256 positionId = positionManager.openPosition(
            address(usdt),
            COLLATERAL_AMOUNT,
            10, // 10x leverage
            true // long
        );

        IPositionManager.Position memory pos = positionManager.getPosition(positionId);

        assertEq(pos.id, positionId);
        assertEq(pos.owner, user1);
        assertEq(pos.collateralToken, address(usdt));
        assertEq(pos.collateralAmount, COLLATERAL_AMOUNT);
        assertEq(pos.size, COLLATERAL_AMOUNT * 10); // 10x leverage
        assertEq(pos.entryPrice, 2000 * 1e18); // Normalized to 18 decimals
        assertEq(pos.leverage, 10);
        assertTrue(pos.isLong);
    }

    function test_OpenShortPosition() public {
        vm.prank(user1);
        uint256 positionId = positionManager.openPosition(
            address(usdt),
            COLLATERAL_AMOUNT,
            5, // 5x leverage
            false // short
        );

        IPositionManager.Position memory pos = positionManager.getPosition(positionId);

        assertEq(pos.leverage, 5);
        assertFalse(pos.isLong);
        assertEq(pos.size, COLLATERAL_AMOUNT * 5);
    }

    function test_ClosePositionWithProfit_Long() public {
        // Open long at $2,000
        vm.prank(user1);
        uint256 positionId = positionManager.openPosition(
            address(usdt),
            COLLATERAL_AMOUNT,
            10,
            true
        );

        // Price increases to $2,100 (5% increase)
        mockAggregator.setPrice(2100_00000000);

        // Skip blocks for flash loan protection
        vm.roll(block.number + 11);

        uint256 balanceBefore = usdt.balanceOf(user1);

        vm.prank(user1);
        uint256 payout = positionManager.closePosition(positionId, type(uint256).max);

        uint256 balanceAfter = usdt.balanceOf(user1);

        // PnL = size * (exitPrice - entryPrice) / entryPrice
        // PnL = 10_000 * (2100 - 2000) / 2000 = 10_000 * 0.05 = 500
        // Payout = collateral + PnL = 1000 + 500 = 1500
        assertEq(payout, 1500 * 1e18);
        assertEq(balanceAfter - balanceBefore, 1500 * 1e18);
    }

    function test_ClosePositionWithLoss_Long() public {
        // Open long at $2,000
        vm.prank(user1);
        uint256 positionId = positionManager.openPosition(
            address(usdt),
            COLLATERAL_AMOUNT,
            10,
            true
        );

        // Price decreases to $1,900 (5% decrease)
        mockAggregator.setPrice(1900_00000000);

        vm.roll(block.number + 11);

        vm.prank(user1);
        uint256 payout = positionManager.closePosition(positionId, type(uint256).max);

        // PnL = 10_000 * (1900 - 2000) / 2000 = 10_000 * (-0.05) = -500
        // Payout = collateral + PnL = 1000 - 500 = 500
        assertEq(payout, 500 * 1e18);
    }

    function test_ClosePositionWithProfit_Short() public {
        // Open short at $2,000
        vm.prank(user1);
        uint256 positionId = positionManager.openPosition(
            address(usdt),
            COLLATERAL_AMOUNT,
            10,
            false // short
        );

        // Price decreases to $1,900 (5% decrease) - profit for short
        mockAggregator.setPrice(1900_00000000);

        vm.roll(block.number + 11);

        vm.prank(user1);
        uint256 payout = positionManager.closePosition(positionId, type(uint256).max);

        // PnL = size * (entryPrice - exitPrice) / entryPrice
        // PnL = 10_000 * (2000 - 1900) / 2000 = 10_000 * 0.05 = 500
        // Payout = collateral + PnL = 1000 + 500 = 1500
        assertEq(payout, 1500 * 1e18);
    }

    function test_ClosePositionWithLoss_Short() public {
        // Open short at $2,000
        vm.prank(user1);
        uint256 positionId = positionManager.openPosition(
            address(usdt),
            COLLATERAL_AMOUNT,
            10,
            false // short
        );

        // Price increases to $2,100 (5% increase) - loss for short
        mockAggregator.setPrice(2100_00000000);

        vm.roll(block.number + 11);

        vm.prank(user1);
        uint256 payout = positionManager.closePosition(positionId, type(uint256).max);

        // PnL = 10_000 * (2000 - 2100) / 2000 = 10_000 * (-0.05) = -500
        // Payout = collateral + PnL = 1000 - 500 = 500
        assertEq(payout, 500 * 1e18);
    }

    function test_PartialClose() public {
        vm.prank(user1);
        uint256 positionId = positionManager.openPosition(
            address(usdt),
            COLLATERAL_AMOUNT,
            10,
            true
        );

        vm.roll(block.number + 11);

        // Close 50% of position
        uint256 halfSize = COLLATERAL_AMOUNT * 10 / 2;

        vm.prank(user1);
        positionManager.closePosition(positionId, halfSize);

        IPositionManager.Position memory pos = positionManager.getPosition(positionId);

        // Position should still exist with remaining size
        assertEq(pos.size, halfSize);
        assertEq(pos.collateralAmount, COLLATERAL_AMOUNT / 2);
    }

    function test_OpenPositionEmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit PositionOpened(
            1, // first position ID
            user1,
            address(usdt),
            COLLATERAL_AMOUNT,
            COLLATERAL_AMOUNT * 10, // size
            2000 * 1e18, // entry price
            10, // leverage
            true // isLong
        );

        vm.prank(user1);
        positionManager.openPosition(address(usdt), COLLATERAL_AMOUNT, 10, true);
    }

    function test_GetPositionsByOwner() public {
        vm.startPrank(user1);
        positionManager.openPosition(address(usdt), COLLATERAL_AMOUNT, 10, true);
        positionManager.openPosition(address(usdt), COLLATERAL_AMOUNT, 5, false);
        vm.stopPrank();

        uint256[] memory positions = positionManager.getPositionsByOwner(user1);
        assertEq(positions.length, 2);
    }

    // ============ Boundary Tests ============

    function test_MinLeverage() public {
        vm.prank(user1);
        uint256 positionId = positionManager.openPosition(
            address(usdt),
            COLLATERAL_AMOUNT,
            2, // minimum leverage
            true
        );

        IPositionManager.Position memory pos = positionManager.getPosition(positionId);
        assertEq(pos.leverage, 2);
        assertEq(pos.size, COLLATERAL_AMOUNT * 2);
    }

    function test_MaxLeverage() public {
        vm.prank(user1);
        uint256 positionId = positionManager.openPosition(
            address(usdt),
            COLLATERAL_AMOUNT,
            20, // maximum leverage
            true
        );

        IPositionManager.Position memory pos = positionManager.getPosition(positionId);
        assertEq(pos.leverage, 20);
        assertEq(pos.size, COLLATERAL_AMOUNT * 20);
    }

    function test_MinPositionSize() public {
        // Minimum position size is $10
        // With 10x leverage, minimum collateral = $1
        uint256 minCollateral = 1 * 1e18; // $1

        vm.prank(user1);
        uint256 positionId = positionManager.openPosition(
            address(usdt),
            minCollateral,
            10,
            true
        );

        IPositionManager.Position memory pos = positionManager.getPosition(positionId);
        assertEq(pos.size, 10 * 1e18); // $10 minimum
    }

    function test_LiquidationScenario() public {
        // Increase oracle deviation threshold for this test
        oracle.setDeviationThreshold(2000); // 20%

        // Open position with 10x leverage
        vm.prank(user1);
        uint256 positionId = positionManager.openPosition(
            address(usdt),
            COLLATERAL_AMOUNT,
            10,
            true
        );

        // Price drops 15% - loss exceeds collateral at 10x leverage
        // Loss = 10_000 * 0.15 = 1500 > 1000 collateral
        mockAggregator.setPrice(1700_00000000); // $1,700 (15% drop)

        vm.roll(block.number + 11);

        vm.prank(user1);
        uint256 payout = positionManager.closePosition(positionId, type(uint256).max);

        // Payout should be 0 (liquidation scenario)
        assertEq(payout, 0);
    }

    function testFuzz_LeverageBounds(uint256 leverage) public {
        leverage = bound(leverage, 2, 20);

        vm.prank(user1);
        uint256 positionId = positionManager.openPosition(
            address(usdt),
            COLLATERAL_AMOUNT,
            leverage,
            true
        );

        IPositionManager.Position memory pos = positionManager.getPosition(positionId);
        assertEq(pos.leverage, leverage);
    }

    // ============ Exception Tests ============

    function test_RevertOnLeverageTooLow() public {
        vm.prank(user1);
        vm.expectRevert(IPositionManager.InvalidLeverage.selector);
        positionManager.openPosition(address(usdt), COLLATERAL_AMOUNT, 1, true);
    }

    function test_RevertOnLeverageTooHigh() public {
        vm.prank(user1);
        vm.expectRevert(IPositionManager.InvalidLeverage.selector);
        positionManager.openPosition(address(usdt), COLLATERAL_AMOUNT, 21, true);
    }

    function test_RevertOnPositionTooSmall() public {
        // Position size = collateral * leverage
        // Need size >= $10, so with 10x: collateral >= $1
        // With $0.5 collateral at 10x = $5 position size (too small)
        uint256 tinyCollateral = 0.5 * 1e18;

        vm.prank(user1);
        vm.expectRevert(IPositionManager.PositionTooSmall.selector);
        positionManager.openPosition(address(usdt), tinyCollateral, 10, true);
    }

    function test_RevertOnCloseNonExistentPosition() public {
        vm.prank(user1);
        vm.expectRevert(IPositionManager.PositionNotFound.selector);
        positionManager.closePosition(999, type(uint256).max);
    }

    function test_RevertOnCloseOthersPosition() public {
        vm.prank(user1);
        uint256 positionId = positionManager.openPosition(
            address(usdt),
            COLLATERAL_AMOUNT,
            10,
            true
        );

        vm.roll(block.number + 11);

        vm.prank(user2);
        vm.expectRevert(IPositionManager.NotPositionOwner.selector);
        positionManager.closePosition(positionId, type(uint256).max);
    }

    function test_RevertOnFlashLoanAttack() public {
        vm.prank(user1);
        uint256 positionId = positionManager.openPosition(
            address(usdt),
            COLLATERAL_AMOUNT,
            10,
            true
        );

        // Try to close in same block (flash loan attack)
        vm.prank(user1);
        vm.expectRevert(IPositionManager.PositionTooNew.selector);
        positionManager.closePosition(positionId, type(uint256).max);
    }

    function test_RevertOnCloseAmountExceedsSize() public {
        vm.prank(user1);
        uint256 positionId = positionManager.openPosition(
            address(usdt),
            COLLATERAL_AMOUNT,
            10,
            true
        );

        vm.roll(block.number + 11);

        // Position size is 10_000, try to close 15_000
        vm.prank(user1);
        vm.expectRevert(IPositionManager.InvalidCloseAmount.selector);
        positionManager.closePosition(positionId, 15_000 * 1e18);
    }

    // ============ Security Tests ============

    function test_FlashLoanProtection() public {
        uint256 startBlock = block.number;

        vm.prank(user1);
        uint256 positionId = positionManager.openPosition(
            address(usdt),
            COLLATERAL_AMOUNT,
            10,
            true
        );

        // Position opened at startBlock
        // Must wait MIN_HOLD_BLOCKS (10) before closing
        // So can close at startBlock + 11 or later

        // Attempt close at various block numbers (should all revert)
        for (uint256 i = 1; i <= 10; i++) {
            vm.roll(startBlock + i);
            vm.prank(user1);
            vm.expectRevert(IPositionManager.PositionTooNew.selector);
            positionManager.closePosition(positionId, type(uint256).max);
        }

        // At block startBlock + 11, should succeed
        vm.roll(startBlock + 11);
        vm.prank(user1);
        positionManager.closePosition(positionId, type(uint256).max);
    }

    function test_OnlyOwnerCanPause() public {
        vm.prank(user1);
        vm.expectRevert();
        positionManager.pause();
    }

    function test_CannotOpenPositionWhenPaused() public {
        positionManager.pause();

        vm.prank(user1);
        vm.expectRevert();
        positionManager.openPosition(address(usdt), COLLATERAL_AMOUNT, 10, true);
    }

    // ============ PnL Calculation Tests ============

    function test_CalculatePnL_Long_Profit() public {
        vm.prank(user1);
        uint256 positionId = positionManager.openPosition(
            address(usdt),
            COLLATERAL_AMOUNT,
            10,
            true
        );

        // Price up 10%
        mockAggregator.setPrice(2200_00000000);

        int256 pnl = positionManager.calculatePnL(positionId);

        // PnL = 10_000 * (2200 - 2000) / 2000 = 1000
        assertEq(pnl, int256(1000 * 1e18));
    }

    function test_CalculatePnL_Long_Loss() public {
        vm.prank(user1);
        uint256 positionId = positionManager.openPosition(
            address(usdt),
            COLLATERAL_AMOUNT,
            10,
            true
        );

        // Price down 10%
        mockAggregator.setPrice(1800_00000000);

        int256 pnl = positionManager.calculatePnL(positionId);

        // PnL = 10_000 * (1800 - 2000) / 2000 = -1000
        assertEq(pnl, -int256(1000 * 1e18));
    }

    function test_CalculatePnL_Short_Profit() public {
        vm.prank(user1);
        uint256 positionId = positionManager.openPosition(
            address(usdt),
            COLLATERAL_AMOUNT,
            10,
            false // short
        );

        // Price down 10% - profit for short
        mockAggregator.setPrice(1800_00000000);

        int256 pnl = positionManager.calculatePnL(positionId);

        // PnL = 10_000 * (2000 - 1800) / 2000 = 1000
        assertEq(pnl, int256(1000 * 1e18));
    }

    function test_GetHealthFactor() public {
        vm.prank(user1);
        uint256 positionId = positionManager.openPosition(
            address(usdt),
            COLLATERAL_AMOUNT,
            10,
            true
        );

        uint256 healthFactor = positionManager.getHealthFactor(positionId);

        // At opening, health factor should be around 100% (1e18)
        // collateral = 1000, size = 10000, HF = collateral / (size / leverage) = 1000 / 1000 = 1
        assertEq(healthFactor, 1e18);
    }

    function test_HealthFactorDecreasesOnLoss() public {
        vm.prank(user1);
        uint256 positionId = positionManager.openPosition(
            address(usdt),
            COLLATERAL_AMOUNT,
            10,
            true
        );

        // Price drops 5%
        mockAggregator.setPrice(1900_00000000);

        uint256 healthFactor = positionManager.getHealthFactor(positionId);

        // HF should be less than 1e18 (100%)
        // collateral = 1000, PnL = -500, effective collateral = 500
        // HF = 500 / 1000 = 0.5e18
        assertEq(healthFactor, 0.5e18);
    }

    // ============ Gas Tests ============

    function test_OpenPositionGas() public {
        vm.prank(user1);
        uint256 gasBefore = gasleft();
        positionManager.openPosition(address(usdt), COLLATERAL_AMOUNT, 10, true);
        uint256 gasUsed = gasBefore - gasleft();

        // Should be under 400,000 gas
        assertLt(gasUsed, 400000);
    }

    function test_ClosePositionGas() public {
        vm.prank(user1);
        uint256 positionId = positionManager.openPosition(
            address(usdt),
            COLLATERAL_AMOUNT,
            10,
            true
        );

        vm.roll(block.number + 11);

        vm.prank(user1);
        uint256 gasBefore = gasleft();
        positionManager.closePosition(positionId, type(uint256).max);
        uint256 gasUsed = gasBefore - gasleft();

        // Should be under 200,000 gas
        assertLt(gasUsed, 200000);
    }
}
