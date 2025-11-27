# Feature: Write fork tests with real BSC data

**Task ID**: 24
**Status**: Completed
**Branch**: feat/task-24-fork-tests

## Overview

Fork tests using BSC mainnet data to validate protocol behavior with real Chainlink oracle prices and verify gas consumption limits.

## Rationale

Fork testing validates that contracts work correctly with real on-chain data, including actual Chainlink price feeds. This is critical for ensuring production readiness and accurate gas estimation.

## Impact Assessment

- **User Stories Affected**: None (testing only)
- **Architecture Changes**: No
- **Breaking Changes**: No

## Requirements Trace

- Traces to: specs/architecture.md#testing-strategy

## Test Scenarios

### Real Oracle Integration
- Connect to BSC mainnet Chainlink XAU/USD (0x86896fEB19D8A607c3b11f2aF50A0f239Bd71CD0)
- Verify price retrieval works with real feed
- Test price staleness with actual timestamps

### End-to-End Trading Scenarios
- Open position with real gold price
- Close position with profit/loss
- Liquidation scenarios with real price movements

### Gas Consumption Verification
- openPosition: <300K gas
- closePosition: <200K gas
- liquidate: <350K gas
