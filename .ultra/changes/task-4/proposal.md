# Feature: OracleAdapter with Chainlink Integration

**Task ID**: 4
**Status**: In Progress
**Branch**: feat/task-4-oracle-adapter

## Overview
Create a robust OracleAdapter contract that integrates Chainlink's XAU/USD price feed for the Paimon Gold Protocol. This adapter provides secure, validated gold price data for leverage trading operations.

## Rationale
- Chainlink is the industry standard for decentralized price feeds
- XAU/USD feed on BSC: `0x86896fEB19D8A607c3b11f2aF50A0f239Bd71CD0`
- Price validation prevents manipulation and stale data attacks
- Circuit breaker provides emergency protection

## Technical Design

### Contract Architecture
```
OracleAdapter (Ownable, Pausable)
├── Primary: Chainlink AggregatorV3Interface
├── Fallback: IPythOracle (placeholder)
├── Validation: staleness, deviation checks
└── Emergency: circuit breaker
```

### Key Parameters
- **Staleness threshold**: 1 hour (3600 seconds)
- **Max deviation**: 5% from last known price
- **Chainlink decimals**: 8 (XAU/USD)
- **Output decimals**: 18 (protocol standard)

### Security Features
1. Price staleness check (revert if >1h old)
2. Price deviation check (revert if >5% change)
3. Pausable circuit breaker
4. Owner-only configuration updates

## Impact Assessment
- **User Stories Affected**: FR-4 Oracle functionality
- **Architecture Changes**: No - follows existing design
- **Breaking Changes**: No - new contract

## Requirements Trace
- Traces to: specs/product.md#fr-4-oracle-功能
- Traces to: specs/architecture.md#oracle-integration
