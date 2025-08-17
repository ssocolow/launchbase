// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Minimal Chainlink Aggregator interface inlined to avoid external import issues
interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

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
    // Default Uniswap V3 paths (preconfigured, per assetId). Assumption: each supported asset has a direct or
    // multi-hop route to/from USDC. For single-hop, path = encodePacked(USDC, fee, ASSET). For multi-hop, concatenate hops.
    // These defaults are used whenever a function with "WithDefaultPaths" is called, so callers don't have to supply paths.
    mapping(uint256 => bytes) public assetDefaultBuyV3Path;  // USDC -> Asset
    mapping(uint256 => bytes) public assetDefaultSellV3Path; // Asset -> USDC

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
        bytes[] memory _defaultBuyPaths,
        bytes[] memory _defaultSellPaths
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
        require(_assetIds.length == _defaultBuyPaths.length, "LEN_MISMATCH_BUY");
        require(_assetIds.length == _defaultSellPaths.length, "LEN_MISMATCH_SELL");
        for (uint256 i = 0; i < _assetIds.length; i++) {
            uint256 aId = _assetIds[i];
            address t = _tokenAddrs[i];
            bytes memory bp = _defaultBuyPaths[i];
            bytes memory sp = _defaultSellPaths[i];
            if (aId == 0) { // Skip USDC path, but token address should be USDC token itself
                if (t != address(0)) {
                    assetTokenAddresses[aId] = t;
                }
                continue;
            }
            if (t != address(0)) {
                assetTokenAddresses[aId] = t;
            }
            if (bp.length > 0) { assetDefaultBuyV3Path[aId] = bp; }
            if (sp.length > 0) { assetDefaultSellV3Path[aId] = sp; }
        }
    }

    /* ---------------- Core Functions ---------------- */

    /// Deposit USDC and immediately execute buys for non-USDC targets using provided Uniswap V3 paths
    /// - buyPaths/buyAmountOutMinimums must align with the non-USDC rows in _desiredAllocation (in order)
    function depositUsdcWithBuys(
        uint256 usdcIn,
        PortfolioAsset[] memory _desiredAllocation,
        bytes[] calldata buyPaths,
        uint256[] calldata buyAmountOutMinimums
    ) external onlyUser nonReentrant {
        require(usdcIn > 0, "ZERO_IN");
        require(_desiredAllocation.length > 0, "EMPTY_ALLOC");
        require(uniswapRouter != address(0), "NO_ROUTER");

        // Validate allocation sums to 100%
        uint256 totalBps = 0;
        uint256 nonUsdcCount = 0;
        for (uint i = 0; i < _desiredAllocation.length; i++) {
            require(isAssetSupported[_desiredAllocation[i].assetId], "ASSET_UNSUPPORTED");
            require(_desiredAllocation[i].bps > 0, "ZERO_BPS");
            totalBps += _desiredAllocation[i].bps;
            if (_desiredAllocation[i].assetId != 0) nonUsdcCount++;
        }
        require(totalBps == MAX_BPS, "BAD_TOTAL_BPS");
        require(buyPaths.length == nonUsdcCount, "BUY_PATHS_MISMATCH");
        require(buyAmountOutMinimums.length == nonUsdcCount, "BUY_AMOUNTS_MISMATCH");

        // Pull USDC from user
        SafeERC20.safeTransferFrom(USDC, msg.sender, address(this), usdcIn);

        // Execute buys per non-USDC leg
        uint256 buyIndex = 0;
        for (uint i = 0; i < _desiredAllocation.length; i++) {
            uint256 assetId = _desiredAllocation[i].assetId;
            uint256 usdcAmount = (usdcIn * _desiredAllocation[i].bps) / MAX_BPS;
            if (assetId == 0 || usdcAmount == 0) continue; // USDC leg remains as USDC
            _swapUsdcToAsset(buyPaths[buyIndex], usdcAmount, buyAmountOutMinimums[buyIndex]);
            buyIndex++;
        }

        // Rebuild portfolio with actual on-chain balances
        delete portfolio;
        for (uint i = 0; i < _desiredAllocation.length; i++) {
            uint256 assetId = _desiredAllocation[i].assetId;
            uint256 units;
            if (assetId == 0) {
                units = USDC.balanceOf(address(this));
            } else {
                address tokenAddr = assetTokenAddresses[assetId];
                require(tokenAddr != address(0), "TOKEN_ADDR_NOT_SET");
                units = IERC20(tokenAddr).balanceOf(address(this));
            }
            portfolio.push(PortfolioAsset({
                assetId: assetId,
                units: units,
                bps: _desiredAllocation[i].bps,
                lastPrice: _getAssetPrice(assetId),
                lastEdited: block.timestamp
            }));
        }

        emit Deposit(user, usdcIn);
    }

    /// Deposit USDC using factory-stored default paths for each non-USDC asset.
    ///
    /// Inputs and alignment rules:
    /// - _desiredAllocation: includes USDC row(s) and non-USDC rows with target bps. USDC rows are kept as USDC.
    /// - buyAmountOutMinimums: one min-out per non-USDC row (in the same order the rows appear in _desiredAllocation).
    ///   The min-out is the per-swap slippage floor. If Uniswap would return less, the tx reverts.
    /// - Default buy path for each assetId must be set ahead of time via the factory (assetDefaultBuyV3Path).
    ///
    /// Behavior:
    /// - Pulls USDC
    /// - For each non-USDC row, swaps USDC -> Asset using the default buy path and caller-provided min-out
    /// - Rebuilds portfolio using actual on-chain balances (USDC + ERC20 balances)
    function depositUsdcWithDefaultPaths(
        uint256 usdcIn,
        PortfolioAsset[] memory _desiredAllocation,
        uint256[] calldata buyAmountOutMinimums
    ) external onlyUser nonReentrant {
        require(usdcIn > 0, "ZERO_IN");
        require(_desiredAllocation.length > 0, "EMPTY_ALLOC");
        require(uniswapRouter != address(0), "NO_ROUTER");

        uint256 totalBps = 0;
        uint256 nonUsdcCount = 0;
        for (uint i = 0; i < _desiredAllocation.length; i++) {
            require(isAssetSupported[_desiredAllocation[i].assetId], "ASSET_UNSUPPORTED");
            require(_desiredAllocation[i].bps > 0, "ZERO_BPS");
            totalBps += _desiredAllocation[i].bps;
            if (_desiredAllocation[i].assetId != 0) nonUsdcCount++;
        }
        require(totalBps == MAX_BPS, "BAD_TOTAL_BPS");
        require(buyAmountOutMinimums.length == nonUsdcCount, "BUY_AMOUNTS_MISMATCH");

        // Pull USDC from user
        SafeERC20.safeTransferFrom(USDC, msg.sender, address(this), usdcIn);

        // Execute buys using default paths per non-USDC asset
        // NOTE: We intentionally skip a "sell" phase on deposit since the product thesis assumes users deposit USDC only.
        uint256 buyIndex = 0;
        for (uint i = 0; i < _desiredAllocation.length; i++) {
            uint256 assetId = _desiredAllocation[i].assetId;
            uint256 usdcAmount = (usdcIn * _desiredAllocation[i].bps) / MAX_BPS;
            if (assetId == 0 || usdcAmount == 0) continue;
            bytes storage p = assetDefaultBuyV3Path[assetId];
            require(p.length > 0, "DEFAULT_PATH_NOT_SET");
            _swapUsdcToAsset(p, usdcAmount, buyAmountOutMinimums[buyIndex]);
            buyIndex++;
        }

        // Rebuild portfolio with actual on-chain balances
        delete portfolio;
        for (uint i = 0; i < _desiredAllocation.length; i++) {
            uint256 assetId = _desiredAllocation[i].assetId;
            uint256 units;
            if (assetId == 0) {
                units = USDC.balanceOf(address(this));
            } else {
                address tokenAddr = assetTokenAddresses[assetId];
                require(tokenAddr != address(0), "TOKEN_ADDR_NOT_SET");
                units = IERC20(tokenAddr).balanceOf(address(this));
            }
            portfolio.push(PortfolioAsset({
                assetId: assetId,
                units: units,
                bps: _desiredAllocation[i].bps,
                lastPrice: _getAssetPrice(assetId),
                lastEdited: block.timestamp
            }));
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

    /// Get total portfolio value in USDC (including staking gains!)
    function getTotalPortfolioValue() external view returns (uint256) {
        return _portfolioValueUsdc(); 
    }

    /// Core calculator: compute total portfolio value in USDC using Chainlink oracles directly
    function _portfolioValueUsdc() internal view returns (uint256 total) {
        for (uint i = 0; i < portfolio.length; i++) {
            uint256 assetId = portfolio[i].assetId;
            uint256 units = portfolio[i].units;
            if (assetId == 0) {
                total += units; // USDC units already in USDC decimals
            } else {
                uint256 price = _getAssetPrice(assetId); // PRICE_DECIMALS (8)
                uint256 aDec = assetDecimals[assetId];
                // usdc = units * price * 10^usdcDec / 10^(aDec + PRICE_DECIMALS)
                total += (units * price * (10 ** usdcDec)) / (10 ** (aDec + PRICE_DECIMALS));
            }
        }
    }
    
    /* ---------------- Convenience Functions ---------------- */
    
    /// NOTE: Convenience helpers. You can derive the same information from getPortfolio() and getTotalPortfolioValue().
    /// - getUserAllocationBps(): returns stored target bps per asset (not live market weights)
    /// - getUsdcBalance(): returns on-chain USDC balance held by this portfolio
    /// - getAssetBalance(assetId): returns stored units for that asset (synthetic or actual)
    function getUserAllocationBps() external view returns (uint16[] memory bps) {
        bps = new uint16[](portfolio.length);
        for (uint i = 0; i < portfolio.length; i++) {
            bps[i] = portfolio[i].bps;
        }
        return bps;
    }

    function getUsdcBalance() external view returns (uint256) {
        return USDC.balanceOf(address(this));
    }

    function getAssetBalance(uint256 assetId) external view returns (uint256) {
        for (uint i = 0; i < portfolio.length; i++) {
            if (portfolio[i].assetId == assetId) {
                return portfolio[i].units;
            }
        }
        return 0;
    }

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

    /// Helper to swap USDC -> target asset using an encoded V3 path (USDC must be tokenIn of path)
    function _swapUsdcToAsset(bytes memory path, uint256 amountIn, uint256 amountOutMinimum) internal {
        require(amountIn > 0, "ZERO_IN");
        // Approve router to spend USDC
        SafeERC20.safeApprove(USDC, uniswapRouter, 0);
        SafeERC20.safeApprove(USDC, uniswapRouter, amountIn);

        IUniswapV3Router.ExactInputParams memory params = IUniswapV3Router.ExactInputParams({
            path: path,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum
        });
        IUniswapV3Router(uniswapRouter).exactInput(params);
    }

    /// Build default sell/buy paths arrays aligned with non-USDC rows.
    ///
    /// Alignment contract:
    /// - We iterate the current portfolio and consider rows with assetId != 0 (non-USDC) in order.
    /// - For each such row, we append its preconfigured default sell and buy paths to the arrays.
    /// - Callers must provide amountOutMinimums arrays that match this exact ordering.
    function _buildDefaultPaths() internal view returns (bytes[] memory sellPaths, bytes[] memory buyPaths) {
        uint256 nonUsdcCount = 0;
        for (uint i = 0; i < portfolio.length; i++) if (portfolio[i].assetId != 0) nonUsdcCount++;
        sellPaths = new bytes[](nonUsdcCount);
        buyPaths  = new bytes[](nonUsdcCount);
        uint256 idx = 0;
        for (uint i = 0; i < portfolio.length; i++) {
            uint256 aId = portfolio[i].assetId;
            if (aId == 0) continue;
            bytes storage sp = assetDefaultSellV3Path[aId];
            bytes storage bp = assetDefaultBuyV3Path[aId];
            require(sp.length > 0 && bp.length > 0, "DEFAULT_PATH_NOT_SET");
            sellPaths[idx] = sp; buyPaths[idx] = bp; idx++;
        }
    }

    /// Set targets from desired allocation and immediately rebalance using default paths.
    ///
    /// Inputs:
    /// - usdcIn: amount of USDC to pull from user (must be approved)
    /// - _desiredAllocation: per-assetId target bps (USDC rows included; USDC bps remains as USDC)
    /// - sellAmountOutMinimums: per non-USDC row min-out for the sell stage (Asset->USDC). On first deposit this will
    ///   typically be zeros (there is nothing to sell yet), but we keep the parameter for uniformity and future calls.
    /// - buyAmountOutMinimums: per non-USDC row min-out for the buy stage (USDC->Asset)
    ///
    /// Flow:
    /// 1) Pull USDC and write target bps rows (units initially 0)
    /// 2) Build default sell/buy path arrays based on the portfolio order
    /// 3) Call _rebalanceWithPaths(), which:
    ///    - Sells all non-USDC balances to USDC (no-op on first deposit)
    ///    - Buys each non-USDC asset per target bps, using default buy paths and min-outs
    ///    - Refreshes units from actual on-chain balances, and stamps lastPrice/lastEdited
    function depositUsdcAndRebalanceWithDefaults(
        uint256 usdcIn,
        PortfolioAsset[] memory _desiredAllocation,
        uint256[] calldata sellAmountOutMinimums,
        uint256[] calldata buyAmountOutMinimums
    ) external onlyUser nonReentrant {
        require(usdcIn > 0, "ZERO_IN");
        require(_desiredAllocation.length > 0, "EMPTY_ALLOC");
        require(uniswapRouter != address(0), "NO_ROUTER");

        // Validate and pull USDC
        uint256 totalBps = 0; uint256 nonUsdcCount = 0;
        for (uint i=0;i<_desiredAllocation.length;i++) {
            require(isAssetSupported[_desiredAllocation[i].assetId], "ASSET_UNSUPPORTED");
            require(_desiredAllocation[i].bps > 0, "ZERO_BPS");
            totalBps += _desiredAllocation[i].bps;
            if (_desiredAllocation[i].assetId != 0) nonUsdcCount++;
        }
        require(totalBps == MAX_BPS, "BAD_TOTAL_BPS");
        require(sellAmountOutMinimums.length == nonUsdcCount, "SELL_AMOUNTS_MISMATCH");
        require(buyAmountOutMinimums.length  == nonUsdcCount, "BUY_AMOUNTS_MISMATCH");
        SafeERC20.safeTransferFrom(USDC, msg.sender, address(this), usdcIn);

        // Set portfolio targets (units set later by rebalance)
        delete portfolio;
        for (uint i=0;i<_desiredAllocation.length;i++) {
            uint256 aId = _desiredAllocation[i].assetId;
            portfolio.push(PortfolioAsset({
                assetId: aId,
                units: 0,
                bps: _desiredAllocation[i].bps,
                lastPrice: _getAssetPrice(aId),
                lastEdited: block.timestamp
            }));
        }

        // Build default paths and run internal rebalance
        (bytes[] memory sellPaths, bytes[] memory buyPaths) = _buildDefaultPaths();
        _rebalanceWithPaths(sellPaths, sellAmountOutMinimums, buyPaths, buyAmountOutMinimums);

        emit Deposit(user, usdcIn);
    }

    /// Internal helper used by both deposit-with-defaults and manual rebalance.
    ///
    /// Inputs must align with non-USDC rows in current portfolio order:
    /// - sellPaths/sellAmountOutMinimums: one per non-USDC row (Asset->USDC)
    /// - buyPaths/buyAmountOutMinimums: one per non-USDC row (USDC->Asset)
    ///
    /// Steps:
    /// 1) Sell phase: convert any existing non-USDC on-chain balances into USDC using provided paths and min-outs
    /// 2) Compute the USDC pool and target USDC per asset via bps
    /// 3) Buy phase: swap USDC into each non-USDC asset via provided buy paths and min-outs
    /// 4) Refresh the portfolio "units" from actual ERC-20 balances (USDC + non-USDC), update lastPrice/lastEdited
    function _rebalanceWithPaths(
        bytes[] memory sellPaths,
        uint256[] memory sellAmountOutMinimums,
        bytes[] memory buyPaths,
        uint256[] memory buyAmountOutMinimums
    ) internal {
        require(uniswapRouter != address(0), "NO_ROUTER");
        require(portfolio.length > 0, "NO_PORTFOLIO");
        _swapNonUsdcAssets(sellPaths, sellAmountOutMinimums);
        uint256 nonUsdcCount = 0; for (uint i=0;i<portfolio.length;i++) if (portfolio[i].assetId != 0) nonUsdcCount++;
        require(buyPaths.length == nonUsdcCount, "BUY_PATHS_MISMATCH");
        require(buyAmountOutMinimums.length == nonUsdcCount, "BUY_AMOUNTS_MISMATCH");
        uint256 usdcBal = USDC.balanceOf(address(this));
        uint256 buyIndex = 0;
        for (uint i=0;i<portfolio.length;i++) {
            uint256 assetId = portfolio[i].assetId; if (assetId == 0) continue;
            uint256 targetUsdcAmt = (usdcBal * portfolio[i].bps) / MAX_BPS;
            if (targetUsdcAmt == 0) { buyIndex++; continue; }
            _swapUsdcToAsset(buyPaths[buyIndex], targetUsdcAmt, buyAmountOutMinimums[buyIndex]);
            buyIndex++;
        }
        // refresh
        for (uint i=0;i<portfolio.length;i++) {
            uint256 assetId = portfolio[i].assetId;
            if (assetId == 0) { portfolio[i].units = USDC.balanceOf(address(this)); }
            else {
                address tokenAddr = assetTokenAddresses[assetId];
                if (tokenAddr != address(0)) portfolio[i].units = IERC20(tokenAddr).balanceOf(address(this));
            }
            portfolio[i].lastPrice = _getAssetPrice(assetId);
            portfolio[i].lastEdited = block.timestamp;
        }
        emit PortfolioRebalanced(user);
    }

    /// Rebalance by selling all non-USDC assets to USDC, then buying back to target allocations.
    /// Paths arrays must align with the order of non-USDC assets in `portfolio` (skip assetId==0).
    ///
    /// If all assets have direct USDC pools (assumption in this product), each path can be single-hop
    /// encodePacked(USDC, fee, ASSET) for buys and encodePacked(ASSET, fee, USDC) for sells.
    function rebalancePortfolio(
        bytes[] calldata sellPaths,
        uint256[] calldata sellAmountOutMinimums,
        bytes[] calldata buyPaths,
        uint256[] calldata buyAmountOutMinimums
    ) external onlyUser nonReentrant {
        _rebalanceWithPaths(sellPaths, sellAmountOutMinimums, buyPaths, buyAmountOutMinimums);
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