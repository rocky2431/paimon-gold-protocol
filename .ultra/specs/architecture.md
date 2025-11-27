# Architecture Design - Paimon Gold Protocol

> **Purpose**: This document defines HOW the system is built, based on requirements in `product.md`.

## 1. System Overview

### 1.1 Architecture Vision

**模块化可升级架构**: 采用 UUPS 代理模式的模块化智能合约设计，平衡安全性、Gas 效率和可升级性。

**核心设计原则**:
- **Security First**: 所有状态变更需审计，强制重入防护
- **Gas Efficiency**: 优化用户交易成本 (开仓 <300K Gas)
- **Composability**: 标准接口 (ERC20) 支持生态集成
- **Upgradeability**: UUPS 代理模式支持紧急修复
- **Decentralization**: 多签 + 时间锁最小化管理权限

### 1.2 Key Components

**核心合约组件**:

| 组件 | 职责 | 关键接口 |
|------|------|---------|
| **GoldLeverageRouter** | 用户交互入口点 | openPosition, closePosition |
| **PositionManager** | 仓位生命周期管理 | createPosition, updateMargin |
| **CollateralVault** | 安全抵押品托管 | deposit, withdraw |
| **OracleAdapter** | Chainlink 价格抽象 | getLatestPrice, validatePrice |
| **LiquidationEngine** | 清算执行与奖励 | liquidate, batchLiquidate |
| **LiquidityPool** | LP 流动性管理 | addLiquidity, removeLiquidity |

### 1.3 Data Flow Overview

**交易数据流**:
```
用户钱包 → GoldLeverageRouter → PositionManager → CollateralVault
                ↓                      ↓
         OracleAdapter ←──────── LiquidationEngine
                ↓
         The Graph (索引) → 前端 dApp (显示)
```

**典型流程**:
1. **Input**: 用户连接钱包 → 授权抵押品 → 选择杠杆 → 开仓
2. **Processing**: 合约验证参数 → 获取 Oracle 价格 → 创建 Position → 发出事件
3. **Storage**: Position 数据链上存储，The Graph 索引历史
4. **Output**: 前端显示仓位状态、PnL、健康因子

---

## 2. Architecture Principles

**Inherited from `.ultra/constitution.md`**:
- Specification-Driven
- Test-First Development
- Minimal Abstraction
- Anti-Future-Proofing

**DeFi-Specific Principles** (Paimon Gold Protocol):
1. **Security First**: All state changes audited, reentrancy guards mandatory
2. **Gas Efficiency**: Optimize for user transaction costs
3. **Composability**: Standard interfaces (ERC20, ERC721) for ecosystem integration
4. **Upgradeability**: Proxy pattern for critical bug fixes only
5. **Decentralization**: Minimize admin privileges, time-locks on changes

---

## 3. Technology Stack

### 3.1 Smart Contract Stack

#### 3.1.1 Blockchain Platform Selection

**Decision**: ✅ BSC (BNB Chain) - 已确认

**Rationale**:
- **Traces to**: product.md Section 1.2 - BSC 生态无专业黄金杠杆协议
- **VM Compatibility**: EVM-compatible, Solidity 完全支持
- **Performance**: ~3s 出块时间, Gas 费用 ~$0.05-0.10/tx
- **Ecosystem**: PancakeSwap 流动性, Chainlink Oracle 已部署
- **Security**: 经过实战验证的基础设施

#### 3.1.2 Technical Details

**已确定技术栈** (Round 3 - 2025-11-27):

| 组件 | 选择 | 版本 | 理由 |
|------|-----|------|------|
| **Platform** | BSC (BNB Chain) | Mainnet: 56, Testnet: 97 | 市场空白机会 |
| **Language** | Solidity | ^0.8.24 | 最新稳定版，custom errors 支持 |
| **Framework** | Foundry (主) + Hardhat (辅) | Foundry 1.0+, Hardhat 2.22+ | Fuzz 测试 + 成熟部署工具 |
| **Upgrade Pattern** | UUPS | OpenZeppelin v5.0 | Gas 效率优，用户指定 |
| **Security Libs** | OpenZeppelin Contracts | v5.0+ | AccessControl, ReentrancyGuard |
| **Oracle** | Chainlink | AggregatorV3Interface | XAU/USD 0x86896fEB19D8A607c3b11f2aF50A0f239Bd71CD0 |

**Foundry 配置** (foundry.toml):
```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "0.8.24"
optimizer = true
optimizer_runs = 200
via_ir = false
ffi = false

[profile.default.fuzz]
runs = 256
max_test_rejects = 65536

[rpc_endpoints]
bsc = "${BSC_RPC_URL}"
bsc_testnet = "https://data-seed-prebsc-1-s1.binance.org:8545/"
```

---

### 3.2 Frontend Stack

#### 3.2.1 Framework Selection

**Decision**: ✅ Next.js 14 (App Router) - 用户指定

**Rationale**:
- **Traces to**: product.md NFR - LCP < 2.5s 性能要求
- **Team Expertise**: 全栈均衡团队，Next.js 生态成熟
- **Web3 Integration**: wagmi v2 + viem 原生支持，类型安全
- **Performance**: SSR/SSG 优化首屏加载，满足 Core Web Vitals

#### 3.2.2 Technical Details

**已确定技术栈** (Round 3 - 2025-11-27):

| 组件 | 选择 | 版本 | 理由 |
|------|-----|------|------|
| **Framework** | Next.js (App Router) | 14.2+ | SSR/ISR，用户指定 |
| **Language** | TypeScript | 5.3+ | 类型安全，合约类型生成 |
| **Web3** | wagmi + viem | wagmi v2, viem v2 | React hooks，类型推断 |
| **State** | TanStack Query + Zustand | v5 + v4 | 服务端/客户端状态分离 |
| **Styling** | Tailwind CSS + shadcn/ui | v3.4+ | 可定制，设计系统基础 |
| **Charts** | Lightweight Charts | v4+ | TradingView 开源，金融级 |
| **Testing** | Vitest + Playwright | Latest | 单元 + E2E 覆盖 |

**wagmi 配置** (lib/wagmi.ts):
```typescript
import { createConfig, http } from 'wagmi'
import { bsc, bscTestnet } from 'wagmi/chains'
import { injected, walletConnect } from 'wagmi/connectors'

export const config = createConfig({
  chains: [bsc, bscTestnet],
  connectors: [
    injected(),
    walletConnect({ projectId: process.env.NEXT_PUBLIC_WC_PROJECT_ID! }),
  ],
  transports: {
    [bsc.id]: http(process.env.NEXT_PUBLIC_BSC_RPC_URL),
    [bscTestnet.id]: http('https://data-seed-prebsc-1-s1.binance.org:8545/'),
  },
})
```

---

### 3.3 Backend Stack (Indexing/Automation)

#### 3.3.1 Indexing Solution Selection

**Decision**: ✅ The Graph (Subgraph) - 链上事件索引

**Rationale**:
- **Traces to**: product.md - 仓位查询、历史交易记录需求
- **BSC Support**: The Graph 原生支持 BSC
- **Decentralization**: 去中心化索引，无单点故障
- **GraphQL**: 灵活查询，前端友好

#### 3.3.2 Technical Details

**已确定技术栈** (Round 3 - 2025-11-27):

| 组件 | 选择 | 用途 |
|------|-----|------|
| **链上索引** | The Graph (Subgraph) | 事件索引、仓位查询 |
| **自动化** | Chainlink Automation | Keeper 任务 (清算、限价单) |
| **价格缓存** | Redis | 减少 RPC 调用，价格数据缓存 |
| **备用索引** | Envio (可选) | 高性能备选方案 |

**Subgraph Schema** (schema.graphql):
```graphql
type Position @entity {
  id: ID!
  owner: Bytes!
  collateral: BigInt!
  leverage: Int!
  entryPrice: BigInt!
  size: BigInt!
  isLong: Boolean!
  openTimestamp: BigInt!
  status: Int!
  pnl: BigInt
  closeTimestamp: BigInt
}

type Trade @entity {
  id: ID!
  position: Position!
  trader: Bytes!
  type: String!  # "open" | "close" | "liquidate"
  price: BigInt!
  timestamp: BigInt!
  txHash: Bytes!
}
```

---

### 3.4 Database Stack

#### 3.4.1 Database Selection

**Decision**: ✅ On-chain Primary + The Graph Indexing + Redis Cache

**DeFi 数据架构**:
- **Primary Data**: 链上存储 (Position, Order 数据)
- **Indexing Data**: The Graph Subgraph (查询优化)
- **Cache**: Redis (价格数据缓存，减少 RPC 调用)

#### 3.4.2 Technical Details

**数据分层** (Round 3 - 2025-11-27):

| 层级 | 存储 | 数据类型 | 访问模式 |
|------|-----|---------|---------|
| **L1 链上** | BSC 状态存储 | Position, Order, LP | 写入 via 合约 |
| **L2 索引** | The Graph | 历史交易、聚合数据 | GraphQL 查询 |
| **L3 缓存** | Redis | 当前价格、热点数据 | Key-Value 读取 |

---

### 3.5 Infrastructure Stack

#### 3.5.1 Deployment Platform Selection

**Decision**: ✅ Vercel (前端) + BSC (合约) + The Graph (索引)

**基础设施架构**:
- **Smart Contracts**: BSC Mainnet via Foundry/Hardhat Deploy
- **Frontend**: Vercel (CDN, Edge Functions)
- **Indexing**: The Graph Hosted/Decentralized Network
- **RPC Provider**: Ankr (主) + QuickNode (备)

#### 3.5.2 Technical Details

**已确定基础设施** (Round 3 - 2025-11-27):

| 组件 | 选择 | 理由 |
|------|-----|------|
| **前端托管** | Vercel | Next.js 原生支持，全球 CDN |
| **RPC 主节点** | Ankr | 免费额度充足，BSC 专业支持 |
| **RPC 备节点** | QuickNode | 付费可靠，低延迟 |
| **合约验证** | BSCScan | 官方标准 |
| **CI/CD** | GitHub Actions | 自动测试部署 |
| **合约监控** | Tenderly | 事务追踪、告警 |
| **前端监控** | Sentry | 错误追踪、性能 |
| **Keeper** | Chainlink Automation | 自动清算、订单执行 |

**GitHub Actions 工作流** (.github/workflows/ci.yml):
```yaml
name: CI/CD Pipeline
on: [push, pull_request]
jobs:
  contracts:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: foundry-rs/foundry-toolchain@v1
      - run: forge build
      - run: forge test -vvv
      - run: forge coverage --report lcov

  frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v2
      - run: pnpm install
      - run: pnpm lint && pnpm typecheck
      - run: pnpm test
```

## 4. Smart Contract Architecture

### 4.1 Contract Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      User Wallet                             │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                   GoldLeverageRouter                         │
│  (Entry point - handles user interactions)                   │
└─────────────────────┬───────────────────────────────────────┘
                      │
          ┌───────────┼───────────┬───────────┐
          ▼           ▼           ▼           ▼
┌─────────────┐ ┌───────────┐ ┌─────────┐ ┌───────────┐
│PositionMgr │ │ Collateral│ │ Oracle  │ │Liquidation│
│             │ │   Vault   │ │ Adapter │ │  Engine   │
│ - openPos() │ │           │ │         │ │           │
│ - closePos()│ │ - deposit │ │ - getXAU│ │ - liquidate│
│ - addMargin │ │ - withdraw│ │   Price │ │ - calcBonus│
└──────┬──────┘ └─────┬─────┘ └────┬────┘ └─────┬─────┘
       │              │            │            │
       └──────────────┴────────────┴────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                    Storage Contract                          │
│  (Proxy-compatible, holds all state)                        │
└─────────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                    Chainlink Oracle                          │
│  (XAU/USD Price Feed)                                       │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Contract Details

#### Contract 1: GoldLeverageRouter
- **Responsibility**: Entry point for all user operations
- **Technology**: Solidity, UUPS Proxy
- **Interfaces**: IPositionManager, ICollateralVault
- **Dependencies**: PositionManager, CollateralVault
- **Trace to**: [product.md - Position Management Epic]

#### Contract 2: PositionManager
- **Responsibility**: Core leverage position logic
- **Technology**: Solidity, AccessControl
- **Interfaces**: IPositionManager
- **Dependencies**: OracleAdapter, CollateralVault
- **Trace to**: [product.md - Core Capabilities]

#### Contract 3: CollateralVault
- **Responsibility**: Secure collateral custody
- **Technology**: Solidity, ReentrancyGuard
- **Interfaces**: ICollateralVault, IERC20
- **Dependencies**: None (isolated)
- **Trace to**: [product.md - Security Requirements]

#### Contract 4: OracleAdapter
- **Responsibility**: Price feed abstraction
- **Technology**: Solidity, Chainlink AggregatorV3Interface
- **Interfaces**: IOracleAdapter
- **Dependencies**: Chainlink XAU/USD feed
- **Trace to**: [product.md - Oracle Integration]

#### Contract 5: LiquidationEngine
- **Responsibility**: Handle undercollateralized positions
- **Technology**: Solidity, keeper-compatible
- **Interfaces**: ILiquidationEngine
- **Dependencies**: PositionManager, OracleAdapter
- **Trace to**: [product.md - Liquidation System]

### 4.3 Position Data Model

```solidity
struct Position {
    uint256 id;              // Unique position identifier
    address owner;           // Position owner
    uint256 collateral;      // Collateral amount (in collateral token decimals)
    uint256 leverage;        // Leverage multiplier (e.g., 3 = 3x)
    uint256 entryPrice;      // XAU/USD price at position open (8 decimals)
    uint256 size;            // Position size (collateral * leverage)
    bool isLong;             // true = long, false = short
    uint256 openTimestamp;   // Block timestamp when opened
    uint8 status;            // 0=Open, 1=Closed, 2=Liquidated
}
```

**Trace to**: [product.md#functional-requirement-001]

## 5. Frontend Architecture

### 5.1 Component Structure

```
src/
├── app/                     # Next.js App Router
│   ├── layout.tsx          # Root layout with providers
│   ├── page.tsx            # Home/dashboard
│   ├── trade/              # Trading interface
│   │   └── page.tsx
│   └── portfolio/          # User positions
│       └── page.tsx
├── components/
│   ├── ui/                 # shadcn/ui components
│   ├── trade/              # Trading-specific components
│   │   ├── LeverageSlider.tsx
│   │   ├── PositionForm.tsx
│   │   └── PriceChart.tsx
│   └── portfolio/          # Portfolio components
│       ├── PositionCard.tsx
│       └── PositionTable.tsx
├── hooks/
│   ├── usePosition.ts      # Position management hooks
│   ├── useGoldPrice.ts     # Oracle price hook
│   └── useWallet.ts        # Wallet connection
├── lib/
│   ├── contracts/          # Contract ABIs and addresses
│   ├── wagmi.ts            # wagmi configuration
│   └── utils.ts            # Utility functions
└── stores/
    └── useTradeStore.ts    # Trade form state (Zustand)
```

### 5.2 Web3 Integration

**wagmi + viem configuration**:
- Chain: BSC Mainnet + BSC Testnet
- Connectors: MetaMask, WalletConnect, Coinbase Wallet
- Contract reads: useReadContract hooks
- Contract writes: useWriteContract with transaction tracking

## 6. Security Architecture

### 6.1 Smart Contract Security

**Mandatory security patterns**:
- **ReentrancyGuard**: All external calls protected
- **AccessControl**: Role-based permissions (ADMIN, KEEPER, PAUSER)
- **Pausable**: Emergency stop functionality
- **SafeERC20**: Safe token transfers

**Oracle security**:
- Price staleness check (max 1 hour old)
- Price deviation check (max 10% change between updates)
- Fallback oracle (if primary fails)

### 6.2 Access Control Roles

```solidity
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
```

- **ADMIN**: Update parameters, upgrade contracts
- **KEEPER**: Execute liquidations
- **PAUSER**: Emergency pause protocol

### 6.3 Audit Requirements

- **Pre-launch**: Full audit by reputable firm (Certik, Trail of Bits, etc.)
- **Bug Bounty**: Immunefi program post-launch
- **Formal Verification**: Critical math functions

## 7. Testing Strategy

### 7.1 Test Pyramid

```
       /\
      /E2E\        - 10%  (Playwright - 完整用户流程)
     /------\
    /Integra\      - 30%  (Foundry Fork - BSC 主网仿真)
   /----------\
  /Unit+Fuzz  \    - 60%  (Foundry - 合约逻辑 + 模糊测试)
 /--------------\
```

### 7.2 Smart Contract Testing (Foundry)

**已确定测试策略** (Round 3 - 2025-11-27):

| 测试类型 | 工具 | 覆盖范围 | 命令 |
|---------|-----|---------|------|
| **Unit Tests** | forge test | 单函数逻辑 | `forge test --match-test test_` |
| **Fuzz Tests** | forge test --fuzz | 边界条件、溢出 | `forge test --match-test testFuzz_` |
| **Fork Tests** | forge test --fork-url | 真实 Oracle 数据 | `forge test --fork-url $BSC_RPC` |
| **Gas Reports** | forge test --gas-report | Gas 优化验证 | `forge test --gas-report` |
| **Coverage** | forge coverage | 覆盖率报告 | `forge coverage --report lcov` |

**Foundry 测试示例**:
```solidity
// test/PositionManager.t.sol
contract PositionManagerTest is Test {
    function setUp() public { /* ... */ }

    function test_OpenLongPosition() public {
        // Unit test - 正常开多仓
    }

    function testFuzz_LeverageRange(uint8 leverage) public {
        // Fuzz test - 杠杆范围 2-50
        leverage = uint8(bound(leverage, 2, 50));
    }

    function testFork_RealOraclePrice() public {
        // Fork test - 真实 XAU/USD 价格
    }
}
```

### 7.3 Test Coverage Targets

See `.ultra/config.json` for all coverage targets:
- Overall coverage: ≥80%
- Critical paths (liquidation, position management): 100%
- Branch coverage: ≥75%
- Function coverage: ≥85%

## 8. Deployment Architecture

### 8.1 Environments

- **Local**: Hardhat network for development
- **Testnet**: BSC Testnet (ChainID: 97)
- **Production**: BSC Mainnet (ChainID: 56)

### 8.2 Deployment Pipeline

1. Code push → GitHub
2. Run tests (unit + fork tests)
3. Static analysis (Slither, Mythril)
4. Deploy to testnet (auto)
5. Integration testing on testnet
6. Manual approval for mainnet
7. Deploy to mainnet with time-lock
8. Verify on BSCScan

### 8.3 Upgrade Strategy

- **Proxy Pattern**: UUPS (gas efficient)
- **Time-lock**: 48-hour delay on upgrades
- **Multi-sig**: 3/5 multi-sig for admin operations

## 9. Monitoring & Observability

### 9.1 On-chain Monitoring

- **Tenderly**: Real-time alerts for contract events
- **Defender**: Automated keeper operations
- **Custom Dashboard**: TVL, position count, liquidation health

### 9.2 Frontend Monitoring

- **Sentry**: Error tracking
- **Vercel Analytics**: Performance metrics
- **Custom Events**: User interaction tracking

## 10. Open Questions

### 10.1 Technical Uncertainties

**已解决问题** (Round 3 - 2025-11-27):

1. ✅ **Upgrade Pattern**: UUPS (用户指定，Gas 效率优)
2. ✅ **Oracle Strategy**: Chainlink only (BSC 已有 XAU/USD)
3. ✅ **多抵押品 MVP**: 支持 (USDT, USDC, BUSD, BNB, 主流代币)

**待解决问题** (Round 4 风险评估):

1. **Question**: Position 是否需要 NFT 化 (ERC-721)?
   - **Impacts**: 可组合性、二级市场、Gas 成本
   - **建议**: MVP 使用内部 mapping，V2 考虑 NFT 化
   - **Deadline**: 智能合约开发前

2. **Question**: 清算奖励百分比具体数值?
   - **Impacts**: 清算者激励、用户损失
   - **建议**: 5-10% (参考 GMX 5%, GNS 5-12%)
   - **Deadline**: 参数定稿前

3. **Question**: 价格偏差保护阈值?
   - **Impacts**: Oracle 操纵防护
   - **建议**: 单次最大 10%, 累计最大 20%/小时
   - **Deadline**: 合约开发时确定

### 10.2 Alternative Approaches - Decisions Made

| 问题 | 选项 | 决定 | 理由 |
|------|-----|------|------|
| **Oracle** | Chainlink only / +Pyth | Chainlink only | BSC 已验证，简化复杂度 |
| **Upgrade** | UUPS / Transparent / Diamond | UUPS | 用户指定，Gas 优 |
| **Position** | Mapping / NFT | Mapping (MVP) | 简化开发，V2 可扩展 |
| **Framework** | Foundry / Hardhat / 混合 | Foundry 主 + Hardhat 辅 | 用户偏好，性能优 |

---

**Document Status**: Round 3 完成
**Last Updated**: 2025-11-27
**Reviewed By**: [待用户确认]
