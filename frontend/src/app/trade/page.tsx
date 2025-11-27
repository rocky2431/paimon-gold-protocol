"use client";

import { WalletConnect } from "@/components/WalletConnect";
import { TradingPanel } from "@/components/trading/TradingPanel";
import { useAccount } from "wagmi";
import Link from "next/link";

export default function TradePage() {
  const { isConnected } = useAccount();

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
            <nav className="hidden md:flex items-center gap-4">
              <Link
                href="/trade"
                className="text-sm font-medium text-amber-500"
              >
                Trade
              </Link>
              <Link
                href="/portfolio"
                className="text-sm font-medium text-zinc-400 hover:text-white transition-colors"
              >
                Portfolio
              </Link>
              <Link
                href="/liquidity"
                className="text-sm font-medium text-zinc-400 hover:text-white transition-colors"
              >
                Liquidity
              </Link>
            </nav>
          </div>
          <WalletConnect />
        </div>
      </header>

      {/* Main Content */}
      <main className="mx-auto max-w-7xl px-4 pt-24 pb-16">
        <div className="grid gap-6 lg:grid-cols-3">
          {/* Left Column - Price Chart Placeholder */}
          <div className="lg:col-span-2">
            <div className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-6">
              <div className="mb-4 flex items-center justify-between">
                <h2 className="text-xl font-bold">XAU/USD</h2>
                <div className="flex items-center gap-2">
                  <span className="text-2xl font-bold text-amber-500">
                    $2,650.00
                  </span>
                  <span className="rounded bg-green-500/20 px-2 py-1 text-sm text-green-500">
                    +0.45%
                  </span>
                </div>
              </div>

              {/* Chart Placeholder */}
              <div className="flex h-[400px] items-center justify-center rounded-lg bg-zinc-800/50">
                <div className="text-center">
                  <svg
                    className="mx-auto h-16 w-16 text-zinc-600"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={1.5}
                      d="M7 12l3-3 3 3 4-4M8 21l4-4 4 4M3 4h18M4 4h16v12a1 1 0 01-1 1H5a1 1 0 01-1-1V4z"
                    />
                  </svg>
                  <p className="mt-4 text-zinc-500">
                    TradingView Chart Integration
                  </p>
                  <p className="text-sm text-zinc-600">Coming in Task #20</p>
                </div>
              </div>

              {/* Market Info */}
              <div className="mt-4 grid grid-cols-4 gap-4">
                <div className="rounded-lg bg-zinc-800/50 p-3">
                  <p className="text-xs text-zinc-500">24h High</p>
                  <p className="font-medium text-green-500">$2,668.50</p>
                </div>
                <div className="rounded-lg bg-zinc-800/50 p-3">
                  <p className="text-xs text-zinc-500">24h Low</p>
                  <p className="font-medium text-red-500">$2,635.20</p>
                </div>
                <div className="rounded-lg bg-zinc-800/50 p-3">
                  <p className="text-xs text-zinc-500">24h Volume</p>
                  <p className="font-medium">$1.2B</p>
                </div>
                <div className="rounded-lg bg-zinc-800/50 p-3">
                  <p className="text-xs text-zinc-500">Open Interest</p>
                  <p className="font-medium">$485M</p>
                </div>
              </div>
            </div>

            {/* Open Positions Summary */}
            {isConnected && (
              <div className="mt-6 rounded-xl border border-zinc-800 bg-zinc-900/50 p-6">
                <div className="mb-4 flex items-center justify-between">
                  <h3 className="font-bold">Your Positions</h3>
                  <Link
                    href="/portfolio"
                    className="text-sm text-amber-500 hover:underline"
                  >
                    View All →
                  </Link>
                </div>
                <div className="flex h-24 items-center justify-center text-zinc-500">
                  No open positions
                </div>
              </div>
            )}
          </div>

          {/* Right Column - Trading Panel */}
          <div className="lg:col-span-1">
            <TradingPanel />
          </div>
        </div>
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
