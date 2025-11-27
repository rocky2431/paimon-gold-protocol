# Feature: LPToken (ERC20)

**Task ID**: 10
**Status**: In Progress
**Branch**: feat/task-10-lp-token

## Overview
Create a UUPS upgradeable ERC20 token representing liquidity provider shares in the protocol's liquidity pool.

## Rationale
- LPs need a fungible token to represent their share of the pool
- UUPS pattern allows for future upgrades without migrating funds
- Mint/burn restricted to LiquidityPool for security

## Technical Design

### UUPS Upgradeable Pattern
```solidity
contract LPToken is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
```

### Key Functions
```solidity
function initialize(string memory name, string memory symbol) external initializer;
function mint(address to, uint256 amount) external;
function burn(address from, uint256 amount) external;
function setLiquidityPool(address pool) external;
```

### Access Control
- `mint()`: Only LiquidityPool
- `burn()`: Only LiquidityPool
- `setLiquidityPool()`: Only Owner
- `_authorizeUpgrade()`: Only Owner

### Events
```solidity
event LiquidityPoolSet(address indexed oldPool, address indexed newPool);
```

### Errors
```solidity
error ZeroAddress();
error Unauthorized();
```

## Impact Assessment
- **User Stories Affected**: FR-2 Liquidity functionality
- **Architecture Changes**: No - standalone token contract
- **Breaking Changes**: No - new contract

## Requirements Trace
- Traces to: specs/product.md#fr-2-流动性功能
