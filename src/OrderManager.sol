// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IOrderManager} from "./interfaces/IOrderManager.sol";
import {IPositionManager} from "./interfaces/IPositionManager.sol";

/// @notice Interface for Oracle
interface IOracle {
    function getLatestPrice() external view returns (uint256);
}

/// @title OrderManager
/// @notice Manages limit orders and TP/SL orders for the protocol
/// @dev Chainlink Automation compatible for automated execution
contract OrderManager is IOrderManager, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Constants ============

    /// @notice Minimum leverage
    uint256 public constant MIN_LEVERAGE = 2;

    /// @notice Maximum leverage
    uint256 public constant MAX_LEVERAGE = 20;

    /// @notice Maximum orders to check per upkeep
    uint256 public constant MAX_ORDERS_PER_UPKEEP = 10;

    // ============ State Variables ============

    /// @notice PositionManager contract
    address public positionManager;

    /// @notice Oracle contract
    address public oracle;

    /// @notice Next order ID
    uint256 private _nextOrderId = 1;

    /// @notice Mapping of order ID to Order
    mapping(uint256 => Order) private _orders;

    /// @notice Mapping of user to their order IDs
    mapping(address => uint256[]) private _userOrders;

    /// @notice Mapping of position ID to TP order ID
    mapping(uint256 => uint256) private _positionToTP;

    /// @notice Mapping of position ID to SL order ID
    mapping(uint256 => uint256) private _positionToSL;

    /// @notice Array of pending order IDs (for upkeep iteration)
    uint256[] private _pendingOrders;

    /// @notice Index of order in pending array
    mapping(uint256 => uint256) private _pendingOrderIndex;

    // ============ Constructor ============

    /// @notice Initialize the OrderManager
    /// @param positionManager_ PositionManager contract address
    /// @param oracle_ Oracle contract address
    constructor(
        address positionManager_,
        address oracle_
    ) Ownable(msg.sender) {
        if (positionManager_ == address(0)) revert ZeroAddress();
        if (oracle_ == address(0)) revert ZeroAddress();

        positionManager = positionManager_;
        oracle = oracle_;
    }

    // ============ Limit Order Functions ============

    /// @inheritdoc IOrderManager
    function createLimitOrder(
        address collateralToken,
        uint256 collateralAmount,
        uint256 leverage,
        bool isLong,
        uint256 triggerPrice,
        uint256 expiry
    ) external nonReentrant returns (uint256 orderId) {
        if (collateralAmount == 0) revert ZeroAmount();
        if (triggerPrice == 0) revert InvalidTriggerPrice();
        if (leverage < MIN_LEVERAGE || leverage > MAX_LEVERAGE) revert InvalidLeverage();

        // Transfer collateral from user
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);

        // Create order
        orderId = _nextOrderId++;
        _orders[orderId] = Order({
            id: orderId,
            owner: msg.sender,
            orderType: OrderType.LIMIT_OPEN,
            positionId: 0,
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            leverage: leverage,
            isLong: isLong,
            triggerPrice: triggerPrice,
            expiry: expiry,
            status: OrderStatus.PENDING,
            createdAt: block.timestamp
        });

        _userOrders[msg.sender].push(orderId);
        _addToPending(orderId);

        emit OrderCreated(orderId, msg.sender, OrderType.LIMIT_OPEN, triggerPrice, expiry);
    }

    // ============ TP/SL Functions ============

    /// @inheritdoc IOrderManager
    function setTakeProfit(
        uint256 positionId,
        uint256 triggerPrice
    ) external nonReentrant returns (uint256 orderId) {
        if (triggerPrice == 0) revert InvalidTriggerPrice();

        // Verify position exists and caller is owner
        IPositionManager.Position memory pos = IPositionManager(positionManager).getPosition(positionId);
        if (pos.id == 0) revert PositionNotFound();
        if (pos.owner != msg.sender) revert NotPositionOwner();

        // Cancel existing TP order if any
        uint256 existingTP = _positionToTP[positionId];
        if (existingTP != 0 && _orders[existingTP].status == OrderStatus.PENDING) {
            _cancelOrderInternal(existingTP);
        }

        // Create TP order
        orderId = _nextOrderId++;
        _orders[orderId] = Order({
            id: orderId,
            owner: msg.sender,
            orderType: OrderType.TAKE_PROFIT,
            positionId: positionId,
            collateralToken: pos.collateralToken,
            collateralAmount: 0,
            leverage: 0,
            isLong: pos.isLong,
            triggerPrice: triggerPrice,
            expiry: 0, // GTC for TP/SL
            status: OrderStatus.PENDING,
            createdAt: block.timestamp
        });

        _positionToTP[positionId] = orderId;
        _userOrders[msg.sender].push(orderId);
        _addToPending(orderId);

        emit OrderCreated(orderId, msg.sender, OrderType.TAKE_PROFIT, triggerPrice, 0);
    }

    /// @inheritdoc IOrderManager
    function setStopLoss(
        uint256 positionId,
        uint256 triggerPrice
    ) external nonReentrant returns (uint256 orderId) {
        if (triggerPrice == 0) revert InvalidTriggerPrice();

        // Verify position exists and caller is owner
        IPositionManager.Position memory pos = IPositionManager(positionManager).getPosition(positionId);
        if (pos.id == 0) revert PositionNotFound();
        if (pos.owner != msg.sender) revert NotPositionOwner();

        // Cancel existing SL order if any
        uint256 existingSL = _positionToSL[positionId];
        if (existingSL != 0 && _orders[existingSL].status == OrderStatus.PENDING) {
            _cancelOrderInternal(existingSL);
        }

        // Create SL order
        orderId = _nextOrderId++;
        _orders[orderId] = Order({
            id: orderId,
            owner: msg.sender,
            orderType: OrderType.STOP_LOSS,
            positionId: positionId,
            collateralToken: pos.collateralToken,
            collateralAmount: 0,
            leverage: 0,
            isLong: pos.isLong,
            triggerPrice: triggerPrice,
            expiry: 0, // GTC for TP/SL
            status: OrderStatus.PENDING,
            createdAt: block.timestamp
        });

        _positionToSL[positionId] = orderId;
        _userOrders[msg.sender].push(orderId);
        _addToPending(orderId);

        emit OrderCreated(orderId, msg.sender, OrderType.STOP_LOSS, triggerPrice, 0);
    }

    // ============ Order Management ============

    /// @inheritdoc IOrderManager
    function cancelOrder(uint256 orderId) external nonReentrant {
        Order storage order = _orders[orderId];
        if (order.id == 0) revert OrderNotFound();
        if (order.owner != msg.sender) revert NotOrderOwner();
        if (order.status != OrderStatus.PENDING) revert OrderNotPending();

        _cancelOrderInternal(orderId);
    }

    /// @inheritdoc IOrderManager
    function executeOrder(uint256 orderId) external nonReentrant {
        Order storage order = _orders[orderId];
        if (order.id == 0) revert OrderNotFound();
        if (order.status != OrderStatus.PENDING) revert OrderNotPending();

        // Check expiry
        if (order.expiry != 0 && block.timestamp > order.expiry) {
            order.status = OrderStatus.EXPIRED;
            _removeFromPending(orderId);
            emit OrderExpired(orderId);
            revert OrderExpiredError();
        }

        // Check trigger condition
        if (!_isTriggered(order)) revert TriggerNotMet();

        uint256 currentPrice = IOracle(oracle).getLatestPrice();
        uint256 resultId;

        if (order.orderType == OrderType.LIMIT_OPEN) {
            // Approve PositionManager to spend collateral
            IERC20(order.collateralToken).approve(positionManager, order.collateralAmount);

            // Open position
            resultId = IPositionManager(positionManager).openPosition(
                order.collateralToken,
                order.collateralAmount,
                order.leverage,
                order.isLong
            );
        } else {
            // Close position for TP/SL
            resultId = IPositionManager(positionManager).closePosition(
                order.positionId,
                type(uint256).max // Close full position
            );

            // Clear position order mappings
            if (order.orderType == OrderType.TAKE_PROFIT) {
                delete _positionToTP[order.positionId];
                // Also cancel SL if exists
                uint256 slOrderId = _positionToSL[order.positionId];
                if (slOrderId != 0 && _orders[slOrderId].status == OrderStatus.PENDING) {
                    _cancelOrderInternal(slOrderId);
                }
            } else {
                delete _positionToSL[order.positionId];
                // Also cancel TP if exists
                uint256 tpOrderId = _positionToTP[order.positionId];
                if (tpOrderId != 0 && _orders[tpOrderId].status == OrderStatus.PENDING) {
                    _cancelOrderInternal(tpOrderId);
                }
            }
        }

        order.status = OrderStatus.EXECUTED;
        _removeFromPending(orderId);

        emit OrderExecuted(orderId, currentPrice, resultId);
    }

    // ============ Chainlink Automation ============

    /// @inheritdoc IOrderManager
    function checkUpkeep(
        bytes calldata
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        uint256[] memory triggeredOrders = new uint256[](MAX_ORDERS_PER_UPKEEP);
        uint256 count = 0;

        for (uint256 i = 0; i < _pendingOrders.length && count < MAX_ORDERS_PER_UPKEEP; i++) {
            uint256 orderId = _pendingOrders[i];
            Order storage order = _orders[orderId];

            if (order.status != OrderStatus.PENDING) continue;

            // Skip expired orders
            if (order.expiry != 0 && block.timestamp > order.expiry) continue;

            if (_isTriggered(order)) {
                triggeredOrders[count] = orderId;
                count++;
            }
        }

        if (count > 0) {
            // Resize array to actual count
            uint256[] memory result = new uint256[](count);
            for (uint256 i = 0; i < count; i++) {
                result[i] = triggeredOrders[i];
            }
            return (true, abi.encode(result));
        }

        return (false, "");
    }

    /// @inheritdoc IOrderManager
    function performUpkeep(bytes calldata performData) external {
        uint256[] memory orderIds = abi.decode(performData, (uint256[]));

        for (uint256 i = 0; i < orderIds.length; i++) {
            uint256 orderId = orderIds[i];
            Order storage order = _orders[orderId];

            if (order.status != OrderStatus.PENDING) continue;

            // Check expiry
            if (order.expiry != 0 && block.timestamp > order.expiry) {
                order.status = OrderStatus.EXPIRED;
                _removeFromPending(orderId);
                emit OrderExpired(orderId);
                continue;
            }

            if (!_isTriggered(order)) continue;

            // Execute the order
            try this.executeOrder(orderId) {} catch {}
        }
    }

    // ============ View Functions ============

    /// @inheritdoc IOrderManager
    function getOrder(uint256 orderId) external view returns (Order memory order) {
        return _orders[orderId];
    }

    /// @inheritdoc IOrderManager
    function getUserOrders(address user) external view returns (uint256[] memory orderIds) {
        return _userOrders[user];
    }

    /// @inheritdoc IOrderManager
    function getPositionOrders(
        uint256 positionId
    ) external view returns (uint256 tpOrderId, uint256 slOrderId) {
        tpOrderId = _positionToTP[positionId];
        slOrderId = _positionToSL[positionId];
    }

    /// @inheritdoc IOrderManager
    function isTriggered(uint256 orderId) external view returns (bool triggered) {
        Order storage order = _orders[orderId];
        if (order.id == 0) return false;
        return _isTriggered(order);
    }

    // ============ Admin Functions ============

    /// @inheritdoc IOrderManager
    function setPositionManager(address manager) external onlyOwner {
        if (manager == address(0)) revert ZeroAddress();

        address oldManager = positionManager;
        positionManager = manager;

        emit PositionManagerSet(oldManager, manager);
    }

    /// @inheritdoc IOrderManager
    function setOracle(address oracle_) external onlyOwner {
        if (oracle_ == address(0)) revert ZeroAddress();

        address oldOracle = oracle;
        oracle = oracle_;

        emit OracleSet(oldOracle, oracle_);
    }

    // ============ Internal Functions ============

    /// @notice Check if order trigger condition is met
    /// @param order The order to check
    /// @return triggered Whether trigger condition is met
    function _isTriggered(Order storage order) internal view returns (bool triggered) {
        uint256 currentPrice = IOracle(oracle).getLatestPrice();

        if (order.orderType == OrderType.LIMIT_OPEN) {
            // Long: trigger when price <= triggerPrice (buy low)
            // Short: trigger when price >= triggerPrice (sell high)
            if (order.isLong) {
                return currentPrice <= order.triggerPrice;
            } else {
                return currentPrice >= order.triggerPrice;
            }
        } else if (order.orderType == OrderType.TAKE_PROFIT) {
            // Long TP: trigger when price >= triggerPrice (take profit high)
            // Short TP: trigger when price <= triggerPrice (take profit low)
            if (order.isLong) {
                return currentPrice >= order.triggerPrice;
            } else {
                return currentPrice <= order.triggerPrice;
            }
        } else {
            // Stop Loss
            // Long SL: trigger when price <= triggerPrice (stop loss low)
            // Short SL: trigger when price >= triggerPrice (stop loss high)
            if (order.isLong) {
                return currentPrice <= order.triggerPrice;
            } else {
                return currentPrice >= order.triggerPrice;
            }
        }
    }

    /// @notice Cancel an order internally
    /// @param orderId The order to cancel
    function _cancelOrderInternal(uint256 orderId) internal {
        Order storage order = _orders[orderId];

        // Refund collateral for limit orders
        if (order.orderType == OrderType.LIMIT_OPEN && order.collateralAmount > 0) {
            IERC20(order.collateralToken).safeTransfer(order.owner, order.collateralAmount);
        }

        order.status = OrderStatus.CANCELLED;
        _removeFromPending(orderId);

        emit OrderCancelled(orderId);
    }

    /// @notice Add order to pending list
    /// @param orderId The order to add
    function _addToPending(uint256 orderId) internal {
        _pendingOrderIndex[orderId] = _pendingOrders.length;
        _pendingOrders.push(orderId);
    }

    /// @notice Remove order from pending list
    /// @param orderId The order to remove
    function _removeFromPending(uint256 orderId) internal {
        uint256 index = _pendingOrderIndex[orderId];
        uint256 lastIndex = _pendingOrders.length - 1;

        if (index != lastIndex) {
            uint256 lastOrderId = _pendingOrders[lastIndex];
            _pendingOrders[index] = lastOrderId;
            _pendingOrderIndex[lastOrderId] = index;
        }

        _pendingOrders.pop();
        delete _pendingOrderIndex[orderId];
    }
}
