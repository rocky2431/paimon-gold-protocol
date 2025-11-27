# Paimon Gold Protocol Subgraph

The Graph subgraph for indexing Paimon Gold Protocol events on BSC.

## Setup

```bash
cd subgraph
pnpm install
```

## Configuration

Before deployment, update `subgraph.yaml`:
1. Replace placeholder contract addresses with deployed addresses
2. Update `startBlock` to deployment block number

## Development

Generate types from ABI:
```bash
pnpm codegen
```

Build the subgraph:
```bash
pnpm build
```

## Deployment

### The Graph Studio
```bash
graph auth --studio YOUR_DEPLOY_KEY
pnpm deploy
```

### Hosted Service (Deprecated)
```bash
graph auth --product hosted-service YOUR_ACCESS_TOKEN
pnpm deploy:hosted
```

### Local Graph Node
```bash
pnpm create-local
pnpm deploy-local
```

## Schema

### Entities

- **Protocol** - Global protocol statistics
- **User** - User accounts with aggregated stats
- **Position** - Trading positions (long/short)
- **Order** - Limit/stop orders
- **LPPosition** - Liquidity provider positions
- **Liquidation** - Liquidation events
- **Deposit/Withdrawal** - Collateral movements
- **DailyStats** - Daily analytics
- **HourlyCandle** - Price candles

### Example Queries

**Get user positions:**
```graphql
query GetUserPositions($user: String!) {
  positions(where: { trader: $user, status: OPEN }) {
    id
    direction
    collateral
    leverage
    entryPrice
    size
    liquidationPrice
    openedAt
  }
}
```

**Get protocol stats:**
```graphql
query GetProtocolStats {
  protocol(id: "protocol") {
    totalPositions
    totalVolume
    totalFees
    totalLiquidations
    totalValueLocked
  }
}
```

**Get daily analytics:**
```graphql
query GetDailyStats($days: Int!) {
  dailyStats(first: $days, orderBy: date, orderDirection: desc) {
    date
    volume
    fees
    positionsOpened
    positionsClosed
    liquidations
  }
}
```

## Contract Events Indexed

### PositionManager
- PositionOpened
- PositionClosed
- PositionPartialClosed
- MarginAdded
- MarginRemoved

### LiquidityPool
- LiquidityAdded
- LiquidityRemoved
- FeesClaimed
- FeesDeposited

### LiquidationEngine
- PositionLiquidated
- PartialLiquidation

### CollateralVault
- Deposited
- Withdrawn

### OrderManager
- OrderCreated
- OrderExecuted
- OrderCancelled
- OrderExpired
