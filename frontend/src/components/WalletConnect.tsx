"use client";

import { useAccount, useConnect, useDisconnect, useBalance, useSwitchChain } from "wagmi";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { CHAIN_IDS, DEFAULT_CHAIN } from "@/config/wagmi";

function formatAddress(address: string): string {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

function formatBalance(balance: bigint | undefined, decimals: number = 18): string {
  if (!balance) return "0.00";
  const value = Number(balance) / Math.pow(10, decimals);
  return value.toFixed(4);
}

export function WalletConnect() {
  const { address, isConnected, chain } = useAccount();
  const { connect, connectors, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain } = useSwitchChain();
  const { data: balance } = useBalance({ address });

  // Check if connected to wrong network
  const isWrongNetwork = isConnected && chain && chain.id !== CHAIN_IDS.BSC_MAINNET && chain.id !== CHAIN_IDS.BSC_TESTNET;

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

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button disabled={isPending}>
          {isPending ? "Connecting..." : "Connect Wallet"}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-56">
        {connectors.map((connector) => (
          <DropdownMenuItem
            key={connector.uid}
            onClick={() => connect({ connector })}
            disabled={isPending}
          >
            {connector.name}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
