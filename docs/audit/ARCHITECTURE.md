# Paimon Gold Protocol - Architecture Documentation

## Contract Architecture

```mermaid
graph TB
    subgraph "User Layer"
        USER[User/Trader]
        LP[Liquidity Provider]
        KEEPER[Keeper/Bot]
    end

    subgraph "Entry Points"
        ROUTER[GoldLeverageRouter]
        ORDER[OrderManager]
    end

    subgraph "Core Logic"
        PM[PositionManager]
        LE[LiquidationEngine]
        POOL[LiquidityPool]
    end

    subgraph "Infrastructure"
        ORACLE[OracleAdapter]
        VAULT[CollateralVault]
        LPTOKEN[LPToken]
        INS[InsuranceFund]
    end

    subgraph "Governance"
        TIMELOCK[ProtocolTimelock]
        ADMIN[Admin Multi-sig 3/5]
    end

    subgraph "External"
        CHAINLINK[Chainlink XAU/USD]
        USDT[USDT/USDC/BNB]
    end

    %% User flows
    USER -->|trade| ROUTER
    USER -->|limit orders| ORDER
    LP -->|add liquidity| POOL
    KEEPER -->|execute orders| ORDER
    KEEPER -->|liquidate| LE

    %% Router flows
    ROUTER -->|manage positions| PM
    ROUTER -->|add/remove liquidity| POOL

    %% Core interactions
    PM -->|get price| ORACLE
    PM -->|custody| VAULT
    LE -->|get price| ORACLE
    LE -->|check positions| PM
    LE -->|cover bad debt| INS
    ORDER -->|get price| ORACLE
    ORDER -->|execute| PM

    %% LP flows
    POOL -->|mint/burn| LPTOKEN
    POOL -->|deposit/withdraw| VAULT
    POOL -->|receive fees| PM

    %% Oracle
    ORACLE -->|price feed| CHAINLINK

    %% Vault
    VAULT -->|hold| USDT

    %% Governance
    ADMIN -->|propose| TIMELOCK
    TIMELOCK -->|execute after 48h| ROUTER
    TIMELOCK -->|execute after 48h| PM
```

## Contract Interactions

### Position Lifecycle

```mermaid
sequenceDiagram
    participant User
    participant Router as GoldLeverageRouter
    participant PM as PositionManager
    participant Oracle as OracleAdapter
    participant Vault as CollateralVault

    User->>Router: openPosition(collateral, leverage, isLong)
    Router->>Oracle: getLatestPrice()
    Oracle-->>Router: price
    Router->>Vault: transferFrom(user, collateral)
    Router->>PM: createPosition(params)
    PM-->>Router: positionId
    Router-->>User: positionId

    Note over User,Vault: Position is now open

    User->>Router: closePosition(positionId)
    Router->>Oracle: getLatestPrice()
    Oracle-->>Router: currentPrice
    Router->>PM: calculatePnL(positionId, currentPrice)
    PM-->>Router: pnl
    Router->>Vault: transfer(user, collateral + pnl)
    Router->>PM: deletePosition(positionId)
```

### Liquidation Flow

```mermaid
sequenceDiagram
    participant Keeper
    participant LE as LiquidationEngine
    participant PM as PositionManager
    participant Oracle as OracleAdapter
    participant Vault as CollateralVault
    participant INS as InsuranceFund

    Keeper->>LE: checkLiquidation(positionId)
    LE->>Oracle: getLatestPrice()
    Oracle-->>LE: currentPrice
    LE->>PM: getPosition(positionId)
    PM-->>LE: position
    LE->>LE: calculateHealthFactor()

    alt Health Factor < 1.0
        LE->>PM: liquidatePosition(positionId)
        PM->>Vault: transfer(keeper, bonus)

        alt Bad Debt
            PM->>INS: coverBadDebt(amount)
        end

        LE-->>Keeper: success + bonus
    else Health Factor >= 1.0
        LE-->>Keeper: revert PositionNotLiquidatable
    end
```

## Contract Summary

| Contract | Purpose | Access Control |
|----------|---------|----------------|
| GoldLeverageRouter | Unified entry point for all user operations | Pausable by PAUSER_ROLE |
| PositionManager | Position lifecycle (open/close/adjust) | Owner can pause |
| LiquidationEngine | Monitor and execute liquidations | Keeper-callable |
| OrderManager | Limit orders, TP/SL orders | Keeper-callable for execution |
| LiquidityPool | LP deposits/withdrawals, fee distribution | Owner can pause |
| CollateralVault | Secure collateral custody | Restricted to trusted contracts |
| OracleAdapter | Chainlink price feed wrapper | Owner can update config |
| LPToken | ERC20 LP token | Minting restricted to LiquidityPool |
| InsuranceFund | Bad debt coverage | Governance-controlled |
| ProtocolTimelock | 48h delay for admin operations | Multi-sig controlled |

## Key Security Features

### 1. Flash Loan Protection
- Minimum 10 blocks (~30s) hold time for positions
- Prevents same-block open/close attacks

### 2. Oracle Safety
- Staleness check (< 1 hour)
- Price deviation check (< 5%)
- Circuit breaker for anomalies

### 3. Access Control
- Multi-sig (3/5) for admin operations
- 48-hour timelock for sensitive changes
- Role-based access (ADMIN, KEEPER, PAUSER)

### 4. Reentrancy Protection
- ReentrancyGuard on all state-changing functions
- SafeERC20 for all token transfers

## Deployed Addresses (Testnet)

| Contract | Address |
|----------|---------|
| GoldLeverageRouter | TBD |
| PositionManager | TBD |
| LiquidationEngine | TBD |
| OrderManager | TBD |
| LiquidityPool | TBD |
| CollateralVault | TBD |
| OracleAdapter | TBD |
| LPToken | TBD |
| InsuranceFund | TBD |
| ProtocolTimelock | TBD |
