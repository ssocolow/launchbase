// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * RiskSliderSynthetic
 * - Accepts REAL USDC (pass address at deploy)
 * - Users deposit USDC only
 * - Contract records a virtual WETH leg in *USDC terms* (no real WETH, no swaps)
 * - Withdraw returns USDC only: usdcLedger + wethExposureUsdc
 * - Always solvent: we only ever pay out USDC that was deposited
 *
 * Later: swap the synthetic logic for real Uniswap swaps behind the same function
 * signatures, or add a flag to route to the real router.
 */


 /*
 Notes
 EACH USER GETS OWN CONTRACT
  * - User-specific risk profiles (USDC vs Virtual WETH)
 * - Extensible for future assets
 * - Risk determination done off-chain
 */

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function allowance(address,address) external view returns (uint256);
    function approve(address,uint256) external returns (bool);
    function transfer(address,uint256) external returns (bool);
    function transferFrom(address,address,uint256) external returns (bool);
    function decimals() external view returns (uint8);
}

library SafeERC20 {
    function safeTransfer(IERC20 t, address to, uint256 amt) internal {
        require(t.transfer(to, amt), "TRANSFER_FAIL");
    }
    function safeTransferFrom(IERC20 t, address from, address to, uint256 amt) internal {
        require(t.transferFrom(from, to, amt), "TRANSFERFROM_FAIL");
    }
    function safeApprove(IERC20 t, address sp, uint256 amt) internal {
        require(t.approve(sp, amt), "APPROVE_FAIL");
    }
}
 //basically a middleware lock to prevent reentrancy
abstract contract ReentrancyGuard {
    uint256 private _status = 1;
    modifier nonReentrant() {
        require(_status == 1, "REENTRANT");
        _status = 2;
        _;
        _status = 1;
    }
}

// Minimal Uniswap V3 router interface for exactInput
interface IUniswapV3Router {
    struct ExactInputParams {
        bytes path;               // encoded path: tokenIn, fee, tokenOut, ... ending in USDC
        address recipient;        // recipient of output tokens
        uint256 deadline;         // unix timestamp deadline
        uint256 amountIn;         // amount of tokenIn to swap
        uint256 amountOutMinimum; // slippage control
    }

    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
}

// Factory contract - deploys individual user contracts
contract PortfolioFactory {
    IERC20 public immutable USDC;
    address public immutable usdcPriceFeed;
    address public immutable wethPriceFeed;
    address public immutable defaultUniswapRouter;
    address public owner;
    mapping(address => address) public userContracts;
    mapping(uint256 => address) public defaultAssetToken;
    mapping(uint256 => bytes) public defaultAssetPath;
    uint256[] public configuredAssetIds;
    mapping(uint256 => bool) private isConfiguredAssetId;
    
    event UserPortfolioCreated(address indexed user, address contractAddress);
    event DefaultAssetConfigSet(uint256 indexed assetId, address token, bytes path);
    
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
        bytes[] memory paths = new bytes[](cfgLen);
        for (uint256 i = 0; i < cfgLen; i++) {
            uint256 aId = configuredAssetIds[i];
            assetIds[i] = aId;
            tokens[i] = defaultAssetToken[aId];
            paths[i] = defaultAssetPath[aId];
        }

        UserPortfolio userPortfolio = new UserPortfolio(
            address(USDC),
            msg.sender,
            usdcPriceFeed,
            wethPriceFeed,
            defaultUniswapRouter,
            assetIds,
            tokens,
            paths
        );
        userContracts[msg.sender] = address(userPortfolio);
        
        emit UserPortfolioCreated(msg.sender, address(userPortfolio));
    }
    
    /// Owner can set default token and path for an assetId (used to pre-seed user portfolios)
    function setDefaultAssetConfig(uint256 assetId, address token, bytes calldata path) external onlyOwner {
        require(token != address(0), "BAD_TOKEN");
        defaultAssetToken[assetId] = token;
        defaultAssetPath[assetId] = path; // allow empty path; user contract may skip if empty
        if (!isConfiguredAssetId[assetId]) {
            isConfiguredAssetId[assetId] = true;
            configuredAssetIds.push(assetId);
        }
        emit DefaultAssetConfigSet(assetId, token, path);
    }

    /// Get user's portfolio address
    function getUserPortfolio(address user) external view returns (address) {
        return userContracts[user];
    }
}

// Individual user portfolio - each user gets their own
contract UserPortfolio is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable USDC;
    address public immutable user;
    uint8 public immutable usdcDec;
    uint16 public constant MAX_BPS = 10_000;
    uint8 public constant PRICE_DECIMALS = 8; // Prices returned by _getAssetPrice use 8 decimals

    // External DEX router (for future real swaps)
    address public uniswapRouter; // TODO: set to real router when implementing swaps

    // Oracle price feeds
    mapping(uint256 => AggregatorV3Interface) public priceFeeds;

    // Struct for each portfolio asset
    struct PortfolioAsset {
        uint256 assetId;        // 0=USDC, 1=WETH, 2=BTC, etc.
        uint256 units;          // Actual units (USDC units, WETH units, etc.)
        uint16 bps;             // Target allocation
        uint256 lastPrice;      // Price when last updated (for rebalancing)
        uint256 lastEdited;     // Timestamp of last edit (for rebalancing)
    }

    // User's portfolio
    PortfolioAsset[] public portfolio;
    
    // Asset metadata for future extensibility
    mapping(uint256 => string) public assetNames;
    mapping(uint256 => uint8) public assetDecimals;
    mapping(uint256 => bool) public isAssetSupported; // guard unsupported assets
    mapping(uint256 => address) public assetTokenAddresses; // ERC20 token addresses for assets (required for real swaps)
    mapping(uint256 => bytes) public assetDefaultV3Path; // Default Uniswap V3 path (encoded) for assetId -> USDC

    // Events
    event Deposit(address indexed user, uint256 usdcIn);
    event WithdrawAllUSDC(address indexed user, uint256 usdcOut);
    event PortfolioRebalanced(address indexed user);
    event SwapUsdcToPortfolioRequested(address indexed user); // future real swap
    event SwapAllAssetsToUsdcRequested(address indexed user); // future real swap

    // Only that specific user can call these functions

    // TODO: confirm this is OK in the frontend, i.e. we will always be logged into that user account when we call it.
    modifier onlyUser() { require(msg.sender == user, "ONLY_USER"); _; }

    constructor(
        address _usdc,
        address _user,
        address _usdcPriceFeed,
        address _wethPriceFeed,
        address _router,
        uint256[] memory _assetIds,
        address[] memory _tokenAddrs,
        bytes[] memory _defaultPaths
    ) {
        USDC = IERC20(_usdc);
        user = _user;
        usdcDec = IERC20(_usdc).decimals();
        
        // Initialize asset metadata
        assetNames[0] = "USDC";
        assetNames[1] = "WETH";
        assetDecimals[0] = 6;
        assetDecimals[1] = 18;
        isAssetSupported[0] = true;
        isAssetSupported[1] = true;

        // Set price feeds
        require(_usdcPriceFeed != address(0), "BAD_USDC_FEED");
        require(_wethPriceFeed != address(0), "BAD_WETH_FEED");
        priceFeeds[0] = AggregatorV3Interface(_usdcPriceFeed); // USDC
        priceFeeds[1] = AggregatorV3Interface(_wethPriceFeed); // WETH

        // Set Uniswap router
        require(_router != address(0), "BAD_ROUTER");
        uniswapRouter = _router;

        // Seed default token addresses and paths
        require(_assetIds.length == _tokenAddrs.length, "LEN_MISMATCH_TOKENS");
        require(_assetIds.length == _defaultPaths.length, "LEN_MISMATCH_PATHS");
        for (uint256 i = 0; i < _assetIds.length; i++) {
            uint256 aId = _assetIds[i];
            address t = _tokenAddrs[i];
            bytes memory p = _defaultPaths[i];
            if (aId == 0) { // Skip USDC path, but token address should be USDC token itself
                if (t != address(0)) {
                    assetTokenAddresses[aId] = t;
                }
                continue;
            }
            if (t != address(0)) {
                assetTokenAddresses[aId] = t;
            }
            if (p.length > 0) {
                assetDefaultV3Path[aId] = p;
            }
        }
    }

    /* ---------------- Core Functions ---------------- */

    /// Configure Uniswap router (for future real swaps)
    function setUniswapRouter(address router) external onlyUser {
        require(router != address(0), "BAD_ROUTER");
        uniswapRouter = router;
    }



    /// Deposit USDC and allocate according to user's desired mix
    function depositUsdc(uint256 usdcIn, PortfolioAsset[] memory _desiredAllocation) external onlyUser nonReentrant {
        require(usdcIn > 0, "ZERO_IN");
        require(_desiredAllocation.length > 0, "EMPTY_ALLOC");

        // Check allocation adds up to 100%
        uint256 totalBps = 0;
        for (uint i = 0; i < _desiredAllocation.length; i++) {
            require(isAssetSupported[_desiredAllocation[i].assetId], "ASSET_UNSUPPORTED");
            require(_desiredAllocation[i].bps > 0, "ZERO_BPS");
            totalBps += _desiredAllocation[i].bps;
        }
        require(totalBps == MAX_BPS, "BAD_TOTAL_BPS");

        // Pull USDC from user
        SafeERC20.safeTransferFrom(USDC, msg.sender, address(this), usdcIn);

        // Clear existing portfolio and create new one (should be safe for initial deposit and also rebalancing)
        delete portfolio;

        // Allocate according to desired mix, using yet to be implemented helper
        for (uint i = 0; i < _desiredAllocation.length; i++) {
            uint256 usdcAmount = (usdcIn * _desiredAllocation[i].bps) / MAX_BPS;
            if (usdcAmount > 0) {
                uint256 assetUnits = _quoteUsdcToAssetUnits(_desiredAllocation[i].assetId, usdcAmount);
                
                portfolio.push(PortfolioAsset({
                    assetId: _desiredAllocation[i].assetId,
                    units: assetUnits,
                    bps: _desiredAllocation[i].bps,
                    lastPrice: _getAssetPrice(_desiredAllocation[i].assetId),
                    lastEdited: block.timestamp
                }));
            }
        }

        emit Deposit(user, usdcIn);
    }

    

    /// Exit everything as USDC (including staking gains!)
    function withdrawAllAsUSDC() external onlyUser nonReentrant {
        uint256 actualBalance = USDC.balanceOf(address(this)); // Real balance (including staking)
        require(actualBalance > 0, "EMPTY");

        // Zero out before external interaction (CEI)
        delete portfolio;

        // Transfer actual balance (no quoting needed)
        SafeERC20.safeTransfer(USDC, user, actualBalance);
        emit WithdrawAllUSDC(user, actualBalance);
    }

    /* ---------------- View Functions ---------------- */

    /// Get user's current portfolio
    function getPortfolio() external view returns (PortfolioAsset[] memory) {
        return portfolio;
    }

    /// Quote total portfolio value in USDC terms (converts all asset units using current oracle prices)
    function quotePortfolioValueUsdc() public view returns (uint256) {
        uint256 totalClaimable;
        for (uint i = 0; i < portfolio.length; i++) {
            totalClaimable += _quoteAssetUnitsToUsdc(portfolio[i].assetId, portfolio[i].units);
        }
        return totalClaimable;
    }

    /// Get user's current allocation percentages (targets)
    function getUserAllocationBps() external view returns (uint16[] memory bps) {
        bps = new uint16[](portfolio.length);
        
        for (uint i = 0; i < portfolio.length; i++) {
            bps[i] = portfolio[i].bps;
        }
    }

    /// Get user's current allocation percentages (live, based on quotes). NOTE: might not be wholly accurate bc gas, esp with circle
    function getUserCurrentAllocationBps() external view returns (uint16[] memory bps) {
        bps = new uint16[](portfolio.length);
        uint256 total = quotePortfolioValueUsdc();
        if (total == 0) return bps;
        for (uint i = 0; i < portfolio.length; i++) {
            uint256 valUsdc = _quoteAssetUnitsToUsdc(portfolio[i].assetId, portfolio[i].units);
            bps[i] = uint16((valUsdc * MAX_BPS) / total);
        }
    }

    /// Get actual USDC balance in this contract
    function getUsdcBalance() external view returns (uint256) {
        return USDC.balanceOf(address(this));
    }

    /// Get total portfolio value in USDC (including staking gains!)
    function getTotalPortfolioValue() external view returns (uint256) {
        return quotePortfolioValueUsdc(); // This includes conversions using oracle
    }

    /// Check individual asset balances
    function getAssetBalance(uint256 assetId) external view returns (uint256) {
        for (uint i = 0; i < portfolio.length; i++) {
            if (portfolio[i].assetId == assetId) {
                return portfolio[i].units;
            }
        }
        return 0;
    }

    /* ---------------- Convenience Functions ---------------- */

    // Approve helper removed: users must approve USDC to this contract from their wallet UI (e.g., MetaMask)
    // before calling depositUsdc(). This contract cannot approve on behalf of the user.

    /* ---------------- Internal Helpers ---------------- */

    function _getAssetPrice(uint256 assetId) internal view returns (uint256) {
        AggregatorV3Interface priceFeed = priceFeeds[assetId];
        require(address(priceFeed) != address(0), "ORACLE_NOT_SET");

        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "BAD_PRICE");

        uint8 oracleDecimals = priceFeed.decimals();
        
        // Adjust price to our internal PRICE_DECIMALS (8)
        if (oracleDecimals > PRICE_DECIMALS) {
            return uint256(price) / (10**(oracleDecimals - PRICE_DECIMALS));
        } else {
            return uint256(price) * (10**(PRICE_DECIMALS - oracleDecimals));
        }
    }

    // Helper function for future Uniswap integration (QUOTE ONLY, no state changes)
    // TODO: REPLACE WITH REAL UNISWAP SWAPS (See below func) when implementing actual redemption swaps. This currently only computes units from USDC using price.
    function _quoteUsdcToAssetUnits(uint256 assetId, uint256 usdcAmount) internal view returns (uint256) {
        require(isAssetSupported[assetId], "ASSET_UNSUPPORTED");
        if (assetId == 0) return usdcAmount; // USDC stays as USDC
        
        // units = usdcAmount * 10^(aDec + PRICE_DECIMALS) / (price * 10^usdcDec)
        uint256 price = _getAssetPrice(assetId);                  // 8 decimals
        uint256 aDec = assetDecimals[assetId];                    // e.g., 18
        return (usdcAmount * (10 ** (aDec + PRICE_DECIMALS))) / (price * (10 ** usdcDec));
    }

    /// Quote conversion of asset units back to USDC terms (no state changes)
    // TODO: TEMPORARY, WITH REAL UNISWAP SWAPS (See below func) when implementing actual redemption swaps
    function _quoteAssetUnitsToUsdc(uint256 assetId, uint256 assetUnits) internal view returns (uint256) {
        require(isAssetSupported[assetId], "ASSET_UNSUPPORTED");
        if (assetId == 0) return assetUnits; // USDC stays as USDC
        
        // usdc = assetUnits * price * 10^usdcDec / 10^(aDec + PRICE_DECIMALS), since price decimals diff for each curr
        uint256 price = _getAssetPrice(assetId);                  // 8 decimals
        uint256 aDec = assetDecimals[assetId];                    // e.g., 18
        return (assetUnits * price * (10 ** usdcDec)) / (10 ** (aDec + PRICE_DECIMALS));
    }

    /// USDC -> portfolio via Uniswap (stub; will perform real swaps later)
    // TODO: implement real swaps using router when non-virtual assets are held
    function swapUsdcToPortfolioViaUniswap(PortfolioAsset[] memory _desiredAllocation, bytes[] calldata /*paths*/) external onlyUser nonReentrant {
        require(uniswapRouter != address(0), "NO_ROUTER");
        // Placeholder: just reuse current virtual allocation flow for hackathon (no real swap)
        // Pull amount must be pre-approved; expect caller to call depositUsdc for now.
        revert("NOT_IMPLEMENTED_REAL_SWAP");
        // emit SwapUsdcToPortfolioRequested(user);
    }

    /// All assets -> USDC via Uniswap (stub; will perform real swaps later)
    // TODO: implement real swaps using router when non-virtual assets are held
    function swapAllAssetsToUsdcViaUniswap(bytes[] calldata paths) external onlyUser nonReentrant {
        require(uniswapRouter != address(0), "NO_ROUTER");
        require(portfolio.length > 0, "NO_PORTFOLIO");

        _swapNonUsdcAssets(paths);

        // After swaps, clear the portfolio and transfer all USDC to the user
        delete portfolio;
        uint256 usdcOut = USDC.balanceOf(address(this));
        require(usdcOut > 0, "NO_USDC_OUT");
        SafeERC20.safeTransfer(USDC, user, usdcOut);

        emit SwapAllAssetsToUsdcRequested(user);
        emit WithdrawAllUSDC(user, usdcOut);
    }

    /// Convenience: withdraw using stored default paths per asset
    function withdrawAllAsUSDCWithDefaultPaths() external onlyUser nonReentrant {
        require(uniswapRouter != address(0), "NO_ROUTER");
        require(portfolio.length > 0, "NO_PORTFOLIO");

        // Build paths array based on current portfolio order (excluding USDC)
        uint256 nonUsdcCount = 0;
        for (uint i = 0; i < portfolio.length; i++) {
            if (portfolio[i].assetId != 0) {
                nonUsdcCount++;
            }
        }
        bytes[] memory paths = new bytes[](nonUsdcCount);
        uint256 idx = 0;
        for (uint i = 0; i < portfolio.length; i++) {
            uint256 assetId = portfolio[i].assetId;
            if (assetId == 0) continue;
            bytes storage p = assetDefaultV3Path[assetId];
            require(p.length > 0, "DEFAULT_PATH_NOT_SET");
            paths[idx] = p;
            idx++;
        }

        _swapNonUsdcAssets(paths, amountOutMinimums);

        delete portfolio;
        uint256 usdcOut = USDC.balanceOf(address(this));
        require(usdcOut > 0, "NO_USDC_OUT");
        SafeERC20.safeTransfer(USDC, user, usdcOut);

        emit SwapAllAssetsToUsdcRequested(user);
        emit WithdrawAllUSDC(user, usdcOut);
    }

    function _swapNonUsdcAssets(bytes[] memory paths, uint256[] memory amountOutMinimums) internal {
        // Iterate non-USDC assets and swap their full balances to USDC
        uint256 nonUsdcCount = 0;
        for (uint i = 0; i < portfolio.length; i++) {
            if (portfolio[i].assetId != 0) {
                nonUsdcCount++;
            }
        }
        require(paths.length == nonUsdcCount, "PATHS_MISMATCH");
        require(amountOutMinimums.length == nonUsdcCount, "AMOUNT_OUT_MIN_MISMATCH");

        uint256 pathIndex = 0;
        for (uint i = 0; i < portfolio.length; i++) {
            uint256 assetId = portfolio[i].assetId;
            if (assetId == 0) {
                continue; // Skip USDC
            }

            address tokenAddr = assetTokenAddresses[assetId];
            require(tokenAddr != address(0), "TOKEN_ADDR_NOT_SET");

            IERC20 token = IERC20(tokenAddr);
            uint256 amountIn = token.balanceOf(address(this));
            if (amountIn == 0) {
                pathIndex++;
                continue; // Nothing to swap for this asset
            }

            // Approve router to spend token
            SafeERC20.safeApprove(token, uniswapRouter, 0);
            SafeERC20.safeApprove(token, uniswapRouter, amountIn);

            // Execute swap to USDC using provided V3-encoded path for this asset
            IUniswapV3Router.ExactInputParams memory params = IUniswapV3Router.ExactInputParams({
                path: paths[pathIndex],
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimums[pathIndex] // User inputted slippage protection
            });

            IUniswapV3Router(uniswapRouter).exactInput(params);
            pathIndex++;
        }
    }
    /// Future: rebalance function (simplified) - just update prices for now (inline, not real, detached from reality/oracle)
    // TODO: REPLACE WITH REAL REBALANCING LOGIC
    function rebalancePortfolio() external onlyUser {
        // Just update prices for now (inline)
        for (uint i = 0; i < portfolio.length; i++) {
            portfolio[i].lastPrice = _getAssetPrice(portfolio[i].assetId);
            portfolio[i].lastEdited = block.timestamp;
        }
        emit PortfolioRebalanced(user);
    }

}


/*
Assumptions
- Single deposit (assume fixed package, no changes in bps)
- Single withdrawal
- infrequent rebalancing (just once or twice for the demo.)
- Sequential function call (no withdrawal during processing deposit)
- Asset IDs, for now just USDC and WETH, but future easy to add more.
- Each user gets their own contract (no shared pool)
*/