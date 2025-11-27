# Feature: Create The Graph subgraph for indexing

**Task ID**: 21
**Status**: In Progress
**Branch**: feat/task-21-subgraph

## Overview

Create a subgraph to index all on-chain events from the Paimon Gold Protocol smart contracts. This enables efficient querying of positions, trades, liquidity events, and liquidations through GraphQL.

## Rationale

Real-time indexing of blockchain events is essential for the frontend to display user positions, trade history, and protocol statistics without directly querying the blockchain for every request.

## Impact Assessment

- **User Stories Affected**: specs/product.md (all user stories requiring historical data)
- **Architecture Changes**: Yes - adds indexing layer
- **Breaking Changes**: No

## Requirements Trace

- Traces to: specs/architecture.md#backend-stack

## Events to Index

### PositionManager
- PositionOpened(positionId, trader, direction, collateral, leverage, entryPrice, size)
- PositionClosed(positionId, trader, exitPrice, pnl)
- PositionPartialClosed(positionId, trader, amount, exitPrice, pnl)
- MarginAdded(positionId, trader, amount)
- MarginRemoved(positionId, trader, amount)

### LiquidityPool
- LiquidityAdded(provider, token, amount, lpTokensMinted)
- LiquidityRemoved(provider, lpTokensBurned, tokensReturned)
- FeesClaimed(user, amount)
- FeesDeposited(token, amount, feeType)

### LiquidationEngine
- PositionLiquidated(positionId, liquidator, trader, collateral, penalty)
- PartialLiquidation(positionId, liquidator, trader, amount)

### CollateralVault
- Deposited(user, token, amount)
- Withdrawn(user, token, amount)
