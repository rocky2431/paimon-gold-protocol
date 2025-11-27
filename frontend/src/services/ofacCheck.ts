/**
 * OFAC (Office of Foreign Assets Control) wallet blacklist check
 * Checks wallet addresses against known sanctioned addresses
 */

export interface OFACCheckResult {
  isBlacklisted: boolean;
  reason?: string;
  address: string;
}

// Known sanctioned wallet addresses (sample list)
// In production, this should be fetched from a maintained API like Chainalysis
// or updated regularly from official OFAC SDN list
const SANCTIONED_ADDRESSES: Set<string> = new Set([
  // Tornado Cash related addresses (sanctioned by OFAC in August 2022)
  "0x8589427373d6d84e98730d7795d8f6f8731fda16",
  "0x722122df12d4e14e13ac3b6895a86e84145b6967",
  "0xdd4c48c0b24039969fc16d1cdf626eab821d3384",
  "0xd90e2f925da726b50c4ed8d0fb90ad053324f31b",
  "0xd96f2b1c14db8458374d9aca76e26c3d18364307",
  "0x4736dcf1b7a3d580672cce6e7c65cd5cc9cfba9d",
  "0xd4b88df4d29f5cedd6857912842cff3b20c8cfa3",
  "0x910cbd523d972eb0a6f4cae4618ad62622b39dbf",
  "0xa160cdab225685da1d56aa342ad8841c3b53f291",
  "0xfd8610d20aa15b7b2e3be39b396a1bc3516c7144",
  "0xf60dd140cff0706bae9cd734ac3ae76ad9ebc32a",
  "0x22aaa7720ddd5388a3c0a3333430953c68f1849b",
  "0xba214c1c1928a32bffe790263e38b4af9bfcd659",
  "0xb1c8094b234dce6e03f10a5b673c1d8c69739a00",
  "0x527653ea119f3e6a1f5bd18fbf4714081d7b31ce",
  "0x58e8dcc13be9780fc42e8723d8ead4cf46943df2",
  "0xd691f27f38b395864ea86cfc7253969b409c362d",
  "0xaeaac358560e11f52454d997aaff2c5731b6f8a6",
  "0x1356c899d8c9467c7f71c195612f8a395abf2f0a",
  "0xa60c772958a3ed56c1f15dd055ba37ac8e523a0d",
  // Add more addresses as needed
]);

// Normalize address to lowercase for comparison
function normalizeAddress(address: string): string {
  return address.toLowerCase().trim();
}

/**
 * Check if a wallet address is on the OFAC sanctions list
 */
export function checkOFACBlacklist(address: string): OFACCheckResult {
  if (!address) {
    return {
      isBlacklisted: false,
      address: "",
      reason: "No address provided",
    };
  }

  const normalizedAddress = normalizeAddress(address);

  // Check against known sanctioned addresses
  const isBlacklisted = SANCTIONED_ADDRESSES.has(normalizedAddress);

  if (isBlacklisted) {
    // Log blacklist hit (in production, send to security/compliance logging)
    console.warn("OFAC blacklist hit:", {
      address: normalizedAddress,
      timestamp: new Date().toISOString(),
    });

    return {
      isBlacklisted: true,
      address: normalizedAddress,
      reason: "This wallet address is on the OFAC sanctions list and cannot interact with this protocol",
    };
  }

  return {
    isBlacklisted: false,
    address: normalizedAddress,
  };
}

/**
 * Async version that could be extended to check external APIs
 * (Chainalysis, TRM Labs, etc.)
 */
export async function checkOFACBlacklistAsync(address: string): Promise<OFACCheckResult> {
  // First check local list
  const localCheck = checkOFACBlacklist(address);
  if (localCheck.isBlacklisted) {
    return localCheck;
  }

  // In production, you would add additional API checks here
  // Example: Chainalysis API, TRM Labs, etc.
  // try {
  //   const response = await fetch(`https://api.chainalysis.com/check/${address}`);
  //   const data = await response.json();
  //   if (data.isSanctioned) {
  //     return { isBlacklisted: true, address, reason: data.reason };
  //   }
  // } catch (error) {
  //   console.error("External OFAC check failed:", error);
  // }

  return localCheck;
}

/**
 * Check multiple addresses at once
 */
export function checkMultipleAddresses(addresses: string[]): Map<string, OFACCheckResult> {
  const results = new Map<string, OFACCheckResult>();

  for (const address of addresses) {
    results.set(address, checkOFACBlacklist(address));
  }

  return results;
}

/**
 * Get the total count of sanctioned addresses in our list
 */
export function getSanctionedAddressCount(): number {
  return SANCTIONED_ADDRESSES.size;
}
