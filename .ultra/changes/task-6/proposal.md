# Feature: PositionManager Core Logic

**Task ID**: 6
**Status**: In Progress
**Branch**: feat/task-6-position-manager

## Overview
Create the core PositionManager contract for managing leveraged gold trading positions. This is the heart of the protocol, handling position lifecycle from opening to closing with accurate PnL calculations.

## Rationale
- Users need to open leveraged long/short positions on gold (XAU/USD)
- Leverage trading requires precise tracking of entry price, collateral, and position size
- PnL calculation must use 18-decimal precision to avoid rounding errors
- Integration with OracleAdapter provides real-time gold prices
- Integration with CollateralVault provides collateral custody

## Technical Design

### Position Struct
```solidity
struct Position {
    uint256 id;              // Unique position ID
    address owner;           // Position owner
    address collateralToken; // Collateral token address
    uint256 collateralAmount;// Amount of collateral
    uint256 size;            // Position size in USD (18 decimals)
    uint256 entryPrice;      // Entry price (18 decimals)
    uint256 leverage;        // Leverage (2-20x)
    bool isLong;             // Long or short
    uint256 openedAt;        // Timestamp when opened
    uint256 openBlock;       // Block number when opened (flash loan protection)
}
```

### Core Functions
1. **openPosition**: Create new leveraged position
   - Validate leverage (2-20x)
   - Validate min size ($10)
   - Transfer collateral from user
   - Get entry price from OracleAdapter
   - Store position and emit event

2. **closePosition**: Close position and settle PnL
   - Calculate current value using oracle price
   - Calculate PnL based on direction (long/short)
   - Return collateral +/- PnL to user
   - Handle liquidation scenario (negative PnL > collateral)

### PnL Calculation
```
For LONG:
  PnL = positionSize * (currentPrice - entryPrice) / entryPrice

For SHORT:
  PnL = positionSize * (entryPrice - currentPrice) / entryPrice

Final payout = collateral + PnL (capped at 0 if negative exceeds collateral)
```

### Security Features
1. ReentrancyGuard on all state-changing functions
2. Flash loan protection (minimum 10 blocks hold)
3. Leverage bounds enforcement
4. Pausable for emergency

## Impact Assessment
- **User Stories Affected**: FR-1 Trading functionality
- **Architecture Changes**: No - follows existing design
- **Breaking Changes**: No - new contract

## Requirements Trace
- Traces to: specs/product.md#fr-1-交易功能
