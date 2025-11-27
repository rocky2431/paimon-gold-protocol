// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OrderManager} from "../src/OrderManager.sol";
import {IOrderManager} from "../src/interfaces/IOrderManager.sol";
import {IPositionManager} from "../src/interfaces/IPositionManager.sol";

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

/// @notice Mock Oracle for testing
contract MockOracle {
    uint256 private _price = 2500e18; // $2500 gold price

    function setPrice(uint256 newPrice) external {
        _price = newPrice;
    }

    function getLatestPrice() external view returns (uint256) {
        return _price;
    }
}

/// @notice Mock PositionManager for testing
contract MockPositionManager {
    uint256 private _nextPositionId = 1;
    mapping(uint256 => IPositionManager.Position) private _positions;
    mapping(address => uint256[]) private _userPositions;

    function openPosition(
        address collateralToken,
        uint256 collateralAmount,
        uint256 leverage,
        bool isLong
    ) external returns (uint256 positionId) {
        positionId = _nextPositionId++;
        _positions[positionId] = IPositionManager.Position({
            id: positionId,
            owner: tx.origin, // Use tx.origin to track through router
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            size: collateralAmount * leverage,
            entryPrice: 2500e18,
            leverage: leverage,
            isLong: isLong,
            openedAt: block.timestamp,
            openBlock: block.number
        });
        _userPositions[tx.origin].push(positionId);
    }

    function closePosition(uint256 positionId, uint256) external returns (uint256 payout) {
        payout = _positions[positionId].collateralAmount;
        delete _positions[positionId];
    }

    function getPosition(uint256 positionId) external view returns (IPositionManager.Position memory) {
        return _positions[positionId];
    }

    function getPositionsByOwner(address owner) external view returns (uint256[] memory) {
        return _userPositions[owner];
    }

    // Helper to create a position directly for testing
    function createTestPosition(
        address owner,
        address collateralToken,
        uint256 collateralAmount,
        uint256 leverage,
        bool isLong
    ) external returns (uint256 positionId) {
        positionId = _nextPositionId++;
        _positions[positionId] = IPositionManager.Position({
            id: positionId,
            owner: owner,
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            size: collateralAmount * leverage,
            entryPrice: 2500e18,
            leverage: leverage,
            isLong: isLong,
            openedAt: block.timestamp,
            openBlock: block.number
        });
        _userPositions[owner].push(positionId);
    }
}

contract OrderManagerTest is Test {
    OrderManager public orderManager;
    MockOracle public oracle;
    MockPositionManager public positionManager;
    MockERC20 public usdc;

    address public owner = address(this);
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public keeper = makeAddr("keeper");

    uint256 public constant INITIAL_PRICE = 2500e18;

    function setUp() public {
        // Deploy mock contracts
        usdc = new MockERC20("USD Coin", "USDC", 6);
        oracle = new MockOracle();
        positionManager = new MockPositionManager();

        // Deploy OrderManager
        orderManager = new OrderManager(
            address(positionManager),
            address(oracle)
        );

        // Mint tokens to users
        usdc.mint(user1, 100_000e6);
        usdc.mint(user2, 100_000e6);

        // Approve OrderManager
        vm.prank(user1);
        usdc.approve(address(orderManager), type(uint256).max);
        vm.prank(user2);
        usdc.approve(address(orderManager), type(uint256).max);
    }

    // ============ Constructor Tests ============

    function test_Constructor_SetsPositionManager() public view {
        assertEq(orderManager.positionManager(), address(positionManager));
    }

    function test_Constructor_SetsOracle() public view {
        assertEq(orderManager.oracle(), address(oracle));
    }

    function test_Constructor_RevertIf_ZeroPositionManager() public {
        vm.expectRevert(IOrderManager.ZeroAddress.selector);
        new OrderManager(address(0), address(oracle));
    }

    function test_Constructor_RevertIf_ZeroOracle() public {
        vm.expectRevert(IOrderManager.ZeroAddress.selector);
        new OrderManager(address(positionManager), address(0));
    }

    // ============ Create Limit Order Tests ============

    function test_CreateLimitOrder_Success() public {
        vm.prank(user1, user1);
        uint256 orderId = orderManager.createLimitOrder(
            address(usdc),
            1000e6,
            5,
            true,
            2400e18, // Below current price for long
            0 // GTC
        );

        assertEq(orderId, 1);

        IOrderManager.Order memory order = orderManager.getOrder(orderId);
        assertEq(order.owner, user1);
        assertEq(uint256(order.orderType), uint256(IOrderManager.OrderType.LIMIT_OPEN));
        assertEq(order.collateralAmount, 1000e6);
        assertEq(order.leverage, 5);
        assertTrue(order.isLong);
        assertEq(order.triggerPrice, 2400e18);
        assertEq(uint256(order.status), uint256(IOrderManager.OrderStatus.PENDING));
    }

    function test_CreateLimitOrder_EmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit IOrderManager.OrderCreated(1, user1, IOrderManager.OrderType.LIMIT_OPEN, 2400e18, 0);

        vm.prank(user1, user1);
        orderManager.createLimitOrder(address(usdc), 1000e6, 5, true, 2400e18, 0);
    }

    function test_CreateLimitOrder_WithExpiry() public {
        uint256 expiry = block.timestamp + 1 days;

        vm.prank(user1, user1);
        uint256 orderId = orderManager.createLimitOrder(
            address(usdc),
            1000e6,
            5,
            true,
            2400e18,
            expiry
        );

        IOrderManager.Order memory order = orderManager.getOrder(orderId);
        assertEq(order.expiry, expiry);
    }

    function test_CreateLimitOrder_RevertIf_ZeroCollateral() public {
        vm.prank(user1, user1);
        vm.expectRevert(IOrderManager.ZeroAmount.selector);
        orderManager.createLimitOrder(address(usdc), 0, 5, true, 2400e18, 0);
    }

    function test_CreateLimitOrder_RevertIf_ZeroTriggerPrice() public {
        vm.prank(user1, user1);
        vm.expectRevert(IOrderManager.InvalidTriggerPrice.selector);
        orderManager.createLimitOrder(address(usdc), 1000e6, 5, true, 0, 0);
    }

    function test_CreateLimitOrder_RevertIf_InvalidLeverage() public {
        vm.prank(user1, user1);
        vm.expectRevert(IOrderManager.InvalidLeverage.selector);
        orderManager.createLimitOrder(address(usdc), 1000e6, 1, true, 2400e18, 0); // <2x

        vm.prank(user1, user1);
        vm.expectRevert(IOrderManager.InvalidLeverage.selector);
        orderManager.createLimitOrder(address(usdc), 1000e6, 21, true, 2400e18, 0); // >20x
    }

    // ============ Set Take Profit Tests ============

    function test_SetTakeProfit_Success() public {
        // Create a position first
        uint256 positionId = positionManager.createTestPosition(
            user1,
            address(usdc),
            1000e6,
            5,
            true // Long position
        );

        vm.prank(user1, user1);
        uint256 orderId = orderManager.setTakeProfit(positionId, 2600e18); // Above entry for long

        assertEq(orderId, 1);

        IOrderManager.Order memory order = orderManager.getOrder(orderId);
        assertEq(order.owner, user1);
        assertEq(uint256(order.orderType), uint256(IOrderManager.OrderType.TAKE_PROFIT));
        assertEq(order.positionId, positionId);
        assertEq(order.triggerPrice, 2600e18);
    }

    function test_SetTakeProfit_EmitsEvent() public {
        uint256 positionId = positionManager.createTestPosition(
            user1, address(usdc), 1000e6, 5, true
        );

        vm.expectEmit(true, true, false, true);
        emit IOrderManager.OrderCreated(1, user1, IOrderManager.OrderType.TAKE_PROFIT, 2600e18, 0);

        vm.prank(user1, user1);
        orderManager.setTakeProfit(positionId, 2600e18);
    }

    function test_SetTakeProfit_RevertIf_NotPositionOwner() public {
        uint256 positionId = positionManager.createTestPosition(
            user1, address(usdc), 1000e6, 5, true
        );

        vm.prank(user2, user2);
        vm.expectRevert(IOrderManager.NotPositionOwner.selector);
        orderManager.setTakeProfit(positionId, 2600e18);
    }

    function test_SetTakeProfit_RevertIf_PositionNotFound() public {
        vm.prank(user1, user1);
        vm.expectRevert(IOrderManager.PositionNotFound.selector);
        orderManager.setTakeProfit(999, 2600e18);
    }

    // ============ Set Stop Loss Tests ============

    function test_SetStopLoss_Success() public {
        uint256 positionId = positionManager.createTestPosition(
            user1, address(usdc), 1000e6, 5, true // Long position
        );

        vm.prank(user1, user1);
        uint256 orderId = orderManager.setStopLoss(positionId, 2400e18); // Below entry for long

        assertEq(orderId, 1);

        IOrderManager.Order memory order = orderManager.getOrder(orderId);
        assertEq(uint256(order.orderType), uint256(IOrderManager.OrderType.STOP_LOSS));
        assertEq(order.triggerPrice, 2400e18);
    }

    function test_SetStopLoss_EmitsEvent() public {
        uint256 positionId = positionManager.createTestPosition(
            user1, address(usdc), 1000e6, 5, true
        );

        vm.expectEmit(true, true, false, true);
        emit IOrderManager.OrderCreated(1, user1, IOrderManager.OrderType.STOP_LOSS, 2400e18, 0);

        vm.prank(user1, user1);
        orderManager.setStopLoss(positionId, 2400e18);
    }

    function test_SetStopLoss_RevertIf_NotPositionOwner() public {
        uint256 positionId = positionManager.createTestPosition(
            user1, address(usdc), 1000e6, 5, true
        );

        vm.prank(user2, user2);
        vm.expectRevert(IOrderManager.NotPositionOwner.selector);
        orderManager.setStopLoss(positionId, 2400e18);
    }

    // ============ Cancel Order Tests ============

    function test_CancelOrder_Success() public {
        vm.prank(user1, user1);
        uint256 orderId = orderManager.createLimitOrder(
            address(usdc), 1000e6, 5, true, 2400e18, 0
        );

        vm.expectEmit(true, false, false, false);
        emit IOrderManager.OrderCancelled(orderId);

        vm.prank(user1, user1);
        orderManager.cancelOrder(orderId);

        IOrderManager.Order memory order = orderManager.getOrder(orderId);
        assertEq(uint256(order.status), uint256(IOrderManager.OrderStatus.CANCELLED));
    }

    function test_CancelOrder_RevertIf_NotOwner() public {
        vm.prank(user1, user1);
        uint256 orderId = orderManager.createLimitOrder(
            address(usdc), 1000e6, 5, true, 2400e18, 0
        );

        vm.prank(user2, user2);
        vm.expectRevert(IOrderManager.NotOrderOwner.selector);
        orderManager.cancelOrder(orderId);
    }

    function test_CancelOrder_RevertIf_NotPending() public {
        vm.prank(user1, user1);
        uint256 orderId = orderManager.createLimitOrder(
            address(usdc), 1000e6, 5, true, 2400e18, 0
        );

        // Cancel once
        vm.prank(user1, user1);
        orderManager.cancelOrder(orderId);

        // Try to cancel again
        vm.prank(user1, user1);
        vm.expectRevert(IOrderManager.OrderNotPending.selector);
        orderManager.cancelOrder(orderId);
    }

    function test_CancelOrder_RevertIf_OrderNotFound() public {
        vm.prank(user1, user1);
        vm.expectRevert(IOrderManager.OrderNotFound.selector);
        orderManager.cancelOrder(999);
    }

    // ============ Execute Order Tests ============

    function test_ExecuteOrder_LimitOpenLong_Success() public {
        // Create limit order for long at 2400
        vm.prank(user1, user1);
        uint256 orderId = orderManager.createLimitOrder(
            address(usdc), 1000e6, 5, true, 2400e18, 0
        );

        // Price drops to trigger level
        oracle.setPrice(2400e18);

        // Execute order
        vm.prank(keeper);
        orderManager.executeOrder(orderId);

        IOrderManager.Order memory order = orderManager.getOrder(orderId);
        assertEq(uint256(order.status), uint256(IOrderManager.OrderStatus.EXECUTED));
    }

    function test_ExecuteOrder_LimitOpenShort_Success() public {
        // Create limit order for short at 2600
        vm.prank(user1, user1);
        uint256 orderId = orderManager.createLimitOrder(
            address(usdc), 1000e6, 5, false, 2600e18, 0
        );

        // Price rises to trigger level
        oracle.setPrice(2600e18);

        // Execute order
        vm.prank(keeper);
        orderManager.executeOrder(orderId);

        IOrderManager.Order memory order = orderManager.getOrder(orderId);
        assertEq(uint256(order.status), uint256(IOrderManager.OrderStatus.EXECUTED));
    }

    function test_ExecuteOrder_TakeProfit_Long() public {
        // Create long position
        uint256 positionId = positionManager.createTestPosition(
            user1, address(usdc), 1000e6, 5, true
        );

        // Set take profit
        vm.prank(user1, user1);
        uint256 orderId = orderManager.setTakeProfit(positionId, 2600e18);

        // Price rises to TP level
        oracle.setPrice(2600e18);

        // Execute order
        vm.prank(keeper);
        orderManager.executeOrder(orderId);

        IOrderManager.Order memory order = orderManager.getOrder(orderId);
        assertEq(uint256(order.status), uint256(IOrderManager.OrderStatus.EXECUTED));
    }

    function test_ExecuteOrder_StopLoss_Long() public {
        // Create long position
        uint256 positionId = positionManager.createTestPosition(
            user1, address(usdc), 1000e6, 5, true
        );

        // Set stop loss
        vm.prank(user1, user1);
        uint256 orderId = orderManager.setStopLoss(positionId, 2400e18);

        // Price drops to SL level
        oracle.setPrice(2400e18);

        // Execute order
        vm.prank(keeper);
        orderManager.executeOrder(orderId);

        IOrderManager.Order memory order = orderManager.getOrder(orderId);
        assertEq(uint256(order.status), uint256(IOrderManager.OrderStatus.EXECUTED));
    }

    function test_ExecuteOrder_TakeProfit_Short() public {
        // Create short position
        uint256 positionId = positionManager.createTestPosition(
            user1, address(usdc), 1000e6, 5, false
        );

        // Set take profit (below entry for short)
        vm.prank(user1, user1);
        uint256 orderId = orderManager.setTakeProfit(positionId, 2400e18);

        // Price drops to TP level
        oracle.setPrice(2400e18);

        // Execute order
        vm.prank(keeper);
        orderManager.executeOrder(orderId);

        IOrderManager.Order memory order = orderManager.getOrder(orderId);
        assertEq(uint256(order.status), uint256(IOrderManager.OrderStatus.EXECUTED));
    }

    function test_ExecuteOrder_StopLoss_Short() public {
        // Create short position
        uint256 positionId = positionManager.createTestPosition(
            user1, address(usdc), 1000e6, 5, false
        );

        // Set stop loss (above entry for short)
        vm.prank(user1, user1);
        uint256 orderId = orderManager.setStopLoss(positionId, 2600e18);

        // Price rises to SL level
        oracle.setPrice(2600e18);

        // Execute order
        vm.prank(keeper);
        orderManager.executeOrder(orderId);

        IOrderManager.Order memory order = orderManager.getOrder(orderId);
        assertEq(uint256(order.status), uint256(IOrderManager.OrderStatus.EXECUTED));
    }

    function test_ExecuteOrder_EmitsEvent() public {
        vm.prank(user1, user1);
        uint256 orderId = orderManager.createLimitOrder(
            address(usdc), 1000e6, 5, true, 2400e18, 0
        );

        oracle.setPrice(2400e18);

        vm.expectEmit(true, false, false, true);
        emit IOrderManager.OrderExecuted(orderId, 2400e18, 1); // positionId = 1

        vm.prank(keeper);
        orderManager.executeOrder(orderId);
    }

    function test_ExecuteOrder_RevertIf_TriggerNotMet() public {
        vm.prank(user1, user1);
        uint256 orderId = orderManager.createLimitOrder(
            address(usdc), 1000e6, 5, true, 2400e18, 0
        );

        // Price is still at 2500, above trigger
        vm.prank(keeper);
        vm.expectRevert(IOrderManager.TriggerNotMet.selector);
        orderManager.executeOrder(orderId);
    }

    function test_ExecuteOrder_RevertIf_OrderExpired() public {
        uint256 expiry = block.timestamp + 1 hours;

        vm.prank(user1, user1);
        uint256 orderId = orderManager.createLimitOrder(
            address(usdc), 1000e6, 5, true, 2400e18, expiry
        );

        // Warp past expiry
        vm.warp(expiry + 1);
        oracle.setPrice(2400e18);

        vm.prank(keeper);
        vm.expectRevert(IOrderManager.OrderExpiredError.selector);
        orderManager.executeOrder(orderId);
    }

    function test_ExecuteOrder_RevertIf_NotPending() public {
        vm.prank(user1, user1);
        uint256 orderId = orderManager.createLimitOrder(
            address(usdc), 1000e6, 5, true, 2400e18, 0
        );

        // Cancel order
        vm.prank(user1, user1);
        orderManager.cancelOrder(orderId);

        oracle.setPrice(2400e18);

        vm.prank(keeper);
        vm.expectRevert(IOrderManager.OrderNotPending.selector);
        orderManager.executeOrder(orderId);
    }

    // ============ Chainlink Automation Tests ============

    function test_CheckUpkeep_ReturnsTrueWhenTriggered() public {
        vm.prank(user1, user1);
        orderManager.createLimitOrder(
            address(usdc), 1000e6, 5, true, 2400e18, 0
        );

        oracle.setPrice(2400e18);

        (bool upkeepNeeded, bytes memory performData) = orderManager.checkUpkeep("");
        assertTrue(upkeepNeeded);
        assertGt(performData.length, 0);
    }

    function test_CheckUpkeep_ReturnsFalseWhenNotTriggered() public {
        vm.prank(user1, user1);
        orderManager.createLimitOrder(
            address(usdc), 1000e6, 5, true, 2400e18, 0
        );

        // Price still at 2500
        (bool upkeepNeeded,) = orderManager.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    function test_PerformUpkeep_ExecutesOrders() public {
        vm.prank(user1, user1);
        uint256 orderId = orderManager.createLimitOrder(
            address(usdc), 1000e6, 5, true, 2400e18, 0
        );

        oracle.setPrice(2400e18);

        (, bytes memory performData) = orderManager.checkUpkeep("");

        orderManager.performUpkeep(performData);

        IOrderManager.Order memory order = orderManager.getOrder(orderId);
        assertEq(uint256(order.status), uint256(IOrderManager.OrderStatus.EXECUTED));
    }

    // ============ View Function Tests ============

    function test_GetOrder_ReturnsCorrectData() public {
        vm.prank(user1, user1);
        uint256 orderId = orderManager.createLimitOrder(
            address(usdc), 1000e6, 5, true, 2400e18, 0
        );

        IOrderManager.Order memory order = orderManager.getOrder(orderId);
        assertEq(order.id, orderId);
        assertEq(order.owner, user1);
        assertEq(order.collateralAmount, 1000e6);
    }

    function test_GetUserOrders_ReturnsAllOrders() public {
        vm.startPrank(user1, user1);
        orderManager.createLimitOrder(address(usdc), 1000e6, 5, true, 2400e18, 0);
        orderManager.createLimitOrder(address(usdc), 2000e6, 10, false, 2600e18, 0);
        vm.stopPrank();

        uint256[] memory orders = orderManager.getUserOrders(user1);
        assertEq(orders.length, 2);
    }

    function test_GetPositionOrders_ReturnsTPSL() public {
        uint256 positionId = positionManager.createTestPosition(
            user1, address(usdc), 1000e6, 5, true
        );

        vm.startPrank(user1, user1);
        uint256 tpOrderId = orderManager.setTakeProfit(positionId, 2600e18);
        uint256 slOrderId = orderManager.setStopLoss(positionId, 2400e18);
        vm.stopPrank();

        (uint256 tp, uint256 sl) = orderManager.getPositionOrders(positionId);
        assertEq(tp, tpOrderId);
        assertEq(sl, slOrderId);
    }

    function test_IsTriggered_LimitOpenLong() public {
        vm.prank(user1, user1);
        uint256 orderId = orderManager.createLimitOrder(
            address(usdc), 1000e6, 5, true, 2400e18, 0
        );

        // Price above trigger - not triggered
        assertFalse(orderManager.isTriggered(orderId));

        // Price at trigger - triggered
        oracle.setPrice(2400e18);
        assertTrue(orderManager.isTriggered(orderId));

        // Price below trigger - triggered
        oracle.setPrice(2300e18);
        assertTrue(orderManager.isTriggered(orderId));
    }

    function test_IsTriggered_LimitOpenShort() public {
        vm.prank(user1, user1);
        uint256 orderId = orderManager.createLimitOrder(
            address(usdc), 1000e6, 5, false, 2600e18, 0
        );

        // Price below trigger - not triggered
        assertFalse(orderManager.isTriggered(orderId));

        // Price at trigger - triggered
        oracle.setPrice(2600e18);
        assertTrue(orderManager.isTriggered(orderId));

        // Price above trigger - triggered
        oracle.setPrice(2700e18);
        assertTrue(orderManager.isTriggered(orderId));
    }

    // ============ Admin Function Tests ============

    function test_SetPositionManager_Success() public {
        address newManager = makeAddr("newManager");

        vm.expectEmit(true, true, false, false);
        emit IOrderManager.PositionManagerSet(address(positionManager), newManager);

        orderManager.setPositionManager(newManager);
        assertEq(orderManager.positionManager(), newManager);
    }

    function test_SetPositionManager_RevertIf_NotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        orderManager.setPositionManager(makeAddr("newManager"));
    }

    function test_SetOracle_Success() public {
        address newOracle = makeAddr("newOracle");

        vm.expectEmit(true, true, false, false);
        emit IOrderManager.OracleSet(address(oracle), newOracle);

        orderManager.setOracle(newOracle);
        assertEq(orderManager.oracle(), newOracle);
    }

    function test_SetOracle_RevertIf_NotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        orderManager.setOracle(makeAddr("newOracle"));
    }

    // ============ Integration Tests ============

    function test_Integration_FullLimitOrderFlow() public {
        // Create limit order
        vm.prank(user1, user1);
        uint256 orderId = orderManager.createLimitOrder(
            address(usdc), 1000e6, 5, true, 2400e18, 0
        );

        // Verify order created
        IOrderManager.Order memory order = orderManager.getOrder(orderId);
        assertEq(uint256(order.status), uint256(IOrderManager.OrderStatus.PENDING));

        // Price drops to trigger
        oracle.setPrice(2400e18);

        // Check upkeep
        (bool upkeepNeeded, bytes memory performData) = orderManager.checkUpkeep("");
        assertTrue(upkeepNeeded);

        // Execute via performUpkeep
        orderManager.performUpkeep(performData);

        // Verify executed
        order = orderManager.getOrder(orderId);
        assertEq(uint256(order.status), uint256(IOrderManager.OrderStatus.EXECUTED));
    }

    function test_Integration_FullTPSLFlow() public {
        // Create position
        uint256 positionId = positionManager.createTestPosition(
            user1, address(usdc), 1000e6, 5, true
        );

        // Set TP and SL
        vm.startPrank(user1, user1);
        uint256 tpOrderId = orderManager.setTakeProfit(positionId, 2600e18);
        uint256 slOrderId = orderManager.setStopLoss(positionId, 2400e18);
        vm.stopPrank();

        // Verify orders created
        (uint256 tp, uint256 sl) = orderManager.getPositionOrders(positionId);
        assertEq(tp, tpOrderId);
        assertEq(sl, slOrderId);

        // Price rises to TP
        oracle.setPrice(2600e18);

        // Execute TP
        vm.prank(keeper);
        orderManager.executeOrder(tpOrderId);

        // Verify TP executed
        IOrderManager.Order memory order = orderManager.getOrder(tpOrderId);
        assertEq(uint256(order.status), uint256(IOrderManager.OrderStatus.EXECUTED));
    }

    // ============ Gas Tests ============

    function test_Gas_CreateLimitOrder() public {
        vm.prank(user1, user1);
        uint256 gasBefore = gasleft();
        orderManager.createLimitOrder(address(usdc), 1000e6, 5, true, 2400e18, 0);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Gas used for createLimitOrder:", gasUsed);
        assertLt(gasUsed, 350_000);
    }

    function test_Gas_ExecuteOrder() public {
        vm.prank(user1, user1);
        uint256 orderId = orderManager.createLimitOrder(
            address(usdc), 1000e6, 5, true, 2400e18, 0
        );

        oracle.setPrice(2400e18);

        vm.prank(keeper);
        uint256 gasBefore = gasleft();
        orderManager.executeOrder(orderId);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Gas used for executeOrder:", gasUsed);
        assertLt(gasUsed, 350_000);
    }

    // ============ Fuzz Tests ============

    function testFuzz_CreateLimitOrder_AnyValidParams(
        uint256 collateral,
        uint256 leverage,
        uint256 triggerPrice
    ) public {
        collateral = bound(collateral, 10e6, 50_000e6);
        leverage = bound(leverage, 2, 20);
        triggerPrice = bound(triggerPrice, 1000e18, 5000e18);

        usdc.mint(user1, collateral);

        vm.prank(user1, user1);
        uint256 orderId = orderManager.createLimitOrder(
            address(usdc),
            collateral,
            leverage,
            true,
            triggerPrice,
            0
        );

        IOrderManager.Order memory order = orderManager.getOrder(orderId);
        assertEq(order.collateralAmount, collateral);
        assertEq(order.leverage, leverage);
        assertEq(order.triggerPrice, triggerPrice);
    }
}
