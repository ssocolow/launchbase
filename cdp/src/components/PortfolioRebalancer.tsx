"use client";

import { useState } from "react";
import { useEvmAddress } from "@coinbase/cdp-hooks";
import PortfolioDashboard from "@/components/PortfolioDashboard";

/**
 * Portfolio Rebalancer UI adapted from app/portfolio.tsx
 * Uses CDP hooks for wallet connection state instead of wagmi
 */
export default function PortfolioRebalancer() {
  const { evmAddress } = useEvmAddress();

  const handleBuyUSDC = () => {
    const onrampURL = `https://pay.coinbase.com/buy/select-asset?appId=22222222-2222-2222-2222-222222222222&addresses={"0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913":["${evmAddress}"]}&assets=["0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"]}&blockchains=["base"]`;
    window.open(onrampURL, "_blank", "width=500,height=700");
  };

  return (
    <div className="w-full">
      {/* New Sleek Portfolio Flow */}
      <PortfolioDashboard />
      
      {/* Keep Buy USDC functionality available */}
      <div className="fixed bottom-4 right-4">
        <button
          onClick={handleBuyUSDC}
          className="bg-emerald-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-emerald-700 transition-colors shadow-lg"
        >
          Buy USDC
        </button>
      </div>
    </div>
  );
}