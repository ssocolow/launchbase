"use client";

import { useState, useEffect } from "react";

// Strategy Selection Screen (Screen 1)
function StrategySelection({ onStrategySelect }: { onStrategySelect: (strategy: string, allocation: number) => void }) {
  const [hoveredStrategy, setHoveredStrategy] = useState<string | null>(null);
  const [showCustom, setShowCustom] = useState(false);
  const [customAllocation, setCustomAllocation] = useState(50);

  const strategies = [
    {
      id: "conservative",
      name: "Conservative",
      ethAllocation: 30,
      description: "Lower volatility, steady returns",
      stats: "30% ETH, 70% USDC",
      riskLevel: "Low Risk"
    },
    {
      id: "balanced", 
      name: "Balanced",
      ethAllocation: 50,
      description: "Moderate risk, balanced growth",
      stats: "50% ETH, 50% USDC", 
      riskLevel: "Medium Risk"
    },
    {
      id: "aggressive",
      name: "Aggressive", 
      ethAllocation: 70,
      description: "Higher volatility, maximum growth potential",
      stats: "70% ETH, 30% USDC",
      riskLevel: "High Risk"
    }
  ];

  const handleStrategyClick = (strategy: any) => {
    onStrategySelect(strategy.id, strategy.ethAllocation);
  };

  const handleCustomSelect = () => {
    onStrategySelect("custom", customAllocation);
  };

  return (
    <div className="min-h-screen bg-gray-50 px-4 py-12">
      <div className="max-w-4xl w-full mx-auto">
        <div className="text-center mb-12">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">Choose Your Strategy</h1>
          <p className="text-xl text-gray-600">Select an investment approach that matches your risk tolerance</p>
        </div>

        {/* Strategy Cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
          {strategies.map((strategy) => (
            <div
              key={strategy.id}
              className="relative bg-white rounded-2xl p-8 shadow-sm border border-gray-100 hover:shadow-xl hover:border-gray-200 transition-all duration-300 cursor-pointer group h-64 flex flex-col justify-center"
              onMouseEnter={() => setHoveredStrategy(strategy.id)}
              onMouseLeave={() => setHoveredStrategy(null)}
              onClick={() => handleStrategyClick(strategy)}
            >
              <div className="text-center flex-1 flex flex-col justify-center">
                <h3 className="text-2xl font-semibold text-gray-900 mb-4">{strategy.name}</h3>
                <div className="text-lg font-medium text-gray-700 mb-4">{strategy.stats}</div>
                
                {/* Hover Details */}
                <div className={`transition-all duration-300 ${
                  hoveredStrategy === strategy.id ? 'opacity-100 max-h-32' : 'opacity-0 max-h-0 overflow-hidden'
                }`}>
                  <div className="border-t border-gray-100 pt-4 mt-4">
                    <p className="text-gray-600 mb-3 text-sm leading-relaxed">{strategy.description}</p>
                    <span className="inline-block px-3 py-1 bg-gray-100 text-gray-700 text-sm rounded-full">
                      {strategy.riskLevel}
                    </span>
                  </div>
                </div>

                {/* Selection Indicator */}
                <div className="absolute inset-0 rounded-2xl border-2 border-transparent group-hover:border-blue-500 transition-all duration-300"></div>
              </div>
            </div>
          ))}
        </div>

        {/* Custom Option */}
        <div className="text-center pb-12">
          <button
            onClick={() => setShowCustom(!showCustom)}
            className="text-lg text-gray-600 hover:text-gray-900 font-medium underline underline-offset-4 hover:no-underline transition-all"
          >
            Custom allocation
          </button>

          {/* Custom Slider */}
          {showCustom && (
            <div className="mt-8 bg-white rounded-2xl p-8 shadow-sm border border-gray-100 max-w-md mx-auto">
              <h4 className="text-lg font-semibold text-gray-900 mb-6">Custom Allocation</h4>
              
              <div className="mb-4">
                <div className="flex justify-between text-sm text-gray-600 mb-2">
                  <span>Conservative</span>
                  <span>Aggressive</span>
                </div>
                <div className="relative">
                  <input
                    type="range"
                    min="10"
                    max="90"
                    value={customAllocation}
                    onChange={e => setCustomAllocation(Number(e.target.value))}
                    className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                    style={{
                      background: `linear-gradient(to right, #9CA3AF 0%, #9CA3AF ${((customAllocation - 10) / 80) * 100}%, #E5E7EB ${((customAllocation - 10) / 80) * 100}%, #E5E7EB 100%)`
                    }}
                  />
                </div>
              </div>

              <div className="text-center mb-6">
                <div className="text-xl font-semibold text-gray-900">
                  {customAllocation}% ETH, {100 - customAllocation}% USDC
                </div>
              </div>

              <button
                onClick={handleCustomSelect}
                className="w-full bg-gray-900 text-white py-3 px-6 rounded-xl font-medium hover:bg-gray-800 transition-colors"
              >
                Continue with Custom
              </button>
            </div>
          )}
        </div>
      </div>

      <style jsx>{`
        input[type="range"] {
          -webkit-appearance: none;
          appearance: none;
        }
        
        input[type="range"]::-webkit-slider-thumb {
          -webkit-appearance: none;
          appearance: none;
          height: 20px;
          width: 20px;
          border-radius: 50%;
          background: #1f2937;
          cursor: pointer;
          border: 2px solid #ffffff;
          box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        input[type="range"]::-moz-range-thumb {
          height: 20px;
          width: 20px;
          border-radius: 50%;
          background: #1f2937;
          cursor: pointer;
          border: 2px solid #ffffff;
          box-shadow: 0 2px 4px rgba(0,0,0,0.1);
          border: none;
        }
        
        input[type="range"]::-moz-range-track {
          height: 8px;
          background: #E5E7EB;
          border-radius: 4px;
          border: none;
        }
      `}</style>
    </div>
  );
}

// Investment Dashboard Screen (Screen 2)
function InvestmentDashboard({ strategy, ethAllocation, defaultInvestment, onBack }: { 
  strategy: string; 
  ethAllocation: number; 
  defaultInvestment: number;
  onBack: () => void 
}) {
  const [depositAmount, setDepositAmount] = useState(defaultInvestment.toString());
  const [totalInvested, setTotalInvested] = useState(defaultInvestment);
  const [ethPrice, setEthPrice] = useState(3200);
  const [isUpdatingPrice, setIsUpdatingPrice] = useState(false);
  const [currentETHAllocation, setCurrentETHAllocation] = useState(ethAllocation);
  const [isLoaded, setIsLoaded] = useState(false);

  const usdcAllocation = 100 - currentETHAllocation;
  const ethValue = (totalInvested * currentETHAllocation) / 100;
  const usdcValue = (totalInvested * usdcAllocation) / 100;

  // Animate pie chart on load
  useEffect(() => {
    const timer = setTimeout(() => {
      setIsLoaded(true);
    }, 500);
    return () => clearTimeout(timer);
  }, []);

  // Get accurate financial metrics based on ETH allocation
  const getAccurateStats = () => {
    if (ethAllocation <= 30) {
      return {
        sharpeRatio: '0.89',
        expectedReturn: '6.2%',
        volatility: '15%',
        maxDrawdown: '-22%'
      };
    } else if (ethAllocation <= 50) {
      return {
        sharpeRatio: '1.15',
        expectedReturn: '9.8%', 
        volatility: '24%',
        maxDrawdown: '-35%'
      };
    } else {
      return {
        sharpeRatio: '1.42',
        expectedReturn: '14.1%',
        volatility: '38%',
        maxDrawdown: '-58%'
      };
    }
  };

  const stats = getAccurateStats();

  // Simulate price updates
  const updatePrice = () => {
    setIsUpdatingPrice(true);
    setTimeout(() => {
      const change = (Math.random() - 0.5) * 0.1; // ±5% change
      const newPrice = ethPrice * (1 + change);
      setEthPrice(Math.round(newPrice));
      
      // Simulate portfolio drift due to price change
      const priceChangePercent = (newPrice - ethPrice) / ethPrice;
      const newETHAllocation = ethAllocation * (1 + priceChangePercent * 0.5); // Dampened effect
      setCurrentETHAllocation(Math.max(20, Math.min(80, newETHAllocation)));
      
      setIsUpdatingPrice(false);
    }, 1500);
  };

  const handleDeposit = () => {
    if (depositAmount) {
      setTotalInvested(prev => prev + parseFloat(depositAmount));
      // Don't clear depositAmount so user can deposit again
    }
  };

  const handleWithdraw = () => {
    if (depositAmount && parseFloat(depositAmount) <= totalInvested) {
      setTotalInvested(prev => Math.max(0, prev - parseFloat(depositAmount)));
      // Don't clear depositAmount so user can withdraw again
    }
  };

  const rebalance = () => {
    setCurrentETHAllocation(ethAllocation);
  };

  const needsRebalancing = Math.abs(currentETHAllocation - ethAllocation) > 2;

  // Pie chart calculation with animation
  const ethAngle = isLoaded ? (currentETHAllocation / 100) * 360 : 0;
  const usdcAngle = isLoaded ? 360 - ethAngle : 0;

  return (
    <div className="min-h-screen bg-gray-50 px-4 py-8">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="flex items-center justify-between mb-8">
          <button
            onClick={onBack}
            className="text-gray-600 hover:text-gray-900 font-medium flex items-center gap-2 transition-colors"
          >
            ← Back to Strategy Selection
          </button>
          <div className="text-right">
            <h1 className="text-2xl font-bold text-gray-900">{strategy.charAt(0).toUpperCase() + strategy.slice(1)} Portfolio</h1>
            <p className="text-gray-600">Target: {ethAllocation}% ETH, {100 - ethAllocation}% USDC</p>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Main Pie Chart Section */}
          <div className="lg:col-span-2">
            <div className="bg-white rounded-2xl p-8 shadow-sm border border-gray-100 h-full">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-semibold text-gray-900">Portfolio Allocation</h2>
                <div className="flex items-center gap-4">
                  <div className="text-right">
                    <div className="text-2xl font-bold text-gray-900">${totalInvested.toLocaleString()}</div>
                    <div className="text-sm text-gray-600">Total Value</div>
                  </div>
                  <button
                    onClick={updatePrice}
                    disabled={isUpdatingPrice}
                    className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
                    title="Update ETH Price"
                  >
                    <div className={`w-6 h-6 border-2 border-gray-400 border-t-gray-700 rounded-full ${isUpdatingPrice ? 'animate-spin' : ''}`}></div>
                  </button>
                </div>
              </div>

              {/* Pie Chart with Side Stats */}
              <div className="flex items-center justify-center mb-8 gap-12">
                {/* Small Stats Panel */}
                <div className="space-y-3">
                  <div className="text-center p-4 bg-gradient-to-br from-gray-50 to-gray-100 rounded-xl border border-gray-200/50 shadow-sm">
                    <div className="text-xl font-bold text-gray-900">
                      {stats.sharpeRatio}
                    </div>
                    <div className="text-xs text-gray-500 font-medium">Sharpe Ratio</div>
                  </div>
                  
                  <div className="text-center p-4 bg-gradient-to-br from-emerald-50 to-emerald-100 rounded-xl border border-emerald-200/50 shadow-sm">
                    <div className="text-xl font-bold text-emerald-700">
                      {stats.expectedReturn}
                    </div>
                    <div className="text-xs text-emerald-600 font-medium">Expected Return</div>
                  </div>
                  
                  <div className="text-center p-4 bg-gradient-to-br from-amber-50 to-amber-100 rounded-xl border border-amber-200/50 shadow-sm">
                    <div className="text-xl font-bold text-amber-700">
                      {stats.volatility}
                    </div>
                    <div className="text-xs text-amber-600 font-medium">Volatility</div>
                  </div>
                  
                  <div className="text-center p-4 bg-gradient-to-br from-red-50 to-red-100 rounded-xl border border-red-200/50 shadow-sm">
                    <div className="text-xl font-bold text-red-700">
                      {stats.maxDrawdown}
                    </div>
                    <div className="text-xs text-red-600 font-medium">Max Drawdown</div>
                  </div>
                </div>

                {/* Ultra-Crisp Pie Chart */}
                <div className="relative">
                  {/* Outer glow effect */}
                  <div className="absolute inset-0 bg-gradient-to-r from-slate-400/20 to-slate-600/20 rounded-full blur-xl scale-110"></div>
                  
                  <div className="relative w-96 h-96 bg-gradient-to-br from-white to-gray-50 rounded-full shadow-2xl border border-gray-200/50">
                    <svg className="w-full h-full transform -rotate-90" viewBox="0 0 200 200">
                      {/* Outer ring shadow */}
                      <circle
                        cx="100"
                        cy="100"
                        r="85"
                        fill="none"
                        stroke="#f1f5f9"
                        strokeWidth="6"
                      />
                      
                      {/* Background circle */}
                      <circle
                        cx="100"
                        cy="100"
                        r="80"
                        fill="none"
                        stroke="#e2e8f0"
                        strokeWidth="24"
                        strokeLinecap="round"
                      />
                      
                      {/* ETH segment with gradient */}
                      <defs>
                        <linearGradient id="ethGradient" x1="0%" y1="0%" x2="100%" y2="100%">
                          <stop offset="0%" stopColor="#6366f1" />
                          <stop offset="100%" stopColor="#4f46e5" />
                        </linearGradient>
                        <linearGradient id="usdcGradient" x1="0%" y1="0%" x2="100%" y2="100%">
                          <stop offset="0%" stopColor="#10b981" />
                          <stop offset="100%" stopColor="#059669" />
                        </linearGradient>
                      </defs>
                      
                      <circle
                        cx="100"
                        cy="100"
                        r="80"
                        fill="none"
                        stroke="url(#ethGradient)"
                        strokeWidth="24"
                        strokeDasharray={`${(ethAngle / 360) * 503} 503`}
                        strokeDashoffset="0"
                        strokeLinecap="round"
                        className="transition-all duration-[2500ms] ease-out drop-shadow-lg"
                        style={{
                          filter: 'drop-shadow(0 4px 8px rgba(79, 70, 229, 0.3))'
                        }}
                      />
                      
                      {/* USDC segment with gradient */}
                      <circle
                        cx="100"
                        cy="100"
                        r="80"
                        fill="none"
                        stroke="url(#usdcGradient)"
                        strokeWidth="24"
                        strokeDasharray={`${(usdcAngle / 360) * 503} 503`}
                        strokeDashoffset={`-${(ethAngle / 360) * 503}`}
                        strokeLinecap="round"
                        className="transition-all duration-[2500ms] ease-out drop-shadow-lg"
                        style={{
                          filter: 'drop-shadow(0 4px 8px rgba(16, 185, 129, 0.3))'
                        }}
                      />
                    </svg>
                    
                    {/* Center content with enhanced styling */}
                    <div className="absolute inset-0 flex items-center justify-center">
                      <div className="text-center bg-white/80 backdrop-blur-sm rounded-full w-32 h-32 flex items-center justify-center shadow-lg border border-gray-200/50">
                        <div>
                          <div className="text-2xl font-bold text-gray-900 tracking-tight">${ethPrice.toLocaleString()}</div>
                          <div className="text-xs text-gray-500 font-medium tracking-wide">ETH PRICE</div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              {/* Legend */}
              <div className="grid grid-cols-2 gap-6">
                <div className="flex items-center gap-4 p-4 bg-gradient-to-r from-indigo-50 to-indigo-100 rounded-xl border border-indigo-200/50">
                  <div className="w-6 h-6 bg-gradient-to-br from-indigo-500 to-indigo-600 rounded-full shadow-sm"></div>
                  <div>
                    <div className="font-semibold text-gray-900">Ethereum</div>
                    <div className="text-sm text-gray-600">{currentETHAllocation.toFixed(1)}% • ${ethValue.toLocaleString()}</div>
                  </div>
                </div>
                <div className="flex items-center gap-4 p-4 bg-gradient-to-r from-emerald-50 to-emerald-100 rounded-xl border border-emerald-200/50">
                  <div className="w-6 h-6 bg-gradient-to-br from-emerald-500 to-emerald-600 rounded-full shadow-sm"></div>
                  <div>
                    <div className="font-semibold text-gray-900">USDC</div>
                    <div className="text-sm text-gray-600">{usdcAllocation.toFixed(1)}% • ${usdcValue.toLocaleString()}</div>
                  </div>
                </div>
              </div>

              {/* Rebalancing Alert */}
              {needsRebalancing && (
                <div className="mt-6 bg-amber-50 border border-amber-200 rounded-xl p-4">
                  <div className="flex items-center justify-between">
                    <div>
                      <div className="font-medium text-amber-800">Portfolio Drift Detected</div>
                      <div className="text-sm text-amber-700">
                        Your allocation has shifted {Math.abs(currentETHAllocation - ethAllocation).toFixed(1)}% from target
                      </div>
                    </div>
                    <button
                      onClick={rebalance}
                      className="bg-amber-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-amber-700 transition-colors"
                    >
                      Rebalance
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Side Panel */}
          <div className="space-y-6">
            {/* Investment Amount */}
            <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Add Funds</h3>
              
              <div className="space-y-4">
                <div className="relative">
                  <input
                    type="number"
                    value={depositAmount}
                    onChange={e => setDepositAmount(e.target.value)}
                    placeholder="0.00"
                    className="w-full px-4 py-3 border border-gray-300 rounded-xl text-lg text-gray-900 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 pr-16"
                  />
                  <span className="absolute right-4 top-3 text-gray-500 font-medium">USDC</span>
                </div>

                <div className="grid grid-cols-2 gap-2">
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

                <button
                  onClick={handleDeposit}
                  disabled={!depositAmount}
                  className="w-full bg-gray-900 text-white py-3 px-4 rounded-xl font-medium hover:bg-gray-800 transition-colors disabled:bg-gray-300 disabled:cursor-not-allowed"
                >
                  Deposit Funds
                </button>

                <button
                  onClick={handleWithdraw}
                  disabled={!depositAmount || parseFloat(depositAmount || "0") > totalInvested}
                  className="w-full bg-red-600 text-white py-3 px-4 rounded-xl font-medium hover:bg-red-700 transition-colors disabled:bg-gray-300 disabled:cursor-not-allowed"
                >
                  Withdraw Funds
                </button>
              </div>
            </div>

            {/* Portfolio Stats */}
            <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Portfolio Stats</h3>
              
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-gray-600">Strategy</span>
                  <span className="font-medium text-gray-900">{strategy.charAt(0).toUpperCase() + strategy.slice(1)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Target ETH</span>
                  <span className="font-medium text-gray-900">{ethAllocation}%</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Current ETH</span>
                  <span className={`font-medium ${needsRebalancing ? 'text-amber-600' : 'text-gray-900'}`}>
                    {currentETHAllocation.toFixed(1)}%
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Auto-Rebalancing</span>
                  <span className="text-green-600 font-medium">Active</span>
                </div>
              </div>
            </div>

            {/* Quick Actions */}
            <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h3>
              
              <div className="space-y-3">
                <button className="w-full text-left px-4 py-3 bg-gray-50 hover:bg-gray-100 rounded-xl transition-colors">
                  <div className="font-medium text-gray-900">View Transaction History</div>
                  <div className="text-sm text-gray-600">See all deposits and rebalancing</div>
                </button>
                <button className="w-full text-left px-4 py-3 bg-gray-50 hover:bg-gray-100 rounded-xl transition-colors">
                  <div className="font-medium text-gray-900">Download Portfolio Report</div>
                  <div className="text-sm text-gray-600">Get detailed performance analysis</div>
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// Main Portfolio Flow Component
export default function PortfolioFlow() {
  const [currentScreen, setCurrentScreen] = useState("strategy"); // "strategy" or "dashboard"
  const [selectedStrategy, setSelectedStrategy] = useState("");
  const [ethAllocation, setEthAllocation] = useState(50);
  const [defaultInvestment] = useState(5); // Default $5 investment

  const handleStrategySelect = (strategy: string, allocation: number) => {
    setSelectedStrategy(strategy);
    setEthAllocation(allocation);
    setCurrentScreen("dashboard");
  };

  const handleBack = () => {
    setCurrentScreen("strategy");
  };

  if (currentScreen === "strategy") {
    return <StrategySelection onStrategySelect={handleStrategySelect} />;
  }

  return (
    <InvestmentDashboard 
      strategy={selectedStrategy}
      ethAllocation={ethAllocation}
      defaultInvestment={defaultInvestment}
      onBack={handleBack}
    />
  );
}