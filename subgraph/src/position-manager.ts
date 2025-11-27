import { BigInt, BigDecimal, Bytes, log } from "@graphprotocol/graph-ts";
import {
  PositionOpened as PositionOpenedEvent,
  PositionClosed as PositionClosedEvent,
  PositionPartialClosed as PositionPartialClosedEvent,
  MarginAdded as MarginAddedEvent,
  MarginRemoved as MarginRemovedEvent,
} from "../generated/PositionManager/PositionManager";
import {
  Position,
  PartialClose,
  User,
  Protocol,
  DailyStats,
} from "../generated/schema";

// Constants
const PROTOCOL_ID = "protocol";
const DECIMALS = BigInt.fromI32(18);
const DECIMAL_FACTOR = BigDecimal.fromString("1000000000000000000");

// Helper functions
function getOrCreateProtocol(): Protocol {
  let protocol = Protocol.load(PROTOCOL_ID);
  if (protocol == null) {
    protocol = new Protocol(PROTOCOL_ID);
    protocol.totalPositions = BigInt.zero();
    protocol.totalVolume = BigDecimal.zero();
    protocol.totalFees = BigDecimal.zero();
    protocol.totalLiquidations = BigInt.zero();
    protocol.totalLiquidityProviders = BigInt.zero();
    protocol.totalValueLocked = BigDecimal.zero();
    protocol.updatedAt = BigInt.zero();
  }
  return protocol;
}

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

function getDayId(timestamp: BigInt): string {
  let dayTimestamp = timestamp.toI32() / 86400;
  return dayTimestamp.toString();
}

function getOrCreateDailyStats(timestamp: BigInt): DailyStats {
  let dayId = getDayId(timestamp);
  let stats = DailyStats.load(dayId);
  if (stats == null) {
    stats = new DailyStats(dayId);
    stats.date = timestamp;
    stats.volume = BigDecimal.zero();
    stats.fees = BigDecimal.zero();
    stats.positionsOpened = BigInt.zero();
    stats.positionsClosed = BigInt.zero();
    stats.liquidations = BigInt.zero();
    stats.liquidityAdded = BigDecimal.zero();
    stats.liquidityRemoved = BigDecimal.zero();
    stats.uniqueTraders = BigInt.zero();
  }
  return stats;
}

function toDecimal(value: BigInt): BigDecimal {
  return value.toBigDecimal().div(DECIMAL_FACTOR);
}

// Event handlers
export function handlePositionOpened(event: PositionOpenedEvent): void {
  let positionId = event.params.positionId.toString();
  let traderAddress = event.params.trader;

  // Create/update user
  let user = getOrCreateUser(traderAddress);
  user.totalPositions = user.totalPositions.plus(BigInt.fromI32(1));
  user.openPositions = user.openPositions.plus(BigInt.fromI32(1));
  user.updatedAt = event.block.timestamp;
  if (user.createdAt.equals(BigInt.zero())) {
    user.createdAt = event.block.timestamp;
  }
  user.save();

  // Create position
  let position = new Position(positionId);
  position.trader = user.id;
  position.direction = event.params.direction == 0 ? "LONG" : "SHORT";
  position.status = "OPEN";
  position.collateral = toDecimal(event.params.collateral);
  position.leverage = event.params.leverage;
  position.entryPrice = toDecimal(event.params.entryPrice);
  position.size = toDecimal(event.params.size);

  // Calculate liquidation price (simplified)
  let maintenanceMargin = position.collateral.times(BigDecimal.fromString("0.05"));
  if (position.direction == "LONG") {
    position.liquidationPrice = position.entryPrice.times(
      BigDecimal.fromString("1").minus(maintenanceMargin.div(position.size))
    );
  } else {
    position.liquidationPrice = position.entryPrice.times(
      BigDecimal.fromString("1").plus(maintenanceMargin.div(position.size))
    );
  }

  position.fees = BigDecimal.zero();
  position.marginAdded = BigDecimal.zero();
  position.marginRemoved = BigDecimal.zero();
  position.openedAt = event.block.timestamp;
  position.openTxHash = event.transaction.hash;
  position.save();

  // Update protocol stats
  let protocol = getOrCreateProtocol();
  protocol.totalPositions = protocol.totalPositions.plus(BigInt.fromI32(1));
  protocol.totalVolume = protocol.totalVolume.plus(position.size);
  protocol.updatedAt = event.block.timestamp;
  protocol.save();

  // Update daily stats
  let dailyStats = getOrCreateDailyStats(event.block.timestamp);
  dailyStats.positionsOpened = dailyStats.positionsOpened.plus(BigInt.fromI32(1));
  dailyStats.volume = dailyStats.volume.plus(position.size);
  dailyStats.save();

  log.info("Position opened: {} by {}", [positionId, traderAddress.toHexString()]);
}

export function handlePositionClosed(event: PositionClosedEvent): void {
  let positionId = event.params.positionId.toString();
  let position = Position.load(positionId);

  if (position == null) {
    log.warning("Position not found: {}", [positionId]);
    return;
  }

  let traderAddress = event.params.trader;
  let user = getOrCreateUser(traderAddress);

  // Update position
  position.status = "CLOSED";
  position.exitPrice = toDecimal(event.params.exitPrice);
  position.realizedPnL = toDecimal(event.params.pnl);
  position.closedAt = event.block.timestamp;
  position.closeTxHash = event.transaction.hash;
  position.save();

  // Update user stats
  user.openPositions = user.openPositions.minus(BigInt.fromI32(1));
  user.totalPnL = user.totalPnL.plus(position.realizedPnL!);
  user.updatedAt = event.block.timestamp;
  user.save();

  // Update daily stats
  let dailyStats = getOrCreateDailyStats(event.block.timestamp);
  dailyStats.positionsClosed = dailyStats.positionsClosed.plus(BigInt.fromI32(1));
  dailyStats.save();

  log.info("Position closed: {} with PnL: {}", [positionId, position.realizedPnL!.toString()]);
}

export function handlePositionPartialClosed(event: PositionPartialClosedEvent): void {
  let positionId = event.params.positionId.toString();
  let position = Position.load(positionId);

  if (position == null) {
    log.warning("Position not found: {}", [positionId]);
    return;
  }

  let traderAddress = event.params.trader;

  // Create partial close record
  let partialCloseId = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let partialClose = new PartialClose(partialCloseId);
  partialClose.position = positionId;
  partialClose.trader = traderAddress.toHexString();
  partialClose.amount = toDecimal(event.params.amount);
  partialClose.exitPrice = toDecimal(event.params.exitPrice);
  partialClose.pnl = toDecimal(event.params.pnl);
  partialClose.timestamp = event.block.timestamp;
  partialClose.txHash = event.transaction.hash;
  partialClose.save();

  // Update position status
  position.status = "PARTIALLY_CLOSED";
  position.size = position.size.minus(partialClose.amount);
  position.save();

  // Update user PnL
  let user = getOrCreateUser(traderAddress);
  user.totalPnL = user.totalPnL.plus(partialClose.pnl);
  user.updatedAt = event.block.timestamp;
  user.save();

  log.info("Position partially closed: {} amount: {}", [positionId, partialClose.amount.toString()]);
}

export function handleMarginAdded(event: MarginAddedEvent): void {
  let positionId = event.params.positionId.toString();
  let position = Position.load(positionId);

  if (position == null) {
    log.warning("Position not found: {}", [positionId]);
    return;
  }

  let addedAmount = toDecimal(event.params.amount);
  position.collateral = position.collateral.plus(addedAmount);
  position.marginAdded = position.marginAdded.plus(addedAmount);
  position.save();

  log.info("Margin added to position: {} amount: {}", [positionId, addedAmount.toString()]);
}

export function handleMarginRemoved(event: MarginRemovedEvent): void {
  let positionId = event.params.positionId.toString();
  let position = Position.load(positionId);

  if (position == null) {
    log.warning("Position not found: {}", [positionId]);
    return;
  }

  let removedAmount = toDecimal(event.params.amount);
  position.collateral = position.collateral.minus(removedAmount);
  position.marginRemoved = position.marginRemoved.plus(removedAmount);
  position.save();

  log.info("Margin removed from position: {} amount: {}", [positionId, removedAmount.toString()]);
}
