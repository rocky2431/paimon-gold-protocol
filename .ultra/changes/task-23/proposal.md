# Feature: Write fuzz tests for math-heavy functions

**Task ID**: 23
**Status**: Completed
**Branch**: feat/task-23-fuzz-tests

## Overview

Comprehensive fuzz testing suite for all math-intensive functions in the Paimon Gold Protocol using Foundry's built-in fuzzing capabilities.

## Rationale

Math functions are critical to protocol security. Fuzz testing with random inputs helps discover edge cases and overflow conditions that manual testing might miss. This is essential for DeFi protocols handling user funds.

## Impact Assessment

- **User Stories Affected**: None (testing only)
- **Architecture Changes**: No
- **Breaking Changes**: No

## Requirements Trace

- Traces to: specs/architecture.md#testing-strategy

## Target Functions

### PositionManager
- `_calculatePnL()` - PnL calculation with leverage
- `_calculateMarginRatio()` - Margin ratio for health
- `_calculateLiquidationPrice()` - Liquidation threshold
- Leverage bounds enforcement (2-20x)

### LiquidationEngine
- `calculateHealthFactor()` - Health factor computation
- `_calculateLiquidationBonus()` - Keeper incentive calculation
- `_calculateMaxLiquidatableAmount()` - Partial liquidation math

### LiquidityPool
- `_calculateLPTokensToMint()` - LP token minting math
- `_calculateFeeShare()` - Fee distribution calculation
- `_calculateWithdrawalAmount()` - Withdrawal math

### OracleAdapter
- Price deviation checks
- Staleness validation

## Test Strategy

1. Use `bound()` to constrain inputs to valid ranges
2. Target 256 fuzz runs minimum (configured in foundry.toml)
3. Document invariants for each function
4. Test both success and failure paths
