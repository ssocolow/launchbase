// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Interfaces.sol";
import "./UserPortfolio.sol";

/**
 * Factory contract - deploys individual user contracts
 */
contract PortfolioFactory {
    IERC20 public immutable USDC;
    address public immutable usdcPriceFeed;
    address public immutable wethPriceFeed;
    address public immutable defaultUniswapRouter;
    address public owner;
    mapping(address => address) public userContracts;
    mapping(uint256 => address) public defaultAssetToken;
    // Separate default paths per asset
    mapping(uint256 => bytes) public defaultAssetBuyPath;  // USDC -> Asset
    mapping(uint256 => bytes) public defaultAssetSellPath; // Asset -> USDC
    uint256[] public configuredAssetIds;
    mapping(uint256 => bool) private isConfiguredAssetId;
    
    event UserPortfolioCreated(address indexed user, address contractAddress);
    event DefaultAssetConfigSet(uint256 indexed assetId, address token, bytes buyPath, bytes sellPath);
    
    modifier onlyOwner() { require(msg.sender == owner, "ONLY_OWNER"); _; }
    
    constructor(address _usdc, address _usdcPriceFeed, address _wethPriceFeed, address _uniswapRouter) {
        require(_usdc != address(0), "BAD_USDC");
        require(_uniswapRouter != address(0), "BAD_ROUTER");
        USDC = IERC20(_usdc);
        usdcPriceFeed = _usdcPriceFeed;
        wethPriceFeed = _wethPriceFeed;
        defaultUniswapRouter = _uniswapRouter;
        owner = msg.sender;
    }
    
    /// Create a new portfolio for the calling user
    function createUserPortfolio() external {
        require(userContracts[msg.sender] == address(0), "EXISTS");
        
        // Prepare defaults arrays from factory configuration
        uint256 cfgLen = configuredAssetIds.length;
        uint256[] memory assetIds = new uint256[](cfgLen);
        address[] memory tokens = new address[](cfgLen);
        bytes[] memory buyPaths = new bytes[](cfgLen);
        bytes[] memory sellPaths = new bytes[](cfgLen);
        for (uint256 i = 0; i < cfgLen; i++) {
            uint256 aId = configuredAssetIds[i];
            assetIds[i] = aId;
            tokens[i] = defaultAssetToken[aId];
            buyPaths[i] = defaultAssetBuyPath[aId];
            sellPaths[i] = defaultAssetSellPath[aId];
        }

        UserPortfolio userPortfolio = new UserPortfolio(
            address(USDC),
            msg.sender,
            usdcPriceFeed,
            wethPriceFeed,
            defaultUniswapRouter,
            assetIds,
            tokens,
            buyPaths,
            sellPaths
        );
        userContracts[msg.sender] = address(userPortfolio);
        
        emit UserPortfolioCreated(msg.sender, address(userPortfolio));
    }
    
    /// Owner can set default token and BOTH paths for an assetId (used to pre-seed user portfolios)
    function setDefaultAssetConfig(uint256 assetId, address token, bytes calldata buyPath, bytes calldata sellPath) external onlyOwner {
        require(token != address(0), "BAD_TOKEN");
        defaultAssetToken[assetId] = token;
        defaultAssetBuyPath[assetId] = buyPath;   // allow empty path; user contract may skip if empty
        defaultAssetSellPath[assetId] = sellPath; // allow empty path; user contract may skip if empty
        if (!isConfiguredAssetId[assetId]) {
            isConfiguredAssetId[assetId] = true;
            configuredAssetIds.push(assetId);
        }
        emit DefaultAssetConfigSet(assetId, token, buyPath, sellPath);
    }

    /// Get user's portfolio address
    function getUserPortfolio(address user) external view returns (address) {
        return userContracts[user];
    }
}
