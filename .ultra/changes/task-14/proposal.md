# Feature: Flash Loan Protection

**Task ID**: 14
**Status**: Completed (Pre-implemented in Task 6)
**Branch**: feat/task-14-flash-loan-protection

## Overview
Implement minimum hold blocks requirement to prevent flash loan attacks on positions. This prevents attackers from opening and closing positions within the same block to exploit price manipulation.

## Rationale
- Flash loans allow attackers to borrow large amounts within a single transaction
- Without hold time, attackers could manipulate prices and profit in one block
- 10 blocks (~30 seconds on BSC) provides reasonable protection
- Aligns with standard DeFi security practices

## Implementation Status

**Already implemented in Task 6 (PositionManager)**:

### Constants
```solidity
// src/PositionManager.sol:31
uint256 public constant MIN_HOLD_BLOCKS = 10;
```

### Position Struct (stores open block)
```solidity
// src/interfaces/IPositionManager.sol:31
struct Position {
    ...
    uint256 openBlock;  // Block when position was opened
}
```

### closePosition Protection
```solidity
// src/PositionManager.sol:140-143
if (block.number <= pos.openBlock + MIN_HOLD_BLOCKS) {
    revert PositionTooNew();
}
```

### removeMargin Protection
```solidity
// src/PositionManager.sol:251-254
if (block.number <= pos.openBlock + MIN_HOLD_BLOCKS) {
    revert PositionTooNew();
}
```

## Test Coverage

Three dedicated tests exist in `test/PositionManager.t.sol`:

1. **test_RevertOnFlashLoanAttack()** - Verifies same-block close reverts
2. **test_FlashLoanProtection()** - Verifies blocks 1-10 revert, block 11 succeeds
3. **test_RemoveMarginFlashLoanProtection()** - Verifies same-block margin removal reverts

## Acceptance Criteria Verification

| Criterion | Implementation | Test |
|-----------|----------------|------|
| closePosition reverts within 10 blocks | Line 141-143 | test_FlashLoanProtection |
| Withdrawal reverts within 10 blocks | Line 252-254 | test_RemoveMarginFlashLoanProtection |
| Block number stored per position | Position.openBlock | test_RevertOnFlashLoanAttack |

## Impact Assessment
- **User Stories Affected**: None - security feature
- **Architecture Changes**: No - already implemented
- **Breaking Changes**: No

## Requirements Trace
- Traces to: specs/product.md#risks-mitigation
