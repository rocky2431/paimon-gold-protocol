// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LiquidityPool} from "../src/LiquidityPool.sol";
import {LPToken} from "../src/LPToken.sol";
import {ILiquidityPool} from "../src/interfaces/ILiquidityPool.sol";

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

contract LiquidityPoolTest is Test {
    LiquidityPool public pool;
    LPToken public lpToken;
    MockERC20 public usdc;
    MockERC20 public paxg;

    address public owner = address(this);
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public treasury = makeAddr("treasury");
    address public tradingContract = makeAddr("tradingContract");

    uint256 public constant PRECISION = 1e18;
    uint256 public constant DEFAULT_COOLDOWN = 24 hours;

    function setUp() public {
        // Deploy mock tokens
        usdc = new MockERC20("USD Coin", "USDC", 6);
        paxg = new MockERC20("PAX Gold", "PAXG", 18);

        // Deploy LPToken with proxy
        LPToken lpTokenImpl = new LPToken();
        bytes memory lpTokenData = abi.encodeWithSelector(
            LPToken.initialize.selector,
            "Paimon LP Token",
            "pLP"
        );
        ERC1967Proxy lpTokenProxy = new ERC1967Proxy(address(lpTokenImpl), lpTokenData);
        lpToken = LPToken(address(lpTokenProxy));

        // Deploy LiquidityPool
        pool = new LiquidityPool(
            address(lpToken),
            address(usdc),
            treasury
        );

        // Set liquidity pool in LPToken
        lpToken.setLiquidityPool(address(pool));

        // Whitelist tokens
        pool.setTokenWhitelist(address(usdc), true);
        pool.setTokenWhitelist(address(paxg), true);

        // Authorize trading contract
        pool.setTradingContract(tradingContract, true);

        // Mint tokens to users
        usdc.mint(user1, 100_000e6);
        usdc.mint(user2, 100_000e6);
        usdc.mint(user3, 100_000e6);
        usdc.mint(tradingContract, 100_000e6);
        paxg.mint(user1, 100e18);
        paxg.mint(user2, 100e18);

        // Approve pool
        vm.prank(user1);
        usdc.approve(address(pool), type(uint256).max);
        vm.prank(user2);
        usdc.approve(address(pool), type(uint256).max);
        vm.prank(user3);
        usdc.approve(address(pool), type(uint256).max);
        vm.prank(tradingContract);
        usdc.approve(address(pool), type(uint256).max);

        vm.prank(user1);
        paxg.approve(address(pool), type(uint256).max);
        vm.prank(user2);
        paxg.approve(address(pool), type(uint256).max);
    }

    // ============ Constructor Tests ============

    function test_Constructor_SetsLPToken() public view {
        assertEq(pool.lpToken(), address(lpToken));
    }

    function test_Constructor_SetsPrimaryToken() public view {
        assertEq(pool.primaryToken(), address(usdc));
    }

    function test_Constructor_SetsTreasury() public view {
        assertEq(pool.protocolTreasury(), treasury);
    }

    function test_Constructor_SetsDefaultCooldown() public view {
        assertEq(pool.getCooldownPeriod(), DEFAULT_COOLDOWN);
    }

    function test_Constructor_RevertIf_ZeroLPToken() public {
        vm.expectRevert(ILiquidityPool.ZeroAddress.selector);
        new LiquidityPool(address(0), address(usdc), treasury);
    }

    function test_Constructor_RevertIf_ZeroPrimaryToken() public {
        vm.expectRevert(ILiquidityPool.ZeroAddress.selector);
        new LiquidityPool(address(lpToken), address(0), treasury);
    }

    function test_Constructor_RevertIf_ZeroTreasury() public {
        vm.expectRevert(ILiquidityPool.ZeroAddress.selector);
        new LiquidityPool(address(lpToken), address(usdc), address(0));
    }

    // ============ Add Liquidity Tests ============

    function test_AddLiquidity_FirstDeposit() public {
        uint256 depositAmount = 10_000e6;

        vm.prank(user1);
        uint256 lpAmount = pool.addLiquidity(address(usdc), depositAmount);

        // First depositor gets 1:1 LP tokens (scaled to 18 decimals)
        assertEq(lpAmount, depositAmount * 1e12); // 6 decimals to 18 decimals
        assertEq(lpToken.balanceOf(user1), lpAmount);
        assertEq(usdc.balanceOf(address(pool)), depositAmount);
    }

    function test_AddLiquidity_SubsequentDeposit() public {
        // First deposit
        vm.prank(user1);
        pool.addLiquidity(address(usdc), 10_000e6);

        // Second deposit
        vm.prank(user2);
        uint256 lpAmount = pool.addLiquidity(address(usdc), 5_000e6);

        // Should get proportional LP tokens
        // totalSupply = 10_000e18, totalAssets = 10_000e6
        // lpAmount = (5_000e6 * 10_000e18) / 10_000e6 = 5_000e18
        assertEq(lpAmount, 5_000e6 * 1e12);
        assertEq(lpToken.balanceOf(user2), lpAmount);
    }

    function test_AddLiquidity_UpdatesUserInfo() public {
        uint256 depositAmount = 10_000e6;

        vm.prank(user1);
        pool.addLiquidity(address(usdc), depositAmount);

        ILiquidityPool.UserInfo memory info = pool.getUserInfo(user1);
        assertEq(info.lpBalance, depositAmount * 1e12);
        assertEq(info.depositTime, block.timestamp);
    }

    function test_AddLiquidity_EmitsEvent() public {
        uint256 depositAmount = 10_000e6;

        vm.expectEmit(true, true, false, true);
        emit ILiquidityPool.LiquidityAdded(user1, address(usdc), depositAmount, depositAmount * 1e12);

        vm.prank(user1);
        pool.addLiquidity(address(usdc), depositAmount);
    }

    function test_AddLiquidity_RevertIf_ZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(ILiquidityPool.ZeroAmount.selector);
        pool.addLiquidity(address(usdc), 0);
    }

    function test_AddLiquidity_RevertIf_TokenNotWhitelisted() public {
        MockERC20 unknownToken = new MockERC20("Unknown", "UNK", 18);
        unknownToken.mint(user1, 1000e18);

        vm.startPrank(user1);
        unknownToken.approve(address(pool), type(uint256).max);
        vm.expectRevert(ILiquidityPool.TokenNotSupported.selector);
        pool.addLiquidity(address(unknownToken), 1000e18);
        vm.stopPrank();
    }

    // ============ Remove Liquidity Tests ============

    function test_RemoveLiquidity_FullWithdraw() public {
        uint256 depositAmount = 10_000e6;

        // Add liquidity
        vm.prank(user1);
        uint256 lpAmount = pool.addLiquidity(address(usdc), depositAmount);

        // Wait for cooldown
        vm.warp(block.timestamp + DEFAULT_COOLDOWN + 1);

        // Remove liquidity
        uint256 balanceBefore = usdc.balanceOf(user1);
        vm.prank(user1);
        (uint256 assetAmount, uint256 feeReward) = pool.removeLiquidity(lpAmount);

        assertEq(assetAmount, depositAmount);
        assertEq(feeReward, 0); // No fees yet
        assertEq(usdc.balanceOf(user1), balanceBefore + depositAmount);
        assertEq(lpToken.balanceOf(user1), 0);
    }

    function test_RemoveLiquidity_PartialWithdraw() public {
        uint256 depositAmount = 10_000e6;

        // Add liquidity
        vm.prank(user1);
        uint256 lpAmount = pool.addLiquidity(address(usdc), depositAmount);

        // Wait for cooldown
        vm.warp(block.timestamp + DEFAULT_COOLDOWN + 1);

        // Remove half
        uint256 withdrawLp = lpAmount / 2;
        vm.prank(user1);
        (uint256 assetAmount,) = pool.removeLiquidity(withdrawLp);

        assertEq(assetAmount, depositAmount / 2);
        assertEq(lpToken.balanceOf(user1), lpAmount - withdrawLp);
    }

    function test_RemoveLiquidity_WithAccumulatedFees() public {
        uint256 depositAmount = 10_000e6;

        // Add liquidity
        vm.prank(user1);
        uint256 lpAmount = pool.addLiquidity(address(usdc), depositAmount);

        // Deposit fees
        uint256 feeAmount = 1000e6;
        vm.prank(tradingContract);
        pool.depositFees(address(usdc), feeAmount);

        // Wait for cooldown
        vm.warp(block.timestamp + DEFAULT_COOLDOWN + 1);

        // Remove liquidity
        vm.prank(user1);
        (uint256 assetAmount, uint256 feeReward) = pool.removeLiquidity(lpAmount);

        // Should get original deposit plus 70% of fees
        uint256 expectedFees = (feeAmount * 70) / 100;
        assertEq(assetAmount, depositAmount);
        assertEq(feeReward, expectedFees);
    }

    function test_RemoveLiquidity_EmitsEvent() public {
        uint256 depositAmount = 10_000e6;

        vm.prank(user1);
        uint256 lpAmount = pool.addLiquidity(address(usdc), depositAmount);

        vm.warp(block.timestamp + DEFAULT_COOLDOWN + 1);

        vm.expectEmit(true, false, false, true);
        emit ILiquidityPool.LiquidityRemoved(user1, lpAmount, depositAmount, 0);

        vm.prank(user1);
        pool.removeLiquidity(lpAmount);
    }

    function test_RemoveLiquidity_RevertIf_ZeroAmount() public {
        vm.prank(user1);
        pool.addLiquidity(address(usdc), 10_000e6);

        vm.warp(block.timestamp + DEFAULT_COOLDOWN + 1);

        vm.prank(user1);
        vm.expectRevert(ILiquidityPool.ZeroAmount.selector);
        pool.removeLiquidity(0);
    }

    function test_RemoveLiquidity_RevertIf_InsufficientBalance() public {
        vm.prank(user1);
        uint256 lpAmount = pool.addLiquidity(address(usdc), 10_000e6);

        vm.warp(block.timestamp + DEFAULT_COOLDOWN + 1);

        vm.prank(user1);
        vm.expectRevert(ILiquidityPool.InsufficientBalance.selector);
        pool.removeLiquidity(lpAmount + 1);
    }

    function test_RemoveLiquidity_RevertIf_CooldownNotPassed() public {
        vm.prank(user1);
        uint256 lpAmount = pool.addLiquidity(address(usdc), 10_000e6);

        vm.prank(user1);
        vm.expectRevert(ILiquidityPool.CooldownNotPassed.selector);
        pool.removeLiquidity(lpAmount);
    }

    function test_RemoveLiquidity_RevertIf_PoolEmpty() public {
        // Deploy fresh pool without any deposits
        LiquidityPool emptyPool = new LiquidityPool(
            address(lpToken),
            address(usdc),
            treasury
        );

        vm.prank(user1);
        vm.expectRevert(ILiquidityPool.InsufficientBalance.selector);
        emptyPool.removeLiquidity(1000e18);
    }

    // ============ Claim Fees Tests ============

    function test_ClaimFees_SingleUser() public {
        uint256 depositAmount = 10_000e6;

        vm.prank(user1);
        pool.addLiquidity(address(usdc), depositAmount);

        // Deposit fees
        uint256 feeAmount = 1000e6;
        vm.prank(tradingContract);
        pool.depositFees(address(usdc), feeAmount);

        // Claim fees
        uint256 balanceBefore = usdc.balanceOf(user1);
        vm.prank(user1);
        uint256 claimed = pool.claimFees();

        uint256 expectedFees = (feeAmount * 70) / 100;
        assertEq(claimed, expectedFees);
        assertEq(usdc.balanceOf(user1), balanceBefore + expectedFees);
    }

    function test_ClaimFees_MultipleUsers() public {
        // User1 deposits 10k, User2 deposits 30k (1:3 ratio)
        vm.prank(user1);
        pool.addLiquidity(address(usdc), 10_000e6);
        vm.prank(user2);
        pool.addLiquidity(address(usdc), 30_000e6);

        // Deposit fees
        uint256 feeAmount = 1000e6;
        vm.prank(tradingContract);
        pool.depositFees(address(usdc), feeAmount);

        // User1 claims (25% of LP fees)
        vm.prank(user1);
        uint256 claimed1 = pool.claimFees();

        // User2 claims (75% of LP fees)
        vm.prank(user2);
        uint256 claimed2 = pool.claimFees();

        uint256 totalLPFees = (feeAmount * 70) / 100; // 700e6
        // User1: 25% = 175e6, User2: 75% = 525e6
        assertApproxEqAbs(claimed1, totalLPFees / 4, 1);
        assertApproxEqAbs(claimed2, (totalLPFees * 3) / 4, 1);
    }

    function test_ClaimFees_NoDoubleClaimAfterClaim() public {
        vm.prank(user1);
        pool.addLiquidity(address(usdc), 10_000e6);

        vm.prank(tradingContract);
        pool.depositFees(address(usdc), 1000e6);

        // First claim
        vm.prank(user1);
        pool.claimFees();

        // Second claim should return 0
        vm.prank(user1);
        uint256 secondClaim = pool.claimFees();
        assertEq(secondClaim, 0);
    }

    function test_ClaimFees_EmitsEvent() public {
        vm.prank(user1);
        pool.addLiquidity(address(usdc), 10_000e6);

        vm.prank(tradingContract);
        pool.depositFees(address(usdc), 1000e6);

        uint256 expectedFees = (1000e6 * 70) / 100;

        vm.expectEmit(true, false, false, true);
        emit ILiquidityPool.FeesClaimed(user1, expectedFees);

        vm.prank(user1);
        pool.claimFees();
    }

    // ============ Deposit Fees Tests ============

    function test_DepositFees_SplitsCorrectly() public {
        vm.prank(user1);
        pool.addLiquidity(address(usdc), 10_000e6);

        uint256 feeAmount = 1000e6;
        uint256 treasuryBefore = usdc.balanceOf(treasury);

        vm.prank(tradingContract);
        pool.depositFees(address(usdc), feeAmount);

        // 30% to treasury
        uint256 protocolShare = (feeAmount * 30) / 100;
        assertEq(usdc.balanceOf(treasury), treasuryBefore + protocolShare);

        // 70% remains in pool for LPs
        assertEq(usdc.balanceOf(address(pool)), 10_000e6 + (feeAmount * 70) / 100);
    }

    function test_DepositFees_UpdatesAccFeePerShare() public {
        vm.prank(user1);
        pool.addLiquidity(address(usdc), 10_000e6);

        uint256 accBefore = pool.getAccFeePerShare();

        vm.prank(tradingContract);
        pool.depositFees(address(usdc), 1000e6);

        uint256 accAfter = pool.getAccFeePerShare();
        assertGt(accAfter, accBefore);
    }

    function test_DepositFees_EmitsEvent() public {
        vm.prank(user1);
        pool.addLiquidity(address(usdc), 10_000e6);

        uint256 feeAmount = 1000e6;
        uint256 lpShare = (feeAmount * 70) / 100;
        uint256 protocolShare = (feeAmount * 30) / 100;

        vm.expectEmit(true, false, false, true);
        emit ILiquidityPool.FeesDeposited(address(usdc), feeAmount, lpShare, protocolShare);

        vm.prank(tradingContract);
        pool.depositFees(address(usdc), feeAmount);
    }

    function test_DepositFees_RevertIf_ZeroAmount() public {
        vm.prank(user1);
        pool.addLiquidity(address(usdc), 10_000e6);

        vm.prank(tradingContract);
        vm.expectRevert(ILiquidityPool.ZeroAmount.selector);
        pool.depositFees(address(usdc), 0);
    }

    function test_DepositFees_RevertIf_Unauthorized() public {
        vm.prank(user1);
        pool.addLiquidity(address(usdc), 10_000e6);

        vm.prank(user1); // Not a trading contract
        vm.expectRevert(ILiquidityPool.Unauthorized.selector);
        pool.depositFees(address(usdc), 1000e6);
    }

    function test_DepositFees_RevertIf_PoolEmpty() public {
        vm.prank(tradingContract);
        vm.expectRevert(ILiquidityPool.PoolEmpty.selector);
        pool.depositFees(address(usdc), 1000e6);
    }

    // ============ Pending Fees Tests ============

    function test_PendingFees_CalculatesCorrectly() public {
        vm.prank(user1);
        pool.addLiquidity(address(usdc), 10_000e6);

        vm.prank(tradingContract);
        pool.depositFees(address(usdc), 1000e6);

        uint256 pending = pool.pendingFees(user1);
        uint256 expectedFees = (1000e6 * 70) / 100;
        assertEq(pending, expectedFees);
    }

    function test_PendingFees_ZeroForNewUser() public {
        vm.prank(user1);
        pool.addLiquidity(address(usdc), 10_000e6);

        vm.prank(tradingContract);
        pool.depositFees(address(usdc), 1000e6);

        // User2 hasn't deposited yet
        uint256 pending = pool.pendingFees(user2);
        assertEq(pending, 0);
    }

    function test_PendingFees_NewDepositorNoOldFees() public {
        // User1 deposits first
        vm.prank(user1);
        pool.addLiquidity(address(usdc), 10_000e6);

        // Fees deposited
        vm.prank(tradingContract);
        pool.depositFees(address(usdc), 1000e6);

        // User2 deposits after fees
        vm.prank(user2);
        pool.addLiquidity(address(usdc), 10_000e6);

        // User2 should have 0 pending (joined after fees)
        uint256 pending = pool.pendingFees(user2);
        assertEq(pending, 0);

        // User1 should have all fees
        uint256 user1Pending = pool.pendingFees(user1);
        assertEq(user1Pending, (1000e6 * 70) / 100);
    }

    // ============ View Functions Tests ============

    function test_GetUserInfo() public {
        vm.prank(user1);
        pool.addLiquidity(address(usdc), 10_000e6);

        ILiquidityPool.UserInfo memory info = pool.getUserInfo(user1);
        assertEq(info.lpBalance, 10_000e6 * 1e12);
        assertEq(info.depositTime, block.timestamp);
    }

    function test_GetTotalPoolValue() public {
        vm.prank(user1);
        pool.addLiquidity(address(usdc), 10_000e6);
        vm.prank(user2);
        pool.addLiquidity(address(usdc), 5_000e6);

        uint256 totalValue = pool.getTotalPoolValue();
        assertEq(totalValue, 15_000e6);
    }

    function test_IsTokenWhitelisted() public {
        assertTrue(pool.isTokenWhitelisted(address(usdc)));
        assertTrue(pool.isTokenWhitelisted(address(paxg)));

        MockERC20 unknownToken = new MockERC20("Unknown", "UNK", 18);
        assertFalse(pool.isTokenWhitelisted(address(unknownToken)));
    }

    // ============ Admin Functions Tests ============

    function test_SetCooldownPeriod() public {
        uint256 newCooldown = 12 hours;

        vm.expectEmit(false, false, false, true);
        emit ILiquidityPool.CooldownUpdated(DEFAULT_COOLDOWN, newCooldown);

        pool.setCooldownPeriod(newCooldown);
        assertEq(pool.getCooldownPeriod(), newCooldown);
    }

    function test_SetCooldownPeriod_RevertIf_NotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        pool.setCooldownPeriod(12 hours);
    }

    function test_SetProtocolTreasury() public {
        address newTreasury = makeAddr("newTreasury");

        vm.expectEmit(true, true, false, false);
        emit ILiquidityPool.ProtocolTreasurySet(treasury, newTreasury);

        pool.setProtocolTreasury(newTreasury);
        assertEq(pool.protocolTreasury(), newTreasury);
    }

    function test_SetProtocolTreasury_RevertIf_ZeroAddress() public {
        vm.expectRevert(ILiquidityPool.ZeroAddress.selector);
        pool.setProtocolTreasury(address(0));
    }

    function test_SetProtocolTreasury_RevertIf_NotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        pool.setProtocolTreasury(makeAddr("newTreasury"));
    }

    function test_SetTokenWhitelist() public {
        MockERC20 newToken = new MockERC20("New Token", "NEW", 18);

        vm.expectEmit(true, false, false, true);
        emit ILiquidityPool.TokenWhitelisted(address(newToken), true);

        pool.setTokenWhitelist(address(newToken), true);
        assertTrue(pool.isTokenWhitelisted(address(newToken)));

        pool.setTokenWhitelist(address(newToken), false);
        assertFalse(pool.isTokenWhitelisted(address(newToken)));
    }

    function test_SetTokenWhitelist_RevertIf_NotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        pool.setTokenWhitelist(address(usdc), false);
    }

    function test_SetTradingContract() public {
        address newTrading = makeAddr("newTrading");
        pool.setTradingContract(newTrading, true);
        assertTrue(pool.isTradingContract(newTrading));
    }

    function test_SetTradingContract_RevertIf_NotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        pool.setTradingContract(makeAddr("newTrading"), true);
    }

    // ============ Integration Tests ============

    function test_Integration_MultiUserFeeDistribution() public {
        // Setup: 3 users with different deposit amounts
        vm.prank(user1);
        pool.addLiquidity(address(usdc), 10_000e6); // 25%

        vm.prank(user2);
        pool.addLiquidity(address(usdc), 20_000e6); // 50%

        vm.prank(user3);
        pool.addLiquidity(address(usdc), 10_000e6); // 25%

        // Multiple fee deposits
        vm.startPrank(tradingContract);
        pool.depositFees(address(usdc), 1000e6);
        pool.depositFees(address(usdc), 2000e6);
        pool.depositFees(address(usdc), 1000e6);
        vm.stopPrank();

        // Total fees: 4000e6, LP share: 2800e6
        uint256 totalLPFees = (4000e6 * 70) / 100;

        // Check pending fees proportional to LP share
        assertApproxEqAbs(pool.pendingFees(user1), totalLPFees / 4, 2);
        assertApproxEqAbs(pool.pendingFees(user2), totalLPFees / 2, 2);
        assertApproxEqAbs(pool.pendingFees(user3), totalLPFees / 4, 2);

        // Users claim fees
        vm.prank(user1);
        uint256 claimed1 = pool.claimFees();
        vm.prank(user2);
        uint256 claimed2 = pool.claimFees();
        vm.prank(user3);
        uint256 claimed3 = pool.claimFees();

        // Verify total claimed equals total LP fees
        assertApproxEqAbs(claimed1 + claimed2 + claimed3, totalLPFees, 3);
    }

    function test_Integration_DepositClaimWithdrawCycle() public {
        // Step 1: User deposits
        vm.prank(user1);
        uint256 lpAmount = pool.addLiquidity(address(usdc), 10_000e6);
        assertEq(lpToken.balanceOf(user1), lpAmount);

        // Step 2: Fees accumulate
        vm.prank(tradingContract);
        pool.depositFees(address(usdc), 1000e6);

        // Step 3: User claims fees
        vm.prank(user1);
        uint256 claimed = pool.claimFees();
        assertEq(claimed, (1000e6 * 70) / 100);

        // Step 4: More fees accumulate
        vm.prank(tradingContract);
        pool.depositFees(address(usdc), 500e6);

        // Step 5: Wait for cooldown and withdraw
        vm.warp(block.timestamp + DEFAULT_COOLDOWN + 1);

        vm.prank(user1);
        (uint256 assets, uint256 fees) = pool.removeLiquidity(lpAmount);

        assertEq(assets, 10_000e6);
        assertEq(fees, (500e6 * 70) / 100);
    }

    // ============ Gas Tests ============

    function test_Gas_AddLiquidity() public {
        vm.prank(user1);
        uint256 gasBefore = gasleft();
        pool.addLiquidity(address(usdc), 10_000e6);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Gas used for addLiquidity:", gasUsed);
        assertLt(gasUsed, 250_000); // Should be under 250k gas
    }

    function test_Gas_RemoveLiquidity() public {
        vm.prank(user1);
        uint256 lpAmount = pool.addLiquidity(address(usdc), 10_000e6);

        vm.warp(block.timestamp + DEFAULT_COOLDOWN + 1);

        vm.prank(user1);
        uint256 gasBefore = gasleft();
        pool.removeLiquidity(lpAmount);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Gas used for removeLiquidity:", gasUsed);
        assertLt(gasUsed, 150_000); // Should be under 150k gas
    }

    function test_Gas_ClaimFees() public {
        vm.prank(user1);
        pool.addLiquidity(address(usdc), 10_000e6);

        vm.prank(tradingContract);
        pool.depositFees(address(usdc), 1000e6);

        vm.prank(user1);
        uint256 gasBefore = gasleft();
        pool.claimFees();
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Gas used for claimFees:", gasUsed);
        assertLt(gasUsed, 100_000); // Should be under 100k gas
    }

    // ============ Fuzz Tests ============

    function testFuzz_AddLiquidity_AnyAmount(uint256 amount) public {
        amount = bound(amount, 1, 1_000_000e6);
        usdc.mint(user1, amount);

        vm.prank(user1);
        uint256 lpAmount = pool.addLiquidity(address(usdc), amount);

        assertGt(lpAmount, 0);
        assertEq(lpToken.balanceOf(user1), lpAmount);
    }

    function testFuzz_FeeDistribution_Proportional(uint256 deposit1, uint256 deposit2, uint256 feeAmount) public {
        deposit1 = bound(deposit1, 1000e6, 100_000e6);
        deposit2 = bound(deposit2, 1000e6, 100_000e6);
        feeAmount = bound(feeAmount, 100e6, 10_000e6);

        usdc.mint(user1, deposit1);
        usdc.mint(user2, deposit2);
        usdc.mint(tradingContract, feeAmount);

        vm.prank(user1);
        pool.addLiquidity(address(usdc), deposit1);
        vm.prank(user2);
        pool.addLiquidity(address(usdc), deposit2);

        vm.prank(tradingContract);
        pool.depositFees(address(usdc), feeAmount);

        uint256 pending1 = pool.pendingFees(user1);
        uint256 pending2 = pool.pendingFees(user2);

        uint256 totalLPFees = (feeAmount * 70) / 100;

        // Verify proportional distribution (with rounding tolerance)
        assertApproxEqRel(pending1 + pending2, totalLPFees, 0.01e18); // 1% tolerance
    }
}
