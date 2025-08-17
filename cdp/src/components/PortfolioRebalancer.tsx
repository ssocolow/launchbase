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

  const handleCreatePortfolio = () => {
  console.log('Creating portfolio:', {
    selectedPreset,
    depositAmount,
    ethPercentage,
    usdcPercentage,
  });
  setShowDashboard(true);
};

  return (
    <div className="w-full bg-gray-50">
      <div className="mx-auto w-full max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
        

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2 space-y-6">
            <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-card">
              <h2 className="text-xl font-semibold text-gray-900 mb-6">Portfolio Strategy</h2>

              <div className="grid grid-cols-4 gap-3 mb-6">
                <button
                  onClick={() => handlePresetSelect("conservative")}
                  className={`px-4 py-3 rounded-lg font-medium text-center flex items-center justify-center transition-all ${
                    selectedPreset === "conservative"
                      ? "bg-emerald-600 text-white shadow-lg"
                      : "bg-emerald-50 text-emerald-700 hover:bg-emerald-100 border border-emerald-200"
                  }`}
                > 
                  
                  Conservative
                </button>
                <button
                  onClick={() => handlePresetSelect("balanced")}
                  className={`px-4 py-3 rounded-lg font-medium transition-all ${
                    selectedPreset === "balanced"
                      ? "bg-blue-600 text-white shadow-lg"
                      : "bg-blue-50 text-blue-700 hover:bg-blue-100 border border-blue-200"
                  }`}
                >
                  Balanced
                </button>
                <button
                  onClick={() => handlePresetSelect("aggressive")}
                  className={`px-4 py-3 rounded-lg font-medium transition-all ${
                    selectedPreset === "aggressive"
                      ? "bg-red-600 text-white shadow-lg"
                      : "bg-red-50 text-red-700 hover:bg-red-100 border border-red-200"
                  }`}
                >
                  Aggressive
                </button>
                <button
                  onClick={handleCustomSelect}
                  className={`px-4 py-3 rounded-lg font-medium transition-all ${
                    selectedPreset === "custom"
                      ? "bg-gray-600 text-white shadow-lg"
                      : "bg-gray-50 text-gray-700 hover:bg-gray-100 border border-gray-200"
                  }`}
                >
                  Custom
                </button>
              </div>

              <div className={`${risk.bgColor} ${risk.borderColor} border rounded-lg p-4 mb-6`}> 
                <div className="flex items-center justify-between">
                  <div>
                    <h3 className={`text-lg font-semibold ${risk.color}`}>{risk.label}</h3>
                    <p className="text-gray-600 text-sm mt-1">{risk.description}</p>
                  </div>
                  <div className="text-right">
                    <div className="text-2xl font-bold text-gray-900">
                      {ethPercentage}% / {usdcPercentage}%
                    </div>
                    <div className="text-sm text-gray-600">ETH / USDC</div>
                  </div>
                </div>
              </div>
               {/* Enhanced Strategic Insights */}
              <StrategyInsights 
                ethPercentage={ethPercentage}
                usdcPercentage={usdcPercentage}
                riskLevel={risk.label}
              />
                  

              {showSlider && selectedPreset === "custom" && (
                <div className="mb-6 p-4 bg-gray-50 rounded-lg border border-gray-200">
                  <h4 className="text-sm font-medium text-gray-700 mb-3">Custom Allocation</h4>
                  <div className="flex justify-between text-sm text-gray-600 mb-2">
                    <span>Conservative</span>
                    <span>Balanced</span>
                    <span>Aggressive</span>
                  </div>
                  <div className="relative">
                    <input
                      type="range"
                      min="10"
                      max="90"
                      value={riskLevel}
                      onChange={e => setRiskLevel(Number(e.target.value))}
                      className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                    />
                    <div
                      className="absolute top-0 h-2 bg-gradient-to-r from-emerald-500 via-blue-500 to-red-500 rounded-lg pointer-events-none"
                      style={{ width: `${((riskLevel - 10) / 80) * 100}%` }}
                    ></div>
                  </div>
                  <div className="text-center mt-2">
                    <span className="text-sm text-gray-500">Custom: {riskLevel}% ETH</span>
                  </div>
                </div>
              )}

              <div className="grid grid-cols-2 gap-4">
                <div className="rounded-lg border border-blue-200 bg-blue-50 p-6 text-center shadow-sm">
                  <div className="mb-1 text-3xl font-extrabold text-blue-600">{ethPercentage}%</div>
                  <div className="font-medium text-gray-900">Ethereum</div>
                  <div className="mt-1 text-xs text-gray-600">Growth asset</div>
                </div>
                <div className="rounded-lg border border-emerald-200 bg-emerald-50 p-6 text-center shadow-sm">
                  <div className="mb-1 text-3xl font-extrabold text-emerald-600">{usdcPercentage}%</div>
                  <div className="font-medium text-gray-900">USDC</div>
                  <div className="mt-1 text-xs text-gray-600">Stable + yield</div>
                </div>
              </div>
            </div>

            <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-card">
              <h2 className="text-xl font-semibold text-gray-900 mb-4">Investment Amount</h2>

              <div className="space-y-4">
                <div className="relative">
                  <input
                    type="number"
                    value={depositAmount}
                    onChange={e => setDepositAmount(e.target.value)}
                    placeholder="0.00"
                    className="w-full px-4 py-3 border border-gray-300 rounded-lg text-lg text-gray-900 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 pr-16"
                  />
                  <span className="absolute right-4 top-3 text-gray-500 font-medium">USDC</span>
                </div>

                <div className="grid grid-cols-4 gap-2">
                  {[100, 500, 1000, 2500].map(amount => (
                    <button
                      key={amount}
                      onClick={() => setDepositAmount(amount.toString())}
                      className="px-3 py-2 bg-gray-100 hover:bg-gray-200 border border-gray-300 rounded-lg text-sm font-medium text-gray-900 transition-colors"
                    >
                      ${amount}
                    </button>
                  ))}
                </div>

                {depositAmount && (
                  <div className="bg-gray-50 rounded-lg p-3">
                    <div className="grid grid-cols-2 gap-4 text-sm">
                      <div>
                        <span className="text-gray-600">ETH allocation:</span>
                        <span className="font-medium ml-2 text-gray-900">
                          ${((parseFloat(depositAmount) * ethPercentage) / 100).toFixed(2)}
                        </span>
                      </div>
                      <div>
                        <span className="text-gray-600">USDC allocation:</span>
                        <span className="font-medium ml-2 text-gray-900">
                          ${((parseFloat(depositAmount) * usdcPercentage) / 100).toFixed(2)}
                        </span>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>

          <div className="space-y-6">
            <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-card">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Wallet</h3>

              {!isConnected ? (
                <div className="space-y-3">
                  <p className="text-sm text-gray-600">Sign in to get started</p>
                </div>
              ) : (
                <div className="space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-gray-600">Address:</span>
                    <span className="text-sm font-mono">
                      {evmAddress?.slice(0, 6)}...{evmAddress?.slice(-4)}
                    </span>
                  </div>

                  {!hasEnoughBalance && (
                    <button
                      onClick={handleBuyUSDC}
                      className="w-full bg-emerald-600 text-white py-3 px-4 rounded-lg font-medium hover:bg-emerald-700 transition-colors"
                    >
                      Buy USDC
                    </button>
                  )}
                </div>
              )}
            </div>

            <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-card">
              <button
                onClick={handleCreatePortfolio}
                disabled={!depositAmount}//disabled={!isConnected || !depositAmount || !hasEnoughBalance}
                className="w-full bg-blue-600 text-white py-4 px-4 rounded-lg font-semibold text-lg hover:bg-blue-700 transition-colors disabled:bg-gray-300 disabled:cursor-not-allowed"
              >
                {!isConnected
                  ? "Connect Wallet First"
                  : !hasEnoughBalance
                    ? "Buy USDC First"
                    : !depositAmount
                      ? "Enter Amount"
                      : `Create Portfolio`}
              </button>

              {depositAmount && isConnected && hasEnoughBalance && (
                <div className="mt-3 text-center">
                  <p className="text-sm text-gray-600">
                    Investing ${depositAmount} USDC • {risk.label} strategy
                  </p>
                </div>
              )}
            </div>

            <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-card">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Features</h3>
              <div className="space-y-3">
                <div className="flex items-center space-x-3">
                  <div className="w-2 h-2 bg-green-500 rounded-full"></div>
                  <span className="text-sm text-gray-700">Automatic rebalancing</span>
                </div>
                <div className="flex items-center space-x-3">
                  <div className="w-2 h-2 bg-blue-500 rounded-full"></div>
                  <span className="text-sm text-gray-700">Base chain security</span>
                  https://api.developer.coinbase.com        </div>
                <div className="flex items-center space-x-3">
                  <div className="w-2 h-2 bg-purple-500 rounded-full"></div>
                  <span className="text-sm text-gray-700">USDC yield generation</span>
                </div>
                <div className="flex items-center space-x-3">
                  <div className="w-2 h-2 bg-orange-500 rounded-full"></div>
                  <span className="text-sm text-gray-700">Low gas fees</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      {/* Rebalancing Dashboard */}
      {showDashboard && (
        <div className="mt-8">
          <PortfolioDashboard />
        </div>
      )}
    </div>
  );
}


