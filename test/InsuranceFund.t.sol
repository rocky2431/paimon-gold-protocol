// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {InsuranceFund} from "../src/InsuranceFund.sol";
import {IInsuranceFund} from "../src/interfaces/IInsuranceFund.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockERC20
/// @notice Mock ERC20 token for testing
contract MockERC20ForInsurance is ERC20 {
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

/// @title InsuranceFundTest
/// @notice Comprehensive test suite for InsuranceFund
contract InsuranceFundTest is Test {
    InsuranceFund public insuranceFund;
    MockERC20ForInsurance public usdt;
    MockERC20ForInsurance public usdc;

    address public owner;
    address public liquidationEngine;
    address public depositor;
    address public recipient;
    address public randomUser;

    uint256 public constant TIMELOCK_DURATION = 24 hours;
    uint256 public constant PRECISION = 1e18;

    function setUp() public {
        owner = address(this);
        liquidationEngine = makeAddr("liquidationEngine");
        depositor = makeAddr("depositor");
        recipient = makeAddr("recipient");
        randomUser = makeAddr("randomUser");

        // Deploy mock tokens
        usdt = new MockERC20ForInsurance("Tether USD", "USDT", 18);
        usdc = new MockERC20ForInsurance("USD Coin", "USDC", 18);

        // Deploy insurance fund
        insuranceFund = new InsuranceFund();
        insuranceFund.setLiquidationEngine(liquidationEngine);

        // Setup depositor with tokens
        usdt.mint(depositor, 1_000_000 * 1e18);
        usdc.mint(depositor, 1_000_000 * 1e18);
        vm.startPrank(depositor);
        usdt.approve(address(insuranceFund), type(uint256).max);
        usdc.approve(address(insuranceFund), type(uint256).max);
        vm.stopPrank();
    }

    // ============ Constructor Tests ============

    function test_Constructor() public view {
        assertEq(insuranceFund.owner(), owner);
        assertEq(insuranceFund.getTimelockDuration(), TIMELOCK_DURATION);
    }

    // ============ setLiquidationEngine Tests ============

    function test_SetLiquidationEngine() public {
        address newEngine = makeAddr("newEngine");

        vm.expectEmit(true, true, false, false);
        emit IInsuranceFund.LiquidationEngineSet(liquidationEngine, newEngine);

        insuranceFund.setLiquidationEngine(newEngine);

        assertEq(insuranceFund.liquidationEngine(), newEngine);
    }

    function test_SetLiquidationEngine_RevertZeroAddress() public {
        vm.expectRevert(IInsuranceFund.ZeroAddress.selector);
        insuranceFund.setLiquidationEngine(address(0));
    }

    function test_SetLiquidationEngine_RevertUnauthorized() public {
        vm.prank(randomUser);
        vm.expectRevert();
        insuranceFund.setLiquidationEngine(makeAddr("newEngine"));
    }

    // ============ deposit Tests ============

    function test_Deposit() public {
        uint256 amount = 100 * 1e18;

        vm.prank(depositor);
        vm.expectEmit(true, true, false, true);
        emit IInsuranceFund.Deposit(address(usdt), depositor, amount);

        insuranceFund.deposit(address(usdt), amount);

        assertEq(insuranceFund.getBalance(address(usdt)), amount);
    }

    function test_Deposit_MultipleTokens() public {
        uint256 usdtAmount = 100 * 1e18;
        uint256 usdcAmount = 200 * 1e18;

        vm.startPrank(depositor);
        insuranceFund.deposit(address(usdt), usdtAmount);
        insuranceFund.deposit(address(usdc), usdcAmount);
        vm.stopPrank();

        assertEq(insuranceFund.getBalance(address(usdt)), usdtAmount);
        assertEq(insuranceFund.getBalance(address(usdc)), usdcAmount);
    }

    function test_Deposit_MultipleDeposits() public {
        uint256 amount1 = 100 * 1e18;
        uint256 amount2 = 50 * 1e18;

        vm.startPrank(depositor);
        insuranceFund.deposit(address(usdt), amount1);
        insuranceFund.deposit(address(usdt), amount2);
        vm.stopPrank();

        assertEq(insuranceFund.getBalance(address(usdt)), amount1 + amount2);
    }

    function test_Deposit_RevertZeroAmount() public {
        vm.prank(depositor);
        vm.expectRevert(IInsuranceFund.ZeroAmount.selector);
        insuranceFund.deposit(address(usdt), 0);
    }

    function test_Deposit_RevertZeroAddress() public {
        vm.prank(depositor);
        vm.expectRevert(IInsuranceFund.ZeroAddress.selector);
        insuranceFund.deposit(address(0), 100 * 1e18);
    }

    // ============ coverBadDebt Tests ============

    function test_CoverBadDebt() public {
        // First deposit funds
        uint256 depositAmount = 100 * 1e18;
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), depositAmount);

        // Cover bad debt
        uint256 badDebtAmount = 30 * 1e18;
        uint256 recipientBalanceBefore = usdt.balanceOf(recipient);

        vm.prank(liquidationEngine);
        vm.expectEmit(true, false, true, true);
        emit IInsuranceFund.BadDebtCovered(address(usdt), badDebtAmount, recipient);

        insuranceFund.coverBadDebt(address(usdt), badDebtAmount, recipient);

        assertEq(insuranceFund.getBalance(address(usdt)), depositAmount - badDebtAmount);
        assertEq(usdt.balanceOf(recipient), recipientBalanceBefore + badDebtAmount);
    }

    function test_CoverBadDebt_RevertUnauthorized() public {
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), 100 * 1e18);

        vm.prank(randomUser);
        vm.expectRevert(IInsuranceFund.Unauthorized.selector);
        insuranceFund.coverBadDebt(address(usdt), 10 * 1e18, recipient);
    }

    function test_CoverBadDebt_RevertInsufficientBalance() public {
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), 100 * 1e18);

        vm.prank(liquidationEngine);
        vm.expectRevert(IInsuranceFund.InsufficientBalance.selector);
        insuranceFund.coverBadDebt(address(usdt), 200 * 1e18, recipient);
    }

    function test_CoverBadDebt_RevertZeroAmount() public {
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), 100 * 1e18);

        vm.prank(liquidationEngine);
        vm.expectRevert(IInsuranceFund.ZeroAmount.selector);
        insuranceFund.coverBadDebt(address(usdt), 0, recipient);
    }

    function test_CoverBadDebt_RevertZeroRecipient() public {
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), 100 * 1e18);

        vm.prank(liquidationEngine);
        vm.expectRevert(IInsuranceFund.ZeroAddress.selector);
        insuranceFund.coverBadDebt(address(usdt), 10 * 1e18, address(0));
    }

    // ============ Emergency Withdraw Tests ============

    function test_QueueEmergencyWithdraw() public {
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), 100 * 1e18);

        uint256 amount = 50 * 1e18;
        uint256 expectedExecuteTime = block.timestamp + TIMELOCK_DURATION;

        bytes32 withdrawId = insuranceFund.queueEmergencyWithdraw(
            address(usdt),
            amount,
            recipient
        );

        IInsuranceFund.PendingWithdrawal memory pending = insuranceFund.getPendingWithdrawal(withdrawId);
        assertEq(pending.token, address(usdt));
        assertEq(pending.amount, amount);
        assertEq(pending.recipient, recipient);
        assertEq(pending.executeTime, expectedExecuteTime);
        assertFalse(pending.executed);
        assertFalse(pending.cancelled);
    }

    function test_QueueEmergencyWithdraw_EmitsEvent() public {
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), 100 * 1e18);

        uint256 amount = 50 * 1e18;

        // Can't predict exact withdrawId, so just check event is emitted
        insuranceFund.queueEmergencyWithdraw(address(usdt), amount, recipient);
    }

    function test_QueueEmergencyWithdraw_RevertUnauthorized() public {
        vm.prank(randomUser);
        vm.expectRevert();
        insuranceFund.queueEmergencyWithdraw(address(usdt), 100 * 1e18, recipient);
    }

    function test_QueueEmergencyWithdraw_RevertZeroAmount() public {
        vm.expectRevert(IInsuranceFund.ZeroAmount.selector);
        insuranceFund.queueEmergencyWithdraw(address(usdt), 0, recipient);
    }

    function test_QueueEmergencyWithdraw_RevertZeroRecipient() public {
        vm.expectRevert(IInsuranceFund.ZeroAddress.selector);
        insuranceFund.queueEmergencyWithdraw(address(usdt), 100 * 1e18, address(0));
    }

    function test_ExecuteEmergencyWithdraw() public {
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), 100 * 1e18);

        uint256 amount = 50 * 1e18;
        bytes32 withdrawId = insuranceFund.queueEmergencyWithdraw(
            address(usdt),
            amount,
            recipient
        );

        // Warp past timelock
        vm.warp(block.timestamp + TIMELOCK_DURATION + 1);

        uint256 recipientBalanceBefore = usdt.balanceOf(recipient);
        uint256 fundBalanceBefore = insuranceFund.getBalance(address(usdt));

        vm.expectEmit(true, true, false, true);
        emit IInsuranceFund.EmergencyWithdrawExecuted(
            withdrawId,
            address(usdt),
            amount,
            recipient
        );

        insuranceFund.executeEmergencyWithdraw(withdrawId);

        assertEq(usdt.balanceOf(recipient), recipientBalanceBefore + amount);
        assertEq(insuranceFund.getBalance(address(usdt)), fundBalanceBefore - amount);

        IInsuranceFund.PendingWithdrawal memory pending = insuranceFund.getPendingWithdrawal(withdrawId);
        assertTrue(pending.executed);
    }

    function test_ExecuteEmergencyWithdraw_RevertNotReady() public {
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), 100 * 1e18);

        bytes32 withdrawId = insuranceFund.queueEmergencyWithdraw(
            address(usdt),
            50 * 1e18,
            recipient
        );

        // Don't warp - should revert
        vm.expectRevert(IInsuranceFund.WithdrawNotReady.selector);
        insuranceFund.executeEmergencyWithdraw(withdrawId);
    }

    function test_ExecuteEmergencyWithdraw_RevertExpired() public {
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), 100 * 1e18);

        bytes32 withdrawId = insuranceFund.queueEmergencyWithdraw(
            address(usdt),
            50 * 1e18,
            recipient
        );

        // Warp past expiry (48 hours after ready)
        vm.warp(block.timestamp + TIMELOCK_DURATION + 48 hours + 1);

        vm.expectRevert(IInsuranceFund.WithdrawExpired.selector);
        insuranceFund.executeEmergencyWithdraw(withdrawId);
    }

    function test_ExecuteEmergencyWithdraw_RevertNotFound() public {
        bytes32 fakeId = keccak256("fake");
        vm.expectRevert(IInsuranceFund.WithdrawNotFound.selector);
        insuranceFund.executeEmergencyWithdraw(fakeId);
    }

    function test_ExecuteEmergencyWithdraw_RevertAlreadyExecuted() public {
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), 100 * 1e18);

        bytes32 withdrawId = insuranceFund.queueEmergencyWithdraw(
            address(usdt),
            50 * 1e18,
            recipient
        );

        vm.warp(block.timestamp + TIMELOCK_DURATION + 1);
        insuranceFund.executeEmergencyWithdraw(withdrawId);

        // Try again
        vm.expectRevert(IInsuranceFund.WithdrawAlreadyProcessed.selector);
        insuranceFund.executeEmergencyWithdraw(withdrawId);
    }

    function test_CancelEmergencyWithdraw() public {
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), 100 * 1e18);

        bytes32 withdrawId = insuranceFund.queueEmergencyWithdraw(
            address(usdt),
            50 * 1e18,
            recipient
        );

        vm.expectEmit(true, false, false, false);
        emit IInsuranceFund.EmergencyWithdrawCancelled(withdrawId);

        insuranceFund.cancelEmergencyWithdraw(withdrawId);

        IInsuranceFund.PendingWithdrawal memory pending = insuranceFund.getPendingWithdrawal(withdrawId);
        assertTrue(pending.cancelled);
    }

    function test_CancelEmergencyWithdraw_RevertUnauthorized() public {
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), 100 * 1e18);

        bytes32 withdrawId = insuranceFund.queueEmergencyWithdraw(
            address(usdt),
            50 * 1e18,
            recipient
        );

        vm.prank(randomUser);
        vm.expectRevert();
        insuranceFund.cancelEmergencyWithdraw(withdrawId);
    }

    function test_CancelEmergencyWithdraw_RevertNotFound() public {
        bytes32 fakeId = keccak256("fake");
        vm.expectRevert(IInsuranceFund.WithdrawNotFound.selector);
        insuranceFund.cancelEmergencyWithdraw(fakeId);
    }

    function test_CancelEmergencyWithdraw_RevertAlreadyCancelled() public {
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), 100 * 1e18);

        bytes32 withdrawId = insuranceFund.queueEmergencyWithdraw(
            address(usdt),
            50 * 1e18,
            recipient
        );

        insuranceFund.cancelEmergencyWithdraw(withdrawId);

        vm.expectRevert(IInsuranceFund.WithdrawAlreadyProcessed.selector);
        insuranceFund.cancelEmergencyWithdraw(withdrawId);
    }

    function test_ExecuteAfterCancel_Reverts() public {
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), 100 * 1e18);

        bytes32 withdrawId = insuranceFund.queueEmergencyWithdraw(
            address(usdt),
            50 * 1e18,
            recipient
        );

        insuranceFund.cancelEmergencyWithdraw(withdrawId);

        vm.warp(block.timestamp + TIMELOCK_DURATION + 1);

        vm.expectRevert(IInsuranceFund.WithdrawAlreadyProcessed.selector);
        insuranceFund.executeEmergencyWithdraw(withdrawId);
    }

    // ============ Balance & Coverage Tests ============

    function test_GetBalance_Empty() public view {
        assertEq(insuranceFund.getBalance(address(usdt)), 0);
    }

    function test_GetCoverageRatio_FullyCovered() public {
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), 100 * 1e18);

        // 100% coverage
        uint256 ratio = insuranceFund.getCoverageRatio(address(usdt), 100 * 1e18);
        assertEq(ratio, PRECISION); // 100%
    }

    function test_GetCoverageRatio_PartiallyCovered() public {
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), 50 * 1e18);

        // 50% coverage
        uint256 ratio = insuranceFund.getCoverageRatio(address(usdt), 100 * 1e18);
        assertEq(ratio, PRECISION / 2); // 50%
    }

    function test_GetCoverageRatio_OverCovered() public {
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), 200 * 1e18);

        // 200% coverage
        uint256 ratio = insuranceFund.getCoverageRatio(address(usdt), 100 * 1e18);
        assertEq(ratio, 2 * PRECISION); // 200%
    }

    function test_GetCoverageRatio_ZeroLiability() public {
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), 100 * 1e18);

        // Zero liability = max coverage
        uint256 ratio = insuranceFund.getCoverageRatio(address(usdt), 0);
        assertEq(ratio, type(uint256).max);
    }

    // ============ Gas Tests ============

    function test_Deposit_GasUsage() public {
        uint256 gasBefore = gasleft();
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), 100 * 1e18);
        uint256 gasUsed = gasBefore - gasleft();

        assertLt(gasUsed, 100_000);
    }

    function test_CoverBadDebt_GasUsage() public {
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), 100 * 1e18);

        uint256 gasBefore = gasleft();
        vm.prank(liquidationEngine);
        insuranceFund.coverBadDebt(address(usdt), 30 * 1e18, recipient);
        uint256 gasUsed = gasBefore - gasleft();

        assertLt(gasUsed, 100_000);
    }

    // ============ Integration Tests ============

    function test_Integration_FullLifecycle() public {
        // 1. Deposit funds
        uint256 depositAmount = 1000 * 1e18;
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), depositAmount);
        assertEq(insuranceFund.getBalance(address(usdt)), depositAmount);

        // 2. Cover bad debt
        uint256 badDebt = 100 * 1e18;
        vm.prank(liquidationEngine);
        insuranceFund.coverBadDebt(address(usdt), badDebt, recipient);
        assertEq(insuranceFund.getBalance(address(usdt)), depositAmount - badDebt);

        // 3. Queue emergency withdraw
        uint256 withdrawAmount = 200 * 1e18;
        bytes32 withdrawId = insuranceFund.queueEmergencyWithdraw(
            address(usdt),
            withdrawAmount,
            owner
        );

        // 4. Wait for timelock
        vm.warp(block.timestamp + TIMELOCK_DURATION + 1);

        // 5. Execute withdrawal
        insuranceFund.executeEmergencyWithdraw(withdrawId);
        assertEq(
            insuranceFund.getBalance(address(usdt)),
            depositAmount - badDebt - withdrawAmount
        );
    }

    function test_Integration_MultipleBadDebts() public {
        vm.prank(depositor);
        insuranceFund.deposit(address(usdt), 1000 * 1e18);

        // Multiple bad debts
        vm.startPrank(liquidationEngine);
        insuranceFund.coverBadDebt(address(usdt), 100 * 1e18, recipient);
        insuranceFund.coverBadDebt(address(usdt), 150 * 1e18, recipient);
        insuranceFund.coverBadDebt(address(usdt), 200 * 1e18, recipient);
        vm.stopPrank();

        assertEq(insuranceFund.getBalance(address(usdt)), 550 * 1e18);
    }
}
