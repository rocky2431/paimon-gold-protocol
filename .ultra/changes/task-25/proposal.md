# Feature: Build order management interface

**Task ID**: 25
**Status**: In Progress
**Branch**: feat/task-25-order-management

## Overview

Order management UI for creating limit orders, managing pending orders, setting TP/SL, and viewing order history.

## Rationale

Users need a comprehensive interface to manage advanced order types beyond market orders, including limit orders and take-profit/stop-loss orders for risk management.

## Impact Assessment

- **User Stories Affected**: US-4.1 (限价开仓), US-4.2 (止盈止损)
- **Architecture Changes**: No
- **Breaking Changes**: No

## Requirements Trace

- Traces to: specs/product.md#us-4-1-限价开仓

## Components

### LimitOrderForm
- Trigger price input
- Order type (buy/sell)
- Collateral amount
- Leverage selector
- Expiry option (GTC/GTD)

### PendingOrdersList
- Active orders table
- Order details (price, size, direction)
- Cancel order action
- Order status indicators

### TPSLSettings
- Take profit price input
- Stop loss price input
- Link to open position
- Modify/cancel actions

### OrderHistory
- Executed orders history
- Order status (filled, cancelled, expired)
- Execution price and time
