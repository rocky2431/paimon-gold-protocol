# Feature: CollateralVault with Multi-Token Support

**Task ID**: 5
**Status**: In Progress
**Branch**: feat/task-5-collateral-vault

## Overview
Create a secure CollateralVault contract for custody of user collateral. Supports multiple stablecoins (USDT, USDC, BUSD) and native BNB. This is the foundation for leverage trading positions.

## Rationale
- Users need to deposit collateral before opening leveraged positions
- Multi-token support provides flexibility for different user preferences
- ReentrancyGuard protects against reentrancy attacks
- SafeERC20 handles non-standard ERC20 implementations

## Technical Design

### Contract Architecture
```
CollateralVault (Ownable, ReentrancyGuard)
├── Supported tokens: mapping(address => bool)
├── User balances: mapping(address => mapping(address => uint256))
├── Deposit: ERC20 + native BNB
├── Withdraw: with balance checks
└── Events: Deposited, Withdrawn
```

### Supported Tokens (BSC)
- USDT: 0x55d398326f99059fF775485246999027B3197955
- USDC: 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d
- BUSD: 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56
- BNB: Native (address(0) or WBNB)

### Security Features
1. ReentrancyGuard on all state-changing functions
2. SafeERC20 for token transfers
3. Balance checks before withdrawals
4. Owner-only token whitelist management

## Impact Assessment
- **User Stories Affected**: FR-1 Trading functionality
- **Architecture Changes**: No - follows existing design
- **Breaking Changes**: No - new contract

## Requirements Trace
- Traces to: specs/product.md#fr-1-交易功能
