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
    
    // Uniswap V3 Router for swaps
    ISwapRouter public immutable swapRouter;

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

    modifier onlyUser() { require(msg.sender == user, "ONLY_USER"); _; }

    constructor(
        address _usdc,
        address _user,
        address _swapRouter
    ) {
        USDC = IERC20(_usdc);
        user = _user;
        usdcDec = IERC20(_usdc).decimals();
        swapRouter = ISwapRouter(_swapRouter);
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

    function rebalance() external nonReentrant {
        uint256 usdcBalance = USDC.balanceOf(address(this));
        require(usdcBalance > 0, "NO_BALANCE");
        require(portfolio.length > 0, "NO_ALLOCATION");
        
        // For each token in portfolio, swap USDC to achieve target allocation
        for (uint i = 0; i < portfolio.length; i++) {
            PortfolioAllocation memory allocation = portfolio[i];
            
            // Skip USDC (no swap needed)
            if (allocation.token == address(USDC)) {
                continue;
            }
            
            // Calculate target amount for this token
            uint256 targetAmount = (usdcBalance * allocation.bps) / MAX_BPS;
            
            // Check current balance of this token
            uint256 currentBalance = IERC20(allocation.token).balanceOf(address(this));
            
            // If we need more of this token, swap USDC for it
            if (currentBalance < targetAmount) {
                uint256 usdcToSwap = targetAmount - currentBalance;
                
                // Use exactInputSingle to swap USDC for the target token
                swapExactInputSingle(
                    address(USDC),
                    allocation.token,
                    500, // 0.05% fee tier
                    usdcToSwap,
                    0 // No slippage protection for simplicity
                );
            }
        }
        
        emit PortfolioRebalanced(user);
    }

    /* ---------------- View Functions ---------------- */

    function calculatePortfolioValue() public view returns (uint256 total) {
        require(portfolio.length > 0, "NO_ALLOCATION");
        
        uint256 usdcBalance = USDC.balanceOf(address(this));
        total = 0;
        
        for (uint i = 0; i < portfolio.length; i++) {
            PortfolioAllocation memory allocation = portfolio[i];
            
            uint256 allocationAmount = (usdcBalance * allocation.bps) / MAX_BPS;
            
            uint256 price = _getAssetPrice(allocation.priceFeed);
            
            uint256 assetUnits = (allocationAmount * (10 ** allocation.decimals)) / (price * (10 ** usdcDec));
            total += (assetUnits * price * (10 ** usdcDec)) / (10 ** (allocation.decimals + PRICE_DECIMALS));
        }
    }

    function getPortfolio() external view returns (PortfolioAllocation[] memory) {
        return portfolio;
    }

    /// Debug function to test price feed
    function testPriceFeed(address priceFeed) external view returns (uint256 price, uint8 decimals) {
        require(priceFeed != address(0), "ORACLE_NOT_SET");
        
        AggregatorV3Interface feed = AggregatorV3Interface(priceFeed);
        (, int256 priceInt, , , ) = feed.latestRoundData();
        require(priceInt > 0, "BAD_PRICE");
        
        price = uint256(priceInt);
        decimals = feed.decimals();
    }

    /// Debug function to test calculation step by step
    function debugCalculation() external view returns (
        uint256 usdcBalance,
        uint256 allocationAmount,
        uint256 price,
        uint256 assetUnits,
        uint256 finalValue
    ) {
        require(portfolio.length > 0, "NO_ALLOCATION");
        
        usdcBalance = USDC.balanceOf(address(this));
        PortfolioAllocation memory allocation = portfolio[0]; // First allocation
        
        allocationAmount = (usdcBalance * allocation.bps) / MAX_BPS;
        price = _getAssetPrice(allocation.priceFeed);
        
        // For USDC, the calculation should be simpler
        if (allocation.token == address(USDC)) {
            assetUnits = allocationAmount;
            finalValue = allocationAmount;
        } else {
            assetUnits = (allocationAmount * (10 ** allocation.decimals)) / (price * (10 ** usdcDec));
            finalValue = (assetUnits * price * (10 ** usdcDec)) / (10 ** (allocation.decimals + PRICE_DECIMALS));
        }
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

    /// @notice swapExactInputSingle swaps a fixed amount of tokenIn for a maximum possible amount of tokenOut
    /// @param tokenIn The token being swapped in
    /// @param tokenOut The token being swapped out
    /// @param fee The fee tier of the pool
    /// @param amountIn The exact amount of tokenIn that will be swapped for tokenOut
    /// @param amountOutMinimum The minimum amount of tokenOut to receive
    /// @return amountOut The amount of tokenOut received
    function swapExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) public returns (uint256 amountOut) {
        // Approve the router to spend tokenIn
        TransferHelper.safeApprove(tokenIn, address(swapRouter), amountIn);

        // Create the swap parameters
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: address(this),
                deadline: block.timestamp + 300, // 5 minute deadline
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0
            });

        // Execute the swap
        amountOut = swapRouter.exactInputSingle(params);
    }

    /// @notice swapExactOutputSingle swaps a minimum possible amount of tokenIn for a fixed amount of tokenOut
    /// @param tokenIn The token being swapped in
    /// @param tokenOut The token being swapped out
    /// @param fee The fee tier of the pool
    /// @param amountOut The exact amount of tokenOut to receive
    /// @param amountInMaximum The maximum amount of tokenIn we are willing to spend
    /// @return amountIn The amount of tokenIn actually spent
    function swapExactOutputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountOut,
        uint256 amountInMaximum
    ) public returns (uint256 amountIn) {
        // Approve the router to spend the maximum amount of tokenIn
        TransferHelper.safeApprove(tokenIn, address(swapRouter), amountInMaximum);

        // Create the swap parameters
        ISwapRouter.ExactOutputSingleParams memory params =
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: address(this),
                deadline: block.timestamp + 300, // 5 minute deadline
                amountOut: amountOut,
                amountInMaximum: amountInMaximum,
                sqrtPriceLimitX96: 0
            });

        // Execute the swap
        amountIn = swapRouter.exactOutputSingle(params);

        // For exact output swaps, the amountInMaximum may not have all been spent
        // If the actual amount spent (amountIn) is less than the specified maximum amount, we must refund and approve 0
        if (amountIn < amountInMaximum) {
            TransferHelper.safeApprove(tokenIn, address(swapRouter), 0);
            TransferHelper.safeTransfer(tokenIn, address(this), amountInMaximum - amountIn);
        }
    }
}
