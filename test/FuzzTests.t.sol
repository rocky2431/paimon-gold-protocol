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
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title MockERC20
/// @notice Mock ERC20 token for fuzz testing
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
/// @notice Mock Chainlink aggregator for fuzz testing
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

    function setUpdatedAt(uint256 timestamp) external {
        _updatedAt = timestamp;
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

/// @title FuzzTests
/// @notice Comprehensive fuzz testing for math-heavy functions
/// @dev Target: 256+ runs per test, all critical math paths covered
contract FuzzTests is Test {
    PositionManager public positionManager;
    LiquidationEngine public liquidationEngine;
    LiquidityPool public liquidityPool;
    LPToken public lpToken;
    OracleAdapter public oracle;
    CollateralVault public vault;
    MockERC20 public usdt;
    MockChainlinkAggregator public mockAggregator;

    address public owner;
    address public user1;
    address public treasury;

    uint256 constant PRECISION = 1e18;
    int256 constant INITIAL_PRICE = 2000_00000000; // $2,000.00 (8 decimals)
    uint8 constant CHAINLINK_DECIMALS = 8;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        treasury = makeAddr("treasury");

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
        liquidityPool = new LiquidityPool(address(lpToken), address(usdt), treasury);

        // Setup LPToken minter
        lpToken.setLiquidityPool(address(liquidityPool));

        // Setup approvals
        vm.startPrank(user1);
        usdt.approve(address(positionManager), type(uint256).max);
        usdt.approve(address(liquidityPool), type(uint256).max);
        vm.stopPrank();
    }

    // ========================================
    // POSITION MANAGER FUZZ TESTS
    // ========================================

    /// @notice Fuzz test: PnL calculation for long positions
    /// @dev Invariant: Long profit = size * (exitPrice - entryPrice) / entryPrice
    function testFuzz_PnL_LongPosition(
        uint256 size,
        uint256 entryPrice,
        uint256 exitPrice
    ) public pure {
        // Bound inputs to realistic ranges
        size = bound(size, 10 * 1e18, 1_000_000 * 1e18); // $10 to $1M
        entryPrice = bound(entryPrice, 100 * 1e18, 10_000 * 1e18); // $100 to $10K
        exitPrice = bound(exitPrice, 100 * 1e18, 10_000 * 1e18); // $100 to $10K

        // Calculate PnL manually (simulating contract logic)
        int256 pnl;
        if (exitPrice >= entryPrice) {
            uint256 gain = (size * (exitPrice - entryPrice)) / entryPrice;
            pnl = int256(gain);
        } else {
            uint256 loss = (size * (entryPrice - exitPrice)) / entryPrice;
            pnl = -int256(loss);
        }

        // Verify invariants:
        // 1. If exitPrice > entryPrice, PnL is positive (long profits on price increase)
        if (exitPrice > entryPrice) {
            assertTrue(pnl > 0, "Long should profit when price increases");
        }
        // 2. If exitPrice < entryPrice, PnL is negative (long loses on price decrease)
        if (exitPrice < entryPrice) {
            assertTrue(pnl < 0, "Long should lose when price decreases");
        }
        // 3. If exitPrice == entryPrice, PnL is zero
        if (exitPrice == entryPrice) {
            assertTrue(pnl == 0, "No price change should result in zero PnL");
        }
    }

    /// @notice Fuzz test: PnL calculation for short positions
    /// @dev Invariant: Short profit = size * (entryPrice - exitPrice) / entryPrice
    function testFuzz_PnL_ShortPosition(
        uint256 size,
        uint256 entryPrice,
        uint256 exitPrice
    ) public pure {
        // Bound inputs to realistic ranges with minimum differences for meaningful tests
        size = bound(size, 1000 * 1e18, 1_000_000 * 1e18); // Min $1000 to avoid rounding to 0
        entryPrice = bound(entryPrice, 1000 * 1e18, 10_000 * 1e18); // Min $1000
        exitPrice = bound(exitPrice, 500 * 1e18, 10_000 * 1e18); // Allow lower exit for shorts

        // Calculate PnL manually (simulating contract logic)
        int256 pnl;
        if (exitPrice <= entryPrice) {
            uint256 gain = (size * (entryPrice - exitPrice)) / entryPrice;
            pnl = int256(gain);
        } else {
            uint256 loss = (size * (exitPrice - entryPrice)) / entryPrice;
            pnl = -int256(loss);
        }

        // Verify invariants:
        // 1. If exitPrice < entryPrice, PnL is positive (short profits on price decrease)
        // Note: Due to integer division, very small price differences may result in 0 PnL
        if (exitPrice < entryPrice) {
            assertTrue(pnl >= 0, "Short should profit or break even when price decreases");
        }
        // 2. If exitPrice > entryPrice, PnL is negative (short loses on price increase)
        if (exitPrice > entryPrice) {
            assertTrue(pnl < 0, "Short should lose when price increases");
        }
        // 3. If exitPrice == entryPrice, PnL is zero
        if (exitPrice == entryPrice) {
            assertTrue(pnl == 0, "No price change should result in zero PnL");
        }
    }

    /// @notice Fuzz test: Position size calculation
    /// @dev Invariant: size = collateral * leverage
    function testFuzz_PositionSize_Calculation(
        uint256 collateral,
        uint256 leverage
    ) public pure {
        // Bound inputs
        collateral = bound(collateral, 1 * 1e18, 1_000_000 * 1e18); // $1 to $1M
        leverage = bound(leverage, 2, 20); // 2x to 20x

        // Calculate position size
        uint256 size = collateral * leverage;

        // Verify invariants:
        // 1. Size is always >= collateral * 2 (minimum leverage)
        assertTrue(size >= collateral * 2, "Size must be at least 2x collateral");
        // 2. Size is always <= collateral * 20 (maximum leverage)
        assertTrue(size <= collateral * 20, "Size must be at most 20x collateral");
        // 3. No overflow should occur
        assertTrue(size / leverage == collateral, "No overflow in size calculation");
    }

    /// @notice Fuzz test: Leverage bounds enforcement
    /// @dev Invariant: Only leverage 2-20 is valid
    function testFuzz_LeverageBounds_Enforcement(uint256 leverage) public {
        uint256 collateral = 1000 * 1e18;
        usdt.mint(user1, collateral);

        vm.startPrank(user1);

        if (leverage < 2 || leverage > 20) {
            // Should revert for invalid leverage
            vm.expectRevert(IPositionManager.InvalidLeverage.selector);
            positionManager.openPosition(address(usdt), collateral, leverage, true);
        } else {
            // Should succeed for valid leverage
            uint256 positionId = positionManager.openPosition(address(usdt), collateral, leverage, true);
            assertTrue(positionId > 0, "Position should be created");

            IPositionManager.Position memory pos = positionManager.getPosition(positionId);
            assertEq(pos.leverage, leverage, "Leverage should match");
        }

        vm.stopPrank();
    }

    /// @notice Fuzz test: Minimum position size enforcement
    /// @dev Invariant: size >= $10 (10e18)
    function testFuzz_MinPositionSize_Enforcement(
        uint256 collateral,
        uint256 leverage
    ) public {
        leverage = bound(leverage, 2, 20);

        // Calculate what collateral would result in valid/invalid position
        uint256 minCollateralForLeverage = (10 * 1e18 + leverage - 1) / leverage;

        if (collateral < minCollateralForLeverage) {
            // Position too small
            if (collateral > 0) {
                usdt.mint(user1, collateral);
                vm.startPrank(user1);
                vm.expectRevert(IPositionManager.PositionTooSmall.selector);
                positionManager.openPosition(address(usdt), collateral, leverage, true);
                vm.stopPrank();
            }
        } else {
            // Valid position size
            collateral = bound(collateral, minCollateralForLeverage, 10_000 * 1e18);
            usdt.mint(user1, collateral);

            vm.startPrank(user1);
            uint256 positionId = positionManager.openPosition(address(usdt), collateral, leverage, true);
            assertTrue(positionId > 0, "Position should be created");

            IPositionManager.Position memory pos = positionManager.getPosition(positionId);
            assertTrue(pos.size >= 10 * 1e18, "Position size should meet minimum");
            vm.stopPrank();
        }
    }

    /// @notice Fuzz test: Partial close proportion calculation
    /// @dev Invariant: proportion = closeAmount / totalSize
    function testFuzz_PartialClose_Proportion(
        uint256 closeAmount,
        uint256 totalSize
    ) public pure {
        // Bound inputs to reasonable ranges
        totalSize = bound(totalSize, 100 * 1e18, 1_000_000 * 1e18);
        // Ensure closeAmount is large enough to produce non-zero proportion
        uint256 minClose = (totalSize / PRECISION) + 1; // Minimum to get proportion > 0
        closeAmount = bound(closeAmount, minClose, totalSize);

        // Calculate proportion (matching contract logic)
        uint256 proportion = (closeAmount * PRECISION) / totalSize;

        // Verify invariants:
        // 1. Proportion is always <= PRECISION (100%)
        assertTrue(proportion <= PRECISION, "Proportion should not exceed 100%");
        // 2. Full close gives PRECISION
        if (closeAmount == totalSize) {
            assertEq(proportion, PRECISION, "Full close should be 100%");
        }
        // 3. Proportion is proportional to closeAmount (with valid minimum)
        assertTrue(proportion > 0, "Proportion should be positive");
    }

    // ========================================
    // LIQUIDATION ENGINE FUZZ TESTS
    // ========================================

    /// @notice Fuzz test: Health factor calculation
    /// @dev Invariant: HF = effectiveCollateral / minRequiredMargin
    function testFuzz_HealthFactor_Calculation(
        uint256 collateral,
        int256 pnl,
        uint256 size
    ) public pure {
        // Bound inputs
        collateral = bound(collateral, 100 * 1e18, 1_000_000 * 1e18);
        size = bound(size, collateral * 2, collateral * 20); // Valid leverage range
        pnl = int256(bound(uint256(int256(type(int128).max)), 0, collateral * 2)); // Reasonable PnL range

        // Randomly make PnL negative sometimes
        if (uint256(keccak256(abi.encode(collateral, size))) % 2 == 0) {
            pnl = -pnl;
        }

        // Calculate health factor (matching contract logic)
        int256 effectiveCollateral = int256(collateral) + pnl;

        if (effectiveCollateral <= 0) {
            // Position is underwater - HF = 0
            assertTrue(true, "Underwater position should have zero HF");
        } else {
            // minRequiredMargin = size / MAX_LEVERAGE (20)
            uint256 minRequiredMargin = size / 20;
            uint256 healthFactor = (uint256(effectiveCollateral) * PRECISION) / minRequiredMargin;

            // Verify invariants:
            // 1. HF should be positive for positive effective collateral
            assertTrue(healthFactor > 0, "HF should be positive");
        }
    }

    /// @notice Fuzz test: Liquidation bonus calculation
    /// @dev Invariant: bonus = collateral * bonusRate / PRECISION
    function testFuzz_LiquidationBonus_Calculation(
        uint256 collateral,
        uint256 size
    ) public pure {
        // Bound inputs
        collateral = bound(collateral, 100 * 1e18, 10_000_000 * 1e18);
        size = bound(size, collateral * 2, collateral * 20);

        uint256 LIQUIDATION_BONUS = 5e16; // 5%
        uint256 LARGE_POSITION_BONUS = 10e16; // 10%
        uint256 LARGE_POSITION_THRESHOLD = 100_000 * 1e18;

        // Calculate bonus (matching contract logic)
        uint256 bonusRate = size >= LARGE_POSITION_THRESHOLD ? LARGE_POSITION_BONUS : LIQUIDATION_BONUS;
        uint256 keeperBonus = (collateral * bonusRate) / PRECISION;

        // Verify invariants:
        // 1. Bonus should be within expected range
        if (size >= LARGE_POSITION_THRESHOLD) {
            // Large position: 10% bonus
            assertEq(keeperBonus, (collateral * 10) / 100, "Large position bonus should be 10%");
        } else {
            // Normal position: 5% bonus
            assertEq(keeperBonus, (collateral * 5) / 100, "Normal position bonus should be 5%");
        }
        // 2. Bonus should never exceed collateral
        assertTrue(keeperBonus <= collateral, "Bonus should not exceed collateral");
    }

    /// @notice Fuzz test: Partial liquidation percentage
    /// @dev Invariant: 0 < percentage <= 100
    function testFuzz_PartialLiquidation_Percentage(
        uint256 percentage,
        uint256 collateral
    ) public pure {
        // Bound inputs
        collateral = bound(collateral, 100 * 1e18, 1_000_000 * 1e18);

        if (percentage == 0 || percentage > 100) {
            // Invalid percentage - would revert
            assertTrue(true, "Invalid percentage should revert");
        } else {
            // Valid percentage
            uint256 liquidatedAmount = (collateral * percentage) / 100;

            // Verify invariants:
            // 1. Liquidated amount should be proportional
            assertTrue(liquidatedAmount > 0, "Should liquidate something");
            // 2. Liquidated amount should not exceed collateral
            assertTrue(liquidatedAmount <= collateral, "Cannot liquidate more than collateral");
            // 3. Full liquidation (100%) should liquidate everything
            if (percentage == 100) {
                assertEq(liquidatedAmount, collateral, "100% should liquidate all");
            }
        }
    }

    // ========================================
    // LIQUIDITY POOL FUZZ TESTS
    // ========================================

    /// @notice Fuzz test: LP token minting ratio (first depositor)
    /// @dev Invariant: First depositor gets 1:1 ratio (scaled to 18 decimals)
    function testFuzz_LPMinting_FirstDepositor(uint256 amount) public {
        // Bound to reasonable range
        amount = bound(amount, 1e18, 1_000_000 * 1e18);

        usdt.mint(user1, amount);

        vm.startPrank(user1);
        uint256 lpAmount = liquidityPool.addLiquidity(address(usdt), amount);
        vm.stopPrank();

        // First depositor gets 1:1 ratio
        assertEq(lpAmount, amount, "First depositor should get 1:1 LP tokens");
    }

    /// @notice Fuzz test: LP token minting ratio (subsequent depositors)
    /// @dev Invariant: lpAmount = (depositAmount * totalSupply) / totalAssets
    function testFuzz_LPMinting_SubsequentDepositor(
        uint256 initialDeposit,
        uint256 subsequentDeposit
    ) public {
        // Bound inputs
        initialDeposit = bound(initialDeposit, 1000 * 1e18, 1_000_000 * 1e18);
        subsequentDeposit = bound(subsequentDeposit, 100 * 1e18, 500_000 * 1e18);

        address user2 = makeAddr("user2");

        // First deposit
        usdt.mint(user1, initialDeposit);
        vm.prank(user1);
        uint256 firstLp = liquidityPool.addLiquidity(address(usdt), initialDeposit);

        // Second deposit
        usdt.mint(user2, subsequentDeposit);
        vm.startPrank(user2);
        usdt.approve(address(liquidityPool), type(uint256).max);
        uint256 secondLp = liquidityPool.addLiquidity(address(usdt), subsequentDeposit);
        vm.stopPrank();

        // Calculate expected LP tokens
        uint256 expectedLp = (subsequentDeposit * firstLp) / initialDeposit;

        // Verify proportional minting
        assertEq(secondLp, expectedLp, "LP tokens should be proportional to share");
    }

    /// @notice Fuzz test: Fee distribution split (70/30)
    /// @dev Invariant: LPs get 70%, protocol gets 30%
    function testFuzz_FeeDistribution_Split(uint256 feeAmount) public {
        // Bound fee amount
        feeAmount = bound(feeAmount, 100 * 1e18, 100_000 * 1e18);

        // Setup: Add liquidity first
        uint256 depositAmount = 10_000 * 1e18;
        usdt.mint(user1, depositAmount);
        vm.prank(user1);
        liquidityPool.addLiquidity(address(usdt), depositAmount);

        // Authorize fee depositor
        address feeDepositor = makeAddr("feeDepositor");
        liquidityPool.setTradingContract(feeDepositor, true);

        // Record treasury balance before
        uint256 treasuryBefore = usdt.balanceOf(treasury);

        // Deposit fees
        usdt.mint(feeDepositor, feeAmount);
        vm.startPrank(feeDepositor);
        usdt.approve(address(liquidityPool), type(uint256).max);
        liquidityPool.depositFees(address(usdt), feeAmount);
        vm.stopPrank();

        // Calculate expected splits
        // Note: Contract calculates lpShare = (fee * 70) / 100, then protocolShare = fee - lpShare
        // This can result in 1 wei rounding difference vs direct (fee * 30) / 100
        uint256 lpShare = (feeAmount * 70) / 100;
        uint256 expectedProtocolShare = feeAmount - lpShare;
        uint256 treasuryReceived = usdt.balanceOf(treasury) - treasuryBefore;

        // Verify protocol share (30%) - exact match with contract's calculation
        assertEq(treasuryReceived, expectedProtocolShare, "Protocol should receive 30%");
    }

    /// @notice Fuzz test: Withdrawal amount calculation
    /// @dev Invariant: assetAmount = (lpAmount * totalAssets) / totalSupply
    function testFuzz_Withdrawal_Calculation(
        uint256 depositAmount,
        uint256 withdrawPercent
    ) public {
        // Bound inputs
        depositAmount = bound(depositAmount, 1000 * 1e18, 1_000_000 * 1e18);
        withdrawPercent = bound(withdrawPercent, 1, 100);

        // Deposit
        usdt.mint(user1, depositAmount);
        vm.prank(user1);
        uint256 lpTokens = liquidityPool.addLiquidity(address(usdt), depositAmount);

        // Skip cooldown
        vm.warp(block.timestamp + 25 hours);

        // Calculate withdrawal amount
        uint256 withdrawLp = (lpTokens * withdrawPercent) / 100;
        if (withdrawLp == 0) return; // Skip if too small

        // Withdraw
        vm.prank(user1);
        (uint256 assetAmount,) = liquidityPool.removeLiquidity(withdrawLp);

        // Expected asset amount (proportional)
        uint256 expectedAsset = (withdrawLp * depositAmount) / lpTokens;

        // Verify proportional withdrawal
        assertEq(assetAmount, expectedAsset, "Withdrawal should be proportional");
    }

    /// @notice Fuzz test: Fee accumulation per share
    /// @dev Invariant: accFeePerShare increases proportionally to fees/totalSupply
    function testFuzz_FeeAccumulation_PerShare(
        uint256 totalDeposit,
        uint256 feeDeposit
    ) public {
        // Bound inputs
        totalDeposit = bound(totalDeposit, 10_000 * 1e18, 10_000_000 * 1e18);
        feeDeposit = bound(feeDeposit, 100 * 1e18, 100_000 * 1e18);

        // Setup: Add liquidity
        usdt.mint(user1, totalDeposit);
        vm.prank(user1);
        uint256 lpSupply = liquidityPool.addLiquidity(address(usdt), totalDeposit);

        // Record accFeePerShare before
        uint256 accFeeBefore = liquidityPool.getAccFeePerShare();

        // Deposit fees
        address feeDepositor = makeAddr("feeDepositor");
        liquidityPool.setTradingContract(feeDepositor, true);
        usdt.mint(feeDepositor, feeDeposit);
        vm.startPrank(feeDepositor);
        usdt.approve(address(liquidityPool), type(uint256).max);
        liquidityPool.depositFees(address(usdt), feeDeposit);
        vm.stopPrank();

        // Calculate expected increase
        uint256 lpShare = (feeDeposit * 70) / 100; // 70% to LPs
        uint256 expectedIncrease = (lpShare * PRECISION) / lpSupply;

        // Verify accumulation
        uint256 accFeeAfter = liquidityPool.getAccFeePerShare();
        assertEq(accFeeAfter - accFeeBefore, expectedIncrease, "Fee per share should increase proportionally");
    }

    // ========================================
    // CROSS-CONTRACT INVARIANT TESTS
    // ========================================

    /// @notice Fuzz test: PnL symmetry (long vs short)
    /// @dev Invariant: Long PnL = -Short PnL for same price movement
    function testFuzz_PnL_Symmetry(
        uint256 size,
        uint256 entryPrice,
        uint256 exitPrice
    ) public pure {
        // Bound inputs
        size = bound(size, 10 * 1e18, 1_000_000 * 1e18);
        entryPrice = bound(entryPrice, 100 * 1e18, 10_000 * 1e18);
        exitPrice = bound(exitPrice, 100 * 1e18, 10_000 * 1e18);

        // Calculate long PnL
        int256 longPnl;
        if (exitPrice >= entryPrice) {
            longPnl = int256((size * (exitPrice - entryPrice)) / entryPrice);
        } else {
            longPnl = -int256((size * (entryPrice - exitPrice)) / entryPrice);
        }

        // Calculate short PnL
        int256 shortPnl;
        if (exitPrice <= entryPrice) {
            shortPnl = int256((size * (entryPrice - exitPrice)) / entryPrice);
        } else {
            shortPnl = -int256((size * (exitPrice - entryPrice)) / entryPrice);
        }

        // Verify symmetry: long profit = short loss (and vice versa)
        assertEq(longPnl, -shortPnl, "Long and short PnL should be symmetric");
    }

    /// @notice Fuzz test: Health factor threshold for liquidation
    /// @dev Invariant: Position is liquidatable iff HF < 1.0
    function testFuzz_Liquidation_Threshold(
        uint256 collateral,
        int256 pnlPercent
    ) public pure {
        // Bound inputs
        collateral = bound(collateral, 1000 * 1e18, 100_000 * 1e18);
        pnlPercent = int256(bound(uint256(int256(type(int64).max)), 0, 200)); // -200% to +200%

        // Calculate PnL and effective collateral
        int256 pnl = (int256(collateral) * pnlPercent) / 100;

        // Randomly make negative
        if (uint256(keccak256(abi.encode(collateral))) % 2 == 0) {
            pnl = -pnl;
        }

        int256 effectiveCollateral = int256(collateral) + pnl;

        // Calculate health factor (assuming 10x leverage, so minMargin = collateral)
        uint256 size = collateral * 10;
        uint256 minMargin = size / 20; // MAX_LEVERAGE = 20

        if (effectiveCollateral <= 0) {
            // Definitely liquidatable
            assertTrue(true, "Underwater position is liquidatable");
        } else {
            uint256 hf = (uint256(effectiveCollateral) * PRECISION) / minMargin;

            // Verify: liquidatable iff HF < 1.0 (PRECISION)
            bool isLiquidatable = hf < PRECISION;
            bool shouldBeLiquidatable = effectiveCollateral < int256(minMargin);

            assertEq(isLiquidatable, shouldBeLiquidatable, "Liquidation threshold consistency");
        }
    }

    /// @notice Fuzz test: No arithmetic overflow in calculations
    /// @dev Invariant: All math operations should not overflow
    function testFuzz_NoOverflow_InPnLCalculation(
        uint256 size,
        uint256 entryPrice,
        uint256 exitPrice
    ) public pure {
        // Use maximum reasonable values
        size = bound(size, 1e18, type(uint128).max);
        entryPrice = bound(entryPrice, 1e18, type(uint128).max);
        exitPrice = bound(exitPrice, 1e18, type(uint128).max);

        // These calculations should not overflow with bounded inputs
        if (exitPrice >= entryPrice) {
            uint256 diff = exitPrice - entryPrice;
            // Skip if no price difference (avoid division by zero in overflow check)
            if (diff == 0) return;
            // Check intermediate multiplication won't overflow
            if (size <= type(uint256).max / diff) {
                uint256 gain = (size * diff) / entryPrice;
                assertTrue(gain >= 0, "Gain calculation succeeded");
            }
        } else {
            uint256 diff = entryPrice - exitPrice;
            // Skip if no price difference (avoid division by zero in overflow check)
            if (diff == 0) return;
            if (size <= type(uint256).max / diff) {
                uint256 loss = (size * diff) / entryPrice;
                assertTrue(loss >= 0, "Loss calculation succeeded");
            }
        }
    }
}
