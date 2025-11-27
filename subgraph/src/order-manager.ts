import { BigInt, BigDecimal, Bytes, log } from "@graphprotocol/graph-ts";
import {
  OrderCreated as OrderCreatedEvent,
  OrderExecuted as OrderExecutedEvent,
  OrderCancelled as OrderCancelledEvent,
  OrderExpired as OrderExpiredEvent,
} from "../generated/OrderManager/OrderManager";
import { Order, User } from "../generated/schema";

// Constants
const DECIMAL_FACTOR = BigDecimal.fromString("1000000000000000000");

// Helper functions
function getOrCreateUser(address: Bytes): User {
  let user = User.load(address.toHexString());
  if (user == null) {
    user = new User(address.toHexString());
    user.totalPositions = BigInt.zero();
    user.openPositions = BigInt.zero();
    user.totalVolume = BigDecimal.zero();
    user.totalPnL = BigDecimal.zero();
    user.totalFeesPaid = BigDecimal.zero();
    user.liquidationCount = BigInt.zero();
    user.createdAt = BigInt.zero();
    user.updatedAt = BigInt.zero();
  }
  return user;
}

function toDecimal(value: BigInt): BigDecimal {
  return value.toBigDecimal().div(DECIMAL_FACTOR);
}

function getOrderTypeString(orderType: i32): string {
  if (orderType == 0) return "LIMIT";
  if (orderType == 1) return "STOP_LOSS";
  if (orderType == 2) return "TAKE_PROFIT";
  return "LIMIT";
}

function getDirectionString(direction: i32): string {
  if (direction == 0) return "LONG";
  return "SHORT";
}

// Event handlers
export function handleOrderCreated(event: OrderCreatedEvent): void {
  let orderId = event.params.orderId.toString();
  let traderAddress = event.params.trader;

  // Create/update user
  let user = getOrCreateUser(traderAddress);
  if (user.createdAt.equals(BigInt.zero())) {
    user.createdAt = event.block.timestamp;
  }
  user.updatedAt = event.block.timestamp;
  user.save();

  // Create order
  let order = new Order(orderId);
  order.trader = user.id;
  order.orderType = getOrderTypeString(event.params.orderType);
  order.status = "PENDING";
  order.direction = getDirectionString(event.params.direction);
  order.triggerPrice = toDecimal(event.params.triggerPrice);
  order.collateral = toDecimal(event.params.collateral);
  order.leverage = event.params.leverage;
  order.createdAt = event.block.timestamp;
  order.expiresAt = event.params.expiresAt;
  order.txHash = event.transaction.hash;
  order.save();

  log.info("Order created: {} by {}", [orderId, traderAddress.toHexString()]);
}

export function handleOrderExecuted(event: OrderExecutedEvent): void {
  let orderId = event.params.orderId.toString();
  let order = Order.load(orderId);

  if (order == null) {
    log.warning("Order not found: {}", [orderId]);
    return;
  }

  order.status = "EXECUTED";
  order.executedAt = event.block.timestamp;
  order.executionTxHash = event.transaction.hash;
  order.save();

  log.info("Order executed: {} at price {}", [orderId, toDecimal(event.params.executionPrice).toString()]);
}

export function handleOrderCancelled(event: OrderCancelledEvent): void {
  let orderId = event.params.orderId.toString();
  let order = Order.load(orderId);

  if (order == null) {
    log.warning("Order not found: {}", [orderId]);
    return;
  }

  order.status = "CANCELLED";
  order.cancelledAt = event.block.timestamp;
  order.save();

  log.info("Order cancelled: {}", [orderId]);
}

export function handleOrderExpired(event: OrderExpiredEvent): void {
  let orderId = event.params.orderId.toString();
  let order = Order.load(orderId);

  if (order == null) {
    log.warning("Order not found: {}", [orderId]);
    return;
  }

  order.status = "EXPIRED";
  order.save();

  log.info("Order expired: {}", [orderId]);
}
