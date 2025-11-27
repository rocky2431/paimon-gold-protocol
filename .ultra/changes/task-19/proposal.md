# Feature: Build LP Interface for Liquidity Providers

**Task ID**: 19
**Status**: In Progress
**Branch**: feat/task-19-lp-interface

## Overview

Create a liquidity provider interface that allows users to deposit tokens into the liquidity pool and earn fees. The interface includes deposit/withdraw forms, pool statistics (TVL, APY, utilization), and user position tracking.

## Rationale

Liquidity providers are essential for the protocol's trading functionality. They need a clear interface to manage their positions, track earnings, and understand pool metrics.

## Impact Assessment

- **User Stories Affected**: specs/product.md#us-3-1-提供流动性
- **Architecture Changes**: No - UI component addition only
- **Breaking Changes**: No

## Requirements Trace

- Traces to: specs/product.md#us-3-1-提供流动性

## Implementation Plan

1. Create /liquidity route and page
2. Build DepositForm component with token selector
3. Build WithdrawForm component
4. Add PoolStats component (TVL, APY, utilization)
5. Create UserLPPosition component
6. Add fee earnings tracker

## Acceptance Criteria

- [ ] Deposit flow works
- [ ] Withdraw flow works
- [ ] APY estimate displayed
- [ ] User LP balance shown
