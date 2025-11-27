"use client";

import { useState, useCallback } from "react";
import { WalletConnect } from "@/components/WalletConnect";
import { TradingPanel } from "@/components/trading/TradingPanel";
import { PriceChart } from "@/components/trading/PriceChart";
import { useAccount } from "wagmi";
import Link from "next/link";

export default function TradePage() {
  const { isConnected } = useAccount();
  const [currentPrice, setCurrentPrice] = useState(2650);

  const handlePriceUpdate = useCallback((price: number) => {
    setCurrentPrice(price);
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
          {/* Left Column - Price Chart */}
          <div className="lg:col-span-2">
            <div className="h-[500px]">
              <PriceChart
                symbol="XAU/USD"
                currentPrice={2650}
                onPriceUpdate={handlePriceUpdate}
              />
            </div>

            {/* Market Info */}
            <div className="mt-4 grid grid-cols-4 gap-4">
              <div className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-3">
                <p className="text-xs text-zinc-500">24h High</p>
                <p className="font-medium text-green-500">$2,668.50</p>
              </div>
              <div className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-3">
                <p className="text-xs text-zinc-500">24h Low</p>
                <p className="font-medium text-red-500">$2,635.20</p>
              </div>
              <div className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-3">
                <p className="text-xs text-zinc-500">24h Volume</p>
                <p className="font-medium">$1.2B</p>
              </div>
              <div className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-3">
                <p className="text-xs text-zinc-500">Open Interest</p>
                <p className="font-medium">$485M</p>
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
