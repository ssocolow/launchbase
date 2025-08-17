// Contract addresses for different networks
export const CONTRACT_ADDRESSES = {
  // Base Mainnet
  base: {
    PORTFOLIO_FACTORY: '0x...', // Replace with your deployed factory address
    USER_PORTFOLIO: '0x...', // This will be the deployed portfolio address for each user
    USDC: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913', // USDC on Base
    WETH: '0x4200000000000000000000000000000000000006', // WETH on Base
  },
  // Base Sepolia Testnet
  baseSepolia: {
    PORTFOLIO_FACTORY: '0x...', // Replace with your deployed factory address
    USER_PORTFOLIO: '0x...', // This will be the deployed portfolio address for each user
    USDC: '0x036CbD53842c5426634e7929541eC2318f3dCF7c', // USDC on Base Sepolia
    WETH: '0x4200000000000000000000000000000000000006', // WETH on Base Sepolia
  },
} as const;

// Network configuration
export const SUPPORTED_CHAINS = {
  base: 8453,
  baseSepolia: 84532,
} as const;

// Get contract addresses for current network
export function getContractAddresses(chainId: number) {
  switch (chainId) {
    case SUPPORTED_CHAINS.base:
      return CONTRACT_ADDRESSES.base;
    case SUPPORTED_CHAINS.baseSepolia:
      return CONTRACT_ADDRESSES.baseSepolia;
    default:
      throw new Error(`Unsupported chain ID: ${chainId}`);
  }
}
