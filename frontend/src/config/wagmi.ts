import { http, createConfig } from "wagmi";
import { bsc, bscTestnet } from "wagmi/chains";
import { injected } from "wagmi/connectors";

export const config = createConfig({
  chains: [bsc, bscTestnet],
  connectors: [
    injected(),
  ],
  transports: {
    [bsc.id]: http(process.env.NEXT_PUBLIC_BSC_RPC_URL || "https://bsc-dataseed.binance.org/"),
    [bscTestnet.id]: http(
      process.env.NEXT_PUBLIC_BSC_TESTNET_RPC_URL || "https://data-seed-prebsc-1-s1.binance.org:8545/"
    ),
  },
  ssr: true,
});

// Export chain IDs for convenience
export const CHAIN_IDS = {
  BSC_MAINNET: bsc.id,
  BSC_TESTNET: bscTestnet.id,
} as const;

// Default chain based on environment
export const DEFAULT_CHAIN = process.env.NODE_ENV === "production" ? bsc : bscTestnet;
