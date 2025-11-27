# Feature: LiquidityPool with Fee Distribution

**Task ID**: 11
**Status**: In Progress
**Branch**: feat/task-11-liquidity-pool

## Overview
Create a LiquidityPool contract that allows users to provide liquidity, receive LP tokens proportionally, and earn fees from trading activity.

## Rationale
- LPs provide capital for leveraged trading
- LP tokens represent ownership share of the pool
- Fee distribution incentivizes liquidity provision
- Cooldown period prevents flash loan attacks

## Technical Design

### Fee Distribution Model
```
Trading Fee → 70% to LPs (accumulated per share)
           → 30% to Protocol Treasury
```

### LP Token Calculation
```solidity
// First depositor
lpAmount = depositAmount

// Subsequent depositors
lpAmount = (depositAmount * totalLPSupply) / totalPoolAssets
```

### Fee Accumulation (MasterChef-style)
```solidity
accFeePerShare += (newFees * PRECISION) / totalLPSupply
pendingFees = (lpBalance * accFeePerShare / PRECISION) - rewardDebt
```

### Key Functions
```solidity
function addLiquidity(address token, uint256 amount) external returns (uint256 lpAmount);
function removeLiquidity(uint256 lpAmount) external returns (uint256 assetAmount, uint256 feeReward);
function claimFees() external returns (uint256 feeAmount);
function depositFees(address token, uint256 amount) external;
```

### Cooldown Mechanism
- Configurable cooldown period (default: 24 hours)
- Users must wait after adding liquidity before withdrawing
- Prevents flash loan sandwich attacks

### Events
```solidity
event LiquidityAdded(address indexed user, address indexed token, uint256 amount, uint256 lpAmount);
event LiquidityRemoved(address indexed user, uint256 lpAmount, uint256 assetAmount, uint256 fees);
event FeesClaimed(address indexed user, uint256 amount);
event FeesDeposited(address indexed token, uint256 amount, uint256 lpShare, uint256 protocolShare);
event CooldownUpdated(uint256 oldCooldown, uint256 newCooldown);
```

### Errors
```solidity
error ZeroAmount();
error ZeroAddress();
error InsufficientBalance();
error CooldownNotPassed();
error Unauthorized();
error TokenNotSupported();
```

## Impact Assessment
- **User Stories Affected**: FR-2 Liquidity functionality
- **Architecture Changes**: No - integrates with LPToken and CollateralVault
- **Breaking Changes**: No - new contract

## Requirements Trace
- Traces to: specs/product.md#fr-2-流动性功能
