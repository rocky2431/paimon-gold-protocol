"use client";

import { WalletConnect } from "@/components/WalletConnect";
import { useAccount, useChainId } from "wagmi";

export default function Home() {
  const { isConnected, address } = useAccount();
  const chainId = useChainId();

  return (
    <div className="min-h-screen bg-gradient-to-b from-zinc-900 to-black text-white">
      {/* Header */}
      <header className="fixed top-0 left-0 right-0 z-50 border-b border-zinc-800 bg-zinc-900/80 backdrop-blur-sm">
        <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4">
          <div className="flex items-center gap-2">
            <span className="text-xl font-bold text-amber-500">Paimon</span>
            <span className="text-xl font-light">Gold Protocol</span>
          </div>
          <WalletConnect />
        </div>
      </header>

      {/* Main Content */}
      <main className="mx-auto max-w-7xl px-4 pt-24">
        {/* Hero Section */}
        <section className="flex min-h-[60vh] flex-col items-center justify-center text-center">
          <h1 className="mb-6 text-5xl font-bold tracking-tight sm:text-6xl">
            <span className="text-amber-500">Multi-Leverage</span> Gold ETF
            <br />
            Trading on BSC
          </h1>
          <p className="mb-8 max-w-2xl text-lg text-zinc-400">
            Trade gold with up to 20x leverage. Powered by Chainlink oracles for real-time XAU/USD prices.
            Built for traders who want exposure to gold without traditional market barriers.
          </p>

          {isConnected ? (
            <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-6">
              <p className="mb-2 text-sm text-zinc-500">Connected Wallet</p>
              <p className="font-mono text-lg">{address}</p>
              <p className="mt-2 text-sm text-zinc-500">
                Chain ID: <span className="text-amber-500">{chainId}</span>
              </p>
            </div>
          ) : (
            <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-6 text-center">
              <p className="text-zinc-400">Connect your wallet to start trading</p>
            </div>
          )}
        </section>

        {/* Features Section */}
        <section className="py-16">
          <h2 className="mb-12 text-center text-3xl font-bold">Protocol Features</h2>
          <div className="grid gap-6 md:grid-cols-3">
            <FeatureCard
              title="Leverage Trading"
              description="Trade gold with 2-20x leverage. Choose your risk level and maximize your exposure."
              icon="chart"
            />
            <FeatureCard
              title="Chainlink Oracles"
              description="Real-time XAU/USD price feeds ensure accurate and tamper-proof pricing."
              icon="link"
            />
            <FeatureCard
              title="BSC Network"
              description="Low fees and fast transactions on Binance Smart Chain."
              icon="bolt"
            />
          </div>
        </section>
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

interface FeatureCardProps {
  title: string;
  description: string;
  icon: "chart" | "link" | "bolt";
}

function FeatureCard({ title, description, icon }: FeatureCardProps) {
  const icons = {
    chart: (
      <svg className="h-8 w-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
      </svg>
    ),
    link: (
      <svg className="h-8 w-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
      </svg>
    ),
    bolt: (
      <svg className="h-8 w-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
      </svg>
    ),
  };

  return (
    <div className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-6 transition-colors hover:border-amber-500/50">
      <div className="mb-4 text-amber-500">{icons[icon]}</div>
      <h3 className="mb-2 text-xl font-semibold">{title}</h3>
      <p className="text-zinc-400">{description}</p>
    </div>
  );
}
