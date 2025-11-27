"use client";

import { useState, useCallback } from "react";
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseUnits } from "viem";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Slider } from "@/components/ui/slider";

interface LimitOrderFormProps {
  currentPrice: number;
  onOrderCreated?: () => void;
}

type ExpiryType = "gtc" | "1d" | "7d" | "30d";

export function LimitOrderForm({ currentPrice, onOrderCreated }: LimitOrderFormProps) {
  const { isConnected } = useAccount();
  const [direction, setDirection] = useState<"long" | "short">("long");
  const [collateral, setCollateral] = useState("");
  const [leverage, setLeverage] = useState(5);
  const [triggerPrice, setTriggerPrice] = useState(currentPrice.toFixed(2));
  const [expiryType, setExpiryType] = useState<ExpiryType>("gtc");
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Calculate position details
  const collateralNum = parseFloat(collateral) || 0;
  const triggerPriceNum = parseFloat(triggerPrice) || 0;
  const positionSize = collateralNum * leverage;
  const priceChange = currentPrice > 0
    ? ((triggerPriceNum - currentPrice) / currentPrice) * 100
    : 0;

  // Get expiry timestamp
  const getExpiryTimestamp = (): bigint => {
    if (expiryType === "gtc") return BigInt(0);
    const now = Math.floor(Date.now() / 1000);
    switch (expiryType) {
      case "1d": return BigInt(now + 86400);
      case "7d": return BigInt(now + 86400 * 7);
      case "30d": return BigInt(now + 86400 * 30);
      default: return BigInt(0);
    }
  };

  const handleSubmit = useCallback(async () => {
    if (!isConnected || collateralNum <= 0 || triggerPriceNum <= 0) return;

    setIsSubmitting(true);
    try {
      // Simulate order creation - in production, this would call the contract
      await new Promise(resolve => setTimeout(resolve, 2000));

      // Reset form
      setCollateral("");
      setTriggerPrice(currentPrice.toFixed(2));
      setLeverage(5);

      onOrderCreated?.();
    } catch (error) {
      console.error("Failed to create order:", error);
    } finally {
      setIsSubmitting(false);
    }
  }, [isConnected, collateralNum, triggerPriceNum, currentPrice, onOrderCreated]);

  const formatCurrency = (value: number) => {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
    }).format(value);
  };

  return (
    <div className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-6">
      <h3 className="mb-4 text-lg font-semibold">Create Limit Order</h3>

      {/* Direction Toggle */}
      <div className="mb-6">
        <Label className="mb-2 block text-sm text-zinc-400">Direction</Label>
        <div className="grid grid-cols-2 gap-2">
          <button
            onClick={() => setDirection("long")}
            className={`rounded-lg py-3 text-sm font-medium transition-colors ${
              direction === "long"
                ? "bg-green-500/20 text-green-500 ring-1 ring-green-500/50"
                : "bg-zinc-800 text-zinc-400 hover:bg-zinc-700"
            }`}
          >
            Long
          </button>
          <button
            onClick={() => setDirection("short")}
            className={`rounded-lg py-3 text-sm font-medium transition-colors ${
              direction === "short"
                ? "bg-red-500/20 text-red-500 ring-1 ring-red-500/50"
                : "bg-zinc-800 text-zinc-400 hover:bg-zinc-700"
            }`}
          >
            Short
          </button>
        </div>
      </div>

      {/* Collateral Input */}
      <div className="mb-4">
        <Label htmlFor="collateral" className="mb-2 block text-sm text-zinc-400">
          Collateral (USDT)
        </Label>
        <Input
          id="collateral"
          type="number"
          placeholder="0.00"
          value={collateral}
          onChange={(e) => setCollateral(e.target.value)}
          className="bg-zinc-800 border-zinc-700"
        />
      </div>

      {/* Leverage Slider */}
      <div className="mb-4">
        <div className="mb-2 flex items-center justify-between">
          <Label className="text-sm text-zinc-400">Leverage</Label>
          <span className="text-sm font-medium text-amber-500">{leverage}x</span>
        </div>
        <Slider
          value={[leverage]}
          onValueChange={(value) => setLeverage(value[0])}
          min={2}
          max={20}
          step={1}
          className="py-2"
        />
        <div className="flex justify-between text-xs text-zinc-500">
          <span>2x</span>
          <span>20x</span>
        </div>
      </div>

      {/* Trigger Price */}
      <div className="mb-4">
        <Label htmlFor="triggerPrice" className="mb-2 block text-sm text-zinc-400">
          Trigger Price (USD)
        </Label>
        <Input
          id="triggerPrice"
          type="number"
          step="0.01"
          value={triggerPrice}
          onChange={(e) => setTriggerPrice(e.target.value)}
          className="bg-zinc-800 border-zinc-700"
        />
        <div className="mt-1 flex items-center justify-between text-xs">
          <span className="text-zinc-500">Current: {formatCurrency(currentPrice)}</span>
          <span className={priceChange > 0 ? "text-green-500" : priceChange < 0 ? "text-red-500" : "text-zinc-500"}>
            {priceChange > 0 ? "+" : ""}{priceChange.toFixed(2)}% from current
          </span>
        </div>
      </div>

      {/* Expiry Selection */}
      <div className="mb-6">
        <Label className="mb-2 block text-sm text-zinc-400">Expiry</Label>
        <div className="grid grid-cols-4 gap-2">
          {(["gtc", "1d", "7d", "30d"] as ExpiryType[]).map((type) => (
            <button
              key={type}
              onClick={() => setExpiryType(type)}
              className={`rounded-lg py-2 text-xs font-medium transition-colors ${
                expiryType === type
                  ? "bg-amber-500/20 text-amber-500 ring-1 ring-amber-500/50"
                  : "bg-zinc-800 text-zinc-400 hover:bg-zinc-700"
              }`}
            >
              {type === "gtc" ? "GTC" : type.toUpperCase()}
            </button>
          ))}
        </div>
        <p className="mt-1 text-xs text-zinc-500">
          {expiryType === "gtc" ? "Good Till Cancelled" : `Expires in ${expiryType}`}
        </p>
      </div>

      {/* Order Summary */}
      <div className="mb-6 rounded-lg bg-zinc-800/50 p-4">
        <h4 className="mb-3 text-sm font-medium text-zinc-400">Order Summary</h4>
        <div className="space-y-2 text-sm">
          <div className="flex justify-between">
            <span className="text-zinc-500">Position Size</span>
            <span className="font-medium">{formatCurrency(positionSize)}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-zinc-500">Direction</span>
            <span className={direction === "long" ? "text-green-500" : "text-red-500"}>
              {direction === "long" ? "Long" : "Short"}
            </span>
          </div>
          <div className="flex justify-between">
            <span className="text-zinc-500">Trigger</span>
            <span className="font-medium">{formatCurrency(triggerPriceNum)}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-zinc-500">Expiry</span>
            <span className="text-zinc-300">{expiryType === "gtc" ? "Never" : expiryType.toUpperCase()}</span>
          </div>
        </div>
      </div>

      {/* Submit Button */}
      <Button
        onClick={handleSubmit}
        disabled={!isConnected || isSubmitting || collateralNum <= 0 || triggerPriceNum <= 0}
        className="w-full"
      >
        {isSubmitting ? (
          <span className="flex items-center gap-2">
            <span className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
            Creating Order...
          </span>
        ) : (
          `Create ${direction === "long" ? "Long" : "Short"} Limit Order`
        )}
      </Button>
    </div>
  );
}
