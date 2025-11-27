"use client";

import { useEffect, useState, useCallback } from "react";
import { useAccount, useConnect, useDisconnect, useBalance, useSwitchChain, type Connector } from "wagmi";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
  DialogDescription,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { CHAIN_IDS, DEFAULT_CHAIN } from "@/config/wagmi";
import { useCompliance } from "@/providers/ComplianceProvider";
import { checkOFACBlacklist } from "@/services/ofacCheck";

function formatAddress(address: string): string {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

function formatBalance(balance: bigint | undefined, decimals: number = 18): string {
  if (!balance) return "0.00";
  const value = Number(balance) / Math.pow(10, decimals);
  return value.toFixed(4);
}

// Wallet icon component based on connector ID/name
function WalletIcon({ connector }: { connector: Connector }) {
  const name = connector.name.toLowerCase();
  const id = connector.id.toLowerCase();

  // MetaMask
  if (name.includes("metamask") || id.includes("metamask")) {
    return (
      <svg className="h-6 w-6" viewBox="0 0 35 33" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M32.9583 1L19.6875 10.9583L22.0417 5.03333L32.9583 1Z" fill="#E2761B" stroke="#E2761B" strokeLinecap="round" strokeLinejoin="round"/>
        <path d="M2.04167 1L15.1875 11.0583L12.9583 5.03333L2.04167 1Z" fill="#E4761B" stroke="#E4761B" strokeLinecap="round" strokeLinejoin="round"/>
        <path d="M28.1667 23.5333L24.625 29.0667L32.2083 31.15L34.3917 23.6667L28.1667 23.5333Z" fill="#E4761B" stroke="#E4761B" strokeLinecap="round" strokeLinejoin="round"/>
        <path d="M0.625 23.6667L2.79167 31.15L10.375 29.0667L6.83333 23.5333L0.625 23.6667Z" fill="#E4761B" stroke="#E4761B" strokeLinecap="round" strokeLinejoin="round"/>
        <path d="M9.96667 14.5167L7.85 17.6833L15.3583 18.0167L15.0917 10L9.96667 14.5167Z" fill="#E4761B" stroke="#E4761B" strokeLinecap="round" strokeLinejoin="round"/>
        <path d="M25.0333 14.5167L19.8417 9.9L19.6875 18.0167L27.15 17.6833L25.0333 14.5167Z" fill="#E4761B" stroke="#E4761B" strokeLinecap="round" strokeLinejoin="round"/>
        <path d="M10.375 29.0667L14.8917 26.8833L10.9667 23.7167L10.375 29.0667Z" fill="#E4761B" stroke="#E4761B" strokeLinecap="round" strokeLinejoin="round"/>
        <path d="M20.1083 26.8833L24.625 29.0667L24.0333 23.7167L20.1083 26.8833Z" fill="#E4761B" stroke="#E4761B" strokeLinecap="round" strokeLinejoin="round"/>
      </svg>
    );
  }

  // WalletConnect
  if (name.includes("walletconnect") || id.includes("walletconnect")) {
    return (
      <svg className="h-6 w-6" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M9.58818 11.8556C13.1293 8.31442 18.8706 8.31442 22.4117 11.8556L22.8379 12.2818C23.015 12.4588 23.015 12.7459 22.8379 12.9229L21.3801 14.3808C21.2916 14.4693 21.148 14.4693 21.0595 14.3808L20.473 13.7943C18.0026 11.3239 13.9973 11.3239 11.5269 13.7943L10.8989 14.4223C10.8104 14.5108 10.6668 14.5108 10.5783 14.4223L9.12041 12.9644C8.94336 12.7874 8.94336 12.5003 9.12041 12.3232L9.58818 11.8556ZM25.4268 14.8707L26.7243 16.1682C26.9014 16.3453 26.9014 16.6324 26.7243 16.8094L20.8737 22.66C20.6966 22.8371 20.4096 22.8371 20.2325 22.66L16.0802 18.5077C16.0359 18.4634 15.9641 18.4634 15.9198 18.5077L11.7675 22.66C11.5904 22.8371 11.3034 22.8371 11.1263 22.66L5.27574 16.8094C5.09869 16.6324 5.09869 16.3453 5.27574 16.1682L6.57319 14.8707C6.75024 14.6937 7.03728 14.6937 7.21433 14.8707L11.3666 19.023C11.4109 19.0673 11.4827 19.0673 11.527 19.023L15.6793 14.8707C15.8564 14.6937 16.1434 14.6937 16.3205 14.8707L20.4728 19.023C20.5171 19.0673 20.5889 19.0673 20.6332 19.023L24.7855 14.8707C24.9626 14.6937 25.2496 14.6937 25.4268 14.8707Z" fill="#3B99FC"/>
      </svg>
    );
  }

  // Coinbase Wallet
  if (name.includes("coinbase") || id.includes("coinbase")) {
    return (
      <svg className="h-6 w-6" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
        <circle cx="16" cy="16" r="16" fill="#0052FF"/>
        <path fillRule="evenodd" clipRule="evenodd" d="M16 6C10.4772 6 6 10.4772 6 16C6 21.5228 10.4772 26 16 26C21.5228 26 26 21.5228 26 16C26 10.4772 21.5228 6 16 6ZM13.5 13C12.6716 13 12 13.6716 12 14.5V17.5C12 18.3284 12.6716 19 13.5 19H18.5C19.3284 19 20 18.3284 20 17.5V14.5C20 13.6716 19.3284 13 18.5 13H13.5Z" fill="white"/>
      </svg>
    );
  }

  // Default wallet icon for injected/other wallets
  return (
    <svg className="h-6 w-6" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M21 7H3C1.89543 7 1 7.89543 1 9V19C1 20.1046 1.89543 21 3 21H21C22.1046 21 23 20.1046 23 19V9C23 7.89543 22.1046 7 21 7Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
      <path d="M1 9L12 15L23 9" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
      <path d="M17 4H7L3 7H21L17 4Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  );
}

// Individual wallet option button
function WalletOption({
  connector,
  onClick,
  isPending,
}: {
  connector: Connector;
  onClick: () => void;
  isPending: boolean;
}) {
  const [ready, setReady] = useState(false);

  useEffect(() => {
    (async () => {
      const provider = await connector.getProvider();
      setReady(!!provider);
    })();
  }, [connector]);

  return (
    <button
      disabled={!ready || isPending}
      onClick={onClick}
      className="flex w-full items-center gap-3 rounded-lg border border-zinc-700 bg-zinc-800/50 p-4 text-left transition-colors hover:border-amber-500/50 hover:bg-zinc-800 disabled:cursor-not-allowed disabled:opacity-50"
    >
      <WalletIcon connector={connector} />
      <div className="flex flex-col">
        <span className="font-medium text-white">{connector.name}</span>
        {!ready && <span className="text-xs text-zinc-500">Not available</span>}
      </div>
    </button>
  );
}

export function WalletConnect() {
  const { address, isConnected, chain } = useAccount();
  const { connect, connectors, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain } = useSwitchChain();
  const { data: balance } = useBalance({ address });
  const [dialogOpen, setDialogOpen] = useState(false);
  const [ofacBlocked, setOfacBlocked] = useState(false);
  const [ofacReason, setOfacReason] = useState<string>();

  // Try to get compliance context, but don't fail if not available
  let compliance: ReturnType<typeof useCompliance> | null = null;
  try {
    compliance = useCompliance();
  } catch {
    // ComplianceProvider not available, continue without it
  }

  // Check OFAC when address changes
  useEffect(() => {
    if (address) {
      const result = checkOFACBlacklist(address);
      if (result.isBlacklisted) {
        setOfacBlocked(true);
        setOfacReason(result.reason);
        // Auto-disconnect blacklisted addresses
        disconnect();
      } else {
        setOfacBlocked(false);
        setOfacReason(undefined);
      }
    }
  }, [address, disconnect]);

  // Check if connected to wrong network
  const isWrongNetwork = isConnected && chain && chain.id !== CHAIN_IDS.BSC_MAINNET && chain.id !== CHAIN_IDS.BSC_TESTNET;

  // Handle successful connection
  const handleConnect = useCallback((connector: Connector) => {
    connect({ connector });
    setDialogOpen(false);
  }, [connect]);

  if (isConnected && address) {
    return (
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant={isWrongNetwork ? "destructive" : "outline"} className="min-w-[180px]">
            {isWrongNetwork ? (
              "Wrong Network"
            ) : (
              <span className="flex items-center gap-2">
                <span className="text-sm">{formatBalance(balance?.value)} {balance?.symbol}</span>
                <span className="text-muted-foreground">|</span>
                <span>{formatAddress(address)}</span>
              </span>
            )}
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" className="w-56">
          {isWrongNetwork && (
            <>
              <DropdownMenuItem onClick={() => switchChain({ chainId: DEFAULT_CHAIN.id })}>
                Switch to {DEFAULT_CHAIN.name}
              </DropdownMenuItem>
              <DropdownMenuSeparator />
            </>
          )}
          <DropdownMenuItem onClick={() => switchChain({ chainId: CHAIN_IDS.BSC_MAINNET })}>
            BSC Mainnet
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => switchChain({ chainId: CHAIN_IDS.BSC_TESTNET })}>
            BSC Testnet
          </DropdownMenuItem>
          <DropdownMenuSeparator />
          <DropdownMenuItem onClick={() => navigator.clipboard.writeText(address)}>
            Copy Address
          </DropdownMenuItem>
          <DropdownMenuSeparator />
          <DropdownMenuItem onClick={() => disconnect()} className="text-red-600">
            Disconnect
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    );
  }

  // Show OFAC blocked warning
  if (ofacBlocked) {
    return (
      <Dialog open={true}>
        <DialogContent className="sm:max-w-md border-red-500/50">
          <DialogHeader>
            <DialogTitle className="text-center text-red-500">Access Denied</DialogTitle>
            <DialogDescription className="text-center">
              {ofacReason || "This wallet address is blocked due to regulatory restrictions."}
            </DialogDescription>
          </DialogHeader>
          <div className="py-4 text-center text-sm text-zinc-400">
            <p>
              If you believe this is an error, please contact{" "}
              <a href="mailto:compliance@paimongold.io" className="text-amber-500 hover:underline">
                compliance@paimongold.io
              </a>
            </p>
          </div>
          <Button onClick={() => setOfacBlocked(false)} variant="outline">
            Close
          </Button>
        </DialogContent>
      </Dialog>
    );
  }

  return (
    <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
      <DialogTrigger asChild>
        <Button disabled={isPending}>
          {isPending ? "Connecting..." : "Connect Wallet"}
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="text-center">Connect Wallet</DialogTitle>
        </DialogHeader>
        <div className="grid gap-3 py-4">
          {connectors.map((connector) => (
            <WalletOption
              key={connector.uid}
              connector={connector}
              onClick={() => handleConnect(connector)}
              isPending={isPending}
            />
          ))}
        </div>
        <p className="text-center text-xs text-zinc-500">
          By connecting a wallet, you agree to our Terms of Service and confirm
          you are not a US resident or on any sanctions list.
        </p>
      </DialogContent>
    </Dialog>
  );
}
