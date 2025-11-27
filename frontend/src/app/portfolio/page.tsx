"use client";

import { useState, useEffect, useCallback, useMemo } from "react";
import { useAccount } from "wagmi";
import Link from "next/link";
import { WalletConnect } from "@/components/WalletConnect";
import { PositionsTable, type Position } from "@/components/portfolio/PositionsTable";
import { Button } from "@/components/ui/button";

// Mock current price - will be replaced with Chainlink oracle
const MOCK_XAU_PRICE = 2650.0;

// Mock positions for demo - will be replaced with smart contract data
const MOCK_POSITIONS: Position[] = [
  {
    id: "1",
    direction: "long",
    collateral: 100,
    leverage: 10,
    entryPrice: 2620.0,
    size: 1000,
    openedAt: new Date(Date.now() - 3600000 * 24), // 1 day ago
    liquidationPrice: 2358.0,
  },
  {
    id: "2",
    direction: "short",
    collateral: 250,
    leverage: 5,
    entryPrice: 2680.0,
    size: 1250,
    openedAt: new Date(Date.now() - 3600000 * 12), // 12 hours ago
    liquidationPrice: 2948.0,
  },
];

// Closed positions history
interface ClosedPosition {
  id: string;
  direction: "long" | "short";
  size: number;
  entryPrice: number;
  exitPrice: number;
  pnl: number;
  closedAt: Date;
}

const MOCK_CLOSED_POSITIONS: ClosedPosition[] = [
  {
    id: "c1",
    direction: "long",
    size: 500,
    entryPrice: 2600.0,
    exitPrice: 2640.0,
    pnl: 7.69,
    closedAt: new Date(Date.now() - 3600000 * 48),
  },
  {
    id: "c2",
    direction: "short",
    size: 800,
    entryPrice: 2700.0,
    exitPrice: 2650.0,
    pnl: 14.81,
    closedAt: new Date(Date.now() - 3600000 * 72),
  },
];

function formatCurrency(value: number): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(value);
}

function formatDate(date: Date): string {
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

export default function PortfolioPage() {
  const { isConnected } = useAccount();
  const [closedPositionIds, setClosedPositionIds] = useState<Set<string>>(new Set());
  const [closedPositions] = useState<ClosedPosition[]>(MOCK_CLOSED_POSITIONS);
  const [currentPrice, setCurrentPrice] = useState(MOCK_XAU_PRICE);
  const [showDemo, setShowDemo] = useState(false);

  // Simulate price updates
  useEffect(() => {
    const interval = setInterval(() => {
      // Random price fluctuation within 0.1%
      const fluctuation = (Math.random() - 0.5) * 0.002;
      setCurrentPrice((prev) => prev * (1 + fluctuation));
    }, 3000);

    return () => clearInterval(interval);
  }, []);

  // Compute positions based on demo mode (using useMemo to avoid setState in useEffect)
  const positions = useMemo(() => {
    const basePositions = showDemo ? MOCK_POSITIONS : [];
    return basePositions.filter(p => !closedPositionIds.has(p.id));
  }, [showDemo, closedPositionIds]);

  // Handle close position
  const handleClosePosition = useCallback(async (positionId: string) => {
    // Simulate closing position
    await new Promise((resolve) => setTimeout(resolve, 1500));
    setClosedPositionIds((prev) => new Set([...prev, positionId]));
  }, []);

  return (
    <div className="min-h-screen bg-gradient-to-b from-zinc-900 to-black text-white">
      {/* Header */}
      <header className="fixed left-0 right-0 top-0 z-50 border-b border-zinc-800 bg-zinc-900/80 backdrop-blur-sm">
        <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4">
          <div className="flex items-center gap-6">
            <Link href="/" className="flex items-center gap-2">
              <span className="text-xl font-bold text-amber-500">Paimon</span>
              <span className="text-xl font-light">Gold Protocol</span>
            </Link>
            <nav className="hidden items-center gap-4 md:flex">
              <Link
                href="/trade"
                className="text-sm font-medium text-zinc-400 transition-colors hover:text-white"
              >
                Trade
              </Link>
              <Link
                href="/portfolio"
                className="text-sm font-medium text-amber-500"
              >
                Portfolio
              </Link>
              <Link
                href="/liquidity"
                className="text-sm font-medium text-zinc-400 transition-colors hover:text-white"
              >
                Liquidity
              </Link>
            </nav>
          </div>
          <WalletConnect />
        </div>
      </header>

      {/* Main Content */}
      <main className="mx-auto max-w-7xl px-4 pb-16 pt-24">
        {/* Page Header */}
        <div className="mb-8 flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold">Portfolio</h1>
            <p className="mt-1 text-zinc-400">
              Manage your open positions and view trading history
            </p>
          </div>
          <div className="flex items-center gap-4">
            {/* Current Price Badge */}
            <div className="rounded-lg border border-zinc-800 bg-zinc-900/50 px-4 py-2">
              <div className="flex items-center gap-2">
                <span className="text-sm text-zinc-400">XAU/USD</span>
                <span className="text-lg font-bold text-amber-500">
                  {formatCurrency(currentPrice)}
                </span>
                <span className="rounded bg-green-500/20 px-1.5 py-0.5 text-xs text-green-500">
                  LIVE
                </span>
              </div>
            </div>
            <Link href="/trade">
              <Button>Open Position</Button>
            </Link>
          </div>
        </div>

        {!isConnected ? (
          /* Not Connected State */
          <div className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-12 text-center">
            <svg
              className="mx-auto mb-4 h-16 w-16 text-zinc-600"
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
            <h2 className="mb-2 text-xl font-bold">Connect Your Wallet</h2>
            <p className="mb-6 text-zinc-400">
              Connect your wallet to view your positions and trading history.
            </p>
            <WalletConnect />
          </div>
        ) : (
          <>
            {/* Demo Toggle */}
            <div className="mb-6 flex justify-end">
              <button
                onClick={() => setShowDemo(!showDemo)}
                className="text-sm text-zinc-500 hover:text-zinc-300"
              >
                {showDemo ? "Hide Demo Data" : "Show Demo Data"}
              </button>
            </div>

            {/* Open Positions */}
            <section className="mb-12">
              <h2 className="mb-4 text-xl font-bold">Open Positions</h2>
              <PositionsTable
                positions={positions}
                currentPrice={currentPrice}
                onClosePosition={handleClosePosition}
              />
            </section>

            {/* Closed Positions History */}
            <section>
              <h2 className="mb-4 text-xl font-bold">Trade History</h2>
              {closedPositions.length === 0 ? (
                <div className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-8 text-center">
                  <p className="text-zinc-500">No trading history yet.</p>
                </div>
              ) : (
                <div className="overflow-x-auto rounded-xl border border-zinc-800 bg-zinc-900/50">
                  <table className="w-full">
                    <thead>
                      <tr className="border-b border-zinc-800 text-left text-sm text-zinc-500">
                        <th className="px-4 py-3 font-medium">Position</th>
                        <th className="px-4 py-3 text-right font-medium">Size</th>
                        <th className="px-4 py-3 text-right font-medium">Entry</th>
                        <th className="px-4 py-3 text-right font-medium">Exit</th>
                        <th className="px-4 py-3 text-right font-medium">PnL</th>
                        <th className="px-4 py-3 text-right font-medium">Closed</th>
                      </tr>
                    </thead>
                    <tbody>
                      {closedPositions.map((position) => (
                        <tr
                          key={position.id}
                          className="border-b border-zinc-800 hover:bg-zinc-800/50"
                        >
                          <td className="px-4 py-4">
                            <div className="flex items-center gap-2">
                              <span
                                className={`rounded px-2 py-1 text-xs font-medium ${
                                  position.direction === "long"
                                    ? "bg-green-500/20 text-green-500"
                                    : "bg-red-500/20 text-red-500"
                                }`}
                              >
                                {position.direction === "long"
                                  ? "↗ LONG"
                                  : "↘ SHORT"}
                              </span>
                              <span className="font-medium">XAU/USD</span>
                            </div>
                          </td>
                          <td className="px-4 py-4 text-right">
                            {formatCurrency(position.size)}
                          </td>
                          <td className="px-4 py-4 text-right">
                            {formatCurrency(position.entryPrice)}
                          </td>
                          <td className="px-4 py-4 text-right">
                            {formatCurrency(position.exitPrice)}
                          </td>
                          <td className="px-4 py-4 text-right">
                            <span
                              className={`font-medium ${
                                position.pnl >= 0
                                  ? "text-green-500"
                                  : "text-red-500"
                              }`}
                            >
                              {position.pnl >= 0 ? "+" : ""}
                              {formatCurrency(position.pnl)}
                            </span>
                          </td>
                          <td className="px-4 py-4 text-right text-zinc-400">
                            {formatDate(position.closedAt)}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </section>
          </>
        )}
      </main>

      {/* Footer */}
      <footer className="border-t border-zinc-800 py-8">
        <div className="mx-auto max-w-7xl px-4 text-center text-sm text-zinc-500">
          <p>Paimon Gold Protocol - Multi-Leverage Gold ETF DeFi Protocol</p>
          <p className="mt-2">Built with Next.js, wagmi, and Solidity</p>
        </div>
      </footer>
    </div>
  );
}
