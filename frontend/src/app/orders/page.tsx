"use client";

import { useState, useCallback } from "react";
import { useAccount } from "wagmi";
import Link from "next/link";
import { WalletConnect } from "@/components/WalletConnect";
import {
  LimitOrderForm,
  PendingOrdersList,
  TPSLSettings,
  OrderHistory,
} from "@/components/orders";

// Mock position for TP/SL demo
interface Position {
  id: string;
  direction: "long" | "short";
  entryPrice: number;
  size: number;
  collateral: number;
  leverage: number;
  takeProfit?: number;
  stopLoss?: number;
}

const mockPosition: Position = {
  id: "pos-1",
  direction: "long",
  entryPrice: 2650.00,
  size: 10000,
  collateral: 1000,
  leverage: 10,
};

export default function OrdersPage() {
  const { isConnected } = useAccount();
  const [currentPrice] = useState(2655.50);
  const [selectedPosition, setSelectedPosition] = useState(mockPosition);

  const handleOrderCreated = useCallback(() => {
    console.log("Order created");
  }, []);

  const handleCancelOrder = useCallback((orderId: string) => {
    console.log("Cancel order:", orderId);
  }, []);

  const handleTPSLUpdate = useCallback((positionId: string, tp?: number, sl?: number) => {
    console.log("TP/SL updated:", positionId, tp, sl);
    setSelectedPosition(prev => ({
      ...prev,
      takeProfit: tp,
      stopLoss: sl,
    }));
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
                className="text-sm font-medium text-zinc-400 hover:text-white transition-colors"
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
                href="/orders"
                className="text-sm font-medium text-amber-500"
              >
                Orders
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
        <div className="mb-6">
          <h1 className="text-2xl font-bold">Order Management</h1>
          <p className="mt-1 text-zinc-400">Create limit orders, manage TP/SL, and view order history</p>
        </div>

        <div className="grid gap-6 lg:grid-cols-3">
          {/* Left Column - Create Order & TP/SL */}
          <div className="space-y-6 lg:col-span-1">
            <LimitOrderForm
              currentPrice={currentPrice}
              onOrderCreated={handleOrderCreated}
            />

            {isConnected && (
              <TPSLSettings
                position={selectedPosition}
                currentPrice={currentPrice}
                onUpdate={handleTPSLUpdate}
              />
            )}
          </div>

          {/* Right Column - Orders Lists */}
          <div className="space-y-6 lg:col-span-2">
            <PendingOrdersList onCancelOrder={handleCancelOrder} />
            <OrderHistory />
          </div>
        </div>

        {/* Quick Stats */}
        {isConnected && (
          <div className="mt-8 grid grid-cols-4 gap-4">
            <div className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-4">
              <p className="text-xs text-zinc-500">Active Orders</p>
              <p className="text-2xl font-bold">3</p>
            </div>
            <div className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-4">
              <p className="text-xs text-zinc-500">Executed Today</p>
              <p className="text-2xl font-bold text-green-500">2</p>
            </div>
            <div className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-4">
              <p className="text-xs text-zinc-500">Cancelled Today</p>
              <p className="text-2xl font-bold text-zinc-400">1</p>
            </div>
            <div className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-4">
              <p className="text-xs text-zinc-500">Success Rate</p>
              <p className="text-2xl font-bold text-amber-500">67%</p>
            </div>
          </div>
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
