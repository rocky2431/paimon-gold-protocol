import { http, createConfig } from "wagmi";
import { bsc, bscTestnet } from "wagmi/chains";
import { injected, walletConnect, coinbaseWallet, metaMask } from "wagmi/connectors";

// WalletConnect Project ID - get yours at https://cloud.walletconnect.com
const walletConnectProjectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || "";

export const config = createConfig({
  chains: [bsc, bscTestnet],
  connectors: [
    // Injected wallets (MetaMask, Trust Wallet browser extension, etc.)
    injected(),
    // Dedicated MetaMask connector with better UX
    metaMask(),
    // WalletConnect v2 - supports 300+ wallets including Trust Wallet mobile
    ...(walletConnectProjectId
      ? [
          walletConnect({
            projectId: walletConnectProjectId,
            showQrModal: true,
            metadata: {
              name: "Paimon Gold Protocol",
              description: "Multi-leverage gold ETF trading on BSC",
              url: typeof window !== "undefined" ? window.location.origin : "",
              icons: ["https://paimon.gold/logo.png"],
            },
          }),
        ]
      : []),
    // Coinbase Wallet
    coinbaseWallet({
      appName: "Paimon Gold Protocol",
      appLogoUrl: "https://paimon.gold/logo.png",
    }),
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
