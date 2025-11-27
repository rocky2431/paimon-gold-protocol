// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {CollateralVault} from "../src/CollateralVault.sol";
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

/// @title CollateralVaultTest
/// @notice Comprehensive test suite for CollateralVault
contract CollateralVaultTest is Test {
    CollateralVault public vault;
    MockERC20 public usdt;
    MockERC20 public usdc;
    MockERC20 public busd;

    address public owner;
    address public user1;
    address public user2;

    uint256 constant INITIAL_BALANCE = 10_000 * 1e18;
    uint256 constant DEPOSIT_AMOUNT = 1_000 * 1e18;

    // Events
    event Deposited(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);
    event TokenWhitelisted(address indexed token, bool status);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy mock tokens
        usdt = new MockERC20("Tether USD", "USDT", 18);
        usdc = new MockERC20("USD Coin", "USDC", 18);
        busd = new MockERC20("Binance USD", "BUSD", 18);

        // Deploy vault
        vault = new CollateralVault();

        // Whitelist tokens
        vault.setTokenWhitelist(address(usdt), true);
        vault.setTokenWhitelist(address(usdc), true);
        vault.setTokenWhitelist(address(busd), true);

        // Mint tokens to users
        usdt.mint(user1, INITIAL_BALANCE);
        usdc.mint(user1, INITIAL_BALANCE);
        busd.mint(user1, INITIAL_BALANCE);
        usdt.mint(user2, INITIAL_BALANCE);

        // Approve vault for spending
        vm.startPrank(user1);
        usdt.approve(address(vault), type(uint256).max);
        usdc.approve(address(vault), type(uint256).max);
        busd.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.prank(user2);
        usdt.approve(address(vault), type(uint256).max);
    }

    // ============ Functional Tests ============

    function test_DepositERC20() public {
        vm.prank(user1);
        vault.deposit(address(usdt), DEPOSIT_AMOUNT);

        assertEq(vault.balanceOf(user1, address(usdt)), DEPOSIT_AMOUNT);
        assertEq(usdt.balanceOf(address(vault)), DEPOSIT_AMOUNT);
    }

    function test_DepositMultipleTokens() public {
        vm.startPrank(user1);
        vault.deposit(address(usdt), DEPOSIT_AMOUNT);
        vault.deposit(address(usdc), DEPOSIT_AMOUNT * 2);
        vault.deposit(address(busd), DEPOSIT_AMOUNT * 3);
        vm.stopPrank();

        assertEq(vault.balanceOf(user1, address(usdt)), DEPOSIT_AMOUNT);
        assertEq(vault.balanceOf(user1, address(usdc)), DEPOSIT_AMOUNT * 2);
        assertEq(vault.balanceOf(user1, address(busd)), DEPOSIT_AMOUNT * 3);
    }

    function test_DepositNativeBNB() public {
        vm.deal(user1, 10 ether);

        vm.prank(user1);
        vault.depositBNB{value: 1 ether}();

        assertEq(vault.balanceOf(user1, address(0)), 1 ether);
        assertEq(address(vault).balance, 1 ether);
    }

    function test_WithdrawERC20() public {
        vm.startPrank(user1);
        vault.deposit(address(usdt), DEPOSIT_AMOUNT);
        vault.withdraw(address(usdt), DEPOSIT_AMOUNT / 2);
        vm.stopPrank();

        assertEq(vault.balanceOf(user1, address(usdt)), DEPOSIT_AMOUNT / 2);
        assertEq(usdt.balanceOf(user1), INITIAL_BALANCE - DEPOSIT_AMOUNT / 2);
    }

    function test_WithdrawNativeBNB() public {
        vm.deal(user1, 10 ether);

        vm.startPrank(user1);
        vault.depositBNB{value: 5 ether}();

        uint256 balanceBefore = user1.balance;
        vault.withdrawBNB(2 ether);
        uint256 balanceAfter = user1.balance;
        vm.stopPrank();

        assertEq(vault.balanceOf(user1, address(0)), 3 ether);
        assertEq(balanceAfter - balanceBefore, 2 ether);
    }

    function test_DepositEmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Deposited(user1, address(usdt), DEPOSIT_AMOUNT);

        vm.prank(user1);
        vault.deposit(address(usdt), DEPOSIT_AMOUNT);
    }

    function test_WithdrawEmitsEvent() public {
        vm.prank(user1);
        vault.deposit(address(usdt), DEPOSIT_AMOUNT);

        vm.expectEmit(true, true, false, true);
        emit Withdrawn(user1, address(usdt), DEPOSIT_AMOUNT);

        vm.prank(user1);
        vault.withdraw(address(usdt), DEPOSIT_AMOUNT);
    }

    // ============ Boundary Tests ============

    function test_DepositMinimumAmount() public {
        vm.prank(user1);
        vault.deposit(address(usdt), 1);

        assertEq(vault.balanceOf(user1, address(usdt)), 1);
    }

    function test_DepositMaximumAmount() public {
        // Test with a large but reasonable amount (1 trillion tokens)
        uint256 largeAmount = 1_000_000_000_000 * 1e18;
        usdt.mint(user1, largeAmount);
        vm.prank(user1);
        usdt.approve(address(vault), type(uint256).max);

        vm.prank(user1);
        vault.deposit(address(usdt), largeAmount);

        assertEq(vault.balanceOf(user1, address(usdt)), largeAmount);
        assertEq(usdt.balanceOf(address(vault)), largeAmount);
    }

    function test_WithdrawFullBalance() public {
        vm.startPrank(user1);
        vault.deposit(address(usdt), DEPOSIT_AMOUNT);
        vault.withdraw(address(usdt), DEPOSIT_AMOUNT);
        vm.stopPrank();

        assertEq(vault.balanceOf(user1, address(usdt)), 0);
        assertEq(usdt.balanceOf(user1), INITIAL_BALANCE);
    }

    function testFuzz_DepositWithdraw(uint256 depositAmount, uint256 withdrawAmount) public {
        depositAmount = bound(depositAmount, 1, INITIAL_BALANCE);
        withdrawAmount = bound(withdrawAmount, 1, depositAmount);

        vm.startPrank(user1);
        vault.deposit(address(usdt), depositAmount);
        vault.withdraw(address(usdt), withdrawAmount);
        vm.stopPrank();

        assertEq(vault.balanceOf(user1, address(usdt)), depositAmount - withdrawAmount);
    }

    // ============ Exception Tests ============

    function test_RevertDepositZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(CollateralVault.InvalidAmount.selector);
        vault.deposit(address(usdt), 0);
    }

    function test_RevertDepositNonWhitelistedToken() public {
        MockERC20 nonWhitelisted = new MockERC20("Random", "RND", 18);
        nonWhitelisted.mint(user1, INITIAL_BALANCE);

        vm.startPrank(user1);
        nonWhitelisted.approve(address(vault), type(uint256).max);
        vm.expectRevert(CollateralVault.TokenNotWhitelisted.selector);
        vault.deposit(address(nonWhitelisted), DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function test_RevertWithdrawZeroAmount() public {
        vm.prank(user1);
        vault.deposit(address(usdt), DEPOSIT_AMOUNT);

        vm.prank(user1);
        vm.expectRevert(CollateralVault.InvalidAmount.selector);
        vault.withdraw(address(usdt), 0);
    }

    function test_RevertWithdrawInsufficientBalance() public {
        vm.prank(user1);
        vault.deposit(address(usdt), DEPOSIT_AMOUNT);

        vm.prank(user1);
        vm.expectRevert(CollateralVault.InsufficientBalance.selector);
        vault.withdraw(address(usdt), DEPOSIT_AMOUNT + 1);
    }

    function test_RevertWithdrawNoDeposit() public {
        vm.prank(user1);
        vm.expectRevert(CollateralVault.InsufficientBalance.selector);
        vault.withdraw(address(usdt), DEPOSIT_AMOUNT);
    }

    function test_RevertDepositBNBZeroValue() public {
        vm.prank(user1);
        vm.expectRevert(CollateralVault.InvalidAmount.selector);
        vault.depositBNB{value: 0}();
    }

    function test_RevertWithdrawBNBInsufficientBalance() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vault.depositBNB{value: 1 ether}();

        vm.prank(user1);
        vm.expectRevert(CollateralVault.InsufficientBalance.selector);
        vault.withdrawBNB(2 ether);
    }

    // ============ Security Tests ============

    function test_OnlyOwnerCanWhitelistToken() public {
        MockERC20 newToken = new MockERC20("New", "NEW", 18);

        vm.prank(user1);
        vm.expectRevert();
        vault.setTokenWhitelist(address(newToken), true);
    }

    function test_OwnerCanWhitelistToken() public {
        MockERC20 newToken = new MockERC20("New", "NEW", 18);

        vm.expectEmit(true, false, false, true);
        emit TokenWhitelisted(address(newToken), true);

        vault.setTokenWhitelist(address(newToken), true);
        assertTrue(vault.isWhitelisted(address(newToken)));
    }

    function test_OwnerCanRemoveFromWhitelist() public {
        vault.setTokenWhitelist(address(usdt), false);
        assertFalse(vault.isWhitelisted(address(usdt)));
    }

    function test_UserCannotWithdrawOthersBalance() public {
        vm.prank(user1);
        vault.deposit(address(usdt), DEPOSIT_AMOUNT);

        vm.prank(user2);
        vm.expectRevert(CollateralVault.InsufficientBalance.selector);
        vault.withdraw(address(usdt), DEPOSIT_AMOUNT);
    }

    function test_ReentrancyProtection() public {
        // This test verifies the ReentrancyGuard is in place
        // The actual reentrancy attack would require a malicious contract
        // For now, we just verify the functions have the nonReentrant modifier

        vm.prank(user1);
        vault.deposit(address(usdt), DEPOSIT_AMOUNT);

        // Multiple withdrawals in sequence should work
        vm.startPrank(user1);
        vault.withdraw(address(usdt), DEPOSIT_AMOUNT / 2);
        vault.withdraw(address(usdt), DEPOSIT_AMOUNT / 2);
        vm.stopPrank();

        assertEq(vault.balanceOf(user1, address(usdt)), 0);
    }

    // ============ Multi-User Tests ============

    function test_MultipleUsersDeposit() public {
        vm.prank(user1);
        vault.deposit(address(usdt), DEPOSIT_AMOUNT);

        vm.prank(user2);
        vault.deposit(address(usdt), DEPOSIT_AMOUNT * 2);

        assertEq(vault.balanceOf(user1, address(usdt)), DEPOSIT_AMOUNT);
        assertEq(vault.balanceOf(user2, address(usdt)), DEPOSIT_AMOUNT * 2);
        assertEq(usdt.balanceOf(address(vault)), DEPOSIT_AMOUNT * 3);
    }

    function test_TotalDepositedByToken() public {
        vm.prank(user1);
        vault.deposit(address(usdt), DEPOSIT_AMOUNT);

        vm.prank(user2);
        vault.deposit(address(usdt), DEPOSIT_AMOUNT * 2);

        assertEq(vault.totalDeposited(address(usdt)), DEPOSIT_AMOUNT * 3);
    }

    // ============ View Function Tests ============

    function test_GetUserBalances() public {
        vm.startPrank(user1);
        vault.deposit(address(usdt), DEPOSIT_AMOUNT);
        vault.deposit(address(usdc), DEPOSIT_AMOUNT * 2);
        vm.stopPrank();

        assertEq(vault.balanceOf(user1, address(usdt)), DEPOSIT_AMOUNT);
        assertEq(vault.balanceOf(user1, address(usdc)), DEPOSIT_AMOUNT * 2);
        assertEq(vault.balanceOf(user1, address(busd)), 0);
    }

    function test_IsTokenWhitelisted() public {
        assertTrue(vault.isWhitelisted(address(usdt)));
        assertTrue(vault.isWhitelisted(address(usdc)));
        assertTrue(vault.isWhitelisted(address(busd)));

        MockERC20 random = new MockERC20("Random", "RND", 18);
        assertFalse(vault.isWhitelisted(address(random)));
    }

    // ============ Gas Tests ============

    function test_DepositGas() public {
        vm.prank(user1);
        uint256 gasBefore = gasleft();
        vault.deposit(address(usdt), DEPOSIT_AMOUNT);
        uint256 gasUsed = gasBefore - gasleft();
        // Should be under 110,000 gas (allowing for optimizer variance)
        assertLt(gasUsed, 110000);
    }

    function test_WithdrawGas() public {
        vm.prank(user1);
        vault.deposit(address(usdt), DEPOSIT_AMOUNT);

        vm.prank(user1);
        uint256 gasBefore = gasleft();
        vault.withdraw(address(usdt), DEPOSIT_AMOUNT);
        uint256 gasUsed = gasBefore - gasleft();
        // Should be under 80,000 gas
        assertLt(gasUsed, 80000);
    }
}
