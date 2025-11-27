# Paimon Gold Protocol

<div align="center">

![Paimon Gold Protocol](https://img.shields.io/badge/Paimon-Gold%20Protocol-gold?style=for-the-badge)
![Solidity](https://img.shields.io/badge/Solidity-0.8.24-blue?style=flat-square&logo=solidity)
![Next.js](https://img.shields.io/badge/Next.js-15-black?style=flat-square&logo=next.js)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

**Multi-Leverage Gold ETF DeFi Protocol on BNB Smart Chain**

[Documentation](#documentation) • [Getting Started](#getting-started) • [Architecture](#architecture) • [Security](#security)

</div>

---

## Overview

Paimon Gold Protocol enables decentralized leveraged trading on gold (XAU/USD) with up to 20x leverage. Built on BNB Smart Chain with Chainlink oracle integration for reliable price feeds.

### Key Features

- **Leveraged Trading**: 2x to 20x leverage on gold positions
- **Multi-Collateral**: Support for USDT, USDC, and BNB
- **Limit Orders**: Create limit open orders with GTC/GTD expiry
- **TP/SL Orders**: Automated take-profit and stop-loss execution
- **Liquidity Pool**: Earn fees by providing liquidity (70% to LPs)
- **Automated Liquidation**: Chainlink Keepers for timely liquidations
- **Security First**: Multi-sig governance, 48h timelock, circuit breakers

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Frontend (Next.js)                       │
├─────────────────────────────────────────────────────────────────┤
│  GoldLeverageRouter (Entry Point)    │    OrderManager          │
├─────────────────────────────────────────────────────────────────┤
│  PositionManager  │  LiquidationEngine  │  LiquidityPool        │
├─────────────────────────────────────────────────────────────────┤
│  OracleAdapter (Chainlink)  │  CollateralVault  │  InsuranceFund│
└─────────────────────────────────────────────────────────────────┘
```

### Smart Contracts

| Contract | Description |
|----------|-------------|
| `GoldLeverageRouter` | Unified entry point for all user operations |
| `PositionManager` | Position lifecycle (open/close/adjust margin) |
| `LiquidationEngine` | Health monitoring and liquidation execution |
| `OrderManager` | Limit orders and TP/SL management |
| `LiquidityPool` | LP deposits, withdrawals, fee distribution |
| `CollateralVault` | Secure collateral custody |
| `OracleAdapter` | Chainlink XAU/USD price feed integration |
| `LPToken` | ERC20 LP token (UUPS upgradeable) |
| `InsuranceFund` | Bad debt coverage |
| `ProtocolTimelock` | 48h delay for admin operations |

## Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) >= 18
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [pnpm](https://pnpm.io/) (recommended)

### Installation

```bash
# Clone the repository
git clone https://github.com/rocky2431/paimon-gold-protocol.git
cd paimon-gold-protocol

# Install Foundry dependencies
forge install

# Install frontend dependencies
cd frontend && pnpm install
```

### Build & Test

```bash
# Build smart contracts
forge build

# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test file
forge test --match-contract PositionManagerTest

# Run fuzz tests (256 runs)
forge test --match-contract FuzzTests

# Run fork tests with real BSC data
forge test --match-contract ForkTests --fork-url https://bsc-dataseed1.binance.org/

# Generate coverage report
forge coverage
```

### Run Frontend

```bash
cd frontend
pnpm dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

## Test Coverage

```
| File                    | % Lines | % Branches | % Functions |
|-------------------------|---------|------------|-------------|
| PositionManager.sol     | 98.30%  | 91.66%     | 100.00%     |
| LiquidationEngine.sol   | 100.00% | 100.00%    | 100.00%     |
| LiquidityPool.sol       | 91.66%  | 81.25%     | 100.00%     |
| OracleAdapter.sol       | 95.83%  | 90.00%     | 100.00%     |
| InsuranceFund.sol       | 100.00% | 100.00%    | 100.00%     |
|-------------------------|---------|------------|-------------|
| Total                   | 90.47%  | 82.45%     | 97.77%      |
```

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/audit/ARCHITECTURE.md) | Contract diagrams and interactions |
| [Threat Model](docs/audit/THREAT_MODEL.md) | STRIDE security analysis |
| [Slither Report](docs/audit/SLITHER_REPORT.md) | Static analysis results |
| [Audit Package](docs/audit/README.md) | Complete audit documentation |

## Security

### Features

- **Reentrancy Protection**: All state-changing functions use `nonReentrant`
- **Flash Loan Protection**: 10-block minimum hold period
- **Oracle Safety**: Staleness check (<1h) and deviation check (<5%)
- **Access Control**: Multi-sig (3/5) + 48h timelock for admin operations
- **Circuit Breaker**: Emergency pause capability

### Compliance

- **Geo-blocking**: US users blocked via IP detection
- **OFAC Compliance**: Sanctioned wallet addresses blocked
- **Disclaimer**: Users must accept terms before connecting

### Audit Status

- [x] Internal review completed
- [x] Slither static analysis passed
- [ ] External audit (pending)

## Tech Stack

### Smart Contracts

- **Language**: Solidity 0.8.24
- **Framework**: Foundry
- **Dependencies**: OpenZeppelin 5.3.0, Chainlink 1.4.0

### Frontend

- **Framework**: Next.js 15 (App Router)
- **Web3**: wagmi v2, viem
- **UI**: Tailwind CSS, shadcn/ui
- **State**: TanStack Query

### Infrastructure

- **Network**: BNB Smart Chain (BSC)
- **Oracle**: Chainlink XAU/USD
- **Indexing**: The Graph
- **CI/CD**: GitHub Actions

## Project Structure

```
paimon-gold-protocol/
├── src/                    # Smart contracts
│   ├── interfaces/         # Contract interfaces
│   └── governance/         # Timelock contracts
├── test/                   # Foundry tests
│   ├── FuzzTests.t.sol     # Fuzz testing
│   └── ForkTests.t.sol     # Fork tests with real data
├── script/                 # Deployment scripts
├── frontend/               # Next.js application
│   ├── src/
│   │   ├── app/            # Pages
│   │   ├── components/     # React components
│   │   ├── providers/      # Context providers
│   │   └── services/       # API services
├── subgraph/               # The Graph indexing
├── docs/                   # Documentation
│   └── audit/              # Audit package
└── .github/                # CI/CD workflows
```

## Roadmap

- [x] Core smart contracts
- [x] Frontend application
- [x] Unit tests (90%+ coverage)
- [x] Fuzz tests
- [x] Fork tests with real BSC data
- [x] Audit documentation
- [ ] External security audit
- [ ] BSC Testnet deployment
- [ ] Bug bounty program
- [ ] BSC Mainnet launch

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact

- **Security Issues**: security@paimongold.io
- **General Inquiries**: info@paimongold.io

---

<div align="center">

**Built with Foundry, Next.js, and wagmi**

</div>
