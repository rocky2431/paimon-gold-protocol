# Task 23: Write fuzz tests for math-heavy functions

## Task Details

- **ID**: 23
- **Priority**: P0
- **Complexity**: 5/10
- **Estimated Days**: 2
- **Dependencies**: Task 22 (completed)

## Description

Write Foundry fuzz tests for: PnL calculation, health factor calculation, leverage bounds (2-20), liquidation threshold, fee calculations. Use bound() for input ranges. Target 256 fuzz runs minimum.

## Acceptance Criteria

1. [x] Fuzz tests for all math functions
2. [x] No failures in 256+ runs
3. [x] Invariants documented

## Implementation Summary

Created `test/FuzzTests.t.sol` with 17 comprehensive fuzz tests:

### PositionManager Fuzz Tests (7 tests)
- [x] `testFuzz_PnL_LongPosition` - Long position PnL calculation
- [x] `testFuzz_PnL_ShortPosition` - Short position PnL calculation
- [x] `testFuzz_PositionSize_Calculation` - Size = collateral * leverage
- [x] `testFuzz_LeverageBounds_Enforcement` - Only 2-20x allowed
- [x] `testFuzz_MinPositionSize_Enforcement` - Min $10 position size
- [x] `testFuzz_PartialClose_Proportion` - Partial close ratio math

### LiquidationEngine Fuzz Tests (4 tests)
- [x] `testFuzz_HealthFactor_Calculation` - HF = effectiveCollateral / minMargin
- [x] `testFuzz_LiquidationBonus_Calculation` - 5% normal, 10% large positions
- [x] `testFuzz_PartialLiquidation_Percentage` - Valid 1-100%
- [x] `testFuzz_Liquidation_Threshold` - HF < 1.0 triggers liquidation

### LiquidityPool Fuzz Tests (5 tests)
- [x] `testFuzz_LPMinting_FirstDepositor` - 1:1 ratio
- [x] `testFuzz_LPMinting_SubsequentDepositor` - Proportional to share
- [x] `testFuzz_FeeDistribution_Split` - 70% LP, 30% protocol
- [x] `testFuzz_Withdrawal_Calculation` - Proportional withdrawal
- [x] `testFuzz_FeeAccumulation_PerShare` - Fee per share increase

### Cross-Contract Tests (1 test)
- [x] `testFuzz_PnL_Symmetry` - Long PnL = -Short PnL
- [x] `testFuzz_NoOverflow_InPnLCalculation` - No arithmetic overflow

## Test Results

- **Total fuzz tests**: 17
- **Runs per test**: 256
- **All tests passing**: ✅
- **Total tests in suite**: 405

## Status

- Started: 2025-11-28
- Status: Completed
