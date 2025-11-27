# Feature: Multi-sig and Timelock Governance

**Task ID**: 15
**Status**: In Progress
**Branch**: feat/task-15-governance

## Overview
Setup governance infrastructure with multi-sig (Safe) and timelock for admin operations. This provides security through multi-party approval and time-delayed execution for critical protocol changes.

## Rationale
- Multi-sig prevents single point of failure for admin keys
- Timelock gives users time to exit before protocol changes
- Role hierarchy enables separation of concerns (ops, admin, upgrades)
- Industry standard security practice for DeFi protocols

## Technical Design

### Architecture
```
┌─────────────────┐
│   Safe (3/5)    │  ← Multi-sig wallet (deployed via Safe UI)
└────────┬────────┘
         │ proposes
         ▼
┌─────────────────┐
│ProtocolTimelock │  ← 48h delay for sensitive operations
│ (TimelockCtrl)  │
└────────┬────────┘
         │ executes after delay
         ▼
┌─────────────────┐
│GoldLeverageRouter│  ← Protocol contracts
│  (AccessControl) │
└─────────────────┘
```

### Role Hierarchy
| Role | Holder | Permissions |
|------|--------|-------------|
| DEFAULT_ADMIN_ROLE | Safe Multi-sig | Grant/revoke roles |
| ADMIN_ROLE | ProtocolTimelock | setPositionManager, setLiquidityPool, setCollateralVault, unpause |
| UPGRADER_ROLE | ProtocolTimelock | UUPS upgrades |
| PAUSER_ROLE | Ops Team EOA | Emergency pause (no timelock) |
| KEEPER_ROLE | Chainlink Automation | Keeper operations |

### ProtocolTimelock Contract
```solidity
contract ProtocolTimelock is TimelockController {
    uint256 public constant MIN_DELAY = 48 hours;

    constructor(
        address[] memory proposers,  // Safe multi-sig
        address[] memory executors,  // Anyone can execute after delay
        address admin                // Safe multi-sig (can change delay)
    ) TimelockController(MIN_DELAY, proposers, executors, admin);
}
```

### Emergency Pause Flow
1. Ops team detects issue
2. Immediately calls `pause()` via PAUSER_ROLE (no timelock)
3. Multi-sig proposes fix
4. After 48h, fix is executed via timelock
5. Multi-sig can call `unpause()` via ADMIN_ROLE through timelock

### Upgrade Flow
1. Multi-sig schedules upgrade via timelock
2. 48h delay allows users to review and exit if needed
3. Anyone can execute upgrade after delay
4. New implementation is deployed via UUPS

## Implementation Files

| File | Description |
|------|-------------|
| `src/governance/ProtocolTimelock.sol` | Timelock wrapper with 48h minimum delay |
| `src/interfaces/IProtocolTimelock.sol` | Interface for timelock |
| `test/ProtocolTimelock.t.sol` | Comprehensive tests |
| `script/SetupGovernance.s.sol` | Deployment script (optional) |

## Impact Assessment
- **User Stories Affected**: Security-related admin operations
- **Architecture Changes**: Yes - adds governance layer
- **Breaking Changes**: No - existing contracts unchanged

## Requirements Trace
- Traces to: specs/product.md#security-constraints
