# Feature: Build price chart with TradingView Lightweight Charts

**Task ID**: 20
**Status**: In Progress
**Branch**: feat/task-20-price-chart

## Overview

Integrate TradingView Lightweight Charts library to display XAU/USD price with candlestick charts, volume indicators, and moving averages. The chart will support real-time price updates and be mobile responsive.

## Rationale

Traders need visual price data to make informed trading decisions. Candlestick charts with technical indicators are industry standard for trading interfaces.

## Impact Assessment

- **User Stories Affected**: specs/product.md#us-2-1-开仓 (price visualization for trading)
- **Architecture Changes**: No - UI component addition only
- **Breaking Changes**: No

## Requirements Trace

- Traces to: specs/architecture.md#frontend-stack

## Implementation Plan

1. Install TradingView Lightweight Charts library
2. Create PriceChart component with candlestick series
3. Add volume histogram
4. Implement MA (Moving Average) indicator
5. Generate mock historical data for demo
6. Add real-time price simulation
7. Ensure mobile responsiveness
8. Integrate into existing trade page
