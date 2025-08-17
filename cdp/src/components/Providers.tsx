"use client";

import { type Config } from "@coinbase/cdp-hooks";
import { CDPReactProvider, type AppConfig } from "@coinbase/cdp-react/components/CDPReactProvider";
import { createCDPEmbeddedWalletConnector } from "@coinbase/cdp-wagmi";
import { WagmiProvider, createConfig } from "wagmi";
import { http } from "viem";
import { baseSepolia } from "viem/chains";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";

import { theme } from "@/components/theme";

interface ProvidersProps {
  children: React.ReactNode;
}

const CDP_CONFIG: Config = {
  projectId: "bdd4fdee-3ed6-48c5-b600-253b5923164d",
};

const APP_CONFIG: AppConfig = {
  name: "LaunchBase",
  logoUrl: "http://localhost:3000/logo.svg",
  authMethods: ["email", "sms"],
};

// Create a Wagmi connector that bridges CDP Embedded Wallet into wagmi
const cdpConnector = createCDPEmbeddedWalletConnector({
  cdpConfig: CDP_CONFIG,
  providerConfig: {
    chains: [baseSepolia],
    transports: {
      [baseSepolia.id]: http(),
    },
  },
});

const wagmiConfig = createConfig({
  connectors: [cdpConnector],
  chains: [baseSepolia],
  transports: {
    [baseSepolia.id]: http(),
  },
});

const queryClient = new QueryClient();

/**
 * Providers component that wraps the application in all requisite providers
 *
 * @param props - { object } - The props for the Providers component
 * @param props.children - { React.ReactNode } - The children to wrap
 * @returns The wrapped children
 */
export default function Providers({ children }: ProvidersProps) {
  return (
    <CDPReactProvider config={CDP_CONFIG} app={APP_CONFIG} theme={theme}>
      <WagmiProvider config={wagmiConfig}>
        <QueryClientProvider client={queryClient}>
          {children}
        </QueryClientProvider>
      </WagmiProvider>
    </CDPReactProvider>
  );
}
