# Feature: OrderManager for Limit Orders and TP/SL

**Task ID**: 13
**Status**: In Progress
**Branch**: feat/task-13-order-manager

## Overview
Create OrderManager contract to handle limit open orders and Take-Profit/Stop-Loss (TP/SL) orders. Orders are stored with trigger prices and executed by keepers when price conditions are met.

## Rationale
- Users need to place orders at specific prices (limit orders)
- Risk management via automated TP/SL
- Keeper-compatible for decentralized execution
- GTC (Good-Til-Cancelled) and GTD (Good-Til-Date) expiry options

## Technical Design

### Order Types
```solidity
enum OrderType {
    LIMIT_OPEN,    // Open position when price reaches trigger
    TAKE_PROFIT,   // Close position when price reaches target (profit)
    STOP_LOSS      // Close position when price reaches target (loss)
}

enum OrderStatus {
    PENDING,       // Waiting for execution
    EXECUTED,      // Successfully executed
    CANCELLED,     // Cancelled by user
    EXPIRED        // Expired without execution
}
```

### Order Struct
```solidity
struct Order {
    uint256 id;              // Unique order ID
    address owner;           // Order creator
    OrderType orderType;     // Type of order
    uint256 positionId;      // Associated position (for TP/SL)
    address collateralToken; // Collateral token (for limit open)
    uint256 collateralAmount;// Collateral amount (for limit open)
    uint256 leverage;        // Leverage (for limit open)
    bool isLong;             // Direction (for limit open)
    uint256 triggerPrice;    // Price at which to execute
    uint256 expiry;          // 0 = GTC, >0 = GTD timestamp
    OrderStatus status;      // Current status
    uint256 createdAt;       // Creation timestamp
}
```

### Key Functions
```solidity
// Limit Orders
function createLimitOrder(
    address collateralToken,
    uint256 collateralAmount,
    uint256 leverage,
    bool isLong,
    uint256 triggerPrice,
    uint256 expiry
) external returns (uint256 orderId);

// TP/SL Orders
function setTakeProfit(uint256 positionId, uint256 triggerPrice) external returns (uint256 orderId);
function setStopLoss(uint256 positionId, uint256 triggerPrice) external returns (uint256 orderId);

// Cancellation
function cancelOrder(uint256 orderId) external;

// Keeper Execution
function executeOrder(uint256 orderId) external;
function checkUpkeep(bytes calldata) external view returns (bool upkeepNeeded, bytes memory performData);
function performUpkeep(bytes calldata performData) external;
```

### Trigger Logic
```solidity
// For LIMIT_OPEN Long: currentPrice <= triggerPrice
// For LIMIT_OPEN Short: currentPrice >= triggerPrice
// For TAKE_PROFIT Long: currentPrice >= triggerPrice
// For TAKE_PROFIT Short: currentPrice <= triggerPrice
// For STOP_LOSS Long: currentPrice <= triggerPrice
// For STOP_LOSS Short: currentPrice >= triggerPrice
```

### Events
```solidity
event OrderCreated(uint256 indexed orderId, address indexed owner, OrderType orderType, uint256 triggerPrice);
event OrderExecuted(uint256 indexed orderId, uint256 executionPrice);
event OrderCancelled(uint256 indexed orderId);
event OrderExpired(uint256 indexed orderId);
```

### Integration Points
- **OracleAdapter**: Get current price for trigger checks
- **PositionManager**: Execute open/close operations
- **Chainlink Automation**: checkUpkeep/performUpkeep interface

## Impact Assessment
- **User Stories Affected**: FR-1.4 (Limit Orders), FR-1.5 (TP/SL)
- **Architecture Changes**: No - integrates with existing contracts
- **Breaking Changes**: No - new contract

## Requirements Trace
- Traces to: specs/product.md#epic-4-订单系统
