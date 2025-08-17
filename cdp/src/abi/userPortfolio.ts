export const USER_PORTFOLIO_ABI = [
  // Core Functions
  {
    "inputs": [
      {"internalType": "uint256", "name": "usdcIn", "type": "uint256"},
      {"components": [
        {"internalType": "uint256", "name": "assetId", "type": "uint256"},
        {"internalType": "uint256", "name": "units", "type": "uint256"},
        {"internalType": "uint16", "name": "bps", "type": "uint16"},
        {"internalType": "uint256", "name": "lastPrice", "type": "uint256"},
        {"internalType": "uint256", "name": "lastEdited", "type": "uint256"}
      ], "internalType": "struct UserPortfolio.PortfolioAsset[]", "name": "_desiredAllocation", "type": "tuple[]"}
    ],
    "name": "depositUsdc",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "withdrawAllAsUSDC",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "bytes[]", "name": "sellPaths", "type": "bytes[]"},
      {"internalType": "uint256[]", "name": "sellAmountOutMinimums", "type": "uint256[]"},
      {"internalType": "bytes[]", "name": "buyPaths", "type": "bytes[]"},
      {"internalType": "uint256[]", "name": "buyAmountOutMinimums", "type": "uint256[]"}
    ],
    "name": "rebalancePortfolio",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "bytes[]", "name": "paths", "type": "bytes[]"},
      {"internalType": "uint256[]", "name": "amountOutMinimums", "type": "uint256[]"}
    ],
    "name": "swapAllAssetsToUsdcViaUniswap",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "uint256[]", "name": "amountOutMinimums", "type": "uint256[]"}
    ],
    "name": "withdrawAllAsUSDCWithDefaultPaths",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "address", "name": "router", "type": "address"}
    ],
    "name": "setUniswapRouter",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },

  // View Functions
  {
    "inputs": [],
    "name": "getPortfolio",
    "outputs": [{"components": [
      {"internalType": "uint256", "name": "assetId", "type": "uint256"},
      {"internalType": "uint256", "name": "units", "type": "uint256"},
      {"internalType": "uint16", "name": "bps", "type": "uint16"},
      {"internalType": "uint256", "name": "lastPrice", "type": "uint256"},
      {"internalType": "uint256", "name": "lastEdited", "type": "uint256"}
    ], "internalType": "struct UserPortfolio.PortfolioAsset[]", "name": "", "type": "tuple[]"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "quotePortfolioValueUsdc",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getUserAllocationBps",
    "outputs": [{"internalType": "uint16[]", "name": "bps", "type": "uint16[]"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getUserCurrentAllocationBps",
    "outputs": [{"internalType": "uint16[]", "name": "bps", "type": "uint16[]"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getUsdcBalance",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getTotalPortfolioValue",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "uint256", "name": "assetId", "type": "uint256"}],
    "name": "getAssetBalance",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },

  // Events
  {
    "anonymous": false,
    "inputs": [{"indexed": true, "internalType": "address", "name": "user", "type": "address"}, {"indexed": false, "internalType": "uint256", "name": "usdcIn", "type": "uint256"}],
    "name": "Deposit",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [{"indexed": true, "internalType": "address", "name": "user", "type": "address"}, {"indexed": false, "internalType": "uint256", "name": "usdcOut", "type": "uint256"}],
    "name": "WithdrawAllUSDC",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [{"indexed": true, "internalType": "address", "name": "user", "type": "address"}],
    "name": "PortfolioRebalanced",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [{"indexed": true, "internalType": "address", "name": "user", "type": "address"}],
    "name": "SwapUsdcToPortfolioRequested",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [{"indexed": true, "internalType": "address", "name": "user", "type": "address"}],
    "name": "SwapAllAssetsToUsdcRequested",
    "type": "event"
  }
] as const;
