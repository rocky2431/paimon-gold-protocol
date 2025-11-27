# Technology Selection Report - Paimon Gold Protocol

**Date**: 2025-11-27
**Round**: 3 - Technology Selection
**Status**: Completed

## Executive Summary

基于用户输入（Foundry 优先、UUPS、Next.js、全栈均衡团队），完成了完整技术栈选型。采用 Foundry 主导的智能合约开发，Next.js 14 前端，The Graph 索引方案。

## User Input Summary

### Technology Preferences
- **合约框架**: Foundry 优先
- **团队技能**: 全栈均衡
- **性能重点**: 均衡型 (Gas + Frontend)
- **升级模式**: UUPS
- **前端框架**: Next.js

## Technology Stack Decisions

### 1. Smart Contract Stack (P0)

| Component | Choice | Version | Rationale |
|-----------|--------|---------|-----------|
| Platform | BSC (BNB Chain) | Mainnet: 56 | Market gap opportunity |
| Language | Solidity | ^0.8.24 | Latest stable, custom errors |
| Framework | Foundry (primary) | 1.0+ | Native fuzz, fast tests |
| Upgrade | UUPS | OZ v5 | User specified, gas efficient |
| Oracle | Chainlink | AggregatorV3 | XAU/USD available on BSC |

### 2. Frontend Stack (P0)

| Component | Choice | Version | Rationale |
|-----------|--------|---------|-----------|
| Framework | Next.js (App Router) | 14.2+ | User specified, SSR/SSG |
| Language | TypeScript | 5.3+ | Type safety |
| Web3 | wagmi + viem | v2 | React hooks, type inference |
| State | TanStack Query + Zustand | v5 + v4 | Server/client state separation |
| UI | shadcn/ui + Tailwind | v3.4+ | Customizable, design system |
| Charts | Lightweight Charts | v4+ | TradingView open source |

### 3. Backend/Indexing Stack (P1)

| Component | Choice | Purpose |
|-----------|--------|---------|
| Indexing | The Graph (Subgraph) | Event indexing, position queries |
| Automation | Chainlink Automation | Keeper tasks (liquidation, orders) |
| Cache | Redis | Price data caching |

### 4. Infrastructure Stack

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Frontend Hosting | Vercel | Next.js native, global CDN |
| RPC Primary | Ankr | Free tier, BSC support |
| RPC Fallback | QuickNode | Paid reliable, low latency |
| CI/CD | GitHub Actions | Automated test/deploy |
| Contract Monitoring | Tenderly | Transaction tracing, alerts |
| Frontend Monitoring | Sentry | Error tracking |

### 5. Testing Stack

| Test Type | Tool | Coverage |
|-----------|------|----------|
| Unit Tests | forge test | 60% - contract logic |
| Fuzz Tests | forge test --fuzz | Boundary conditions |
| Fork Tests | forge --fork-url | Real oracle data |
| Frontend | Vitest + Playwright | UI + E2E |

## Key Decisions Made

| Question | Options | Decision | Rationale |
|----------|---------|----------|-----------|
| Oracle | Chainlink / +Pyth | Chainlink only | BSC verified, simplify |
| Upgrade | UUPS / Transparent / Diamond | UUPS | User specified, gas efficient |
| Position | Mapping / NFT | Mapping (MVP) | Simplify dev, V2 extensible |
| Framework | Foundry / Hardhat / Hybrid | Foundry primary | User preference, performance |

## Output

- ✅ Updated `specs/architecture.md` Section 3: Technology Stack
- ✅ Updated `specs/architecture.md` Section 7: Testing Strategy
- ✅ Updated `specs/architecture.md` Section 10: Open Questions
- ✅ Updated `config.json` techStackDecisions

## Next Steps

1. Round 4: Risk Assessment - 详细风险分析与缓解策略

---

**Validation**: User satisfied with technology selection
**Iteration Count**: 0
**Rating**: 满意 (Satisfied)
