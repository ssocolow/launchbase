// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Interfaces.sol";
import "./Libraries.sol";

/**
 * UserPortfolio - Multi-token portfolio management
 * Tracks allocations and calculates portfolio value based on target percentages
 */
contract UserPortfolio is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable USDC;
    address public immutable user;
    uint8 public immutable usdcDec;
    uint16 public constant MAX_BPS = 10_000;
    uint8 public constant PRICE_DECIMALS = 8;
    address public liquidityVault;

    struct PortfolioAllocation {
        address token;         // Token address
        uint16 bps;            // Target allocation percentage
        uint8 decimals;        // Asset decimals
        address priceFeed;     // Price feed address
        uint256 lastEdited;    // Timestamp of last edit
    }

    // Portfolio configuration - array of allocations
    PortfolioAllocation[] public portfolio;

    // Events
    event Deposit(address indexed user, uint256 usdcAmount);
    event PortfolioAllocationSet(address indexed user, address[] tokens, uint16[] bps);
    event Withdraw(address indexed user, uint256 usdcAmount);
    event PortfolioRebalanced(address indexed user);
    event ETHPriceIncreaseSimulated(address indexed user, uint256 wethAmount);

    modifier onlyUser() { require(msg.sender == user, "ONLY_USER"); _; }

    constructor(
        address _usdc,
        address _user,
        address _liquidityVault
    ) {
        USDC = IERC20(_usdc);
        user = _user;
        usdcDec = IERC20(_usdc).decimals();
        liquidityVault = _liquidityVault;
    }

    /* ---------------- Core Functions ---------------- */

    /// Deposit USDC into the portfolio
    function depositUsdc(uint256 usdcIn) external onlyUser nonReentrant {
        require(usdcIn > 0, "ZERO_IN");
        
        // Pull USDC
        SafeERC20.safeTransferFrom(USDC, msg.sender, address(this), usdcIn);

        emit Deposit(user, usdcIn);
    }

    /// Set the portfolio allocation targets
    function setPortfolioAllocation(
        address[] memory tokens,
        uint16[] memory bps,
        uint8[] memory decimals,
        address[] memory priceFeeds
    ) external onlyUser {
        require(tokens.length > 0, "EMPTY_ALLOC");
        require(tokens.length == bps.length, "LEN_MISMATCH_BPS");
        require(tokens.length == decimals.length, "LEN_MISMATCH_DECIMALS");
        require(tokens.length == priceFeeds.length, "LEN_MISMATCH_FEEDS");

        // Validate allocation
        uint256 totalBps = 0;
        for (uint i = 0; i < bps.length; i++) {
            require(bps[i] > 0, "ZERO_BPS");
            totalBps += bps[i];
        }
        require(totalBps == MAX_BPS, "BAD_TOTAL_BPS");
        
        // Clear existing portfolio by deleting the array
        delete portfolio;
        
        // Set new portfolio allocations
        for (uint i = 0; i < tokens.length; i++) {
            portfolio.push(PortfolioAllocation({
                token: tokens[i],
                bps: bps[i],
                decimals: decimals[i],
                priceFeed: priceFeeds[i],
                lastEdited: block.timestamp
            }));
        }

        emit PortfolioAllocationSet(user, tokens, bps);
    }

    /// Withdraw all USDC
    function withdrawAllAsUSDC() external onlyUser nonReentrant {
        uint256 usdcBalance = USDC.balanceOf(address(this));
        require(usdcBalance > 0, "NO_BALANCE");
        
        // Transfer USDC to user
        SafeERC20.safeTransfer(USDC, user, usdcBalance);
        
        emit Withdraw(user, usdcBalance);
    }

    /// Demo: Simulate ETH price increase by requesting WETH from LiquidityVault
    /// This represents the portfolio gaining value due to ETH price appreciation
    function simulateETHPriceIncrease(uint256 wethAmount) external onlyUser {
        require(liquidityVault != address(0), "NO_VAULT");
        require(wethAmount > 0, "ZERO_AMOUNT");
        
        // Request WETH from LiquidityVault (simulates ETH price going up)
        ILiquidityVault(liquidityVault).requestWETH(wethAmount);
        
        // The WETH is now in this portfolio, representing increased ETH value
        emit ETHPriceIncreaseSimulated(user, wethAmount);
    }

    function rebalance() external nonReentrant {
        
        require(portfolio.length > 0, "no target");
        require(liquidityVault != address(0), "NO_VAULT");

        // Demo: Convert all non-USDC assets to USDC using LiquidityVault
        for (uint i = 0; i < portfolio.length; i++) {
            address token = portfolio[i].token;
            if (token == address(0) || token == address(USDC)) continue; // Skip zero address and USDC itself
            uint256 bal = IERC20(token).balanceOf(address(this));
            if (bal == 0) continue;

            // Demo: For WETH, use LiquidityVault's fixed-rate swap
            if (token == ILiquidityVault(liquidityVault).WETH()) {
                SafeERC20.safeApprove(IERC20(token), liquidityVault, bal);
                ILiquidityVault(liquidityVault).swapExactWETHForUSDCFixed(bal, address(this));
            }
        }
 
        // Update timestamps to show rebalancing occurred
        for (uint i = 0; i < portfolio.length; i++) {
            portfolio[i].lastEdited = block.timestamp;
        }

        emit PortfolioRebalanced(user);
    }

    /* ---------------- View Functions ---------------- */

    function calculatePortfolioValue() public view returns (uint256 total) {
        require(portfolio.length > 0, "NO_ALLOCATION");
        total = 0;
        for (uint i = 0; i < portfolio.length; i++) {
            PortfolioAllocation memory a = portfolio[i];
            if (a.token == address(USDC)) {
                total += USDC.balanceOf(address(this));
            } else {
                uint256 bal = IERC20(a.token).balanceOf(address(this));
                if (bal == 0) continue;
                uint256 price = _getAssetPrice(a.priceFeed); // 8 dp
                // usdc = bal * price * 10^usdcDec / 10^(a.decimals + PRICE_DECIMALS)
                total += (bal * price * (10 ** usdcDec)) / (10 ** (a.decimals + PRICE_DECIMALS));
            }
        }
    }

    function getPortfolio() external view returns (PortfolioAllocation[] memory) {
        return portfolio;
    }
    
    /* ---------------- Internal Helpers ---------------- */

    function _getAssetPrice(address priceFeed) internal view returns (uint256) {
        require(priceFeed != address(0), "ORACLE_NOT_SET");

        AggregatorV3Interface feed = AggregatorV3Interface(priceFeed);
        (, int256 price, , , ) = feed.latestRoundData();
        require(price > 0, "BAD_PRICE");

        uint8 oracleDecimals = feed.decimals();
        
        // Adjust price to our internal PRICE_DECIMALS (8)
        if (oracleDecimals > PRICE_DECIMALS) {
            return uint256(price) / (10**(oracleDecimals - PRICE_DECIMALS));
        } else {
            return uint256(price) * (10**(PRICE_DECIMALS - oracleDecimals));
        }
    }

    

}
