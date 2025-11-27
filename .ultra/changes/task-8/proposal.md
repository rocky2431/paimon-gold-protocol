# Feature: LiquidationEngine with Keeper Support

**Task ID**: 8
**Status**: In Progress
**Branch**: feat/task-8-liquidation-engine

## Overview
Implement a LiquidationEngine contract that monitors position health factors and enables automated liquidation by keeper bots when positions become undercollateralized.

## Rationale
- Positions with HF < 1.0 pose risk to protocol solvency
- Keepers are incentivized with liquidation bonus (5-10%)
- Partial liquidation prevents market impact for large positions
- Chainlink Automation enables decentralized keeper network

## Technical Design

### Health Factor Calculation
```
Health Factor = (Collateral + Unrealized PnL) / Required Margin
Required Margin = Position Size / MAX_LEVERAGE (20x)

HF >= 1.0: Position is safe
HF < 1.0: Position can be liquidated
```

### Liquidation Bonus Structure
- Base bonus: 5% of liquidated collateral
- Large position bonus: Up to 10% for positions requiring partial liquidation
- Bonus paid from position's collateral

### Partial Liquidation
- Triggered when position size > $100,000
- Liquidate 50% per transaction to prevent market impact
- Multiple liquidation calls may be needed

### Chainlink Automation Integration
```solidity
interface AutomationCompatibleInterface {
    function checkUpkeep(bytes calldata checkData)
        external view returns (bool upkeepNeeded, bytes memory performData);
    function performUpkeep(bytes calldata performData) external;
}
```

### Key Functions
```solidity
function liquidate(uint256 positionId) external;
function liquidatePartial(uint256 positionId, uint256 percentage) external;
function getHealthFactor(uint256 positionId) external view returns (uint256);
function isLiquidatable(uint256 positionId) external view returns (bool);
```

### Events
```solidity
event PositionLiquidated(
    uint256 indexed positionId,
    address indexed liquidator,
    uint256 collateralLiquidated,
    uint256 keeperBonus,
    uint256 remainingCollateral
);
event PartialLiquidation(
    uint256 indexed positionId,
    uint256 percentage,
    uint256 newHealthFactor
);
```

### Errors
```solidity
error PositionNotLiquidatable();
error InvalidLiquidationPercentage();
error ZeroAddress();
```

## Impact Assessment
- **User Stories Affected**: FR-3 Liquidation functionality
- **Architecture Changes**: No - new standalone contract
- **Breaking Changes**: No - additive changes only

## Requirements Trace
- Traces to: specs/product.md#fr-3-清算功能
