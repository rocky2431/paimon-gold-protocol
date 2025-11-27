# Product Specification - Paimon Gold Protocol

> **Source of Truth**: This document defines WHAT the system does and WHY. Technology choices belong in `architecture.md`.

## 1. Problem Statement

### 1.1 Core Problem

DeFi 用户缺乏在 BSC 上获得高效、透明、低成本杠杆黄金敞口的途径。

**根本原因**:
- 传统黄金 ETF (GLD, IAU) 费用高昂 (管理费 0.4%+)、门槛高、无法 24/7 交易
- 现有 DeFi 黄金协议 (Synthetix sXAU, GMX XAU) 未部署在 BSC，用户需跨链
- BSC 生态缺乏专业的黄金衍生品协议，市场空白明显

**问题不解决的后果**:
- BSC 用户流失到 Arbitrum/Optimism 使用 GMX/Synthetix
- 错失 BSC 低费用、高用户基数的市场机会
- 亚洲用户无法便捷获得链上黄金敞口

### 1.2 Current Pain Points

1. **缺乏链上黄金敞口**: BSC 上无专业黄金杠杆协议，用户需跨链或使用 CEX
2. **杠杆倍数不足**: 现有产品资金效率低，杠杆选择有限
3. **费用高昂**: 传统黄金 ETF 管理费 + 交易费累计可达 1%+
4. **透明度低**: 传统产品无法验证实际黄金储备，信任成本高
5. **可组合性差**: 传统黄金产品无法与 DeFi 协议组合使用

### 1.3 How Users Currently Solve This

**现有替代方案及其不足**:

| 替代方案 | 优点 | 缺点 |
|---------|------|------|
| **传统黄金 ETF (GLD/IAU)** | 监管合规、流动性好 | 费用高、交易时间限制、无杠杆 |
| **Synthetix sXAU** | 零滑点、链上透明 | 高抵押率 (400%+)、仅在 Optimism |
| **GMX XAU** | 真实收益、低费用 | 仅在 Arbitrum、BSC 用户需跨链 |
| **CEX 黄金合约** | 高杠杆、流动性好 | 中心化风险、KYC 要求、资金托管 |
| **PAXG 代币** | 1:1 黄金锚定 | 无杠杆、仅现货敞口 |

**市场空白**: BSC 上无原生、专业、支持杠杆的黄金交易协议

---

## 2. Users & Stakeholders

### 2.1 Primary User Segments

| 用户群体 | 描述 | 规模估计 | 优先级 |
|---------|------|---------|--------|
| **DeFi 零售交易者** | 个人用户，寻求杠杆黄金敞口，资金 $100-$10K | 大 (BSC 活跃用户 500K+) | P0 |
| **机构/大户** | 专业交易员、对冲基金、财库管理，资金 $10K-$1M | 中 | P0 |
| **流动性提供者 (LP)** | 做市商、收益农民，寻求真实收益 | 中 | P0 |
| **套利者** | 寻求 Oracle/DEX 价差机会 | 小 | P1 |

### 2.2 User Characteristics

**零售交易者**:
- **地域**: 东南亚、华语区为主 (BSC 用户分布)
- **技术水平**: 中等 (熟悉 DeFi 基本操作，理解杠杆风险)
- **钱包偏好**: MetaMask (60%), Trust Wallet (30%), 其他 (10%)
- **风险偏好**: 高 (愿意承担杠杆风险换取高收益)
- **典型仓位**: $500 - $5,000
- **交易频率**: 每周 2-5 次

**机构/大户**:
- **技术水平**: 高 (理解清算机制、资金费率、Oracle 机制)
- **钱包偏好**: 硬件钱包、多签钱包
- **风险偏好**: 中高 (有风控体系)
- **典型仓位**: $10,000 - $500,000
- **需求特点**: 低滑点、高流动性、API 接入

**流动性提供者**:
- **目标**: 获取协议费用分成 + 代币激励
- **风险考量**: LP 作为对手方承担部分方向性风险
- **典型资金**: $10,000 - $1,000,000

### 2.3 Secondary Stakeholders

| 利益相关者 | 角色 | 重要性 |
|-----------|------|--------|
| **清算人 (Liquidators)** | 执行清算、维护协议健康 | 关键 (协议安全) |
| **治理代币持有者** | 参与协议决策、参数调整 | 重要 (长期发展) |
| **Oracle 提供商 (Chainlink)** | 提供 XAU/USD 价格源 | 关键 (核心依赖) |
| **审计公司** | 安全审计、代码审查 | 关键 (上线前) |
| **做市商合作方** | 提供初始流动性 | 重要 (冷启动) |

## 3. User Stories

### 3.1 MVP Feature Scope

**MVP 功能范围**: 完整交易系统

| 类别 | Must-Have (P0) | Nice-to-Have (P1) |
|------|---------------|-------------------|
| **交易** | 开/平仓、双向多空、调整保证金 | 限价单、止盈止损 |
| **清算** | 自动清算机制 | 清算预警通知 |
| **流动性** | LP 存取、收益分配 | 激励计划 |
| **Oracle** | Chainlink XAU/USD | 备用价格源 |
| **管理** | 基础参数配置 | 时间锁、多签 |

**杠杆范围**: 2x - 50x (激进型)
**抵押品**: USDT, USDC, BUSD, BNB, 主流代币

### 3.2 Epic Breakdown

---

#### Epic 1: 仓位管理 (Position Management) - P0

**US-1.1: 开仓 (Open Position)**

**As a** 交易者
**I want to** 使用抵押品开立杠杆黄金仓位
**So that** 我可以获得放大的黄金价格敞口

**验收标准**:
- [ ] 支持选择杠杆倍数 (2x, 5x, 10x, 20x, 50x)
- [ ] 支持选择方向 (多头/空头)
- [ ] 支持多种抵押品 (USDT, USDC, BUSD, BNB)
- [ ] 显示预估开仓价格、手续费、清算价格
- [ ] 开仓后生成唯一仓位 ID
- [ ] 发出 PositionOpened 事件

**优先级**: P0

---

**US-1.2: 平仓 (Close Position)**

**As a** 交易者
**I want to** 关闭我的杠杆仓位
**So that** 我可以实现盈利或止损

**验收标准**:
- [ ] 支持全部平仓
- [ ] 支持部分平仓 (按百分比或金额)
- [ ] 自动计算 PnL (考虑资金费率)
- [ ] 抵押品自动返还到用户钱包
- [ ] 发出 PositionClosed 事件

**优先级**: P0

---

**US-1.3: 调整保证金 (Adjust Margin)**

**As a** 交易者
**I want to** 增加或减少仓位保证金
**So that** 我可以调整清算风险

**验收标准**:
- [ ] 支持追加保证金 (降低清算风险)
- [ ] 支持提取多余保证金 (提高资金效率)
- [ ] 实时更新健康因子和清算价格
- [ ] 提取时检查最低保证金要求

**优先级**: P0

---

#### Epic 2: 清算系统 (Liquidation System) - P0

**US-2.1: 自动清算 (Auto Liquidation)**

**As a** 清算人 (Keeper)
**I want to** 清算不健康的仓位
**So that** 我可以获得清算奖励，同时维护协议健康

**验收标准**:
- [ ] 当健康因子 < 1.0 时仓位可被清算
- [ ] 清算人获得 5-10% 清算奖励
- [ ] 剩余抵押品返还给仓位所有者
- [ ] 支持批量清算 (Gas 优化)
- [ ] 发出 PositionLiquidated 事件

**优先级**: P0

---

**US-2.2: 清算价格预警 (Liquidation Alert)**

**As a** 交易者
**I want to** 在接近清算价格时收到预警
**So that** 我可以及时追加保证金或平仓

**验收标准**:
- [ ] 健康因子 < 1.5 时显示黄色警告
- [ ] 健康因子 < 1.2 时显示红色警告
- [ ] 前端实时更新清算价格

**优先级**: P1

---

#### Epic 3: 流动性池 (Liquidity Pool) - P0

**US-3.1: 提供流动性 (Provide Liquidity)**

**As a** LP
**I want to** 向协议提供流动性
**So that** 我可以赚取交易费用分成

**验收标准**:
- [ ] 支持单币种存入 (USDT, USDC, BNB)
- [ ] 铸造 LP 代币作为凭证
- [ ] 显示预估 APY
- [ ] 支持随时查看份额价值

**优先级**: P0

---

**US-3.2: 提取流动性 (Withdraw Liquidity)**

**As a** LP
**I want to** 提取我的流动性和收益
**So that** 我可以退出或重新配置资金

**验收标准**:
- [ ] 销毁 LP 代币换取底层资产
- [ ] 包含累计收益
- [ ] 支持部分提取
- [ ] 冷却期机制 (可选)

**优先级**: P0

---

#### Epic 4: 订单系统 (Order System) - P1

**US-4.1: 限价开仓 (Limit Open Order)**

**As a** 交易者
**I want to** 设置限价开仓订单
**So that** 我可以在目标价格自动开仓

**验收标准**:
- [ ] 设置触发价格
- [ ] 设置仓位参数 (杠杆、方向、数量)
- [ ] 订单到期时间 (GTC/GTD)
- [ ] Keeper 自动执行

**优先级**: P1

---

**US-4.2: 止盈止损 (TP/SL Orders)**

**As a** 交易者
**I want to** 为仓位设置止盈止损
**So that** 自动管理风险和锁定利润

**验收标准**:
- [ ] 设置止盈价格 (Take Profit)
- [ ] 设置止损价格 (Stop Loss)
- [ ] 触发后自动平仓
- [ ] 支持修改和取消

**优先级**: P1

---

#### Epic 5: Oracle 集成 (Oracle Integration) - P0

**US-5.1: 价格获取 (Price Feed)**

**As a** 协议
**I want to** 获取准确的 XAU/USD 价格
**So that** 可以正确计算仓位价值和 PnL

**验收标准**:
- [ ] 集成 Chainlink XAU/USD 价格源 (0x86896fEB19D8A607c3b11f2aF50A0f239Bd71CD0)
- [ ] 价格新鲜度检查 (< 1 小时)
- [ ] 价格偏差检查 (< 5% 单次变动)
- [ ] 电路断路器 (异常时暂停)

**优先级**: P0

---

#### Epic 6: 协议管理 (Protocol Management) - P1

**US-6.1: 参数配置 (Parameter Config)**

**As a** 协议管理员
**I want to** 调整协议参数
**So that** 可以响应市场变化和优化协议

**验收标准**:
- [ ] 调整费用参数 (开仓费 0.05%、资金费率)
- [ ] 调整风控参数 (最大杠杆 50x、最大持仓)
- [ ] 调整清算参数 (清算阈值、奖励 5-10%)
- [ ] 时间锁机制 (关键参数 48h 延迟)

**优先级**: P1

---

### 3.3 Key User Scenarios

**6 个主要用户场景**:

| # | 场景 | 用户 | 流程 | 预期结果 |
|---|------|------|------|---------|
| 1 | **开多仓** | 交易者 | 连接钱包 → 存入 USDT → 选择 10x 杠杆 → 开多 | 仓位创建，显示 PnL |
| 2 | **平仓获利** | 交易者 | 查看仓位 → 点击平仓 → 确认 | 收到抵押品 + 盈利 |
| 3 | **被清算** | 交易者 | 价格下跌 → 健康因子<1 → Keeper 清算 | 收到剩余抵押品 |
| 4 | **提供流动性** | LP | 存入 USDT → 获得 LP 代币 → 持有 | 累计交易费收益 |
| 5 | **执行清算** | Keeper | 监控仓位 → 发现不健康 → 调用清算 | 获得 5-10% 奖励 |
| 6 | **限价开仓** | 交易者 | 设置目标价 → 提交订单 → 等待 | 价格触发后自动开仓 |

---

## 4. Functional Requirements

### 4.1 Core Capabilities

#### FR-1: 交易功能

| ID | 功能 | 描述 | 输入 | 输出 | 业务规则 |
|----|------|------|------|------|---------|
| FR-1.1 | **开仓** | 创建杠杆黄金仓位 | 抵押品数量、杠杆倍数、方向 | 仓位 ID、开仓价格 | 杠杆 2-50x，最小仓位 $10 |
| FR-1.2 | **平仓** | 关闭仓位并结算 PnL | 仓位 ID、平仓比例 | 结算金额、PnL | 扣除资金费率 |
| FR-1.3 | **调整保证金** | 追加/提取保证金 | 仓位 ID、金额 | 新健康因子 | 提取后健康因子 > 1.5 |
| FR-1.4 | **限价单** | 设置触发价格订单 | 触发价、仓位参数 | 订单 ID | GTC/GTD 到期策略 |
| FR-1.5 | **止盈止损** | 自动平仓订单 | 仓位 ID、TP/SL 价格 | 订单 ID | 绑定仓位生命周期 |

#### FR-2: 流动性功能

| ID | 功能 | 描述 | 输入 | 输出 | 业务规则 |
|----|------|------|------|------|---------|
| FR-2.1 | **存入流动性** | LP 提供资金 | 代币类型、数量 | LP 代币数量 | 支持 USDT/USDC/BNB |
| FR-2.2 | **提取流动性** | LP 取回资金 | LP 代币数量 | 底层资产 + 收益 | 可选冷却期 |
| FR-2.3 | **收益分配** | 协议费用分成 | - | LP 收益更新 | 70% LP / 30% 协议 |

#### FR-3: 清算功能

| ID | 功能 | 描述 | 输入 | 输出 | 业务规则 |
|----|------|------|------|------|---------|
| FR-3.1 | **健康因子计算** | 实时计算仓位健康度 | 仓位 ID | 健康因子 | = 抵押品价值 / 债务价值 |
| FR-3.2 | **自动清算** | Keeper 执行清算 | 仓位 ID | 清算奖励 | 健康因子 < 1.0 触发 |
| FR-3.3 | **保险基金** | 处理坏账 | - | 坏账覆盖 | 协议收入 10% 注入 |

#### FR-4: Oracle 功能

| ID | 功能 | 描述 | 输入 | 输出 | 业务规则 |
|----|------|------|------|------|---------|
| FR-4.1 | **价格获取** | 获取 XAU/USD 价格 | - | 价格 (8 位小数) | Chainlink 0.2% 偏差 |
| FR-4.2 | **价格验证** | 检查价格有效性 | 价格、时间戳 | 有效/无效 | < 1 小时，< 5% 偏差 |
| FR-4.3 | **电路断路器** | 异常时暂停 | 价格异常触发 | 协议暂停 | 管理员可恢复 |

### 4.2 Data Operations

**链上数据结构**:

```solidity
struct Position {
    uint256 id;              // 仓位 ID
    address owner;           // 所有者地址
    uint256 collateral;      // 抵押品数量 (18 decimals)
    uint256 leverage;        // 杠杆倍数 (2-50)
    uint256 entryPrice;      // 开仓价格 (8 decimals)
    uint256 size;            // 仓位规模 = collateral * leverage
    bool isLong;             // true = 多头, false = 空头
    uint256 openTimestamp;   // 开仓时间
    uint8 status;            // 0=Open, 1=Closed, 2=Liquidated
}
```

**数据操作**:
- **Create**: 开仓创建新 Position
- **Read**: 查询用户仓位列表、单个仓位详情
- **Update**: 调整保证金、设置 TP/SL
- **Delete**: 平仓/清算后标记为已关闭

### 4.3 Integration Requirements

| 集成方 | 用途 | 接口类型 | 优先级 |
|--------|------|---------|--------|
| **Chainlink** | XAU/USD 价格源 | AggregatorV3Interface | P0 |
| **PancakeSwap** | 抵押品兑换 | IUniswapV2Router | P1 |
| **The Graph** | 数据索引 | GraphQL | P1 |
| **Chainlink Automation** | 自动清算/限价单 | KeeperCompatible | P1 |
| **BSC RPC** | 区块链交互 | JSON-RPC | P0 |

---

## 5. Non-Functional Requirements

**NFR 优先级**: 平衡型 (安全、性能、扩展同等重要)

### 5.1 Performance Requirements

#### 智能合约性能

| 指标 | 目标 | 测量方式 |
|------|------|---------|
| **开仓 Gas** | < 300,000 | Hardhat gas report |
| **平仓 Gas** | < 200,000 | Hardhat gas report |
| **清算 Gas** | < 250,000 | Hardhat gas report |
| **LP 存取 Gas** | < 150,000 | Hardhat gas report |
| **交易确认** | < 3 秒 | BSC 出块时间 |

#### 前端性能 (Core Web Vitals)

| 指标 | 目标 | 说明 |
|------|------|------|
| **LCP** | < 2.5s | 最大内容绘制 |
| **INP** | < 200ms | 交互到下一帧 |
| **CLS** | < 0.1 | 累计布局偏移 |
| **首屏加载** | < 3s | 3G 网络 |

### 5.2 Security Requirements

#### 智能合约安全

| 要求 | 目标 | 实现方式 |
|------|------|---------|
| **重入攻击防护** | 100% 覆盖 | OpenZeppelin ReentrancyGuard |
| **访问控制** | 角色分离 | AccessControl (ADMIN, KEEPER, PAUSER) |
| **Oracle 安全** | 防操纵 | 价格检查 + TWAP + 电路断路器 |
| **闪电贷防护** | 多区块结算 | 开仓/提取延迟或 commit-reveal |
| **整数溢出** | 防止 | Solidity 0.8+ 内置检查 |

#### 审计要求

| 阶段 | 要求 | 时间点 |
|------|------|--------|
| **代码审计** | 至少 1 家知名审计公司 | Mainnet 上线前 |
| **Bug Bounty** | Immunefi 计划 | Mainnet 上线后 |
| **形式验证** | 关键数学函数 | 可选 |

### 5.3 Scalability Requirements

| 指标 | 目标 | 说明 |
|------|------|------|
| **TVL 目标** | $10M - $100M | Phase 1-3 |
| **最大仓位数** | 10,000+ | 高效存储结构 |
| **多资产预留** | 接口设计 | 资产注册表模式 |
| **多链兼容** | 架构预留 | 链无关合约设计 |
| **批量操作** | 支持 | 清算批量优化 |

### 5.4 Reliability Requirements

| 要求 | 目标 | 实现方式 |
|------|------|---------|
| **Oracle 容错** | 主备切换 | Chainlink + 备用源 |
| **紧急暂停** | < 1 分钟 | Pausable 合约 |
| **升级能力** | 安全升级 | UUPS 代理模式 |
| **数据完整性** | 100% | 事件日志 + 索引 |
| **恢复机制** | 支持 | 紧急提取功能 |

### 5.5 Usability Requirements

| 要求 | 目标 | 说明 |
|------|------|------|
| **钱包支持** | 5+ 钱包 | MetaMask, WalletConnect, Trust Wallet, Coinbase, OKX |
| **移动端** | 响应式 | 优先移动端设计 |
| **语言** | 2 种 | 英文、简体中文 |
| **浏览器** | 主流 | Chrome, Firefox, Safari, Edge |
| **无障碍** | WCAG 2.1 AA | 键盘导航、屏幕阅读器 |

## 6. Constraints

### 6.1 Technical Constraints (不可协商)

| ID | 约束 | 原因 | 可协商性 |
|----|------|------|---------|
| C-1 | **必须部署在 BSC** | 目标市场定位、Chainlink XAU/USD 可用 | 不可协商 |
| C-2 | **必须使用 Chainlink Oracle** | XAU/USD 数据源唯一性、已验证可靠 | 不可协商 |
| C-3 | **Solidity ^0.8.24** | 安全特性要求 (overflow 检查) | 可升级 |
| C-4 | **UUPS 代理模式** | 用户指定、Gas 效率优 | 不可协商 |
| C-5 | **Gas < 300,000 (开仓)** | 用户体验要求 | 可放宽至 350K |

### 6.2 Business Constraints (已确认)

| ID | 约束 | 原因 | 可协商性 |
|----|------|------|---------|
| C-6 | **MVP 杠杆范围 2-20x** | 风险控制 (TVL>$20M 后可放开至 50x) | 已用户确认 |
| C-7 | **最小仓位 $10** | 防滥用 | 可调整 |
| C-8 | **健康因子 < 1.0 触发清算** | 风控要求 | 不可协商 |
| C-9 | **协议费用 < 0.1%** | 竞争力要求 | 可动态调整 |
| C-10 | **保险基金 >= TVL 5%** | 坏账兜底 | 不可协商 |

### 6.3 Regulatory Constraints (不可协商)

| ID | 约束 | 原因 | 实施方式 |
|----|------|------|---------|
| C-11 | **无美国用户** | CFTC/SEC 合规风险 | 前端 IP 封锁 + 钱包黑名单 |
| C-12 | **明确免责声明** | 法律保护 | 连接钱包前弹窗确认 |
| C-13 | **MVP 不发行治理代币** | 避免证券认定 | 延迟至充分去中心化 |

### 6.4 Security Constraints (不可协商)

| ID | 约束 | 原因 | 验证方式 |
|----|------|------|---------|
| C-14 | **上线前完成审计** | 行业标准、用户保护 | 审计报告公开 |
| C-15 | **多签控制 ADMIN (3/5)** | 去中心化要求 | Safe 多签钱包 |
| C-16 | **时间锁 48 小时 (升级)** | 用户保护 | Timelock 合约 |

---

## 7. Risks & Mitigation

### 7.1 Critical Risks (Top 5)

| 排名 | 风险 ID | 风险名称 | 概率 | 影响 | 等级 |
|------|---------|---------|------|------|------|
| 1 | R-11 | **清算级联** | Medium | Critical | **Critical** |
| 2 | R-1 | **UUPS 初始化漏洞** | Medium | Critical | **Critical** |
| 3 | R-9 | **Oracle 单点故障** | Low | Critical | **Critical** |
| 4 | R-10 | **闪电贷攻击** | Medium | Critical | **Critical** |
| 5 | R-15/16 | **监管不确定性** | High | Significant | **High** |

**完整风险矩阵**: 见 `.ultra/docs/research/risk-assessment-2025-11-27.md`

### 7.2 Mitigation Strategies

| 风险 | 核心缓解策略 | 实施阶段 |
|------|-------------|---------|
| **清算级联** | MVP 最大杠杆 20x，TVL>$20M 后渐进放开 | MVP |
| **UUPS 漏洞** | 构造函数调用 `_disableInitializers()` | 开发 |
| **Oracle 故障** | Chainlink + Pyth 双 Oracle 架构 | MVP |
| **闪电贷** | 最小持仓 10 区块 (~30秒) | MVP |
| **监管** | 排除美国用户 + DAO 法律架构 | MVP |

### 7.3 Assumptions (设计前提)

**市场假设**:

| ID | 假设 | 验证方式 | 风险 (若错误) |
|----|------|---------|--------------|
| A-1 | BSC 用户对黄金杠杆有需求 | 市场调研、早期反馈 | 产品失败 |
| A-2 | 黄金日波动率 < 3% (常态) | 历史数据分析 | 清算频繁 |
| A-3 | Chainlink XAU/USD 可用性 > 99.9% | SLA 监控 | 协议停摆 |
| A-4 | 清算人有足够激励执行清算 | 激励模拟 | 坏账累积 |

**技术假设**:

| ID | 假设 | 验证方式 | 风险 (若错误) |
|----|------|---------|--------------|
| A-5 | BSC 出块时间稳定 ~3s | 网络监控 | 清算延迟 |
| A-6 | The Graph 索引延迟 < 30s | 性能测试 | 前端数据过期 |
| A-7 | OpenZeppelin 合约无已知漏洞 | CVE 监控 | 继承漏洞 |

**经济假设**:

| ID | 假设 | 验证方式 | 风险 (若错误) |
|----|------|---------|--------------|
| A-8 | LP 愿意承担对手方风险换取收益 | LP 招募数据 | 流动性不足 |
| A-9 | 资金费率能平衡多空 | 历史数据 | OI 失衡 |
| A-10 | 保险基金增长速度 > 坏账速度 | 风险模型 | 基金耗尽 |

---

## 8. Success Metrics

### 8.1 Key Performance Indicators (KPIs)

**DeFi Metrics**:
1. **Total Value Locked (TVL)**
   - Current: $0
   - Target: [Define]
   - Measurement: On-chain data

2. **Daily Active Users (DAU)**
   - Current: 0
   - Target: [Define]
   - Measurement: Unique wallet interactions

3. **Trading Volume**
   - Current: $0
   - Target: [Define]
   - Measurement: Position open/close volume

### 8.2 User Satisfaction Metrics

- **User Retention**: Returning traders after 30 days
- **Position Profitability**: % of profitable positions

---

## 9. Out of Scope

**Explicitly list what this project will NOT include**:

- **Feature X**: [Reason]
- **Feature Y**: [Reason]

---

## 10. Dependencies

### 10.1 External Dependencies

- **Chainlink Oracle**: XAU/USD price feed
- **BSC Network**: Blockchain infrastructure
- **PancakeSwap**: DEX liquidity

### 10.2 Internal Dependencies

- None (new project)

---

## 11. Open Questions

### 11.1 已解决问题 (Round 1-4)

| 问题 | 决定 | 决定时间 |
|------|------|---------|
| 杠杆倍数范围？ | MVP: 2-20x，后期: 最高 50x | Round 4 |
| 抵押品类型？ | 多币种: USDT, USDC, BUSD, BNB | Round 2 |
| Position 是否 NFT 化？ | MVP: 内部 mapping，V2: 考虑 NFT | Round 3 |
| 升级模式？ | UUPS | Round 3 |
| Oracle 策略？ | Chainlink + Pyth 双源 | Round 4 |

### 11.2 待解决问题 (开发阶段)

1. **Question**: 清算奖励百分比具体数值？
   - **建议**: 5-10% (参考 GMX 5%, GNS 5-12%)
   - **Deadline**: 参数定稿前

2. **Question**: LP 提取冷却期时长？
   - **选项**: 24h / 48h / 无
   - **Deadline**: LP 池开发时

3. **Question**: 资金费率结算周期？
   - **选项**: 1h / 8h / 24h
   - **Deadline**: 资金费率模块开发时

## References

- Chainlink XAU/USD Feed: [0x86896fEB19D8A607c3b11f2aF50A0f239Bd71CD0](https://bscscan.com/address/0x86896fEB19D8A607c3b11f2aF50A0f239Bd71CD0)
- BSC Documentation: https://docs.bnbchain.org/
- Similar protocols: [GMX](https://gmx.io/), [GNS](https://gains.trade/), [Synthetix](https://synthetix.io/)
- Risk Assessment: `.ultra/docs/research/risk-assessment-2025-11-27.md`

---

**Document Status**: Research Complete (Round 4/4)
**Last Updated**: 2025-11-27
**Research Ratings**: Round 1 (4★) | Round 2 (5★) | Round 3 (满意) | Round 4 (满意)
**Next Phase**: /ultra-plan (任务规划)
