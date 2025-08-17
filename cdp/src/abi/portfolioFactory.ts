export const PORTFOLIO_FACTORY_ABI = [
  {
    "inputs": [],
    "name": "createUserPortfolio",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "address", "name": "user", "type": "address"}],
    "name": "getUserPortfolio",
    "outputs": [{"internalType": "address", "name": "", "type": "address"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "uint256", "name": "assetId", "type": "uint256"}, {"internalType": "address", "name": "token", "type": "address"}, {"internalType": "bytes", "name": "path", "type": "bytes"}],
    "name": "setDefaultAssetConfig",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "anonymous": false,
    "inputs": [{"indexed": true, "internalType": "address", "name": "user", "type": "address"}, {"indexed": false, "internalType": "address", "name": "contractAddress", "type": "address"}],
    "name": "UserPortfolioCreated",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [{"indexed": true, "internalType": "uint256", "name": "assetId", "type": "uint256"}, {"indexed": false, "internalType": "address", "name": "token", "type": "address"}, {"indexed": false, "internalType": "bytes", "name": "path", "type": "bytes"}],
    "name": "DefaultAssetConfigSet",
    "type": "event"
  }
] as const;
