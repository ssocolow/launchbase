"use client";

import { useState } from "react";
import type { NextPage } from "next";
import { useAccount } from "wagmi";
import { Address } from "~~/components/scaffold-eth";

const Home: NextPage = () => {
  const { address: connectedAddress } = useAccount();
  const [riskLevel, setRiskLevel] = useState(50); // Default to balanced (50% ETH, 50% USDC)
  const [depositAmount, setDepositAmount] = useState("");

  // Calculate allocations based on risk level
  const ethPercentage = riskLevel;
  const usdcPercentage = 100 - riskLevel;

  const getRiskLabel = () => {
    if (riskLevel <= 30) return "Conservative";
    if (riskLevel <= 70) return "Balanced";
    return "Aggressive";
  };

  const getRiskColor = () => {
    if (riskLevel <= 30) return "text-green-500";
    if (riskLevel <= 70) return "text-yellow-500";
    return "text-red-500";
  };

  return (
    <>
      <div className="flex items-center flex-col grow pt-10 min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
        {/* Header */}
        <div className="px-5 mb-8">
          <h1 className="text-center">
            <span className="block text-3xl mb-2 text-gray-700">Welcome to</span>
            <span className="block text-5xl font-bold bg-gradient-to-r from-blue-600 to-indigo-600 bg-clip-text text-transparent">
              Portfolio Rebalancer
            </span>
          </h1>
          <p className="text-center text-xl text-gray-600 mt-4">Automated USDC/ETH Portfolio on Base Chain</p>
        </div>

        {/* Wallet Connection Status */}
        {connectedAddress && (
          <div className="flex justify-center items-center space-x-2 mb-8 bg-white rounded-lg px-4 py-2 shadow-sm">
            <p className="font-medium text-gray-700">Connected:</p>
            <Address address={connectedAddress} />
          </div>
        )}

        {/* Main Portfolio Setup Card */}
        <div className="bg-white rounded-2xl shadow-xl p-8 max-w-2xl w-full mx-4">
          {/* Risk Selection */}
          <div className="mb-8">
            <h2 className="text-2xl font-bold text-gray-800 mb-6 text-center">Choose Your Risk Level</h2>

            {/* Risk Level Display */}
            <div className="text-center mb-6">
              <div className={`text-3xl font-bold ${getRiskColor()}`}>{getRiskLabel()}</div>
              <div className="text-gray-600 mt-2">
                {ethPercentage}% ETH / {usdcPercentage}% USDC
              </div>
            </div>

            {/* Risk Slider */}
            <div className="mb-6">
              <input
                type="range"
                min="10"
                max="90"
                value={riskLevel}
                onChange={e => setRiskLevel(Number(e.target.value))}
                className="w-full h-3 bg-gray-200 rounded-lg appearance-none cursor-pointer slider"
                style={{
                  background: `linear-gradient(to right, #10b981 0%, #eab308 50%, #ef4444 100%)`,
                }}
              />
              <div className="flex justify-between text-sm text-gray-500 mt-2">
                <span>Conservative</span>
                <span>Balanced</span>
                <span>Aggressive</span>
              </div>
            </div>

            {/* Portfolio Preview */}
            <div className="grid grid-cols-2 gap-4 mb-6">
              <div className="bg-blue-50 rounded-lg p-4 text-center">
                <div className="text-2xl font-bold text-blue-600">{ethPercentage}%</div>
                <div className="text-gray-700">ETH</div>
                <div className="text-sm text-gray-500">Growth potential</div>
              </div>
              <div className="bg-green-50 rounded-lg p-4 text-center">
                <div className="text-2xl font-bold text-green-600">{usdcPercentage}%</div>
                <div className="text-gray-700">USDC</div>
                <div className="text-sm text-gray-500">Stability + Yield</div>
              </div>
            </div>
          </div>

          {/* Deposit Amount */}
          <div className="mb-8">
            <h3 className="text-xl font-bold text-gray-800 mb-4">Investment Amount</h3>
            <div className="relative">
              <input
                type="number"
                value={depositAmount}
                onChange={e => setDepositAmount(e.target.value)}
                placeholder="Enter amount in USDC"
                className="w-full px-4 py-3 border border-gray-300 rounded-lg text-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
              <span className="absolute right-3 top-3 text-gray-500 font-medium">USDC</span>
            </div>
            <div className="flex gap-2 mt-3">
              {[100, 500, 1000].map(amount => (
                <button
                  key={amount}
                  onClick={() => setDepositAmount(amount.toString())}
                  className="px-4 py-2 bg-gray-100 hover:bg-gray-200 rounded-lg text-sm font-medium transition-colors"
                >
                  ${amount}
                </button>
              ))}
            </div>
          </div>

          {/* Action Buttons */}
          <div className="space-y-4">
            {!connectedAddress ? (
              <button className="w-full bg-gradient-to-r from-blue-600 to-indigo-600 text-white py-4 rounded-lg font-bold text-lg hover:from-blue-700 hover:to-indigo-700 transition-all">
                Connect Wallet to Start
              </button>
            ) : (
              <>
                <button
                  disabled={!depositAmount}
                  className="w-full bg-gradient-to-r from-blue-600 to-indigo-600 text-white py-4 rounded-lg font-bold text-lg hover:from-blue-700 hover:to-indigo-700 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {depositAmount ? `Create Portfolio with $${depositAmount}` : "Enter Amount to Continue"}
                </button>
                <button className="w-full bg-gray-100 hover:bg-gray-200 text-gray-700 py-3 rounded-lg font-medium transition-colors">
                  Buy USDC First (Coinbase Onramp)
                </button>
              </>
            )}
          </div>

          {/* Features */}
          <div className="mt-8 pt-6 border-t border-gray-200">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-center">
              <div>
                <div className="text-2xl mb-1">⚡</div>
                <div className="text-sm font-medium text-gray-700">Auto Rebalancing</div>
              </div>
              <div>
                <div className="text-2xl mb-1">🛡️</div>
                <div className="text-sm font-medium text-gray-700">Base Chain Security</div>
              </div>
              <div>
                <div className="text-2xl mb-1">💰</div>
                <div className="text-sm font-medium text-gray-700">USDC Yield + ETH Growth</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </>
  );
};

export default Home;
