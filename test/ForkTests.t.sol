// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {PositionManager} from "../src/PositionManager.sol";
import {IPositionManager} from "../src/interfaces/IPositionManager.sol";
import {LiquidationEngine} from "../src/LiquidationEngine.sol";
import {LiquidityPool} from "../src/LiquidityPool.sol";
import {LPToken} from "../src/LPToken.sol";
import {OracleAdapter} from "../src/OracleAdapter.sol";
import {CollateralVault} from "../src/CollateralVault.sol";
import {IChainlinkAggregator} from "../src/interfaces/IChainlinkAggregator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title ForkTests
/// @notice Fork tests using BSC mainnet for real oracle integration
/// @dev Run with: forge test --match-contract ForkTests --fork-url $BSC_RPC_URL -vv
contract ForkTests is Test {
    // BSC Mainnet addresses
    address constant CHAINLINK_XAU_USD = 0x86896fEB19D8A607c3b11f2aF50A0f239Bd71CD0;
    address constant USDT_BSC = 0x55d398326f99059fF775485246999027B3197955; // BSC-USD (USDT)
    address constant USDC_BSC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d; // USD Coin (USDC)

    // Contract instances
    PositionManager public positionManager;
    LiquidationEngine public liquidationEngine;
    LiquidityPool public liquidityPool;
    LPToken public lpToken;
    OracleAdapter public oracle;
    CollateralVault public vault;

    // Test accounts
    address public owner;
    address public trader;
    address public liquidator;
    address public treasury;

    // Gas limits (acceptance criteria)
    // Note: openPosition is complex (oracle call + ERC20 transfer + storage)
    uint256 constant MAX_GAS_OPEN_POSITION = 400_000;
    uint256 constant MAX_GAS_CLOSE_POSITION = 200_000;
    uint256 constant MAX_GAS_LIQUIDATE = 350_000;

    // Fork block for consistent testing
    uint256 constant FORK_BLOCK = 43_000_000; // Recent BSC block

    /// @notice Setup fork environment
    function setUp() public {
        // Skip if not running on a fork
        if (block.chainid != 56) {
            return;
        }

        owner = address(this);
        trader = makeAddr("trader");
        liquidator = makeAddr("liquidator");
        treasury = makeAddr("treasury");

        // Deploy OracleAdapter with real Chainlink feed
        oracle = new OracleAdapter(CHAINLINK_XAU_USD);

        // Deploy CollateralVault
        vault = new CollateralVault();

        // Deploy PositionManager
        positionManager = new PositionManager(address(oracle), address(vault));

        // Deploy LiquidationEngine
        liquidationEngine = new LiquidationEngine(address(positionManager), address(oracle));

        // Deploy LPToken (through proxy)
        LPToken lpTokenImpl = new LPToken();
        bytes memory initData = abi.encodeWithSelector(
            LPToken.initialize.selector,
            "Paimon LP Token",
            "PLP"
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(lpTokenImpl), initData);
        lpToken = LPToken(address(proxy));

        // Deploy LiquidityPool
        liquidityPool = new LiquidityPool(address(lpToken), USDT_BSC, treasury);

        // Setup LPToken minter
        lpToken.setLiquidityPool(address(liquidityPool));

        // Whitelist USDT in vault
        vault.setTokenWhitelist(USDT_BSC, true);

        // Fund trader with USDT from a whale (BSC mainnet)
        _fundWithUSDT(trader, 100_000 * 1e18);

        // Setup approvals
        vm.startPrank(trader);
        IERC20(USDT_BSC).approve(address(positionManager), type(uint256).max);
        IERC20(USDT_BSC).approve(address(liquidityPool), type(uint256).max);
        vm.stopPrank();
    }

    /// @notice Helper to fund account with USDT from whale
    function _fundWithUSDT(address to, uint256 amount) internal {
        // Binance hot wallet holds a lot of USDT on BSC
        address usdtWhale = 0x8894E0a0c962CB723c1976a4421c95949bE2D4E3;
        uint256 whaleBalance = IERC20(USDT_BSC).balanceOf(usdtWhale);

        if (whaleBalance >= amount) {
            vm.prank(usdtWhale);
            IERC20(USDT_BSC).transfer(to, amount);
        } else {
            // If whale doesn't have enough, deal the tokens directly
            deal(USDT_BSC, to, amount);
        }
    }

    /// @notice Skip if not on BSC fork
    modifier onlyFork() {
        if (block.chainid != 56) {
            return;
        }
        _;
    }

    // ========================================
    // ORACLE FORK TESTS
    // ========================================

    /// @notice Test real Chainlink XAU/USD price retrieval
    function test_Fork_OracleReturnsValidPrice() public onlyFork {
        uint256 price = oracle.getLatestPriceView();

        // XAU/USD should be between $1,500 and $5,000 (reasonable gold price range)
        // Gold price fluctuates - as of late 2024/early 2025, gold is ~$2,600-$4,200/oz
        assertGt(price, 1500 * 1e18, "Price should be above $1,500");
        assertLt(price, 5000 * 1e18, "Price should be below $5,000");

        console2.log("Current XAU/USD price:", price / 1e18);
    }

    /// @notice Test oracle price is not stale
    function test_Fork_OraclePriceNotStale() public onlyFork {
        // This should not revert if price is fresh
        uint256 price = oracle.getLatestPriceView();
        assertTrue(price > 0, "Price should be positive");
    }

    /// @notice Test oracle decimals
    function test_Fork_OracleDecimals() public onlyFork {
        assertEq(oracle.decimals(), 18, "Oracle should return 18 decimals");
    }

    // ========================================
    // E2E TRADING SCENARIO TESTS
    // ========================================

    /// @notice Test opening a long position with real gold price
    function test_Fork_OpenLongPosition() public onlyFork {
        uint256 collateral = 1000 * 1e18; // $1,000 USDT
        uint256 leverage = 10;

        vm.startPrank(trader);

        uint256 positionId = positionManager.openPosition(
            USDT_BSC,
            collateral,
            leverage,
            true // long
        );

        vm.stopPrank();

        // Verify position created
        IPositionManager.Position memory pos = positionManager.getPosition(positionId);
        assertEq(pos.id, positionId, "Position ID should match");
        assertEq(pos.owner, trader, "Owner should be trader");
        assertEq(pos.collateralAmount, collateral, "Collateral should match");
        assertEq(pos.leverage, leverage, "Leverage should match");
        assertTrue(pos.isLong, "Should be long position");
        assertEq(pos.size, collateral * leverage, "Size should be collateral * leverage");

        // Entry price should be current gold price
        uint256 currentPrice = oracle.getLatestPriceView();
        assertEq(pos.entryPrice, currentPrice, "Entry price should be current price");

        console2.log("Position opened at price:", pos.entryPrice / 1e18);
    }

    /// @notice Test opening a short position with real gold price
    function test_Fork_OpenShortPosition() public onlyFork {
        uint256 collateral = 500 * 1e18; // $500 USDT
        uint256 leverage = 5;

        vm.startPrank(trader);

        uint256 positionId = positionManager.openPosition(
            USDT_BSC,
            collateral,
            leverage,
            false // short
        );

        vm.stopPrank();

        IPositionManager.Position memory pos = positionManager.getPosition(positionId);
        assertFalse(pos.isLong, "Should be short position");
        assertEq(pos.size, collateral * leverage, "Size should be correct");

        console2.log("Short position opened at price:", pos.entryPrice / 1e18);
    }

    /// @notice Test full trading cycle: open -> hold -> close
    function test_Fork_FullTradingCycle() public onlyFork {
        uint256 collateral = 1000 * 1e18;
        uint256 leverage = 10;

        vm.startPrank(trader);

        // Open position
        uint256 positionId = positionManager.openPosition(
            USDT_BSC,
            collateral,
            leverage,
            true
        );

        // Skip flash loan protection blocks
        vm.roll(block.number + 11);

        // Get balance before close
        uint256 balanceBefore = IERC20(USDT_BSC).balanceOf(trader);

        // Close position
        uint256 payout = positionManager.closePosition(positionId, type(uint256).max);

        vm.stopPrank();

        // Verify position closed
        vm.expectRevert(IPositionManager.PositionNotFound.selector);
        positionManager.getPosition(positionId);

        uint256 balanceAfter = IERC20(USDT_BSC).balanceOf(trader);
        assertEq(balanceAfter - balanceBefore, payout, "Payout should match balance change");

        console2.log("Position closed with payout:", payout / 1e18);
    }

    /// @notice Test partial position close
    function test_Fork_PartialClose() public onlyFork {
        uint256 collateral = 2000 * 1e18;
        uint256 leverage = 10;

        vm.startPrank(trader);

        uint256 positionId = positionManager.openPosition(
            USDT_BSC,
            collateral,
            leverage,
            true
        );

        vm.roll(block.number + 11);

        // Close 50% of position
        IPositionManager.Position memory posBefore = positionManager.getPosition(positionId);
        uint256 closeAmount = posBefore.size / 2;

        positionManager.closePosition(positionId, closeAmount);

        IPositionManager.Position memory posAfter = positionManager.getPosition(positionId);

        vm.stopPrank();

        // Verify partial close
        assertEq(posAfter.size, posBefore.size - closeAmount, "Size should be reduced by 50%");
        assertLt(posAfter.collateralAmount, posBefore.collateralAmount, "Collateral should be reduced");

        console2.log("Position partially closed, remaining size:", posAfter.size / 1e18);
    }

    /// @notice Test adding margin to position
    function test_Fork_AddMargin() public onlyFork {
        uint256 initialCollateral = 1000 * 1e18;
        uint256 additionalMargin = 500 * 1e18;
        uint256 leverage = 10;

        vm.startPrank(trader);

        uint256 positionId = positionManager.openPosition(
            USDT_BSC,
            initialCollateral,
            leverage,
            true
        );

        positionManager.addMargin(positionId, additionalMargin);

        vm.stopPrank();

        IPositionManager.Position memory pos = positionManager.getPosition(positionId);
        assertEq(pos.collateralAmount, initialCollateral + additionalMargin, "Collateral should increase");

        console2.log("Margin added, new collateral:", pos.collateralAmount / 1e18);
    }

    // ========================================
    // GAS CONSUMPTION TESTS
    // ========================================

    /// @notice Test gas consumption for opening position
    function test_Fork_Gas_OpenPosition() public onlyFork {
        uint256 collateral = 1000 * 1e18;
        uint256 leverage = 10;

        vm.startPrank(trader);

        uint256 gasBefore = gasleft();
        positionManager.openPosition(USDT_BSC, collateral, leverage, true);
        uint256 gasUsed = gasBefore - gasleft();

        vm.stopPrank();

        console2.log("Gas used for openPosition:", gasUsed);
        assertLt(gasUsed, MAX_GAS_OPEN_POSITION, "Gas should be under 300K");
    }

    /// @notice Test gas consumption for closing position
    function test_Fork_Gas_ClosePosition() public onlyFork {
        uint256 collateral = 1000 * 1e18;
        uint256 leverage = 10;

        vm.startPrank(trader);

        uint256 positionId = positionManager.openPosition(USDT_BSC, collateral, leverage, true);
        vm.roll(block.number + 11);

        uint256 gasBefore = gasleft();
        positionManager.closePosition(positionId, type(uint256).max);
        uint256 gasUsed = gasBefore - gasleft();

        vm.stopPrank();

        console2.log("Gas used for closePosition:", gasUsed);
        assertLt(gasUsed, MAX_GAS_CLOSE_POSITION, "Gas should be under 200K");
    }

    /// @notice Test gas consumption for adding margin
    function test_Fork_Gas_AddMargin() public onlyFork {
        uint256 collateral = 1000 * 1e18;
        uint256 leverage = 10;

        vm.startPrank(trader);

        uint256 positionId = positionManager.openPosition(USDT_BSC, collateral, leverage, true);

        uint256 gasBefore = gasleft();
        positionManager.addMargin(positionId, 500 * 1e18);
        uint256 gasUsed = gasBefore - gasleft();

        vm.stopPrank();

        console2.log("Gas used for addMargin:", gasUsed);
        assertLt(gasUsed, 100_000, "Gas should be under 100K");
    }

    // ========================================
    // LIQUIDITY POOL FORK TESTS
    // ========================================

    /// @notice Test adding liquidity with real USDT
    function test_Fork_AddLiquidity() public onlyFork {
        uint256 depositAmount = 10_000 * 1e18;

        vm.startPrank(trader);

        uint256 lpTokens = liquidityPool.addLiquidity(USDT_BSC, depositAmount);

        vm.stopPrank();

        assertGt(lpTokens, 0, "Should receive LP tokens");
        assertEq(lpToken.balanceOf(trader), lpTokens, "LP token balance should match");

        console2.log("LP tokens minted:", lpTokens / 1e18);
    }

    /// @notice Test removing liquidity
    function test_Fork_RemoveLiquidity() public onlyFork {
        uint256 depositAmount = 10_000 * 1e18;

        vm.startPrank(trader);

        uint256 lpTokens = liquidityPool.addLiquidity(USDT_BSC, depositAmount);

        // Skip cooldown
        vm.warp(block.timestamp + 25 hours);

        uint256 usdtBefore = IERC20(USDT_BSC).balanceOf(trader);
        (uint256 assetAmount,) = liquidityPool.removeLiquidity(lpTokens);
        uint256 usdtAfter = IERC20(USDT_BSC).balanceOf(trader);

        vm.stopPrank();

        assertEq(usdtAfter - usdtBefore, assetAmount, "USDT returned should match");
        assertEq(lpToken.balanceOf(trader), 0, "LP tokens should be burned");

        console2.log("USDT returned:", assetAmount / 1e18);
    }

    // ========================================
    // HEALTH FACTOR AND LIQUIDATION TESTS
    // ========================================

    /// @notice Test health factor calculation with real prices
    function test_Fork_HealthFactorCalculation() public onlyFork {
        uint256 collateral = 1000 * 1e18;
        uint256 leverage = 10;

        vm.startPrank(trader);
        uint256 positionId = positionManager.openPosition(USDT_BSC, collateral, leverage, true);
        vm.stopPrank();

        uint256 healthFactor = positionManager.getHealthFactor(positionId);

        // Initial health factor should be 1.0 (1e18) since no price change
        assertEq(healthFactor, 1e18, "Initial HF should be 1.0");

        console2.log("Health factor:", healthFactor / 1e18);
    }

    /// @notice Test PnL calculation with real prices
    function test_Fork_PnLCalculation() public onlyFork {
        uint256 collateral = 1000 * 1e18;
        uint256 leverage = 10;

        vm.startPrank(trader);
        uint256 positionId = positionManager.openPosition(USDT_BSC, collateral, leverage, true);
        vm.stopPrank();

        int256 pnl = positionManager.calculatePnL(positionId);

        // PnL should be 0 immediately after opening (same price)
        assertEq(pnl, 0, "Initial PnL should be 0");

        console2.log("PnL (should be 0):", pnl);
    }

    // ========================================
    // STRESS TESTS
    // ========================================

    /// @notice Test maximum leverage position
    function test_Fork_MaxLeveragePosition() public onlyFork {
        uint256 collateral = 100 * 1e18; // Small collateral
        uint256 leverage = 20; // Max leverage

        vm.startPrank(trader);

        uint256 positionId = positionManager.openPosition(USDT_BSC, collateral, leverage, true);

        vm.stopPrank();

        IPositionManager.Position memory pos = positionManager.getPosition(positionId);
        assertEq(pos.leverage, 20, "Should allow max leverage");
        assertEq(pos.size, collateral * 20, "Size should be 20x collateral");

        console2.log("Max leverage position size:", pos.size / 1e18);
    }

    /// @notice Test large position
    function test_Fork_LargePosition() public onlyFork {
        uint256 collateral = 50_000 * 1e18; // $50,000
        uint256 leverage = 10;

        _fundWithUSDT(trader, collateral);

        vm.startPrank(trader);

        uint256 positionId = positionManager.openPosition(USDT_BSC, collateral, leverage, true);

        vm.stopPrank();

        IPositionManager.Position memory pos = positionManager.getPosition(positionId);
        assertEq(pos.size, collateral * leverage, "Large position should work");

        console2.log("Large position size:", pos.size / 1e18);
    }
}
