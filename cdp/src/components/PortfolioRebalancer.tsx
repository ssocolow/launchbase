"use client";

import { useState } from "react";

import StrategyInsights from "@/components/StrategyInsights";
import PortfolioDashboard from "@/components/PortfolioDashboard";
import { useEvmAddress } from "@coinbase/cdp-hooks";
 
/**
 * Portfolio Rebalancer UI adapted from app/portfolio.tsx
 * Uses CDP hooks for wallet connection state instead of wagmi
 */
export default function PortfolioRebalancer() {
  const { evmAddress } = useEvmAddress();

  const isConnected = Boolean(evmAddress);

  const [riskLevel, setRiskLevel] = useState(50);
  const [depositAmount, setDepositAmount] = useState("");
  const [selectedPreset, setSelectedPreset] = useState("balanced"); // "conservative", "balanced", "aggressive", "custom"
  const [showSlider, setShowSlider] = useState(false);
  const [showDashboard, setShowDashboard] = useState(false);

  // NOTE: Balance integration pending; enable primary flow for now
  const hasEnoughBalance = false;


  // Call our backend /quote endpoint which returns a ready-to-open Onramp URL
  const getOnrampUrlFromServer = async (): Promise<string> => {
    if (!evmAddress) throw new Error('Wallet address is required');
    const response = await fetch('http://localhost:3007/quote', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        destination_address: evmAddress,
        // Optional: pass amount/currency if server supports it
        payment_amount: depositAmount || undefined,
        payment_currency: 'USD',
        payment_method: 'CARD',
        country: 'US',
      }),
    });
    if (!response.ok) {
      const text = await response.text();
      throw new Error(`Failed to get quote: ${response.status} ${text}`);
    }
    const data: any = await response.json();
    // Try multiple shapes: top-level and nested under `result` (camelCase and snake_case)
    const url: string | undefined =
      data?.buyUrl ||
      data?.onrampUrl ||
      data?.onramp_url ||
      data?.url ||
      data?.result?.buyUrl ||
      data?.result?.onrampUrl ||
      data?.result?.onramp_url ||
      data?.result?.url;
    if (!url) throw new Error('Server did not return an onramp URL');
    // Insert "-sandbox" after "pay" in the URL if present
    if (typeof url === "string" && url.includes("/pay")) {
      const newurl = url.replace(/\/pay(\/|$)/, "/pay-sandbox$1") + "&redirectUrl=http://localhost:3000";
      console.log(newurl);
      return newurl;
    }
    return url;
  };

  const ethPercentage =
    selectedPreset === "custom"
      ? riskLevel
      : selectedPreset === "conservative"
        ? 30
        : selectedPreset === "balanced"
          ? 50
          : 70;

  const usdcPercentage = 100 - ethPercentage;

  const getRiskConfig = () => {
    if (ethPercentage <= 30)
      return {
        label: "Conservative",
        color: "text-emerald-600",
        bgColor: "bg-emerald-50",
        borderColor: "border-emerald-200",
        description: "Lower volatility, steady returns",
      } as const;
    if (ethPercentage <= 70)
      return {
        label: "Balanced",
        color: "text-blue-600",
        bgColor: "bg-blue-50",
        borderColor: "border-blue-200",
        description: "Moderate risk, balanced growth",
      } as const;
    return {
      label: "Aggressive",
      color: "text-red-600",
      bgColor: "bg-red-50",
      borderColor: "border-red-200",
      description: "Higher volatility, maximum growth potential",
    } as const;
  };

  const risk = getRiskConfig();

  const handlePresetSelect = (preset: string) => {
    setSelectedPreset(preset);
    setShowSlider(false);

    if (preset === "conservative") setRiskLevel(30);
    if (preset === "balanced") setRiskLevel(50);
    if (preset === "aggressive") setRiskLevel(70);
  };

  const handleCustomSelect = () => {
    setSelectedPreset("custom");
    setShowSlider(true);
  };
  
  const handleBuyUSDC = async () => {
    try {
      const url = await getOnrampUrlFromServer();
      window.open(url, "_blank", "width=500,height=700");
    } catch (e) {
      console.error(e);
      alert('Failed to start Onramp flow. Check console for details.');
    }
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