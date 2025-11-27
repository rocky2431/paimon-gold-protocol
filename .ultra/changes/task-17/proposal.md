# Feature: Build Trading Interface with Leverage Slider

**Task ID**: 17
**Status**: In Progress
**Branch**: feat/task-17-trading-interface

## Overview

Create a comprehensive trading page for the Paimon Gold Protocol that allows users to open leveraged positions on gold (XAU/USD). The interface includes collateral input, leverage slider (2-20x), direction toggle (long/short), position size calculator, real-time price display, and health factor preview.

## Rationale

This is the core trading functionality that enables users to interact with the protocol. The trading interface must be intuitive, provide real-time feedback, and ensure users understand their risk exposure before opening positions.

## Impact Assessment

- **User Stories Affected**: specs/product.md#us-1-1-开仓
- **Architecture Changes**: No - UI component addition only
- **Breaking Changes**: No

## Requirements Trace

- Traces to: specs/product.md#us-1-1-开仓

## Implementation Plan

1. Create trading page layout with two-column design
2. Build leverage slider component (2-20x with visual feedback)
3. Implement collateral input with token selector
4. Add direction toggle (Long/Short)
5. Build position calculator (size, liquidation price, fees)
6. Integrate mock price feed (to be replaced with real oracle)
7. Create transaction confirmation dialog
8. Add health factor preview

## Acceptance Criteria

- [ ] Leverage slider 2-20x
- [ ] Live XAU/USD price display
- [ ] Position size calculated correctly
- [ ] Transaction confirmation flow

## UI Components

```
┌─────────────────────────────────────────────────────────┐
│ Trading Interface                                        │
├─────────────────────────┬───────────────────────────────┤
│ Price Chart (future)    │ Trade Panel                   │
│                         │ ┌───────────────────────────┐ │
│                         │ │ [Long] [Short]            │ │
│                         │ ├───────────────────────────┤ │
│                         │ │ Collateral: [____] USDT   │ │
│                         │ ├───────────────────────────┤ │
│                         │ │ Leverage: [===●===] 10x   │ │
│                         │ ├───────────────────────────┤ │
│                         │ │ Position Size: $1,000     │ │
│                         │ │ Entry Price: $2,650.00    │ │
│                         │ │ Liq. Price: $2,385.00     │ │
│                         │ │ Health Factor: 1.82       │ │
│                         │ │ Trading Fee: $1.00        │ │
│                         │ ├───────────────────────────┤ │
│                         │ │ [Open Position]           │ │
│                         │ └───────────────────────────┘ │
└─────────────────────────┴───────────────────────────────┘
```
