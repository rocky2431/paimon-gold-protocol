# Feature: InsuranceFund for Bad Debt Coverage

**Task ID**: 9
**Status**: In Progress
**Branch**: feat/task-9-insurance-fund

## Overview
Create an InsuranceFund contract that receives protocol fees and automatically covers bad debt from underwater liquidations, protecting LPs from losses.

## Rationale
- When liquidations result in bad debt (position value < 0), LPs would otherwise absorb losses
- Insurance fund provides a buffer to protect LPs
- 10% of protocol fees fund the insurance pool
- Emergency governance controls allow treasury management

## Technical Design

### Fund Mechanics
```
Protocol Fees → 10% to InsuranceFund → Covers Bad Debt
```

### Key Functions
```solidity
function deposit(address token, uint256 amount) external;
function coverBadDebt(address token, uint256 amount, address recipient) external;
function emergencyWithdraw(address token, uint256 amount, address recipient) external;
function getCoverageRatio(address token) external view returns (uint256);
function getBalance(address token) external view returns (uint256);
```

### Access Control
- `deposit()`: Anyone (protocol contracts)
- `coverBadDebt()`: Only LiquidationEngine
- `emergencyWithdraw()`: Only Owner with timelock

### Timelock for Emergency Withdraw
- 24-hour delay for emergency withdrawals
- Allows community to react to malicious proposals
- Can be cancelled during timelock period

### Events
```solidity
event Deposit(address indexed token, uint256 amount);
event BadDebtCovered(address indexed token, uint256 amount, address indexed recipient);
event EmergencyWithdrawQueued(address indexed token, uint256 amount, address recipient, uint256 executeTime);
event EmergencyWithdrawExecuted(address indexed token, uint256 amount, address recipient);
event EmergencyWithdrawCancelled(bytes32 indexed withdrawId);
```

### Errors
```solidity
error ZeroAmount();
error ZeroAddress();
error InsufficientBalance();
error Unauthorized();
error WithdrawNotReady();
error WithdrawExpired();
error WithdrawNotFound();
```

## Impact Assessment
- **User Stories Affected**: FR-3 Liquidation functionality
- **Architecture Changes**: No - new standalone contract
- **Breaking Changes**: No - additive changes only

## Requirements Trace
- Traces to: specs/product.md#fr-3-清算功能
