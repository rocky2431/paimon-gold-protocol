"use client";

import { useState, useCallback, useEffect } from "react";
import { useAccount } from "wagmi";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";

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

interface TPSLSettingsProps {
  position: Position;
  currentPrice: number;
  onUpdate?: (positionId: string, tp?: number, sl?: number) => void;
}

export function TPSLSettings({ position, currentPrice, onUpdate }: TPSLSettingsProps) {
  const { isConnected } = useAccount();
  const [enableTP, setEnableTP] = useState(!!position.takeProfit);
  const [enableSL, setEnableSL] = useState(!!position.stopLoss);
  const [takeProfit, setTakeProfit] = useState(position.takeProfit?.toFixed(2) || "");
  const [stopLoss, setStopLoss] = useState(position.stopLoss?.toFixed(2) || "");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [hasChanges, setHasChanges] = useState(false);

  // Calculate suggested TP/SL based on position
  const suggestedTP = position.direction === "long"
    ? position.entryPrice * 1.05 // 5% profit for long
    : position.entryPrice * 0.95; // 5% profit for short

  const suggestedSL = position.direction === "long"
    ? position.entryPrice * 0.97 // 3% loss for long
    : position.entryPrice * 1.03; // 3% loss for short

  // Calculate potential PnL
  const tpPrice = parseFloat(takeProfit) || 0;
  const slPrice = parseFloat(stopLoss) || 0;

  const calculatePnL = (exitPrice: number) => {
    const priceDiff = position.direction === "long"
      ? exitPrice - position.entryPrice
      : position.entryPrice - exitPrice;
    return (priceDiff / position.entryPrice) * position.size;
  };

  const potentialProfit = tpPrice > 0 ? calculatePnL(tpPrice) : 0;
  const potentialLoss = slPrice > 0 ? calculatePnL(slPrice) : 0;

  // Track changes
  useEffect(() => {
    const tpChanged = enableTP !== !!position.takeProfit ||
      (enableTP && parseFloat(takeProfit) !== position.takeProfit);
    const slChanged = enableSL !== !!position.stopLoss ||
      (enableSL && parseFloat(stopLoss) !== position.stopLoss);
    setHasChanges(tpChanged || slChanged);
  }, [enableTP, enableSL, takeProfit, stopLoss, position]);

  const handleSubmit = useCallback(async () => {
    if (!isConnected || !hasChanges) return;

    setIsSubmitting(true);
    try {
      const tp = enableTP && takeProfit ? parseFloat(takeProfit) : undefined;
      const sl = enableSL && stopLoss ? parseFloat(stopLoss) : undefined;

      // Simulate update - in production, this would call the contract
      await new Promise(resolve => setTimeout(resolve, 1500));

      onUpdate?.(position.id, tp, sl);
      setHasChanges(false);
    } catch (error) {
      console.error("Failed to update TP/SL:", error);
    } finally {
      setIsSubmitting(false);
    }
  }, [isConnected, hasChanges, enableTP, enableSL, takeProfit, stopLoss, position.id, onUpdate]);

  const formatCurrency = (value: number) => {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
    }).format(value);
  };

  const formatPnL = (value: number) => {
    const formatted = formatCurrency(Math.abs(value));
    return value >= 0 ? `+${formatted}` : `-${formatted}`;
  };

  // Validation
  const isTpValid = !enableTP || (tpPrice > 0 && (
    position.direction === "long" ? tpPrice > position.entryPrice : tpPrice < position.entryPrice
  ));
  const isSlValid = !enableSL || (slPrice > 0 && (
    position.direction === "long" ? slPrice < position.entryPrice : slPrice > position.entryPrice
  ));

  return (
    <div className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-6">
      <div className="mb-4 flex items-center justify-between">
        <h3 className="text-lg font-semibold">TP/SL Settings</h3>
        <span className={`text-sm ${position.direction === "long" ? "text-green-500" : "text-red-500"}`}>
          {position.direction === "long" ? "Long" : "Short"} Position
        </span>
      </div>

      {/* Position Info */}
      <div className="mb-6 rounded-lg bg-zinc-800/50 p-3">
        <div className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <span className="text-zinc-500">Entry Price</span>
            <p className="font-medium">{formatCurrency(position.entryPrice)}</p>
          </div>
          <div>
            <span className="text-zinc-500">Current Price</span>
            <p className="font-medium">{formatCurrency(currentPrice)}</p>
          </div>
          <div>
            <span className="text-zinc-500">Position Size</span>
            <p className="font-medium">{formatCurrency(position.size)}</p>
          </div>
          <div>
            <span className="text-zinc-500">Leverage</span>
            <p className="font-medium text-amber-500">{position.leverage}x</p>
          </div>
        </div>
      </div>

      {/* Take Profit */}
      <div className="mb-6">
        <div className="mb-3 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Switch
              checked={enableTP}
              onCheckedChange={setEnableTP}
              className="data-[state=checked]:bg-green-500"
            />
            <Label className="text-sm font-medium">Take Profit</Label>
          </div>
          {enableTP && (
            <button
              onClick={() => setTakeProfit(suggestedTP.toFixed(2))}
              className="text-xs text-amber-500 hover:text-amber-400"
            >
              Suggested: {formatCurrency(suggestedTP)}
            </button>
          )}
        </div>
        {enableTP && (
          <div>
            <Input
              type="number"
              step="0.01"
              placeholder="Take profit price"
              value={takeProfit}
              onChange={(e) => setTakeProfit(e.target.value)}
              className={`bg-zinc-800 border-zinc-700 ${!isTpValid ? "border-red-500" : ""}`}
            />
            {tpPrice > 0 && (
              <div className="mt-2 flex items-center justify-between text-xs">
                <span className="text-zinc-500">
                  {position.direction === "long" ? "Price must be above entry" : "Price must be below entry"}
                </span>
                <span className={potentialProfit >= 0 ? "text-green-500" : "text-red-500"}>
                  Est. profit: {formatPnL(potentialProfit)}
                </span>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Stop Loss */}
      <div className="mb-6">
        <div className="mb-3 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Switch
              checked={enableSL}
              onCheckedChange={setEnableSL}
              className="data-[state=checked]:bg-red-500"
            />
            <Label className="text-sm font-medium">Stop Loss</Label>
          </div>
          {enableSL && (
            <button
              onClick={() => setStopLoss(suggestedSL.toFixed(2))}
              className="text-xs text-amber-500 hover:text-amber-400"
            >
              Suggested: {formatCurrency(suggestedSL)}
            </button>
          )}
        </div>
        {enableSL && (
          <div>
            <Input
              type="number"
              step="0.01"
              placeholder="Stop loss price"
              value={stopLoss}
              onChange={(e) => setStopLoss(e.target.value)}
              className={`bg-zinc-800 border-zinc-700 ${!isSlValid ? "border-red-500" : ""}`}
            />
            {slPrice > 0 && (
              <div className="mt-2 flex items-center justify-between text-xs">
                <span className="text-zinc-500">
                  {position.direction === "long" ? "Price must be below entry" : "Price must be above entry"}
                </span>
                <span className={potentialLoss >= 0 ? "text-green-500" : "text-red-500"}>
                  Est. loss: {formatPnL(potentialLoss)}
                </span>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Risk Summary */}
      {(enableTP || enableSL) && (
        <div className="mb-6 rounded-lg bg-zinc-800/30 p-3">
          <h4 className="mb-2 text-xs font-medium text-zinc-400">Risk Summary</h4>
          <div className="grid grid-cols-2 gap-4 text-sm">
            {enableTP && tpPrice > 0 && (
              <div>
                <span className="text-zinc-500">Max Profit</span>
                <p className="font-medium text-green-500">{formatPnL(potentialProfit)}</p>
              </div>
            )}
            {enableSL && slPrice > 0 && (
              <div>
                <span className="text-zinc-500">Max Loss</span>
                <p className="font-medium text-red-500">{formatPnL(potentialLoss)}</p>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Submit Button */}
      <Button
        onClick={handleSubmit}
        disabled={!isConnected || isSubmitting || !hasChanges || !isTpValid || !isSlValid}
        className="w-full"
      >
        {isSubmitting ? (
          <span className="flex items-center gap-2">
            <span className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
            Updating...
          </span>
        ) : (
          "Update TP/SL"
        )}
      </Button>
    </div>
  );
}
