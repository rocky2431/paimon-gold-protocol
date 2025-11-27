# Feature: Build Portfolio View with Positions Table

**Task ID**: 18
**Status**: In Progress
**Branch**: feat/task-18-portfolio-view

## Overview

Create a portfolio page that displays all user positions with real-time PnL updates, health factor monitoring, and close position actions. The page shows open positions in a table format with entry price, current price, PnL%, and health factor.

## Rationale

Users need visibility into their open and closed positions to manage risk and make informed trading decisions. Real-time PnL updates and health factor monitoring are critical for leveraged trading.

## Impact Assessment

- **User Stories Affected**: specs/product.md#us-1-2-平仓
- **Architecture Changes**: No - UI component addition only
- **Breaking Changes**: No

## Requirements Trace

- Traces to: specs/product.md#us-1-2-平仓

## Implementation Plan

1. Create /portfolio route and page
2. Build PositionsTable component with sortable columns
3. Add real-time PnL calculation
4. Implement health factor color-coding
5. Create close position action with confirmation
6. Add total equity summary

## Acceptance Criteria

- [ ] Display all user positions
- [ ] Real-time PnL calculation
- [ ] Close position action works
- [ ] Health factor color-coded
