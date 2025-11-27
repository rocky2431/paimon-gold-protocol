"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";

type OrderType = "LIMIT_OPEN" | "TAKE_PROFIT" | "STOP_LOSS";
type OrderStatus = "PENDING" | "EXECUTED" | "CANCELLED" | "EXPIRED";

interface HistoricalOrder {
  id: string;
  orderType: OrderType;
  status: OrderStatus;
  direction: "long" | "short";
  triggerPrice: number;
  executionPrice?: number;
  collateral: number;
  leverage: number;
  createdAt: Date;
  executedAt?: Date;
}

interface OrderHistoryProps {
  orders?: HistoricalOrder[];
  isLoading?: boolean;
}

// Mock data for development
const mockHistory: HistoricalOrder[] = [
  {
    id: "h1",
    orderType: "LIMIT_OPEN",
    status: "EXECUTED",
    direction: "long",
    triggerPrice: 2600.00,
    executionPrice: 2599.50,
    collateral: 1000,
    leverage: 10,
    createdAt: new Date(Date.now() - 86400000),
    executedAt: new Date(Date.now() - 82800000),
  },
  {
    id: "h2",
    orderType: "TAKE_PROFIT",
    status: "EXECUTED",
    direction: "long",
    triggerPrice: 2700.00,
    executionPrice: 2701.25,
    collateral: 500,
    leverage: 5,
    createdAt: new Date(Date.now() - 172800000),
    executedAt: new Date(Date.now() - 86400000),
  },
  {
    id: "h3",
    orderType: "LIMIT_OPEN",
    status: "CANCELLED",
    direction: "short",
    triggerPrice: 2550.00,
    collateral: 750,
    leverage: 8,
    createdAt: new Date(Date.now() - 259200000),
  },
  {
    id: "h4",
    orderType: "STOP_LOSS",
    status: "EXPIRED",
    direction: "long",
    triggerPrice: 2500.00,
    collateral: 1200,
    leverage: 15,
    createdAt: new Date(Date.now() - 604800000),
  },
];

export function OrderHistory({
  orders = mockHistory,
  isLoading = false,
}: OrderHistoryProps) {
  const { isConnected } = useAccount();
  const [filter, setFilter] = useState<OrderStatus | "ALL">("ALL");

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

  const getStatusBadge = (status: OrderStatus) => {
    switch (status) {
      case "EXECUTED":
        return <Badge className="bg-green-500/20 text-green-500">Executed</Badge>;
      case "CANCELLED":
        return <Badge className="bg-zinc-500/20 text-zinc-400">Cancelled</Badge>;
      case "EXPIRED":
        return <Badge className="bg-amber-500/20 text-amber-500">Expired</Badge>;
      default:
        return <Badge className="bg-blue-500/20 text-blue-500">Pending</Badge>;
    }
  };

  const getDirectionBadge = (direction: "long" | "short") => {
    return direction === "long" ? (
      <Badge variant="outline" className="border-green-500/50 text-green-500">Long</Badge>
    ) : (
      <Badge variant="outline" className="border-red-500/50 text-red-500">Short</Badge>
    );
  };

  // Filter orders (exclude pending - those are shown in PendingOrdersList)
  const historicalOrders = orders.filter(order => order.status !== "PENDING");
  const filteredOrders = filter === "ALL"
    ? historicalOrders
    : historicalOrders.filter(order => order.status === filter);

  // Count by status
  const statusCounts = {
    ALL: historicalOrders.length,
    EXECUTED: historicalOrders.filter(o => o.status === "EXECUTED").length,
    CANCELLED: historicalOrders.filter(o => o.status === "CANCELLED").length,
    EXPIRED: historicalOrders.filter(o => o.status === "EXPIRED").length,
  };

  if (!isConnected) {
    return (
      <div className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-6">
        <h3 className="mb-4 text-lg font-semibold">Order History</h3>
        <p className="text-center text-zinc-500">Connect wallet to view history</p>
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-6">
        <h3 className="mb-4 text-lg font-semibold">Order History</h3>
        <div className="flex items-center justify-center py-8">
          <span className="h-6 w-6 animate-spin rounded-full border-2 border-amber-500 border-t-transparent" />
        </div>
      </div>
    );
  }

  return (
    <div className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-6">
      <div className="mb-4 flex items-center justify-between">
        <h3 className="text-lg font-semibold">Order History</h3>
        <span className="text-sm text-zinc-500">{historicalOrders.length} orders</span>
      </div>

      {/* Filter Buttons */}
      <div className="mb-4 flex gap-2">
        {(["ALL", "EXECUTED", "CANCELLED", "EXPIRED"] as const).map((status) => (
          <Button
            key={status}
            variant="ghost"
            size="sm"
            onClick={() => setFilter(status)}
            className={`text-xs ${
              filter === status
                ? "bg-zinc-800 text-white"
                : "text-zinc-400 hover:text-white"
            }`}
          >
            {status === "ALL" ? "All" : status.charAt(0) + status.slice(1).toLowerCase()}
            <span className="ml-1 text-zinc-500">({statusCounts[status]})</span>
          </Button>
        ))}
      </div>

      {filteredOrders.length === 0 ? (
        <div className="py-8 text-center">
          <p className="text-zinc-500">No orders in history</p>
        </div>
      ) : (
        <div className="overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow className="border-zinc-800 hover:bg-transparent">
                <TableHead className="text-zinc-400">Type</TableHead>
                <TableHead className="text-zinc-400">Status</TableHead>
                <TableHead className="text-zinc-400">Direction</TableHead>
                <TableHead className="text-zinc-400">Trigger</TableHead>
                <TableHead className="text-zinc-400">Execution</TableHead>
                <TableHead className="text-zinc-400">Size</TableHead>
                <TableHead className="text-zinc-400">Date</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filteredOrders.map((order) => (
                <TableRow key={order.id} className="border-zinc-800 hover:bg-zinc-800/50">
                  <TableCell>{getOrderTypeBadge(order.orderType)}</TableCell>
                  <TableCell>{getStatusBadge(order.status)}</TableCell>
                  <TableCell>{getDirectionBadge(order.direction)}</TableCell>
                  <TableCell className="font-medium">{formatCurrency(order.triggerPrice)}</TableCell>
                  <TableCell>
                    {order.executionPrice ? (
                      <span className="font-medium">{formatCurrency(order.executionPrice)}</span>
                    ) : (
                      <span className="text-zinc-500">-</span>
                    )}
                  </TableCell>
                  <TableCell>
                    <div className="flex flex-col">
                      <span className="font-medium">{formatCurrency(order.collateral * order.leverage)}</span>
                      <span className="text-xs text-zinc-500">{order.leverage}x</span>
                    </div>
                  </TableCell>
                  <TableCell className="text-zinc-400">
                    <div className="flex flex-col">
                      <span>{formatDate(order.createdAt)}</span>
                      {order.executedAt && (
                        <span className="text-xs text-green-500">
                          Filled: {formatDate(order.executedAt)}
                        </span>
                      )}
                    </div>
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
