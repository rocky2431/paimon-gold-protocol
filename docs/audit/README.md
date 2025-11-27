# Paimon Gold Protocol - Audit Package

## Overview

Paimon Gold Protocol is a decentralized leveraged gold trading protocol on BSC (BNB Smart Chain). This audit package contains all documentation necessary for a comprehensive security review.

## Package Contents

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Contract architecture, interactions, and diagrams |
| [THREAT_MODEL.md](./THREAT_MODEL.md) | STRIDE-based threat analysis and mitigations |
| [SLITHER_REPORT.md](./SLITHER_REPORT.md) | Static analysis results and responses |
| [slither-report.json](./slither-report.json) | Raw Slither output (machine-readable) |

## Protocol Summary

**Purpose**: Enable leveraged long/short positions on gold (XAU/USD) with up to 20x leverage

**Key Features**:
- Multi-collateral support (USDT, USDC, BNB)
- Chainlink oracle integration for price feeds
- Automated liquidation via Chainlink Keepers
- Limit orders and TP/SL functionality
- Liquidity provider yield from trading fees

## Contract Inventory

| Contract | Lines | Purpose |
|----------|-------|---------|
| GoldLeverageRouter.sol | ~200 | Entry point for all user operations |
| PositionManager.sol | ~350 | Position lifecycle management |
| LiquidationEngine.sol | ~200 | Health monitoring and liquidations |
| OrderManager.sol | ~450 | Limit orders, TP/SL |
| LiquidityPool.sol | ~350 | LP deposits and fee distribution |
| CollateralVault.sol | ~150 | Collateral custody |
| OracleAdapter.sol | ~200 | Chainlink integration |
| LPToken.sol | ~100 | ERC20 LP token (upgradeable) |
| InsuranceFund.sol | ~150 | Bad debt coverage |
| ProtocolTimelock.sol | ~200 | Admin operations with delay |

**Total SLOC**: ~1,900 lines (excluding interfaces, tests)

## Dependencies

| Package | Version | Usage |
|---------|---------|-------|
| OpenZeppelin Contracts | 5.3.0 | Access control, ReentrancyGuard, SafeERC20, UUPS |
| Chainlink Contracts | 1.4.0 | Price feeds, Automation |

## Key Security Features

### Access Control

- **Multi-sig**: 3/5 Safe multi-sig for admin operations
- **Timelock**: 48-hour delay for sensitive changes
- **Roles**: ADMIN, KEEPER, PAUSER

### Safety Mechanisms

- **Reentrancy Protection**: All state-changing functions protected
- **Flash Loan Protection**: 10-block minimum hold period
- **Oracle Safety**: Staleness (<1h) and deviation (<5%) checks
- **Circuit Breaker**: Emergency pause capability

### Token Handling

- SafeERC20 for all token operations
- Whitelist for approved collateral tokens
- Slippage protection on swaps

## Test Coverage

```
forge coverage

| File                    | % Lines | % Statements | % Branches | % Functions |
|-------------------------|---------|--------------|------------|-------------|
| CollateralVault.sol     | 95.23%  | 93.75%       | 83.33%     | 100.00%     |
| GoldLeverageRouter.sol  | 87.87%  | 86.66%       | 75.00%     | 92.30%      |
| InsuranceFund.sol       | 100.00% | 100.00%      | 100.00%    | 100.00%     |
| LiquidationEngine.sol   | 100.00% | 100.00%      | 100.00%    | 100.00%     |
| LiquidityPool.sol       | 91.66%  | 90.00%       | 81.25%     | 100.00%     |
| LPToken.sol             | 87.50%  | 85.71%       | 75.00%     | 100.00%     |
| OracleAdapter.sol       | 95.83%  | 95.00%       | 90.00%     | 100.00%     |
| OrderManager.sol        | 80.32%  | 78.33%       | 70.83%     | 94.44%      |
| PositionManager.sol     | 98.30%  | 97.67%       | 91.66%     | 100.00%     |
| ProtocolTimelock.sol    | 88.88%  | 87.50%       | 83.33%     | 93.33%      |
|-------------------------|---------|--------------|------------|-------------|
| Total                   | 90.47%  | 89.44%       | 82.45%     | 97.77%      |
```

## Building and Testing

```bash
# Install dependencies
forge install

# Build
forge build

# Run tests
forge test -vv

# Run fuzz tests (256 runs)
forge test --match-contract FuzzTests -vvv

# Run fork tests (requires RPC)
forge test --match-contract ForkTests --fork-url https://bsc-dataseed1.binance.org/

# Generate coverage
forge coverage --report lcov
```

## Audit Scope

### In Scope

- All Solidity contracts in `src/` directory
- Contract interactions and state management
- Access control and privilege escalation
- Math operations and precision
- Oracle integration and manipulation resistance
- Token handling and reentrancy

### Out of Scope

- Frontend application (`frontend/`)
- Test files (`test/`)
- Deployment scripts (`script/`)
- Off-chain keeper implementations
- Third-party dependencies (OpenZeppelin, Chainlink)

## Known Issues / Trade-offs

1. **MEV Exposure**: Limit orders are visible in mempool; consider Flashbots in production
2. **Single Oracle**: Only Chainlink XAU/USD; Pyth fallback planned
3. **Gas Costs**: Complex operations like openPosition use ~387K gas

## Contact

- **Security Disclosures**: security@paimongold.io
- **General Inquiries**: info@paimongold.io
- **Bug Bounty**: Coming soon (Immunefi)

## Timeline

- **Audit Start**: TBD
- **Audit End**: TBD
- **Testnet Launch**: After audit
- **Mainnet Launch**: After testnet validation

---

*This audit package was prepared on 2025-11-28*
