"use client";

import { useState, useCallback } from "react";
import { useAccount } from "wagmi";
import { Button } from "@/components/ui/button";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";

// Order types matching contract enum
type OrderType = "LIMIT_OPEN" | "TAKE_PROFIT" | "STOP_LOSS";
type OrderStatus = "PENDING" | "EXECUTED" | "CANCELLED" | "EXPIRED";

interface Order {
  id: string;
  orderType: OrderType;
  status: OrderStatus;
  direction: "long" | "short";
  triggerPrice: number;
  collateral: number;
  leverage: number;
  createdAt: Date;
  expiresAt?: Date;
  positionId?: string;
}

interface PendingOrdersListProps {
  orders?: Order[];
  onCancelOrder?: (orderId: string) => void;
  isLoading?: boolean;
}

// Mock data for development
const mockOrders: Order[] = [
  {
    id: "1",
    orderType: "LIMIT_OPEN",
    status: "PENDING",
    direction: "long",
    triggerPrice: 2650.00,
    collateral: 1000,
    leverage: 10,
    createdAt: new Date(Date.now() - 3600000),
  },
  {
    id: "2",
    orderType: "TAKE_PROFIT",
    status: "PENDING",
    direction: "long",
    triggerPrice: 2750.00,
    collateral: 500,
    leverage: 5,
    createdAt: new Date(Date.now() - 7200000),
    positionId: "pos-123",
  },
  {
    id: "3",
    orderType: "STOP_LOSS",
    status: "PENDING",
    direction: "short",
    triggerPrice: 2600.00,
    collateral: 750,
    leverage: 8,
    createdAt: new Date(Date.now() - 1800000),
    positionId: "pos-123",
  },
];

export function PendingOrdersList({
  orders = mockOrders,
  onCancelOrder,
  isLoading = false,
}: PendingOrdersListProps) {
  const { isConnected } = useAccount();
  const [cancellingId, setCancellingId] = useState<string | null>(null);

  const handleCancel = useCallback(async (orderId: string) => {
    setCancellingId(orderId);
    try {
      // Simulate cancellation - in production, this would call the contract
      await new Promise(resolve => setTimeout(resolve, 1500));
      onCancelOrder?.(orderId);
    } catch (error) {
      console.error("Failed to cancel order:", error);
    } finally {
      setCancellingId(null);
    }
  }, [onCancelOrder]);

  const formatCurrency = (value: number) => {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
    }).format(value);
  };

  const formatDate = (date: Date) => {
    return new Intl.DateTimeFormat("en-US", {
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    }).format(date);
  };

  const getOrderTypeBadge = (orderType: OrderType) => {
    switch (orderType) {
      case "LIMIT_OPEN":
        return <Badge variant="outline" className="border-blue-500 text-blue-500">Limit</Badge>;
      case "TAKE_PROFIT":
        return <Badge variant="outline" className="border-green-500 text-green-500">TP</Badge>;
      case "STOP_LOSS":
        return <Badge variant="outline" className="border-red-500 text-red-500">SL</Badge>;
    }
  };

  const getDirectionBadge = (direction: "long" | "short") => {
    return direction === "long" ? (
      <Badge className="bg-green-500/20 text-green-500 hover:bg-green-500/30">Long</Badge>
    ) : (
      <Badge className="bg-red-500/20 text-red-500 hover:bg-red-500/30">Short</Badge>
    );
  };

  const pendingOrders = orders.filter(order => order.status === "PENDING");

  if (!isConnected) {
    return (
      <div className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-6">
        <h3 className="mb-4 text-lg font-semibold">Pending Orders</h3>
        <p className="text-center text-zinc-500">Connect wallet to view orders</p>
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-6">
        <h3 className="mb-4 text-lg font-semibold">Pending Orders</h3>
        <div className="flex items-center justify-center py-8">
          <span className="h-6 w-6 animate-spin rounded-full border-2 border-amber-500 border-t-transparent" />
        </div>
      </div>
    );
  }

  return (
    <div className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-6">
      <div className="mb-4 flex items-center justify-between">
        <h3 className="text-lg font-semibold">Pending Orders</h3>
        <span className="text-sm text-zinc-500">{pendingOrders.length} active</span>
      </div>

      {pendingOrders.length === 0 ? (
        <div className="py-8 text-center">
          <p className="text-zinc-500">No pending orders</p>
          <p className="mt-1 text-sm text-zinc-600">Create a limit order to get started</p>
        </div>
      ) : (
        <div className="overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow className="border-zinc-800 hover:bg-transparent">
                <TableHead className="text-zinc-400">Type</TableHead>
                <TableHead className="text-zinc-400">Direction</TableHead>
                <TableHead className="text-zinc-400">Trigger Price</TableHead>
                <TableHead className="text-zinc-400">Size</TableHead>
                <TableHead className="text-zinc-400">Created</TableHead>
                <TableHead className="text-right text-zinc-400">Action</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {pendingOrders.map((order) => (
                <TableRow key={order.id} className="border-zinc-800 hover:bg-zinc-800/50">
                  <TableCell>{getOrderTypeBadge(order.orderType)}</TableCell>
                  <TableCell>{getDirectionBadge(order.direction)}</TableCell>
                  <TableCell className="font-medium">{formatCurrency(order.triggerPrice)}</TableCell>
                  <TableCell>
                    <div className="flex flex-col">
                      <span className="font-medium">{formatCurrency(order.collateral * order.leverage)}</span>
                      <span className="text-xs text-zinc-500">{order.leverage}x leverage</span>
                    </div>
                  </TableCell>
                  <TableCell className="text-zinc-400">{formatDate(order.createdAt)}</TableCell>
                  <TableCell className="text-right">
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => handleCancel(order.id)}
                      disabled={cancellingId === order.id}
                      className="text-red-500 hover:bg-red-500/10 hover:text-red-400"
                    >
                      {cancellingId === order.id ? (
                        <span className="flex items-center gap-1">
                          <span className="h-3 w-3 animate-spin rounded-full border-2 border-red-500 border-t-transparent" />
                          Cancelling
                        </span>
                      ) : (
                        "Cancel"
                      )}
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}
    </div>
  );
}
