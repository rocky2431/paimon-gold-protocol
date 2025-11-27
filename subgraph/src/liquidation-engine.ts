import { BigInt, BigDecimal, Bytes, log } from "@graphprotocol/graph-ts";
import {
  PositionLiquidated as PositionLiquidatedEvent,
  PartialLiquidation as PartialLiquidationEvent,
} from "../generated/LiquidationEngine/LiquidationEngine";
import {
  Liquidation,
  Position,
  User,
  Protocol,
  DailyStats,
} from "../generated/schema";

// Constants
const PROTOCOL_ID = "protocol";
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
export function handlePositionLiquidated(event: PositionLiquidatedEvent): void {
  let positionId = event.params.positionId.toString();
  let position = Position.load(positionId);

  if (position == null) {
    log.warning("Position not found for liquidation: {}", [positionId]);
    return;
  }

  let traderAddress = event.params.trader;
  let liquidatorAddress = event.params.liquidator;
  let collateralLiquidated = toDecimal(event.params.collateral);
  let penalty = toDecimal(event.params.penalty);

  // Update position status
  position.status = "LIQUIDATED";
  position.closedAt = event.block.timestamp;
  position.closeTxHash = event.transaction.hash;
  position.realizedPnL = position.collateral.neg(); // Full loss
  position.save();

  // Update trader stats
  let trader = getOrCreateUser(traderAddress);
  trader.openPositions = trader.openPositions.minus(BigInt.fromI32(1));
  trader.liquidationCount = trader.liquidationCount.plus(BigInt.fromI32(1));
  trader.totalPnL = trader.totalPnL.minus(collateralLiquidated);
  trader.updatedAt = event.block.timestamp;
  trader.save();

  // Create liquidation record
  let liquidationId = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let liquidation = new Liquidation(liquidationId);
  liquidation.position = positionId;
  liquidation.liquidator = liquidatorAddress;
  liquidation.trader = trader.id;
  liquidation.collateralLiquidated = collateralLiquidated;
  liquidation.penalty = penalty;
  liquidation.liquidatorReward = penalty.times(BigDecimal.fromString("0.5")); // 50% to liquidator
  liquidation.isPartial = false;
  liquidation.timestamp = event.block.timestamp;
  liquidation.txHash = event.transaction.hash;
  liquidation.save();

  // Update protocol stats
  let protocol = getOrCreateProtocol();
  protocol.totalLiquidations = protocol.totalLiquidations.plus(BigInt.fromI32(1));
  protocol.updatedAt = event.block.timestamp;
  protocol.save();

  // Update daily stats
  let dailyStats = getOrCreateDailyStats(event.block.timestamp);
  dailyStats.liquidations = dailyStats.liquidations.plus(BigInt.fromI32(1));
  dailyStats.save();

  log.info("Position liquidated: {} trader: {} liquidator: {}", [
    positionId,
    traderAddress.toHexString(),
    liquidatorAddress.toHexString(),
  ]);
}

export function handlePartialLiquidation(event: PartialLiquidationEvent): void {
  let positionId = event.params.positionId.toString();
  let position = Position.load(positionId);

  if (position == null) {
    log.warning("Position not found for partial liquidation: {}", [positionId]);
    return;
  }

  let traderAddress = event.params.trader;
  let liquidatorAddress = event.params.liquidator;
  let amount = toDecimal(event.params.amount);

  // Update position (partial liquidation)
  position.collateral = position.collateral.minus(amount);
  position.save();

  // Create liquidation record
  let liquidationId = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let liquidation = new Liquidation(liquidationId);
  liquidation.position = positionId;
  liquidation.liquidator = liquidatorAddress;
  liquidation.trader = traderAddress.toHexString();
  liquidation.collateralLiquidated = amount;
  liquidation.penalty = amount.times(BigDecimal.fromString("0.05")); // 5% penalty estimate
  liquidation.liquidatorReward = liquidation.penalty.times(BigDecimal.fromString("0.5"));
  liquidation.isPartial = true;
  liquidation.timestamp = event.block.timestamp;
  liquidation.txHash = event.transaction.hash;
  liquidation.save();

  // Update protocol stats
  let protocol = getOrCreateProtocol();
  protocol.totalLiquidations = protocol.totalLiquidations.plus(BigInt.fromI32(1));
  protocol.updatedAt = event.block.timestamp;
  protocol.save();

  // Update daily stats
  let dailyStats = getOrCreateDailyStats(event.block.timestamp);
  dailyStats.liquidations = dailyStats.liquidations.plus(BigInt.fromI32(1));
  dailyStats.save();

  log.info("Partial liquidation: {} amount: {}", [positionId, amount.toString()]);
}
