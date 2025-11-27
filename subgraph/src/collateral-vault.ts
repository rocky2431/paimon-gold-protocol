import { BigInt, BigDecimal, Bytes, log } from "@graphprotocol/graph-ts";
import {
  Deposited as DepositedEvent,
  Withdrawn as WithdrawnEvent,
} from "../generated/CollateralVault/CollateralVault";
import { Deposit, Withdrawal, User, Protocol } from "../generated/schema";

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

function toDecimal(value: BigInt): BigDecimal {
  return value.toBigDecimal().div(DECIMAL_FACTOR);
}

// Event handlers
export function handleDeposited(event: DepositedEvent): void {
  let userAddress = event.params.user;
  let tokenAddress = event.params.token;
  let amount = toDecimal(event.params.amount);

  // Create/update user
  let user = getOrCreateUser(userAddress);
  if (user.createdAt.equals(BigInt.zero())) {
    user.createdAt = event.block.timestamp;
  }
  user.updatedAt = event.block.timestamp;
  user.save();

  // Create deposit record
  let depositId = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let deposit = new Deposit(depositId);
  deposit.user = user.id;
  deposit.token = tokenAddress;
  deposit.amount = amount;
  deposit.timestamp = event.block.timestamp;
  deposit.txHash = event.transaction.hash;
  deposit.save();

  // Update protocol TVL
  let protocol = getOrCreateProtocol();
  protocol.totalValueLocked = protocol.totalValueLocked.plus(amount);
  protocol.updatedAt = event.block.timestamp;
  protocol.save();

  log.info("Collateral deposited: {} by {}", [amount.toString(), userAddress.toHexString()]);
}

export function handleWithdrawn(event: WithdrawnEvent): void {
  let userAddress = event.params.user;
  let tokenAddress = event.params.token;
  let amount = toDecimal(event.params.amount);

  // Update user
  let user = getOrCreateUser(userAddress);
  user.updatedAt = event.block.timestamp;
  user.save();

  // Create withdrawal record
  let withdrawalId = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let withdrawal = new Withdrawal(withdrawalId);
  withdrawal.user = user.id;
  withdrawal.token = tokenAddress;
  withdrawal.amount = amount;
  withdrawal.timestamp = event.block.timestamp;
  withdrawal.txHash = event.transaction.hash;
  withdrawal.save();

  // Update protocol TVL
  let protocol = getOrCreateProtocol();
  protocol.totalValueLocked = protocol.totalValueLocked.minus(amount);
  protocol.updatedAt = event.block.timestamp;
  protocol.save();

  log.info("Collateral withdrawn: {} by {}", [amount.toString(), userAddress.toHexString()]);
}
