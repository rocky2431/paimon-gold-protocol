"use client";

import { useState, useMemo, useCallback } from "react";
import { useAccount } from "wagmi";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Slider } from "@/components/ui/slider";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";

// Constants
const MIN_LEVERAGE = 2;
const MAX_LEVERAGE = 20;
const MIN_COLLATERAL = 10; // $10 minimum
const TRADING_FEE_RATE = 0.001; // 0.1%
const LIQUIDATION_THRESHOLD = 0.8; // 80% threshold

// Mock price - will be replaced with Chainlink oracle
const MOCK_XAU_PRICE = 2650.0;

type Direction = "long" | "short";

interface PositionCalculation {
  positionSize: number;
  entryPrice: number;
  liquidationPrice: number;
  healthFactor: number;
  tradingFee: number;
  requiredMargin: number;
}

function calculatePosition(
  collateral: number,
  leverage: number,
  direction: Direction,
  currentPrice: number
): PositionCalculation {
  const positionSize = collateral * leverage;
  const entryPrice = currentPrice;
  const tradingFee = positionSize * TRADING_FEE_RATE;
  const requiredMargin = collateral;

  // Calculate liquidation price based on direction
  // Long: liquidation when price drops to where loss = collateral * threshold
  // Short: liquidation when price rises to where loss = collateral * threshold
  const maxLoss = collateral * LIQUIDATION_THRESHOLD;
  const priceMovement = maxLoss / (positionSize / entryPrice);

  const liquidationPrice =
    direction === "long"
      ? entryPrice - priceMovement
      : entryPrice + priceMovement;

  // Health factor = collateral value / required margin
  // At opening, health factor is based on leverage
  const healthFactor = 1 / (1 - 1 / leverage);

  return {
    positionSize,
    entryPrice,
    liquidationPrice,
    healthFactor,
    tradingFee,
    requiredMargin,
  };
}

function formatCurrency(value: number, decimals: number = 2): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(value);
}

function formatNumber(value: number, decimals: number = 2): string {
  return new Intl.NumberFormat("en-US", {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(value);
}

export function TradingPanel() {
  const { isConnected } = useAccount();
  const [direction, setDirection] = useState<Direction>("long");
  const [collateralInput, setCollateralInput] = useState<string>("100");
  const [leverage, setLeverage] = useState<number>(10);
  const [isConfirmOpen, setIsConfirmOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Parse collateral input
  const collateral = useMemo(() => {
    const value = parseFloat(collateralInput);
    return isNaN(value) ? 0 : value;
  }, [collateralInput]);

  // Calculate position details
  const position = useMemo(() => {
    if (collateral < MIN_COLLATERAL) {
      return null;
    }
    return calculatePosition(collateral, leverage, direction, MOCK_XAU_PRICE);
  }, [collateral, leverage, direction]);

  // Validation
  const isValid = useMemo(() => {
    return (
      isConnected &&
      collateral >= MIN_COLLATERAL &&
      leverage >= MIN_LEVERAGE &&
      leverage <= MAX_LEVERAGE
    );
  }, [isConnected, collateral, leverage]);

  // Handle collateral input change
  const handleCollateralChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const value = e.target.value;
      // Allow empty, numbers, and one decimal point
      if (value === "" || /^\d*\.?\d*$/.test(value)) {
        setCollateralInput(value);
      }
    },
    []
  );

  // Handle leverage change
  const handleLeverageChange = useCallback((value: number[]) => {
    setLeverage(value[0]);
  }, []);

  // Handle open position
  const handleOpenPosition = useCallback(async () => {
    if (!isValid || !position) return;

    setIsSubmitting(true);
    try {
      // TODO: Integrate with smart contract
      // For now, simulate transaction
      await new Promise((resolve) => setTimeout(resolve, 2000));
      setIsConfirmOpen(false);
      // Reset form or show success
    } catch (error) {
      console.error("Failed to open position:", error);
    } finally {
      setIsSubmitting(false);
    }
  }, [isValid, position]);

  // Get health factor color
  const getHealthFactorColor = (hf: number) => {
    if (hf >= 2) return "text-green-500";
    if (hf >= 1.5) return "text-amber-500";
    return "text-red-500";
  };

  return (
    <div className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-6">
      {/* Direction Toggle */}
      <div className="mb-6 grid grid-cols-2 gap-2">
        <Button
          variant={direction === "long" ? "default" : "outline"}
          className={
            direction === "long"
              ? "bg-green-600 hover:bg-green-700"
              : "border-zinc-700"
          }
          onClick={() => setDirection("long")}
        >
          <span className="mr-2">↗</span> Long
        </Button>
        <Button
          variant={direction === "short" ? "default" : "outline"}
          className={
            direction === "short"
              ? "bg-red-600 hover:bg-red-700"
              : "border-zinc-700"
          }
          onClick={() => setDirection("short")}
        >
          <span className="mr-2">↘</span> Short
        </Button>
      </div>

      {/* Current Price Display */}
      <div className="mb-6 rounded-lg bg-zinc-800/50 p-4">
        <div className="flex items-center justify-between">
          <span className="text-sm text-zinc-400">XAU/USD</span>
          <div className="flex items-center gap-2">
            <span className="text-xl font-bold text-amber-500">
              {formatCurrency(MOCK_XAU_PRICE)}
            </span>
            <span className="rounded bg-green-500/20 px-2 py-0.5 text-xs text-green-500">
              LIVE
            </span>
          </div>
        </div>
      </div>

      {/* Collateral Input */}
      <div className="mb-6">
        <Label htmlFor="collateral" className="mb-2 block">
          Collateral (USDT)
        </Label>
        <div className="relative">
          <span className="absolute left-3 top-1/2 -translate-y-1/2 text-zinc-500">
            $
          </span>
          <Input
            id="collateral"
            type="text"
            inputMode="decimal"
            value={collateralInput}
            onChange={handleCollateralChange}
            className="pl-7 pr-16"
            placeholder="0.00"
          />
          <span className="absolute right-3 top-1/2 -translate-y-1/2 text-zinc-500">
            USDT
          </span>
        </div>
        {collateral > 0 && collateral < MIN_COLLATERAL && (
          <p className="mt-1 text-xs text-red-500">
            Minimum collateral is ${MIN_COLLATERAL}
          </p>
        )}
      </div>

      {/* Leverage Slider */}
      <div className="mb-6">
        <div className="mb-2 flex items-center justify-between">
          <Label>Leverage</Label>
          <span className="text-lg font-bold text-amber-500">{leverage}x</span>
        </div>
        <Slider
          value={[leverage]}
          onValueChange={handleLeverageChange}
          min={MIN_LEVERAGE}
          max={MAX_LEVERAGE}
          step={1}
          className="mb-2"
        />
        <div className="flex justify-between text-xs text-zinc-500">
          <span>{MIN_LEVERAGE}x</span>
          <span>{MAX_LEVERAGE}x</span>
        </div>
        {/* Leverage markers */}
        <div className="mt-2 flex justify-between">
          {[2, 5, 10, 15, 20].map((val) => (
            <button
              key={val}
              onClick={() => setLeverage(val)}
              className={`rounded px-2 py-1 text-xs transition-colors ${
                leverage === val
                  ? "bg-amber-500 text-black"
                  : "bg-zinc-800 text-zinc-400 hover:bg-zinc-700"
              }`}
            >
              {val}x
            </button>
          ))}
        </div>
      </div>

      {/* Position Details */}
      {position && (
        <div className="mb-6 space-y-3 rounded-lg bg-zinc-800/50 p-4">
          <div className="flex justify-between text-sm">
            <span className="text-zinc-400">Position Size</span>
            <span className="font-medium">
              {formatCurrency(position.positionSize)}
            </span>
          </div>
          <div className="flex justify-between text-sm">
            <span className="text-zinc-400">Entry Price</span>
            <span className="font-medium">
              {formatCurrency(position.entryPrice)}
            </span>
          </div>
          <div className="flex justify-between text-sm">
            <span className="text-zinc-400">Liquidation Price</span>
            <span
              className={`font-medium ${direction === "long" ? "text-red-500" : "text-red-500"}`}
            >
              {formatCurrency(position.liquidationPrice)}
            </span>
          </div>
          <div className="flex justify-between text-sm">
            <span className="text-zinc-400">Health Factor</span>
            <span
              className={`font-medium ${getHealthFactorColor(position.healthFactor)}`}
            >
              {formatNumber(position.healthFactor)}
            </span>
          </div>
          <div className="border-t border-zinc-700 pt-3">
            <div className="flex justify-between text-sm">
              <span className="text-zinc-400">Trading Fee (0.1%)</span>
              <span className="font-medium">
                {formatCurrency(position.tradingFee)}
              </span>
            </div>
          </div>
        </div>
      )}

      {/* Open Position Button */}
      <Button
        className="w-full"
        size="lg"
        disabled={!isValid}
        onClick={() => setIsConfirmOpen(true)}
      >
        {!isConnected
          ? "Connect Wallet"
          : !isValid
            ? `Enter at least $${MIN_COLLATERAL}`
            : `Open ${direction === "long" ? "Long" : "Short"} Position`}
      </Button>

      {/* Confirmation Dialog */}
      <Dialog open={isConfirmOpen} onOpenChange={setIsConfirmOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Confirm Trade</DialogTitle>
          </DialogHeader>
          {position && (
            <div className="space-y-4 py-4">
              <div
                className={`rounded-lg p-4 ${direction === "long" ? "bg-green-500/10" : "bg-red-500/10"}`}
              >
                <div className="mb-2 flex items-center justify-between">
                  <span className="text-lg font-bold">
                    {direction === "long" ? "↗ LONG" : "↘ SHORT"} XAU/USD
                  </span>
                  <span className="text-lg font-bold">{leverage}x</span>
                </div>
              </div>

              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-zinc-400">Collateral</span>
                  <span>{formatCurrency(collateral)} USDT</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-zinc-400">Position Size</span>
                  <span>{formatCurrency(position.positionSize)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-zinc-400">Entry Price</span>
                  <span>{formatCurrency(position.entryPrice)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-zinc-400">Liquidation Price</span>
                  <span className="text-red-500">
                    {formatCurrency(position.liquidationPrice)}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-zinc-400">Trading Fee</span>
                  <span>{formatCurrency(position.tradingFee)}</span>
                </div>
              </div>

              <div className="rounded-lg bg-amber-500/10 p-3 text-xs text-amber-500">
                ⚠️ Leveraged trading involves significant risk. You may lose
                your entire collateral if the market moves against your
                position.
              </div>
            </div>
          )}
          <DialogFooter className="gap-2 sm:gap-0">
            <Button
              variant="outline"
              onClick={() => setIsConfirmOpen(false)}
              disabled={isSubmitting}
            >
              Cancel
            </Button>
            <Button
              className={
                direction === "long"
                  ? "bg-green-600 hover:bg-green-700"
                  : "bg-red-600 hover:bg-red-700"
              }
              onClick={handleOpenPosition}
              disabled={isSubmitting}
            >
              {isSubmitting ? "Confirming..." : "Confirm Trade"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
