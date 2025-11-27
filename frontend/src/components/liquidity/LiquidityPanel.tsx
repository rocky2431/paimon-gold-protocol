"use client";

import { useState, useMemo, useCallback } from "react";
import { useAccount } from "wagmi";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";

// Types
type TabType = "deposit" | "withdraw";

interface Token {
  symbol: string;
  name: string;
  decimals: number;
  balance: number;
}

interface PoolStats {
  tvl: number;
  apy: number;
  utilization: number;
  totalLpTokens: number;
  userLpBalance: number;
  userShare: number;
  pendingFees: number;
}

// Mock tokens
const SUPPORTED_TOKENS: Token[] = [
  { symbol: "USDT", name: "Tether USD", decimals: 18, balance: 5000 },
  { symbol: "USDC", name: "USD Coin", decimals: 18, balance: 3500 },
  { symbol: "BUSD", name: "Binance USD", decimals: 18, balance: 2000 },
];

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

// Token Selector Component
function TokenSelector({
  tokens,
  selected,
  onSelect,
}: {
  tokens: Token[];
  selected: Token;
  onSelect: (token: Token) => void;
}) {
  return (
    <div className="flex gap-2">
      {tokens.map((token) => (
        <button
          key={token.symbol}
          onClick={() => onSelect(token)}
          className={`rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
            selected.symbol === token.symbol
              ? "bg-amber-500 text-black"
              : "bg-zinc-800 text-zinc-300 hover:bg-zinc-700"
          }`}
        >
          {token.symbol}
        </button>
      ))}
    </div>
  );
}

interface LiquidityPanelProps {
  poolStats: PoolStats;
  onDeposit: (token: string, amount: number) => Promise<void>;
  onWithdraw: (lpAmount: number) => Promise<void>;
}

export function LiquidityPanel({
  poolStats,
  onDeposit,
  onWithdraw,
}: LiquidityPanelProps) {
  const { isConnected } = useAccount();
  const [activeTab, setActiveTab] = useState<TabType>("deposit");
  const [selectedToken, setSelectedToken] = useState<Token>(SUPPORTED_TOKENS[0]);
  const [amountInput, setAmountInput] = useState("");
  const [isConfirmOpen, setIsConfirmOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Parse amount input
  const amount = useMemo(() => {
    const value = parseFloat(amountInput);
    return isNaN(value) ? 0 : value;
  }, [amountInput]);

  // Calculate LP tokens to receive (for deposit)
  const lpTokensToReceive = useMemo(() => {
    if (activeTab !== "deposit" || amount <= 0) return 0;
    // Simple calculation: 1:1 for MVP
    const lpRatio = poolStats.tvl > 0 ? poolStats.totalLpTokens / poolStats.tvl : 1;
    return amount * lpRatio;
  }, [activeTab, amount, poolStats]);

  // Calculate USD value to receive (for withdraw)
  const usdToReceive = useMemo(() => {
    if (activeTab !== "withdraw" || amount <= 0) return 0;
    const usdRatio = poolStats.totalLpTokens > 0 ? poolStats.tvl / poolStats.totalLpTokens : 1;
    return amount * usdRatio;
  }, [activeTab, amount, poolStats]);

  // Validation
  const maxAmount = useMemo(() => {
    if (activeTab === "deposit") {
      return selectedToken.balance;
    }
    return poolStats.userLpBalance;
  }, [activeTab, selectedToken, poolStats]);

  const isValid = useMemo(() => {
    return isConnected && amount > 0 && amount <= maxAmount;
  }, [isConnected, amount, maxAmount]);

  // Handle amount input
  const handleAmountChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const value = e.target.value;
      if (value === "" || /^\d*\.?\d*$/.test(value)) {
        setAmountInput(value);
      }
    },
    []
  );

  // Handle max button
  const handleMax = useCallback(() => {
    setAmountInput(maxAmount.toString());
  }, [maxAmount]);

  // Handle confirm
  const handleConfirm = async () => {
    if (!isValid) return;

    setIsSubmitting(true);
    try {
      if (activeTab === "deposit") {
        await onDeposit(selectedToken.symbol, amount);
      } else {
        await onWithdraw(amount);
      }
      setIsConfirmOpen(false);
      setAmountInput("");
    } catch (error) {
      console.error("Transaction failed:", error);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-6">
      {/* Tabs */}
      <div className="mb-6 grid grid-cols-2 gap-2 rounded-lg bg-zinc-800 p-1">
        <button
          onClick={() => {
            setActiveTab("deposit");
            setAmountInput("");
          }}
          className={`rounded-md py-2 text-sm font-medium transition-colors ${
            activeTab === "deposit"
              ? "bg-amber-500 text-black"
              : "text-zinc-400 hover:text-white"
          }`}
        >
          Deposit
        </button>
        <button
          onClick={() => {
            setActiveTab("withdraw");
            setAmountInput("");
          }}
          className={`rounded-md py-2 text-sm font-medium transition-colors ${
            activeTab === "withdraw"
              ? "bg-amber-500 text-black"
              : "text-zinc-400 hover:text-white"
          }`}
        >
          Withdraw
        </button>
      </div>

      {activeTab === "deposit" ? (
        <>
          {/* Token Selector */}
          <div className="mb-4">
            <Label className="mb-2 block">Select Token</Label>
            <TokenSelector
              tokens={SUPPORTED_TOKENS}
              selected={selectedToken}
              onSelect={(token) => {
                setSelectedToken(token);
                setAmountInput("");
              }}
            />
          </div>

          {/* Amount Input */}
          <div className="mb-6">
            <div className="mb-2 flex items-center justify-between">
              <Label>Amount</Label>
              <span className="text-xs text-zinc-500">
                Balance: {formatNumber(selectedToken.balance, 2)} {selectedToken.symbol}
              </span>
            </div>
            <div className="relative">
              <Input
                type="text"
                inputMode="decimal"
                value={amountInput}
                onChange={handleAmountChange}
                placeholder="0.00"
                className="pr-20"
              />
              <button
                onClick={handleMax}
                className="absolute right-3 top-1/2 -translate-y-1/2 rounded bg-zinc-700 px-2 py-0.5 text-xs text-amber-500 hover:bg-zinc-600"
              >
                MAX
              </button>
            </div>
          </div>

          {/* Preview */}
          {amount > 0 && (
            <div className="mb-6 rounded-lg bg-zinc-800/50 p-4">
              <div className="flex justify-between text-sm">
                <span className="text-zinc-400">You will receive</span>
                <span className="font-medium">
                  {formatNumber(lpTokensToReceive)} PGP-LP
                </span>
              </div>
              <div className="mt-2 flex justify-between text-sm">
                <span className="text-zinc-400">Share of pool</span>
                <span className="font-medium">
                  {formatPercent(
                    ((lpTokensToReceive + poolStats.userLpBalance) /
                      (poolStats.totalLpTokens + lpTokensToReceive)) *
                      100
                  )}
                </span>
              </div>
            </div>
          )}
        </>
      ) : (
        <>
          {/* LP Token Amount */}
          <div className="mb-6">
            <div className="mb-2 flex items-center justify-between">
              <Label>LP Tokens to Withdraw</Label>
              <span className="text-xs text-zinc-500">
                Balance: {formatNumber(poolStats.userLpBalance)} PGP-LP
              </span>
            </div>
            <div className="relative">
              <Input
                type="text"
                inputMode="decimal"
                value={amountInput}
                onChange={handleAmountChange}
                placeholder="0.00"
                className="pr-20"
              />
              <button
                onClick={handleMax}
                className="absolute right-3 top-1/2 -translate-y-1/2 rounded bg-zinc-700 px-2 py-0.5 text-xs text-amber-500 hover:bg-zinc-600"
              >
                MAX
              </button>
            </div>
          </div>

          {/* Preview */}
          {amount > 0 && (
            <div className="mb-6 rounded-lg bg-zinc-800/50 p-4">
              <div className="flex justify-between text-sm">
                <span className="text-zinc-400">You will receive</span>
                <span className="font-medium">~{formatCurrency(usdToReceive)}</span>
              </div>
              <div className="mt-2 flex justify-between text-sm">
                <span className="text-zinc-400">Remaining share</span>
                <span className="font-medium">
                  {formatPercent(
                    ((poolStats.userLpBalance - amount) / (poolStats.totalLpTokens - amount)) *
                      100
                  )}
                </span>
              </div>
            </div>
          )}
        </>
      )}

      {/* Action Button */}
      <Button
        className="w-full"
        size="lg"
        disabled={!isValid}
        onClick={() => setIsConfirmOpen(true)}
      >
        {!isConnected
          ? "Connect Wallet"
          : amount <= 0
            ? `Enter Amount`
            : amount > maxAmount
              ? "Insufficient Balance"
              : activeTab === "deposit"
                ? `Deposit ${selectedToken.symbol}`
                : "Withdraw"}
      </Button>

      {/* Confirmation Dialog */}
      <Dialog open={isConfirmOpen} onOpenChange={setIsConfirmOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>
              Confirm {activeTab === "deposit" ? "Deposit" : "Withdrawal"}
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="rounded-lg bg-zinc-800/50 p-4">
              {activeTab === "deposit" ? (
                <>
                  <div className="flex justify-between text-sm">
                    <span className="text-zinc-400">Deposit Amount</span>
                    <span className="font-medium">
                      {formatNumber(amount, 2)} {selectedToken.symbol}
                    </span>
                  </div>
                  <div className="mt-2 flex justify-between text-sm">
                    <span className="text-zinc-400">LP Tokens to Receive</span>
                    <span className="font-medium">
                      {formatNumber(lpTokensToReceive)} PGP-LP
                    </span>
                  </div>
                </>
              ) : (
                <>
                  <div className="flex justify-between text-sm">
                    <span className="text-zinc-400">LP Tokens to Burn</span>
                    <span className="font-medium">
                      {formatNumber(amount)} PGP-LP
                    </span>
                  </div>
                  <div className="mt-2 flex justify-between text-sm">
                    <span className="text-zinc-400">USD Value</span>
                    <span className="font-medium">~{formatCurrency(usdToReceive)}</span>
                  </div>
                </>
              )}
            </div>

            <div className="rounded-lg bg-amber-500/10 p-3 text-xs text-amber-500">
              ⚠️ {activeTab === "deposit"
                ? "Your deposited tokens will be used to provide liquidity for traders. You earn fees from trades but may experience impermanent loss."
                : "Withdrawing will burn your LP tokens and return your share of the pool assets."}
            </div>
          </div>
          <DialogFooter className="gap-2 sm:gap-0">
            <Button
              variant="outline"
              onClick={() => setIsConfirmOpen(false)}
              disabled={isSubmitting}
            >
              Cancel
            </Button>
            <Button onClick={handleConfirm} disabled={isSubmitting}>
              {isSubmitting
                ? "Processing..."
                : activeTab === "deposit"
                  ? "Confirm Deposit"
                  : "Confirm Withdrawal"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
