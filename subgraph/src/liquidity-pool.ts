import { BigInt, BigDecimal, Bytes, log } from "@graphprotocol/graph-ts";
import {
  LiquidityAdded as LiquidityAddedEvent,
  LiquidityRemoved as LiquidityRemovedEvent,
  FeesClaimed as FeesClaimedEvent,
  FeesDeposited as FeesDepositedEvent,
} from "../generated/LiquidityPool/LiquidityPool";
import {
  LPPosition,
  LiquidityAdd,
  LiquidityRemove,
  User,
  Protocol,
  DailyStats,
  FeeCollection,
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

function getOrCreateLPPosition(userAddress: Bytes): LPPosition {
  let lpPosition = LPPosition.load(userAddress.toHexString());
  if (lpPosition == null) {
    lpPosition = new LPPosition(userAddress.toHexString());
    lpPosition.user = userAddress.toHexString();
    lpPosition.lpTokenBalance = BigDecimal.zero();
    lpPosition.totalDeposited = BigDecimal.zero();
    lpPosition.totalWithdrawn = BigDecimal.zero();
    lpPosition.totalFeesClaimed = BigDecimal.zero();
    lpPosition.shares = BigDecimal.zero();
    lpPosition.createdAt = BigInt.zero();
    lpPosition.updatedAt = BigInt.zero();
  }
  return lpPosition;
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

function getFeeTypeString(feeType: i32): string {
  if (feeType == 0) return "TRADING";
  if (feeType == 1) return "BORROWING";
  if (feeType == 2) return "LIQUIDATION";
  return "UNKNOWN";
}

// Event handlers
export function handleLiquidityAdded(event: LiquidityAddedEvent): void {
  let providerAddress = event.params.provider;
  let amount = toDecimal(event.params.amount);
  let lpTokensMinted = toDecimal(event.params.lpTokensMinted);

  // Create/update user
  let user = getOrCreateUser(providerAddress);
  if (user.createdAt.equals(BigInt.zero())) {
    user.createdAt = event.block.timestamp;
  }
  user.updatedAt = event.block.timestamp;
  user.save();

  // Update LP position
  let lpPosition = getOrCreateLPPosition(providerAddress);
  let isNewProvider = lpPosition.lpTokenBalance.equals(BigDecimal.zero());
  lpPosition.lpTokenBalance = lpPosition.lpTokenBalance.plus(lpTokensMinted);
  lpPosition.totalDeposited = lpPosition.totalDeposited.plus(amount);
  if (lpPosition.createdAt.equals(BigInt.zero())) {
    lpPosition.createdAt = event.block.timestamp;
  }
  lpPosition.updatedAt = event.block.timestamp;
  lpPosition.save();

  // Create liquidity add record
  let liquidityAddId = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let liquidityAdd = new LiquidityAdd(liquidityAddId);
  liquidityAdd.provider = user.id;
  liquidityAdd.token = event.params.token;
  liquidityAdd.amount = amount;
  liquidityAdd.lpTokensMinted = lpTokensMinted;
  liquidityAdd.timestamp = event.block.timestamp;
  liquidityAdd.txHash = event.transaction.hash;
  liquidityAdd.save();

  // Update protocol stats
  let protocol = getOrCreateProtocol();
  protocol.totalValueLocked = protocol.totalValueLocked.plus(amount);
  if (isNewProvider) {
    protocol.totalLiquidityProviders = protocol.totalLiquidityProviders.plus(BigInt.fromI32(1));
  }
  protocol.updatedAt = event.block.timestamp;
  protocol.save();

  // Update daily stats
  let dailyStats = getOrCreateDailyStats(event.block.timestamp);
  dailyStats.liquidityAdded = dailyStats.liquidityAdded.plus(amount);
  dailyStats.save();

  log.info("Liquidity added: {} by {}", [amount.toString(), providerAddress.toHexString()]);
}

export function handleLiquidityRemoved(event: LiquidityRemovedEvent): void {
  let providerAddress = event.params.provider;
  let lpTokensBurned = toDecimal(event.params.lpTokensBurned);
  let tokensReturned = toDecimal(event.params.tokensReturned);

  // Update LP position
  let lpPosition = getOrCreateLPPosition(providerAddress);
  lpPosition.lpTokenBalance = lpPosition.lpTokenBalance.minus(lpTokensBurned);
  lpPosition.totalWithdrawn = lpPosition.totalWithdrawn.plus(tokensReturned);
  lpPosition.updatedAt = event.block.timestamp;
  lpPosition.save();

  // Create liquidity remove record
  let liquidityRemoveId = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let liquidityRemove = new LiquidityRemove(liquidityRemoveId);
  liquidityRemove.provider = providerAddress.toHexString();
  liquidityRemove.lpTokensBurned = lpTokensBurned;
  liquidityRemove.tokensReturned = tokensReturned;
  liquidityRemove.timestamp = event.block.timestamp;
  liquidityRemove.txHash = event.transaction.hash;
  liquidityRemove.save();

  // Update protocol stats
  let protocol = getOrCreateProtocol();
  protocol.totalValueLocked = protocol.totalValueLocked.minus(tokensReturned);
  if (lpPosition.lpTokenBalance.equals(BigDecimal.zero())) {
    protocol.totalLiquidityProviders = protocol.totalLiquidityProviders.minus(BigInt.fromI32(1));
  }
  protocol.updatedAt = event.block.timestamp;
  protocol.save();

  // Update daily stats
  let dailyStats = getOrCreateDailyStats(event.block.timestamp);
  dailyStats.liquidityRemoved = dailyStats.liquidityRemoved.plus(tokensReturned);
  dailyStats.save();

  log.info("Liquidity removed: {} by {}", [tokensReturned.toString(), providerAddress.toHexString()]);
}

export function handleFeesClaimed(event: FeesClaimedEvent): void {
  let userAddress = event.params.user;
  let amount = toDecimal(event.params.amount);

  // Update LP position
  let lpPosition = getOrCreateLPPosition(userAddress);
  lpPosition.totalFeesClaimed = lpPosition.totalFeesClaimed.plus(amount);
  lpPosition.updatedAt = event.block.timestamp;
  lpPosition.save();

  log.info("Fees claimed: {} by {}", [amount.toString(), userAddress.toHexString()]);
}

export function handleFeesDeposited(event: FeesDepositedEvent): void {
  let amount = toDecimal(event.params.amount);
  let feeType = getFeeTypeString(event.params.feeType);

  // Create fee collection record
  let feeCollectionId = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let feeCollection = new FeeCollection(feeCollectionId);
  feeCollection.token = event.params.token;
  feeCollection.amount = amount;
  feeCollection.feeType = feeType;
  feeCollection.timestamp = event.block.timestamp;
  feeCollection.txHash = event.transaction.hash;
  feeCollection.save();

  // Update protocol stats
  let protocol = getOrCreateProtocol();
  protocol.totalFees = protocol.totalFees.plus(amount);
  protocol.updatedAt = event.block.timestamp;
  protocol.save();

  // Update daily stats
  let dailyStats = getOrCreateDailyStats(event.block.timestamp);
  dailyStats.fees = dailyStats.fees.plus(amount);
  dailyStats.save();

  log.info("Fees deposited: {} type: {}", [amount.toString(), feeType]);
}
