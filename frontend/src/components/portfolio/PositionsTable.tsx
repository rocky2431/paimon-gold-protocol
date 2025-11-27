"use client";

import { useState, useMemo } from "react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";

// Types
export interface Position {
  id: string;
  direction: "long" | "short";
  collateral: number;
  leverage: number;
  entryPrice: number;
  size: number;
  openedAt: Date;
  liquidationPrice: number;
}

interface PositionsTableProps {
  positions: Position[];
  currentPrice: number;
  onClosePosition: (positionId: string) => Promise<void>;
}

// Calculate PnL for a position
function calculatePnL(
  position: Position,
  currentPrice: number
): { pnl: number; pnlPercent: number; healthFactor: number } {
  const { direction, entryPrice, size, collateral } = position;

  // Calculate price change
  const priceChange = currentPrice - entryPrice;
  const priceChangePercent = priceChange / entryPrice;

  // Calculate PnL based on direction
  let pnl: number;
  if (direction === "long") {
    pnl = (priceChangePercent * size);
  } else {
    pnl = (-priceChangePercent * size);
  }

  const pnlPercent = (pnl / collateral) * 100;

  // Calculate health factor
  const currentCollateralValue = collateral + pnl;
  const requiredMargin = size * 0.05; // 5% minimum margin
  const healthFactor = currentCollateralValue / requiredMargin;

  return { pnl, pnlPercent, healthFactor: Math.max(0, healthFactor) };
}

// Format helpers
function formatCurrency(value: number, decimals: number = 2): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(value);
}

function formatPercent(value: number): string {
  const prefix = value >= 0 ? "+" : "";
  return `${prefix}${value.toFixed(2)}%`;
}

function formatNumber(value: number, decimals: number = 2): string {
  return new Intl.NumberFormat("en-US", {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(value);
}

function getHealthFactorColor(hf: number): string {
  if (hf >= 2) return "text-green-500";
  if (hf >= 1.5) return "text-amber-500";
  if (hf >= 1.2) return "text-orange-500";
  return "text-red-500";
}

function getPnLColor(pnl: number): string {
  if (pnl > 0) return "text-green-500";
  if (pnl < 0) return "text-red-500";
  return "text-zinc-400";
}

// Position Row Component
function PositionRow({
  position,
  currentPrice,
  onClose,
}: {
  position: Position;
  currentPrice: number;
  onClose: () => void;
}) {
  const { pnl, pnlPercent, healthFactor } = useMemo(
    () => calculatePnL(position, currentPrice),
    [position, currentPrice]
  );

  return (
    <tr className="border-b border-zinc-800 hover:bg-zinc-800/50">
      {/* Direction & Asset */}
      <td className="px-4 py-4">
        <div className="flex items-center gap-2">
          <span
            className={`rounded px-2 py-1 text-xs font-medium ${
              position.direction === "long"
                ? "bg-green-500/20 text-green-500"
                : "bg-red-500/20 text-red-500"
            }`}
          >
            {position.direction === "long" ? "↗ LONG" : "↘ SHORT"}
          </span>
          <span className="font-medium">XAU/USD</span>
        </div>
      </td>

      {/* Size */}
      <td className="px-4 py-4 text-right">
        <div className="text-sm">{formatCurrency(position.size)}</div>
        <div className="text-xs text-zinc-500">{position.leverage}x</div>
      </td>

      {/* Collateral */}
      <td className="px-4 py-4 text-right">
        <div className="text-sm">{formatCurrency(position.collateral)}</div>
      </td>

      {/* Entry Price */}
      <td className="px-4 py-4 text-right">
        <div className="text-sm">{formatCurrency(position.entryPrice)}</div>
      </td>

      {/* Current Price */}
      <td className="px-4 py-4 text-right">
        <div className="text-sm">{formatCurrency(currentPrice)}</div>
      </td>

      {/* PnL */}
      <td className="px-4 py-4 text-right">
        <div className={`text-sm font-medium ${getPnLColor(pnl)}`}>
          {formatCurrency(pnl)}
        </div>
        <div className={`text-xs ${getPnLColor(pnlPercent)}`}>
          {formatPercent(pnlPercent)}
        </div>
      </td>

      {/* Health Factor */}
      <td className="px-4 py-4 text-right">
        <span className={`font-medium ${getHealthFactorColor(healthFactor)}`}>
          {formatNumber(healthFactor)}
        </span>
      </td>

      {/* Liquidation Price */}
      <td className="px-4 py-4 text-right">
        <div className="text-sm text-red-500">
          {formatCurrency(position.liquidationPrice)}
        </div>
      </td>

      {/* Actions */}
      <td className="px-4 py-4 text-right">
        <Button variant="outline" size="sm" onClick={onClose}>
          Close
        </Button>
      </td>
    </tr>
  );
}

// Main Component
export function PositionsTable({
  positions,
  currentPrice,
  onClosePosition,
}: PositionsTableProps) {
  const [closingPosition, setClosingPosition] = useState<Position | null>(null);
  const [isClosing, setIsClosing] = useState(false);

  const handleClose = async () => {
    if (!closingPosition) return;

    setIsClosing(true);
    try {
      await onClosePosition(closingPosition.id);
      setClosingPosition(null);
    } catch (error) {
      console.error("Failed to close position:", error);
    } finally {
      setIsClosing(false);
    }
  };

  // Calculate total PnL
  const totalPnL = useMemo(() => {
    return positions.reduce((sum, pos) => {
      const { pnl } = calculatePnL(pos, currentPrice);
      return sum + pnl;
    }, 0);
  }, [positions, currentPrice]);

  // Calculate total collateral
  const totalCollateral = useMemo(() => {
    return positions.reduce((sum, pos) => sum + pos.collateral, 0);
  }, [positions]);

  // Calculate total equity
  const totalEquity = totalCollateral + totalPnL;

  if (positions.length === 0) {
    return (
      <div className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-8">
        <div className="flex flex-col items-center justify-center text-center">
          <svg
            className="mb-4 h-16 w-16 text-zinc-600"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={1.5}
              d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"
            />
          </svg>
          <h3 className="mb-2 text-lg font-medium text-zinc-300">
            No Open Positions
          </h3>
          <p className="text-zinc-500">
            Open a position on the{" "}
            <a href="/trade" className="text-amber-500 hover:underline">
              Trade page
            </a>{" "}
            to get started.
          </p>
        </div>
      </div>
    );
  }

  return (
    <>
      {/* Summary Cards */}
      <div className="mb-6 grid gap-4 sm:grid-cols-3">
        <div className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-4">
          <p className="text-sm text-zinc-500">Total Collateral</p>
          <p className="text-xl font-bold">{formatCurrency(totalCollateral)}</p>
        </div>
        <div className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-4">
          <p className="text-sm text-zinc-500">Unrealized PnL</p>
          <p className={`text-xl font-bold ${getPnLColor(totalPnL)}`}>
            {formatCurrency(totalPnL)}
          </p>
        </div>
        <div className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-4">
          <p className="text-sm text-zinc-500">Total Equity</p>
          <p className="text-xl font-bold">{formatCurrency(totalEquity)}</p>
        </div>
      </div>

      {/* Positions Table */}
      <div className="overflow-x-auto rounded-xl border border-zinc-800 bg-zinc-900/50">
        <table className="w-full min-w-[900px]">
          <thead>
            <tr className="border-b border-zinc-800 text-left text-sm text-zinc-500">
              <th className="px-4 py-3 font-medium">Position</th>
              <th className="px-4 py-3 text-right font-medium">Size</th>
              <th className="px-4 py-3 text-right font-medium">Collateral</th>
              <th className="px-4 py-3 text-right font-medium">Entry</th>
              <th className="px-4 py-3 text-right font-medium">Current</th>
              <th className="px-4 py-3 text-right font-medium">PnL</th>
              <th className="px-4 py-3 text-right font-medium">Health</th>
              <th className="px-4 py-3 text-right font-medium">Liq. Price</th>
              <th className="px-4 py-3 text-right font-medium">Action</th>
            </tr>
          </thead>
          <tbody>
            {positions.map((position) => (
              <PositionRow
                key={position.id}
                position={position}
                currentPrice={currentPrice}
                onClose={() => setClosingPosition(position)}
              />
            ))}
          </tbody>
        </table>
      </div>

      {/* Close Position Dialog */}
      <Dialog
        open={!!closingPosition}
        onOpenChange={() => setClosingPosition(null)}
      >
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Close Position</DialogTitle>
          </DialogHeader>
          {closingPosition && (
            <div className="space-y-4 py-4">
              <div
                className={`rounded-lg p-4 ${
                  closingPosition.direction === "long"
                    ? "bg-green-500/10"
                    : "bg-red-500/10"
                }`}
              >
                <div className="mb-2 flex items-center justify-between">
                  <span className="text-lg font-bold">
                    {closingPosition.direction === "long" ? "↗ LONG" : "↘ SHORT"}{" "}
                    XAU/USD
                  </span>
                  <span className="text-lg font-bold">
                    {closingPosition.leverage}x
                  </span>
                </div>
              </div>

              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-zinc-400">Position Size</span>
                  <span>{formatCurrency(closingPosition.size)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-zinc-400">Collateral</span>
                  <span>{formatCurrency(closingPosition.collateral)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-zinc-400">Entry Price</span>
                  <span>{formatCurrency(closingPosition.entryPrice)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-zinc-400">Current Price</span>
                  <span>{formatCurrency(currentPrice)}</span>
                </div>

                {(() => {
                  const { pnl, pnlPercent } = calculatePnL(
                    closingPosition,
                    currentPrice
                  );
                  return (
                    <div className="flex justify-between border-t border-zinc-700 pt-2">
                      <span className="text-zinc-400">Realized PnL</span>
                      <span className={`font-medium ${getPnLColor(pnl)}`}>
                        {formatCurrency(pnl)} ({formatPercent(pnlPercent)})
                      </span>
                    </div>
                  );
                })()}
              </div>

              <div className="rounded-lg bg-amber-500/10 p-3 text-xs text-amber-500">
                ⚠️ Closing this position will realize your PnL and return your
                remaining collateral to your wallet.
              </div>
            </div>
          )}
          <DialogFooter className="gap-2 sm:gap-0">
            <Button
              variant="outline"
              onClick={() => setClosingPosition(null)}
              disabled={isClosing}
            >
              Cancel
            </Button>
            <Button
              variant="destructive"
              onClick={handleClose}
              disabled={isClosing}
            >
              {isClosing ? "Closing..." : "Close Position"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
