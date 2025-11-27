// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IOrderManager
/// @notice Interface for the OrderManager contract - handles limit orders and TP/SL
interface IOrderManager {
    // ============ Enums ============

    /// @notice Order type
    enum OrderType {
        LIMIT_OPEN,    // Open position when price reaches trigger
        TAKE_PROFIT,   // Close position when price reaches target (profit)
        STOP_LOSS      // Close position when price reaches target (loss)
    }

    /// @notice Order status
    enum OrderStatus {
        PENDING,       // Waiting for execution
        EXECUTED,      // Successfully executed
        CANCELLED,     // Cancelled by user
        EXPIRED        // Expired without execution
    }

    // ============ Structs ============

    /// @notice Order data structure
    struct Order {
        uint256 id;              // Unique order ID
        address owner;           // Order creator
        OrderType orderType;     // Type of order
        uint256 positionId;      // Associated position (for TP/SL, 0 for limit open)
        address collateralToken; // Collateral token (for limit open)
        uint256 collateralAmount;// Collateral amount (for limit open)
        uint256 leverage;        // Leverage (for limit open)
        bool isLong;             // Direction
        uint256 triggerPrice;    // Price at which to execute (18 decimals)
        uint256 expiry;          // 0 = GTC, >0 = GTD timestamp
        OrderStatus status;      // Current status
        uint256 createdAt;       // Creation timestamp
    }

    // ============ Events ============

    /// @notice Emitted when a new order is created
    event OrderCreated(
        uint256 indexed orderId,
        address indexed owner,
        OrderType orderType,
        uint256 triggerPrice,
        uint256 expiry
    );

    /// @notice Emitted when an order is executed
    event OrderExecuted(
        uint256 indexed orderId,
        uint256 executionPrice,
        uint256 resultId // positionId for limit open, payout for TP/SL
    );

    /// @notice Emitted when an order is cancelled
    event OrderCancelled(uint256 indexed orderId);

    /// @notice Emitted when an order expires
    event OrderExpired(uint256 indexed orderId);

    /// @notice Emitted when PositionManager is set
    event PositionManagerSet(address indexed oldManager, address indexed newManager);

    /// @notice Emitted when Oracle is set
    event OracleSet(address indexed oldOracle, address indexed newOracle);

    // ============ Errors ============

    /// @notice Thrown when address is zero
    error ZeroAddress();

    /// @notice Thrown when amount is zero
    error ZeroAmount();

    /// @notice Thrown when trigger price is invalid
    error InvalidTriggerPrice();

    /// @notice Thrown when order does not exist
    error OrderNotFound();

    /// @notice Thrown when caller is not order owner
    error NotOrderOwner();

    /// @notice Thrown when order is not in pending status
    error OrderNotPending();

    /// @notice Thrown when order has expired
    error OrderExpiredError();

    /// @notice Thrown when trigger condition is not met
    error TriggerNotMet();

    /// @notice Thrown when position does not exist
    error PositionNotFound();

    /// @notice Thrown when caller is not position owner
    error NotPositionOwner();

    /// @notice Thrown when leverage is invalid
    error InvalidLeverage();

    // ============ Limit Order Functions ============

    /// @notice Create a limit open order
    /// @param collateralToken Token used as collateral
    /// @param collateralAmount Amount of collateral
    /// @param leverage Leverage multiplier (2-20)
    /// @param isLong True for long, false for short
    /// @param triggerPrice Price at which to open position
    /// @param expiry Expiry timestamp (0 for GTC)
    /// @return orderId The created order ID
    function createLimitOrder(
        address collateralToken,
        uint256 collateralAmount,
        uint256 leverage,
        bool isLong,
        uint256 triggerPrice,
        uint256 expiry
    ) external returns (uint256 orderId);

    // ============ TP/SL Functions ============

    /// @notice Set take profit for a position
    /// @param positionId The position to set TP for
    /// @param triggerPrice Price at which to take profit
    /// @return orderId The created order ID
    function setTakeProfit(
        uint256 positionId,
        uint256 triggerPrice
    ) external returns (uint256 orderId);

    /// @notice Set stop loss for a position
    /// @param positionId The position to set SL for
    /// @param triggerPrice Price at which to stop loss
    /// @return orderId The created order ID
    function setStopLoss(
        uint256 positionId,
        uint256 triggerPrice
    ) external returns (uint256 orderId);

    // ============ Order Management ============

    /// @notice Cancel a pending order
    /// @param orderId The order to cancel
    function cancelOrder(uint256 orderId) external;

    /// @notice Execute an order (keeper function)
    /// @param orderId The order to execute
    function executeOrder(uint256 orderId) external;

    // ============ Chainlink Automation ============

    /// @notice Check if any orders need execution
    /// @param checkData Encoded check parameters
    /// @return upkeepNeeded Whether upkeep is needed
    /// @return performData Data to pass to performUpkeep
    function checkUpkeep(
        bytes calldata checkData
    ) external view returns (bool upkeepNeeded, bytes memory performData);

    /// @notice Execute pending orders
    /// @param performData Data from checkUpkeep
    function performUpkeep(bytes calldata performData) external;

    // ============ View Functions ============

    /// @notice Get order details
    /// @param orderId The order ID
    /// @return order The order data
    function getOrder(uint256 orderId) external view returns (Order memory order);

    /// @notice Get all orders for a user
    /// @param user The user address
    /// @return orderIds Array of order IDs
    function getUserOrders(address user) external view returns (uint256[] memory orderIds);

    /// @notice Get TP/SL orders for a position
    /// @param positionId The position ID
    /// @return tpOrderId Take profit order ID (0 if not set)
    /// @return slOrderId Stop loss order ID (0 if not set)
    function getPositionOrders(
        uint256 positionId
    ) external view returns (uint256 tpOrderId, uint256 slOrderId);

    /// @notice Check if order trigger condition is met
    /// @param orderId The order to check
    /// @return triggered Whether trigger condition is met
    function isTriggered(uint256 orderId) external view returns (bool triggered);

    // ============ Admin Functions ============

    /// @notice Set the PositionManager contract
    /// @param manager New PositionManager address
    function setPositionManager(address manager) external;

    /// @notice Set the Oracle contract
    /// @param oracle New Oracle address
    function setOracle(address oracle) external;
}
