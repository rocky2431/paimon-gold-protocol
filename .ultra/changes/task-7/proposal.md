# Feature: Margin Adjustment Functionality

**Task ID**: 7
**Status**: In Progress
**Branch**: feat/task-7-margin-adjustment

## Overview
Add margin adjustment functions to PositionManager allowing users to add or remove collateral from their open positions without closing them.

## Rationale
- Users may want to reduce liquidation risk by adding margin
- Users may want to free up capital by removing excess margin
- Health factor enforcement prevents unsafe margin removal
- Leverage recalculation maintains accurate position metrics

## Technical Design

### New Functions
```solidity
function addMargin(uint256 positionId, uint256 amount) external;
function removeMargin(uint256 positionId, uint256 amount) external;
```

### Health Factor Requirement
- Minimum health factor after margin removal: 1.5 (150%)
- Health Factor = (collateral + unrealizedPnL) / requiredMargin
- Required margin = positionSize / leverage

### Events
```solidity
event MarginAdded(uint256 indexed positionId, uint256 amount, uint256 newCollateral);
event MarginRemoved(uint256 indexed positionId, uint256 amount, uint256 newCollateral);
```

### Errors
```solidity
error InsufficientHealthFactor();
error InsufficientMargin();
```

## Impact Assessment
- **User Stories Affected**: FR-1 Trading functionality
- **Architecture Changes**: No - extends existing PositionManager
- **Breaking Changes**: No - additive changes only

## Requirements Trace
- Traces to: specs/product.md#fr-1-交易功能
