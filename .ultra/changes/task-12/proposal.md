# Feature: GoldLeverageRouter - Unified Entry Point

**Task ID**: 12
**Status**: In Progress
**Branch**: feat/task-12-gold-leverage-router

## Overview
Create GoldLeverageRouter as the unified user entry point for all protocol interactions. The router aggregates access to PositionManager and LiquidityPool through a single UUPS upgradeable contract with AccessControl and pausable functionality.

## Rationale
- Single contract address for all user interactions
- Simplified frontend integration
- Centralized access control and pause mechanism
- Upgradeable for future feature additions
- Input validation at entry point

## Technical Design

### Architecture
```
User → GoldLeverageRouter (UUPS Proxy)
              ├─→ PositionManager (trading)
              └─→ LiquidityPool (LP operations)
```

### Access Control Roles
```solidity
bytes32 ADMIN_ROLE       // Protocol admin (multi-sig)
bytes32 KEEPER_ROLE      // Automation keepers
bytes32 PAUSER_ROLE      // Emergency pause authority
bytes32 UPGRADER_ROLE    // Contract upgrade authority
```

### Router Functions

**Trading Functions (→ PositionManager)**:
```solidity
function openPosition(address collateralToken, uint256 collateralAmount, uint256 leverage, bool isLong) external returns (uint256 positionId);
function closePosition(uint256 positionId, uint256 closeAmount) external returns (int256 pnl);
function addMargin(uint256 positionId, uint256 amount) external;
function removeMargin(uint256 positionId, uint256 amount) external;
```

**LP Functions (→ LiquidityPool)**:
```solidity
function addLiquidity(address token, uint256 amount) external returns (uint256 lpAmount);
function removeLiquidity(uint256 lpAmount) external returns (uint256 assetAmount, uint256 feeReward);
function claimFees() external returns (uint256 feeAmount);
```

**View Functions**:
```solidity
function getPosition(uint256 positionId) external view returns (Position memory);
function getUserPositions(address user) external view returns (uint256[] memory);
function getHealthFactor(uint256 positionId) external view returns (uint256);
function getPendingFees(address user) external view returns (uint256);
function getPoolStats() external view returns (uint256 tvl, uint256 utilization);
```

### Emergency Controls
```solidity
function pause() external onlyRole(PAUSER_ROLE);
function unpause() external onlyRole(ADMIN_ROLE);
```

### Events
```solidity
event PositionManagerSet(address indexed oldManager, address indexed newManager);
event LiquidityPoolSet(address indexed oldPool, address indexed newPool);
event EmergencyPause(address indexed pauser, uint256 timestamp);
event EmergencyUnpause(address indexed admin, uint256 timestamp);
```

## Impact Assessment
- **User Stories Affected**: All trading and LP user stories
- **Architecture Changes**: No - adds entry point layer
- **Breaking Changes**: No - new contract, existing contracts unchanged

## Requirements Trace
- Traces to: specs/architecture.md#contract-1-goldleveragerouter
