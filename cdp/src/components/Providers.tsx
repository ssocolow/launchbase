"use client";

import React from 'react';
import { type Config } from "@coinbase/cdp-hooks";
import { CDPReactProvider, type AppConfig } from "@coinbase/cdp-react/components/CDPReactProvider";
import { createCDPEmbeddedWalletConnector } from '@coinbase/cdp-wagmi';
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { http } from "viem";
import { baseSepolia, base } from 'viem/chains';
import { WagmiProvider, createConfig } from 'wagmi';

import { theme } from "@/components/theme";

interface ProvidersProps {
  children: React.ReactNode;
}

const CDP_CONFIG: Config = {
  projectId: process.env.NEXT_PUBLIC_CDP_PROJECT_ID ?? "",
};

const APP_CONFIG: AppConfig = {
  name: "CDP Next.js StarterKit",
  logoUrl: "http://localhost:3000/logo.svg",
  authMethods: ["email", "sms"],
};

// Wagmi configuration with CDPEmbeddedWalletConnector
const cdpConfig: Config = {
  projectId: process.env.NEXT_PUBLIC_CDP_PROJECT_ID!, // Copy your Project ID here.
}

const connector = createCDPEmbeddedWalletConnector({
  cdpConfig: cdpConfig,
  providerConfig: {
    chains: [base, baseSepolia],
    transports: {
      [base.id]: http(),
      [baseSepolia.id]: http()
    }
  }
});

const wagmiConfig = createConfig({
  connectors: [connector],
  chains: [base, baseSepolia],
  transports: {
    [base.id]: http(),
    [baseSepolia.id]: http(),
  },
});

const queryClient = new QueryClient(); // For use with react-query

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
