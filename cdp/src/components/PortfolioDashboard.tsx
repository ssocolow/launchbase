// Put this content in PortfolioDashboard.tsx
"use client";
import { useState, useEffect } from "react";

export default function PortfolioDashboard() {
  const [currentETH, setCurrentETH] = useState(52.3);
  const [currentUSDC, setCurrentUSDC] = useState(47.7);
  const [targetETH] = useState(50);
  const [targetUSDC] = useState(50);
  const [portfolioValue] = useState(1000);
  const [isRebalancing, setIsRebalancing] = useState(false);

  const needsRebalance = Math.abs(currentETH - targetETH) > 5;

  const handleRebalance = () => {
    setIsRebalancing(true);
    // Simulate rebalancing animation
    setTimeout(() => {
      setCurrentETH(50);
      setCurrentUSDC(50);
      setIsRebalancing(false);
    }, 2000);
  };

  return (
    <div className="space-y-6">
      <div className="bg-white rounded-xl p-6 shadow-lg">
        <h2 className="text-2xl font-bold mb-4">Portfolio Dashboard</h2>
        
        {/* Portfolio Value */}
        <div className="bg-gradient-to-r from-blue-50 to-purple-50 rounded-lg p-4 mb-6">
          <div className="text-3xl font-bold text-gray-900">${portfolioValue.toLocaleString()}</div>
          <div className="text-gray-600">Total Portfolio Value</div>
        </div>

        {/* Current vs Target Allocation */}
        <div className="grid grid-cols-2 gap-4 mb-6">
          <div className="bg-blue-50 rounded-lg p-4">
            <div className="flex justify-between items-center mb-2">
              <span className="font-medium">ETH</span>
              <span className={`font-bold ${needsRebalance ? 'text-red-600' : 'text-green-600'}`}>
                {currentETH.toFixed(1)}%
              </span>
            </div>
            <div className="text-sm text-gray-600">Target: {targetETH}%</div>
            <div className="mt-2 bg-gray-200 rounded-full h-2">
              <div 
                className={`h-2 rounded-full transition-all duration-500 ${needsRebalance ? 'bg-red-500' : 'bg-blue-500'}`}
                style={{ width: `${currentETH}%` }}
              ></div>
            </div>
          </div>

          <div className="bg-green-50 rounded-lg p-4">
            <div className="flex justify-between items-center mb-2">
              <span className="font-medium">USDC</span>
              <span className={`font-bold ${needsRebalance ? 'text-red-600' : 'text-green-600'}`}>
                {currentUSDC.toFixed(1)}%
              </span>
            </div>
            <div className="text-sm text-gray-600">Target: {targetUSDC}%</div>
            <div className="mt-2 bg-gray-200 rounded-full h-2">
              <div 
                className={`h-2 rounded-full transition-all duration-500 ${needsRebalance ? 'bg-red-500' : 'bg-green-500'}`}
                style={{ width: `${currentUSDC}%` }}
              ></div>
            </div>
          </div>
        </div>

        {/* Rebalancing Status */}
        {needsRebalance && !isRebalancing && (
          <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-4">
            <div className="flex items-center justify-between">
              <div>
                <div className="font-medium text-yellow-800">⚠️ Rebalance Needed</div>
                <div className="text-sm text-yellow-700">Portfolio has drifted {Math.abs(currentETH - targetETH).toFixed(1)}% from target</div>
              </div>
              <button
                onClick={handleRebalance}
                className="bg-blue-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-blue-700 transition-colors"
              >
                Rebalance Now
              </button>
            </div>
          </div>
        )}

        {isRebalancing && (
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
            <div className="flex items-center space-x-3">
              <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600"></div>
              <div>
                <div className="font-medium text-blue-800">🔄 Rebalancing in Progress</div>
                <div className="text-sm text-blue-700">Executing trades to restore target allocation...</div>
              </div>
            </div>
          </div>
        )}

        {!needsRebalance && !isRebalancing && (
          <div className="bg-green-50 border border-green-200 rounded-lg p-4 mb-4">
            <div className="font-medium text-green-800">✅ Portfolio Balanced</div>
            <div className="text-sm text-green-700">Allocation is within target range</div>
          </div>
        )}
      </div>
    </div>
  );
}