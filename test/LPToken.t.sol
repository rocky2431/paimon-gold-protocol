// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LPToken} from "../src/LPToken.sol";
import {ILPToken} from "../src/interfaces/ILPToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title LPTokenTest
/// @notice Comprehensive test suite for LPToken (UUPS upgradeable)
contract LPTokenTest is Test {
    LPToken public implementation;
    LPToken public lpToken;
    ERC1967Proxy public proxy;

    address public owner;
    address public liquidityPool;
    address public user1;
    address public user2;
    address public randomUser;

    string public constant TOKEN_NAME = "Paimon LP Token";
    string public constant TOKEN_SYMBOL = "PLP";

    function setUp() public {
        owner = address(this);
        liquidityPool = makeAddr("liquidityPool");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        randomUser = makeAddr("randomUser");

        // Deploy implementation
        implementation = new LPToken();

        // Deploy proxy and initialize
        bytes memory initData = abi.encodeWithSelector(
            LPToken.initialize.selector,
            TOKEN_NAME,
            TOKEN_SYMBOL
        );
        proxy = new ERC1967Proxy(address(implementation), initData);

        // Cast proxy to LPToken
        lpToken = LPToken(address(proxy));

        // Set liquidity pool
        lpToken.setLiquidityPool(liquidityPool);
    }

    // ============ Initialize Tests ============

    function test_Initialize() public view {
        assertEq(lpToken.name(), TOKEN_NAME);
        assertEq(lpToken.symbol(), TOKEN_SYMBOL);
        assertEq(lpToken.decimals(), 18);
        assertEq(lpToken.owner(), owner);
    }

    function test_Initialize_RevertDoubleInit() public {
        vm.expectRevert();
        lpToken.initialize("New Name", "NEW");
    }

    // ============ setLiquidityPool Tests ============

    function test_SetLiquidityPool() public {
        address newPool = makeAddr("newPool");

        vm.expectEmit(true, true, false, false);
        emit ILPToken.LiquidityPoolSet(liquidityPool, newPool);

        lpToken.setLiquidityPool(newPool);
        assertEq(lpToken.liquidityPool(), newPool);
    }

    function test_SetLiquidityPool_RevertZeroAddress() public {
        vm.expectRevert(ILPToken.ZeroAddress.selector);
        lpToken.setLiquidityPool(address(0));
    }

    function test_SetLiquidityPool_RevertUnauthorized() public {
        vm.prank(randomUser);
        vm.expectRevert();
        lpToken.setLiquidityPool(makeAddr("newPool"));
    }

    // ============ mint Tests ============

    function test_Mint() public {
        uint256 amount = 100 * 1e18;

        vm.prank(liquidityPool);
        lpToken.mint(user1, amount);

        assertEq(lpToken.balanceOf(user1), amount);
        assertEq(lpToken.totalSupply(), amount);
    }

    function test_Mint_MultipleMints() public {
        uint256 amount1 = 100 * 1e18;
        uint256 amount2 = 50 * 1e18;

        vm.startPrank(liquidityPool);
        lpToken.mint(user1, amount1);
        lpToken.mint(user2, amount2);
        vm.stopPrank();

        assertEq(lpToken.balanceOf(user1), amount1);
        assertEq(lpToken.balanceOf(user2), amount2);
        assertEq(lpToken.totalSupply(), amount1 + amount2);
    }

    function test_Mint_RevertUnauthorized() public {
        vm.prank(randomUser);
        vm.expectRevert(ILPToken.Unauthorized.selector);
        lpToken.mint(user1, 100 * 1e18);
    }

    function test_Mint_RevertZeroAddress() public {
        vm.prank(liquidityPool);
        vm.expectRevert(ILPToken.ZeroAddress.selector);
        lpToken.mint(address(0), 100 * 1e18);
    }

    function test_Mint_RevertZeroAmount() public {
        vm.prank(liquidityPool);
        vm.expectRevert(ILPToken.ZeroAmount.selector);
        lpToken.mint(user1, 0);
    }

    // ============ burn Tests ============

    function test_Burn() public {
        uint256 mintAmount = 100 * 1e18;
        uint256 burnAmount = 30 * 1e18;

        vm.prank(liquidityPool);
        lpToken.mint(user1, mintAmount);

        vm.prank(liquidityPool);
        lpToken.burn(user1, burnAmount);

        assertEq(lpToken.balanceOf(user1), mintAmount - burnAmount);
        assertEq(lpToken.totalSupply(), mintAmount - burnAmount);
    }

    function test_Burn_FullBalance() public {
        uint256 amount = 100 * 1e18;

        vm.prank(liquidityPool);
        lpToken.mint(user1, amount);

        vm.prank(liquidityPool);
        lpToken.burn(user1, amount);

        assertEq(lpToken.balanceOf(user1), 0);
        assertEq(lpToken.totalSupply(), 0);
    }

    function test_Burn_RevertUnauthorized() public {
        vm.prank(liquidityPool);
        lpToken.mint(user1, 100 * 1e18);

        vm.prank(randomUser);
        vm.expectRevert(ILPToken.Unauthorized.selector);
        lpToken.burn(user1, 50 * 1e18);
    }

    function test_Burn_RevertZeroAddress() public {
        vm.prank(liquidityPool);
        vm.expectRevert(ILPToken.ZeroAddress.selector);
        lpToken.burn(address(0), 100 * 1e18);
    }

    function test_Burn_RevertZeroAmount() public {
        vm.prank(liquidityPool);
        lpToken.mint(user1, 100 * 1e18);

        vm.prank(liquidityPool);
        vm.expectRevert(ILPToken.ZeroAmount.selector);
        lpToken.burn(user1, 0);
    }

    function test_Burn_RevertInsufficientBalance() public {
        vm.prank(liquidityPool);
        lpToken.mint(user1, 100 * 1e18);

        vm.prank(liquidityPool);
        vm.expectRevert();
        lpToken.burn(user1, 200 * 1e18);
    }

    // ============ ERC20 Compliance Tests ============

    function test_Transfer() public {
        uint256 amount = 100 * 1e18;

        vm.prank(liquidityPool);
        lpToken.mint(user1, amount);

        vm.prank(user1);
        lpToken.transfer(user2, 30 * 1e18);

        assertEq(lpToken.balanceOf(user1), 70 * 1e18);
        assertEq(lpToken.balanceOf(user2), 30 * 1e18);
    }

    function test_Approve_TransferFrom() public {
        uint256 amount = 100 * 1e18;

        vm.prank(liquidityPool);
        lpToken.mint(user1, amount);

        vm.prank(user1);
        lpToken.approve(user2, 50 * 1e18);

        vm.prank(user2);
        lpToken.transferFrom(user1, user2, 30 * 1e18);

        assertEq(lpToken.balanceOf(user1), 70 * 1e18);
        assertEq(lpToken.balanceOf(user2), 30 * 1e18);
        assertEq(lpToken.allowance(user1, user2), 20 * 1e18);
    }

    function test_TotalSupply() public {
        assertEq(lpToken.totalSupply(), 0);

        vm.prank(liquidityPool);
        lpToken.mint(user1, 100 * 1e18);
        assertEq(lpToken.totalSupply(), 100 * 1e18);

        vm.prank(liquidityPool);
        lpToken.mint(user2, 50 * 1e18);
        assertEq(lpToken.totalSupply(), 150 * 1e18);

        vm.prank(liquidityPool);
        lpToken.burn(user1, 30 * 1e18);
        assertEq(lpToken.totalSupply(), 120 * 1e18);
    }

    // ============ UUPS Upgrade Tests ============

    function test_Upgrade_OnlyOwner() public {
        LPToken newImplementation = new LPToken();

        // Should not revert when called by owner
        lpToken.upgradeToAndCall(address(newImplementation), "");
    }

    function test_Upgrade_RevertUnauthorized() public {
        LPToken newImplementation = new LPToken();

        vm.prank(randomUser);
        vm.expectRevert();
        lpToken.upgradeToAndCall(address(newImplementation), "");
    }

    function test_Upgrade_PreservesState() public {
        // Mint some tokens before upgrade
        vm.prank(liquidityPool);
        lpToken.mint(user1, 100 * 1e18);

        // Deploy new implementation and upgrade
        LPToken newImplementation = new LPToken();
        lpToken.upgradeToAndCall(address(newImplementation), "");

        // Verify state is preserved
        assertEq(lpToken.name(), TOKEN_NAME);
        assertEq(lpToken.symbol(), TOKEN_SYMBOL);
        assertEq(lpToken.balanceOf(user1), 100 * 1e18);
        assertEq(lpToken.liquidityPool(), liquidityPool);
    }

    // ============ Gas Tests ============

    function test_Mint_GasUsage() public {
        uint256 gasBefore = gasleft();
        vm.prank(liquidityPool);
        lpToken.mint(user1, 100 * 1e18);
        uint256 gasUsed = gasBefore - gasleft();

        assertLt(gasUsed, 100_000);
    }

    function test_Burn_GasUsage() public {
        vm.prank(liquidityPool);
        lpToken.mint(user1, 100 * 1e18);

        uint256 gasBefore = gasleft();
        vm.prank(liquidityPool);
        lpToken.burn(user1, 50 * 1e18);
        uint256 gasUsed = gasBefore - gasleft();

        assertLt(gasUsed, 50_000);
    }

    // ============ Integration Tests ============

    function test_Integration_FullLifecycle() public {
        // 1. Mint to user1
        vm.prank(liquidityPool);
        lpToken.mint(user1, 1000 * 1e18);
        assertEq(lpToken.balanceOf(user1), 1000 * 1e18);

        // 2. User1 transfers to user2
        vm.prank(user1);
        lpToken.transfer(user2, 200 * 1e18);
        assertEq(lpToken.balanceOf(user1), 800 * 1e18);
        assertEq(lpToken.balanceOf(user2), 200 * 1e18);

        // 3. User1 burns some
        vm.prank(liquidityPool);
        lpToken.burn(user1, 300 * 1e18);
        assertEq(lpToken.balanceOf(user1), 500 * 1e18);

        // 4. Total supply check
        assertEq(lpToken.totalSupply(), 700 * 1e18);
    }

    function test_Integration_MultipleUsers() public {
        address[] memory users = new address[](5);
        users[0] = makeAddr("user0");
        users[1] = makeAddr("user1");
        users[2] = makeAddr("user2");
        users[3] = makeAddr("user3");
        users[4] = makeAddr("user4");

        // Mint to all users
        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(liquidityPool);
            lpToken.mint(users[i], (i + 1) * 100 * 1e18);
        }

        // Verify balances
        assertEq(lpToken.balanceOf(users[0]), 100 * 1e18);
        assertEq(lpToken.balanceOf(users[4]), 500 * 1e18);

        // Total = 100 + 200 + 300 + 400 + 500 = 1500
        assertEq(lpToken.totalSupply(), 1500 * 1e18);
    }

    // ============ Fuzz Tests ============

    function testFuzz_Mint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0 && amount < type(uint128).max);

        vm.prank(liquidityPool);
        lpToken.mint(to, amount);

        assertEq(lpToken.balanceOf(to), amount);
    }

    function testFuzz_Transfer(uint256 mintAmount, uint256 transferAmount) public {
        vm.assume(mintAmount > 0 && mintAmount < type(uint128).max);
        vm.assume(transferAmount > 0 && transferAmount <= mintAmount);

        vm.prank(liquidityPool);
        lpToken.mint(user1, mintAmount);

        vm.prank(user1);
        lpToken.transfer(user2, transferAmount);

        assertEq(lpToken.balanceOf(user1), mintAmount - transferAmount);
        assertEq(lpToken.balanceOf(user2), transferAmount);
    }
}
