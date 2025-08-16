"use client";
import { useState } from "react";

interface StrategyInsightsProps {
  ethPercentage: number;
  usdcPercentage: number;
  riskLevel: string;
}

export default function StrategyInsights({ ethPercentage, usdcPercentage, riskLevel }: StrategyInsightsProps) {
  const [activeCard, setActiveCard] = useState<string | null>(null);

  // Mock historical data for demonstration
  // Realistic DeFi data for ETH NYC judges
  const getHistoricalData = () => {
    // Realistic ETH annual volatility: ~80-120%
    const ethVolatility = 0.95; // 95%
    // Realistic USDC yield from lending: ~4-6%
    const usdcYield = 0.05; // 5%
    // Realistic ETH expected return: ~15-25% long term
    const ethExpectedReturn = 0.18; // 18%
    
    // Portfolio calculations
    const portfolioReturn = (ethPercentage / 100) * ethExpectedReturn + (usdcPercentage / 100) * usdcYield;
    const portfolioVolatility = (ethPercentage / 100) * ethVolatility;
    
    // Risk-free rate (current US 10-year treasury ~4.5%)
    const riskFreeRate = 0.045;
    // Proper Sharpe ratio calculation
    const sharpeRatio = (portfolioReturn - riskFreeRate) / Math.max(portfolioVolatility, 0.01);
    
    // Realistic max drawdown (roughly 60% of volatility)
    const maxDrawdown = portfolioVolatility * 0.6;
    
    return {
      yearReturn: (portfolioReturn * 100).toFixed(1),
      volatility: (portfolioVolatility * 100).toFixed(0),
      maxDrawdown: (maxDrawdown * 100).toFixed(0),
      sharpeRatio: sharpeRatio.toFixed(2)
    };
  };

  const data = getHistoricalData();

  const getRiskColor = () => {
    if (ethPercentage <= 30) return "from-green-500 to-emerald-600";
    if (ethPercentage <= 70) return "from-blue-500 to-indigo-600";
    return "from-red-500 to-pink-600";
  };

  const cards = [
    {
      id: "eth",
      title: "ETH Strategy",
      icon: "https://assets.coingecko.com/coins/images/279/small/ethereum.png",
      color: "blue",
      hoverColor: "bg-blue-50",
      insights: [
        `${ethPercentage}% allocation targeting ~18% annual returns`,
        `Expected volatility: ${data.volatility}% (high but normal for ETH)`,
        `Benefits from Ethereum ecosystem growth`
      ]
    },
    {
      id: "usdc",
      title: "USDC Strategy", 
      icon: "https://assets.coingecko.com/coins/images/6319/small/USD_Coin_icon.png",
      color: "emerald",
      hoverColor: "bg-emerald-50",
      insights: [
        `${usdcPercentage}% provides portfolio stability`,
        `Current yield: ~5% through Base lending protocols`,
        `Reduces overall portfolio volatility significantly`,
        `Maintains liquidity for rebalancing opportunities`
      ]
    },
    {
      id: "performance",
      title: "Expected Performance",
      icon: "📊",
      color: "purple",
      hoverColor: "bg-purple-50",
      insights: [
        `Projected annual return: ${data.yearReturn}%`,
        `Sharpe ratio: ${data.sharpeRatio}`,
        `Max expected drawdown: ${data.maxDrawdown}%`,
        `Rebalances trigger at ±5% deviation`
      ]
    }
  ];

  return (
    <div className="space-y-4">
      {/* Risk Meter */}
      <div className="bg-white rounded-xl border border-gray-200 p-4">
        <h3 className="text-sm font-medium text-gray-700 mb-3">Risk Level</h3>
        <div className="relative">
          <div className="h-3 bg-gray-200 rounded-full overflow-hidden">
            <div 
              className={`h-full bg-gradient-to-r ${getRiskColor()} transition-all duration-500`}
              style={{ width: `${ethPercentage}%` }}
            ></div>
          </div>
          <div className="flex justify-between text-xs text-gray-500 mt-1">
            <span>Conservative</span>
            <span>Aggressive</span>
          </div>
          <div className="text-center mt-2">
            <span className="text-sm font-medium text-gray-700">{riskLevel}</span>
          </div>
        </div>
      </div>

      {/* Interactive Strategy Cards */}
      <div className="grid grid-cols-3 gap-3">
        {cards.map((card) => (
          <div
            key={card.id}
            className={`relative cursor-pointer transition-all duration-300 ${
              activeCard === card.id ? 'scale-105' : 'hover:scale-102'
            }`}
            onMouseEnter={() => setActiveCard(card.id)}
            onMouseLeave={() => setActiveCard(null)}
          >
            <div className={`p-4 rounded-lg border-2 transition-all ${
              activeCard === card.id 
                ? `border-${card.color}-300 ${card.hoverColor}` 
                : 'border-gray-200 bg-gray-50'
            }`}>
              <div className="flex items-center space-x-2 mb-2">
                {typeof card.icon === 'string' && card.icon.startsWith('http') ? (
                  <img src={card.icon} alt={card.title} className="w-5 h-5" />
                ) : (
                  <span className="text-lg">{card.icon}</span>
                )}
                <span className="text-sm font-medium text-gray-700">{card.title}</span>
              </div>

              {/* Expanded Content */}
              {activeCard === card.id && (
                <div className="space-y-2 mt-3">
                  {card.insights.map((insight, index) => (
                    <div key={index} className="flex items-start space-x-2">
                      <div className={`w-1.5 h-1.5 rounded-full bg-${card.color}-500 mt-1.5 flex-shrink-0`}></div>
                      <span className="text-xs text-gray-600">{insight}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        ))}
      </div>

      {/* Quick Stats Bar */}
      <div className="grid grid-cols-4 gap-3 bg-gray-50 rounded-lg p-3">
        <div className="text-center">
          <div className="text-sm font-bold text-gray-900">{data.yearReturn}%</div>
          <div className="text-xs text-gray-500">Expected Return</div>
        </div>
        <div className="text-center">
          <div className="text-sm font-bold text-gray-900">{data.volatility}%</div>
          <div className="text-xs text-gray-500">Volatility</div>
        </div>
        <div className="text-center">
          <div className="text-sm font-bold text-gray-900">{data.sharpeRatio}</div>
          <div className="text-xs text-gray-500">Sharpe Ratio</div>
        </div>
        <div className="text-center">
          <div className="text-sm font-bold text-gray-900">5%</div>
          <div className="text-xs text-gray-500">Rebalance Trigger</div>
        </div>
      </div>
    </div>
  );
}
