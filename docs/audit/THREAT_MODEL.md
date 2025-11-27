# Paimon Gold Protocol - Threat Model

## Overview

This document outlines the threat model for Paimon Gold Protocol using the STRIDE methodology. It identifies potential threats, their severity, and implemented mitigations.

## System Trust Boundaries

```
┌─────────────────────────────────────────────────────────────────┐
│                        UNTRUSTED ZONE                           │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐            │
│  │  User   │  │  LP     │  │ Attacker│  │ Keeper  │            │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘            │
└───────┼────────────┼────────────┼────────────┼──────────────────┘
        │            │            │            │
════════╪════════════╪════════════╪════════════╪════════ TRUST BOUNDARY
        │            │            │            │
┌───────┼────────────┼────────────┼────────────┼──────────────────┐
│       ▼            ▼            ▼            ▼                  │
│  ┌─────────────────────────────────────────────────┐           │
│  │            Smart Contract Layer                  │           │
│  │  ┌──────────────┐  ┌──────────────┐             │           │
│  │  │   Router     │  │ OrderManager │             │           │
│  │  └──────┬───────┘  └──────┬───────┘             │           │
│  │         │                 │                      │           │
│  │  ┌──────┴─────────────────┴──────┐              │           │
│  │  │     PositionManager           │              │           │
│  │  │     LiquidationEngine         │              │           │
│  │  │     LiquidityPool             │              │           │
│  │  └──────────────┬────────────────┘              │           │
│  │                 │                                │           │
│  │  ┌──────────────┴────────────────┐              │           │
│  │  │  CollateralVault (Assets)     │              │           │
│  │  └───────────────────────────────┘              │           │
│  └─────────────────────────────────────────────────┘           │
│                        TRUSTED ZONE                             │
└─────────────────────────────────────────────────────────────────┘
```

## STRIDE Analysis

### S - Spoofing

| Threat | Description | Severity | Mitigation |
|--------|-------------|----------|------------|
| S1 | Attacker spoofs user identity | High | Use `msg.sender` for all ownership checks |
| S2 | Spoofed oracle responses | Critical | Chainlink's cryptographic signatures + staleness check |
| S3 | Fake token addresses | Medium | Whitelist approved collateral tokens |

**S1 Mitigation Details:**
- All position operations verify `msg.sender == position.owner`
- No relayer patterns that could enable spoofing
- Position IDs are sequential and unpredictable

**S2 Mitigation Details:**
- OracleAdapter validates Chainlink signatures
- Price staleness check (< 1 hour)
- Price deviation check (< 5% from last known)

### T - Tampering

| Threat | Description | Severity | Mitigation |
|--------|-------------|----------|------------|
| T1 | Manipulate position data | Critical | Positions stored in contract storage, no external access |
| T2 | Tamper with collateral amounts | Critical | SafeERC20, exact balance tracking |
| T3 | Oracle price manipulation | Critical | Chainlink oracle, TWAP consideration |
| T4 | Flash loan attacks | High | 10-block minimum hold period |

**T4 Mitigation Details:**
```solidity
// Flash loan protection in PositionManager
if (block.number < position.openBlock + MIN_HOLD_BLOCKS) {
    revert PositionTooNew();
}
```

### R - Repudiation

| Threat | Description | Severity | Mitigation |
|--------|-------------|----------|------------|
| R1 | User denies opening position | Low | All actions emit events with block timestamp |
| R2 | Admin denies executing change | Medium | Timelock logs all proposals and executions |

**Event Logging:**
- `PositionOpened(id, owner, size, leverage, entryPrice)`
- `PositionClosed(id, pnl, exitPrice)`
- `Liquidated(id, liquidator, bonus)`
- `ProposalQueued(id, target, data, eta)`

### I - Information Disclosure

| Threat | Description | Severity | Mitigation |
|--------|-------------|----------|------------|
| I1 | Position data visible on-chain | Low | Accepted - blockchain transparency |
| I2 | LP strategy front-running | Medium | LP withdrawal has optional cooldown |
| I3 | Order front-running | High | Use private mempool or commit-reveal |

**I3 Consideration:**
- Current implementation vulnerable to MEV
- Future: Integrate Flashbots Protect or similar

### D - Denial of Service

| Threat | Description | Severity | Mitigation |
|--------|-------------|----------|------------|
| D1 | Gas griefing attacks | Medium | Fixed gas costs, no unbounded loops |
| D2 | Oracle unavailability | High | Circuit breaker, graceful degradation |
| D3 | Contract pause abuse | Medium | Multi-sig + timelock for pause |

**D1 Mitigation Details:**
- No array iterations in user-facing functions
- Position lookups are O(1) via mapping
- LP token mint/burn are O(1)

**D2 Mitigation Details:**
```solidity
// OracleAdapter circuit breaker
function getLatestPrice() external view returns (uint256) {
    if (circuitBreakerTriggered) revert OraclePaused();
    // Price validation...
}
```

### E - Elevation of Privilege

| Threat | Description | Severity | Mitigation |
|--------|-------------|----------|------------|
| E1 | Attacker becomes admin | Critical | Multi-sig (3/5) + 48h timelock |
| E2 | Keeper executes arbitrary calls | High | Keeper role limited to specific functions |
| E3 | Upgrade to malicious implementation | Critical | Timelock delay for proxy upgrades |

**Access Control Matrix:**

| Role | Capabilities |
|------|-------------|
| USER | Open/close positions, add/remove liquidity |
| KEEPER | Execute limit orders, trigger liquidations |
| PAUSER | Emergency pause contracts |
| ADMIN | Configure parameters (via timelock) |
| TIMELOCK | Execute queued admin operations |

## Attack Scenarios

### Scenario 1: Price Manipulation Attack

```
Attacker → Manipulate XAU/USD price on DEX
         → Oracle uses manipulated price
         → Open leveraged position at wrong price
         → Profit when price returns to normal
```

**Mitigations:**
1. Chainlink oracle (not DEX-based)
2. 5% max deviation check
3. Staleness validation

### Scenario 2: Flash Loan + Position Attack

```
Attacker → Flash loan large amount
         → Open huge position
         → Move market
         → Close position for profit
         → Repay flash loan
```

**Mitigations:**
1. 10-block minimum hold period
2. Position size limits
3. Liquidity utilization caps

### Scenario 3: Liquidation Front-Running

```
MEV Bot → Monitor mempool for liquidations
        → Front-run with higher gas
        → Steal liquidation bonus
```

**Mitigations:**
1. Fair liquidation queue (future)
2. Maximum bonus cap
3. Partial liquidation support

### Scenario 4: Admin Key Compromise

```
Attacker → Compromise 1-2 admin keys
         → Attempt malicious upgrade
         → 48h timelock allows detection
         → Community can respond
```

**Mitigations:**
1. 3/5 multi-sig requirement
2. 48-hour timelock delay
3. Public proposal monitoring

## Risk Assessment Summary

| Risk Category | Count | Critical | High | Medium | Low |
|---------------|-------|----------|------|--------|-----|
| Spoofing | 3 | 1 | 1 | 1 | 0 |
| Tampering | 4 | 2 | 1 | 0 | 1 |
| Repudiation | 2 | 0 | 0 | 1 | 1 |
| Info Disclosure | 3 | 0 | 1 | 1 | 1 |
| DoS | 3 | 0 | 1 | 2 | 0 |
| Elevation | 3 | 2 | 1 | 0 | 0 |
| **Total** | **18** | **5** | **5** | **5** | **3** |

## Recommendations

### Immediate (Pre-Launch)

1. [ ] Complete Slither analysis - fix all medium+ issues
2. [ ] External audit by reputable firm
3. [ ] Bug bounty program setup
4. [ ] Formal verification of critical functions

### Post-Launch

1. [ ] Implement MEV protection (Flashbots)
2. [ ] Add secondary oracle (Pyth Network)
3. [ ] Real-time monitoring dashboard
4. [ ] Incident response playbook

## Audit Scope

### In Scope

- All Solidity contracts in `src/`
- Access control logic
- Math calculations (PnL, health factor)
- Oracle integration
- Token handling

### Out of Scope

- Frontend application
- Off-chain keeper implementation
- Third-party dependencies (OpenZeppelin, Chainlink)

## Contact

For security disclosures: security@paimongold.io
