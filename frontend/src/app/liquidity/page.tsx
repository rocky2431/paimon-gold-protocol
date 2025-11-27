"use client";

import { useState, useCallback, useMemo } from "react";
import Link from "next/link";
import { useAccount } from "wagmi";
import { WalletConnect } from "@/components/WalletConnect";
import { LiquidityPanel } from "@/components/liquidity/LiquidityPanel";

// Format helpers
function formatCurrency(value: number, decimals: number = 2): string {
  if (value >= 1000000) {
    return `$${(value / 1000000).toFixed(2)}M`;
  }
  if (value >= 1000) {
    return `$${(value / 1000).toFixed(2)}K`;
  }
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(value);
}

function formatPercent(value: number): string {
  return `${value.toFixed(2)}%`;
}

function formatNumber(value: number, decimals: number = 4): string {
  return new Intl.NumberFormat("en-US", {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(value);
}

// Pool Stats Component
function PoolStats({
  tvl,
  apy,
  utilization,
  totalLpTokens,
}: {
  tvl: number;
  apy: number;
  utilization: number;
  totalLpTokens: number;
}) {
  return (
    <div className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-6">
      <h2 className="mb-4 text-lg font-semibold">Pool Statistics</h2>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div className="rounded-lg bg-zinc-800/50 p-4">
          <p className="text-sm text-zinc-500">Total Value Locked</p>
          <p className="text-2xl font-bold text-amber-500">{formatCurrency(tvl)}</p>
        </div>
        <div className="rounded-lg bg-zinc-800/50 p-4">
          <p className="text-sm text-zinc-500">APY (Estimated)</p>
          <p className="text-2xl font-bold text-green-500">{formatPercent(apy)}</p>
        </div>
        <div className="rounded-lg bg-zinc-800/50 p-4">
          <p className="text-sm text-zinc-500">Utilization Rate</p>
          <p className="text-2xl font-bold">{formatPercent(utilization)}</p>
          <div className="mt-2 h-2 w-full overflow-hidden rounded-full bg-zinc-700">
            <div
              className="h-full bg-amber-500 transition-all"
              style={{ width: `${Math.min(utilization, 100)}%` }}
            />
          </div>
        </div>
        <div className="rounded-lg bg-zinc-800/50 p-4">
          <p className="text-sm text-zinc-500">Total LP Tokens</p>
          <p className="text-2xl font-bold">{formatNumber(totalLpTokens, 2)}</p>
        </div>
      </div>
    </div>
  );
}

// User Position Component
function UserPosition({
  userLpBalance,
  userShare,
  tvl,
  pendingFees,
  apy,
}: {
  userLpBalance: number;
  userShare: number;
  tvl: number;
  pendingFees: number;
  apy: number;
}) {
  const { isConnected } = useAccount();
  const userValueInPool = (userShare / 100) * tvl;

  if (!isConnected) {
    return (
      <div className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-6">
        <h2 className="mb-4 text-lg font-semibold">Your Position</h2>
        <div className="flex flex-col items-center justify-center py-8 text-center">
          <svg
            className="mb-4 h-12 w-12 text-zinc-600"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={1.5}
              d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
            />
          </svg>
          <p className="mb-4 text-zinc-500">Connect wallet to view your position</p>
          <WalletConnect />
        </div>
      </div>
    );
  }

  if (userLpBalance === 0) {
    return (
      <div className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-6">
        <h2 className="mb-4 text-lg font-semibold">Your Position</h2>
        <div className="flex flex-col items-center justify-center py-8 text-center">
          <svg
            className="mb-4 h-12 w-12 text-zinc-600"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={1.5}
              d="M12 6v6m0 0v6m0-6h6m-6 0H6"
            />
          </svg>
          <p className="mb-2 text-zinc-300">No LP Position</p>
          <p className="text-sm text-zinc-500">
            Deposit stablecoins to earn {formatPercent(apy)} APY
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-6">
      <h2 className="mb-4 text-lg font-semibold">Your Position</h2>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div className="rounded-lg bg-zinc-800/50 p-4">
          <p className="text-sm text-zinc-500">LP Tokens</p>
          <p className="text-xl font-bold">{formatNumber(userLpBalance)} PGP-LP</p>
        </div>
        <div className="rounded-lg bg-zinc-800/50 p-4">
          <p className="text-sm text-zinc-500">Pool Share</p>
          <p className="text-xl font-bold">{formatPercent(userShare)}</p>
        </div>
        <div className="rounded-lg bg-zinc-800/50 p-4">
          <p className="text-sm text-zinc-500">Value in Pool</p>
          <p className="text-xl font-bold text-amber-500">{formatCurrency(userValueInPool)}</p>
        </div>
        <div className="rounded-lg bg-zinc-800/50 p-4">
          <p className="text-sm text-zinc-500">Pending Fees</p>
          <p className="text-xl font-bold text-green-500">{formatCurrency(pendingFees)}</p>
        </div>
      </div>

      {/* Earnings Breakdown */}
      <div className="mt-4 rounded-lg bg-amber-500/10 p-4">
        <div className="flex items-center gap-2">
          <svg
            className="h-5 w-5 text-amber-500"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"
            />
          </svg>
          <span className="text-sm font-medium text-amber-500">
            Estimated Daily Earnings: {formatCurrency((userValueInPool * apy) / 100 / 365)}
          </span>
        </div>
      </div>
    </div>
  );
}

// Fee History Component
function FeeHistory({ isConnected }: { isConnected: boolean }) {
  // Mock fee history
  const feeHistory = [
    { date: "2024-01-15", amount: 12.45, type: "Trading Fee" },
    { date: "2024-01-14", amount: 8.32, type: "Trading Fee" },
    { date: "2024-01-13", amount: 15.67, type: "Trading Fee" },
    { date: "2024-01-12", amount: 6.89, type: "Trading Fee" },
    { date: "2024-01-11", amount: 21.23, type: "Trading Fee" },
  ];

  if (!isConnected) {
    return null;
  }

  return (
    <div className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-6">
      <h2 className="mb-4 text-lg font-semibold">Recent Fee Earnings</h2>
      <div className="space-y-3">
        {feeHistory.map((fee, index) => (
          <div
            key={index}
            className="flex items-center justify-between rounded-lg bg-zinc-800/50 p-3"
          >
            <div>
              <p className="text-sm font-medium">{fee.type}</p>
              <p className="text-xs text-zinc-500">{fee.date}</p>
            </div>
            <p className="font-medium text-green-500">+{formatCurrency(fee.amount)}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

export default function LiquidityPage() {
  const { isConnected } = useAccount();
  const [showDemo, setShowDemo] = useState(true);

  // Mock pool stats - in production this would come from contract
  // Use useMemo to recompute stats based on showDemo and isConnected
  const poolStats = useMemo(() => ({
    tvl: 2450000,
    apy: 12.5,
    utilization: 68.5,
    totalLpTokens: 2400000,
    userLpBalance: showDemo && isConnected ? 15000 : 0,
    userShare: showDemo && isConnected ? 0.625 : 0,
    pendingFees: showDemo && isConnected ? 45.67 : 0,
  }), [showDemo, isConnected]);

  // State for pool mutations (deposit/withdraw)
  const [poolMutations, setPoolMutations] = useState({
    tvlDelta: 0,
    lpTokensDelta: 0,
    userLpDelta: 0,
  });

  // Compute effective pool stats with mutations
  const effectivePoolStats = useMemo(() => ({
    ...poolStats,
    tvl: poolStats.tvl + poolMutations.tvlDelta,
    totalLpTokens: poolStats.totalLpTokens + poolMutations.lpTokensDelta,
    userLpBalance: poolStats.userLpBalance + poolMutations.userLpDelta,
    userShare: poolStats.totalLpTokens + poolMutations.lpTokensDelta > 0
      ? ((poolStats.userLpBalance + poolMutations.userLpDelta) / (poolStats.totalLpTokens + poolMutations.lpTokensDelta)) * 100
      : 0,
  }), [poolStats, poolMutations]);

  // Handle deposit
  const handleDeposit = useCallback(async (token: string, amount: number) => {
    // Simulate transaction delay
    await new Promise((resolve) => setTimeout(resolve, 2000));
    console.log(`Depositing ${amount} ${token}`);

    // Update pool mutations
    setPoolMutations((prev) => ({
      ...prev,
      tvlDelta: prev.tvlDelta + amount,
      lpTokensDelta: prev.lpTokensDelta + amount,
      userLpDelta: prev.userLpDelta + amount,
    }));
  }, []);

  // Handle withdraw
  const handleWithdraw = useCallback(async (lpAmount: number) => {
    // Simulate transaction delay
    await new Promise((resolve) => setTimeout(resolve, 2000));
    console.log(`Withdrawing ${lpAmount} LP tokens`);

    // Calculate USD value
    const usdRatio = effectivePoolStats.tvl / effectivePoolStats.totalLpTokens;
    const usdAmount = lpAmount * usdRatio;

    // Update pool mutations
    setPoolMutations((prev) => ({
      ...prev,
      tvlDelta: prev.tvlDelta - usdAmount,
      lpTokensDelta: prev.lpTokensDelta - lpAmount,
      userLpDelta: prev.userLpDelta - lpAmount,
    }));
  }, [effectivePoolStats]);

  return (
    <main className="min-h-screen bg-zinc-950 text-white">
      {/* Header */}
      <header className="border-b border-zinc-800 bg-zinc-900/50">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-4">
          <div className="flex items-center gap-8">
            <Link href="/" className="text-xl font-bold text-amber-500">
              Paimon Gold
            </Link>
            <nav className="hidden gap-6 md:flex">
              <Link href="/trade" className="text-zinc-400 hover:text-white">
                Trade
              </Link>
              <Link href="/portfolio" className="text-zinc-400 hover:text-white">
                Portfolio
              </Link>
              <Link href="/liquidity" className="font-medium text-amber-500">
                Liquidity
              </Link>
            </nav>
          </div>
          <div className="flex items-center gap-4">
            {/* Demo Toggle */}
            <label className="flex cursor-pointer items-center gap-2">
              <span className="text-xs text-zinc-500">Demo Data</span>
              <div
                onClick={() => setShowDemo(!showDemo)}
                className={`relative h-5 w-9 rounded-full transition-colors ${
                  showDemo ? "bg-amber-500" : "bg-zinc-700"
                }`}
              >
                <div
                  className={`absolute top-0.5 h-4 w-4 rounded-full bg-white transition-transform ${
                    showDemo ? "left-[18px]" : "left-0.5"
                  }`}
                />
              </div>
            </label>
            <WalletConnect />
          </div>
        </div>
      </header>

      {/* Main Content */}
      <div className="mx-auto max-w-7xl px-4 py-8">
        {/* Page Title */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold">Liquidity Pool</h1>
          <p className="mt-2 text-zinc-400">
            Provide liquidity to earn trading fees. Deposited funds are used to facilitate
            leveraged trading.
          </p>
        </div>

        {/* Pool Stats */}
        <div className="mb-8">
          <PoolStats
            tvl={effectivePoolStats.tvl}
            apy={effectivePoolStats.apy}
            utilization={effectivePoolStats.utilization}
            totalLpTokens={effectivePoolStats.totalLpTokens}
          />
        </div>

        {/* Main Grid */}
        <div className="grid gap-8 lg:grid-cols-3">
          {/* Left Column - User Position & Fee History */}
          <div className="space-y-8 lg:col-span-2">
            <UserPosition
              userLpBalance={effectivePoolStats.userLpBalance}
              userShare={effectivePoolStats.userShare}
              tvl={effectivePoolStats.tvl}
              pendingFees={effectivePoolStats.pendingFees}
              apy={effectivePoolStats.apy}
            />
            <FeeHistory isConnected={isConnected} />
          </div>

          {/* Right Column - Deposit/Withdraw Panel */}
          <div>
            <LiquidityPanel
              poolStats={effectivePoolStats}
              onDeposit={handleDeposit}
              onWithdraw={handleWithdraw}
            />
          </div>
        </div>

        {/* Info Section */}
        <div className="mt-8 rounded-xl border border-zinc-800 bg-zinc-900/50 p-6">
          <h2 className="mb-4 text-lg font-semibold">How It Works</h2>
          <div className="grid gap-6 md:grid-cols-3">
            <div className="flex gap-4">
              <div className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-full bg-amber-500/20 text-amber-500">
                1
              </div>
              <div>
                <h3 className="font-medium">Deposit Stablecoins</h3>
                <p className="mt-1 text-sm text-zinc-400">
                  Deposit USDT, USDC, or BUSD to receive PGP-LP tokens representing your share.
                </p>
              </div>
            </div>
            <div className="flex gap-4">
              <div className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-full bg-amber-500/20 text-amber-500">
                2
              </div>
              <div>
                <h3 className="font-medium">Earn Trading Fees</h3>
                <p className="mt-1 text-sm text-zinc-400">
                  Traders pay fees when opening and closing positions. These fees accrue to LPs.
                </p>
              </div>
            </div>
            <div className="flex gap-4">
              <div className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-full bg-amber-500/20 text-amber-500">
                3
              </div>
              <div>
                <h3 className="font-medium">Withdraw Anytime</h3>
                <p className="mt-1 text-sm text-zinc-400">
                  Burn your LP tokens to receive your share of the pool plus accumulated fees.
                </p>
              </div>
            </div>
          </div>

          <div className="mt-6 rounded-lg bg-amber-500/10 p-4 text-sm text-amber-500">
            <strong>Risk Warning:</strong> As a liquidity provider, you may experience losses if
            traders are profitable. Your deposited funds act as counter-party to leveraged trades.
          </div>
        </div>
      </div>
    </main>
  );
}
