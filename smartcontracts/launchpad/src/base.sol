// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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

// Factory contract - deploys individual user contracts
contract PortfolioFactory {
    IERC20 public immutable USDC;
    mapping(address => address) public userContracts;
    
    event UserPortfolioCreated(address indexed user, address contractAddress);
    
    constructor(address _usdc) {
        require(_usdc != address(0), "BAD_USDC");
        USDC = IERC20(_usdc);
    }
    
    /// Create a new portfolio for the calling user
    function createUserPortfolio() external {
        require(userContracts[msg.sender] == address(0), "EXISTS");
        
        UserPortfolio userPortfolio = new UserPortfolio(address(USDC), address(0), msg.sender);
        userContracts[msg.sender] = address(userPortfolio);
        
        emit UserPortfolioCreated(msg.sender, address(userPortfolio));
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
    IERC20 public immutable WETH;
    address public immutable user;
    uint8 public immutable usdcDec;
    uint16 public constant MAX_BPS = 10_000;
    uint8 public constant PRICE_DECIMALS = 8; // Prices returned by _getAssetPrice use 8 decimals

    // External DEX router (for future real swaps)
    address public uniswapRouter; // TODO: set to real router when implementing swaps

    // Struct for each portfolio asset
    struct PortfolioAsset {
        uint256 assetId;        // 0=USDC, 1=WETH, 2=BTC, etc.
        address tokenAddress;   // Token address (ERC-20)
        uint256 units;          // Actual units (USDC units, WETH units, etc.)
        uint16 bps;             // Target allocation
        uint256 lastEdited;     // Timestamp of last edit (for rebalancing)
    }

    // User's portfolio
    PortfolioAsset[] public portfolio;
    
    // Asset metadata for future extensibility
    mapping(uint256 => string) public assetNames;
    mapping(uint256 => uint8) public assetDecimals;
    mapping(uint256 => bool) public isAssetSupported; // guard unsupported assets

    // Events
    event Deposit(address indexed user, uint256 usdcIn);
    event WithdrawAllUSDC(address indexed user, uint256 usdcOut);
    event PortfolioRebalanced(address indexed user);
    event SwapUsdcToPortfolioRequested(address indexed user); // future real swap
    event SwapAllAssetsToUsdcRequested(address indexed user); // future real swap

    // Only that specific user can call these functions

    // TODO: confirm this is OK in the frontend, i.e. we will always be logged into that user account when we call it.
    modifier onlyUser() { require(msg.sender == user, "ONLY_USER"); _; }

    constructor(address _usdc, address _weth, address _user) {
        USDC = IERC20(_usdc);
        WETH = IERC20(_weth);
        user = _user;
        usdcDec = IERC20(_usdc).decimals();
        
        // Initialize asset metadata
        assetNames[0] = "USDC";
        assetNames[1] = "WETH";
        assetDecimals[0] = 6;
        assetDecimals[1] = 18;
        isAssetSupported[0] = true;
        isAssetSupported[1] = true;
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
                    tokenAddress: _desiredAllocation[i].tokenAddress,
                    units: assetUnits,
                    bps: _desiredAllocation[i].bps,
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

    // Simple price function - just USDC and WETH for now
    // TODO: REPLACE WITH REAL ORACLE
    function _getAssetPrice(uint256 assetId) internal view returns (uint256) {
        if (assetId == 0) return 1_000_000;        // USDC = $1.00 (6 decimals)
        if (assetId == 1) return 3000_000_000_00;  // WETH = $3000.00 (8 decimals)
        revert("ASSET_UNSUPPORTED");
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
    function swapAllAssetsToUsdcViaUniswap(bytes[] calldata /*paths*/) external onlyUser nonReentrant {
        require(uniswapRouter != address(0), "NO_ROUTER");
        revert("NOT_IMPLEMENTED_REAL_SWAP");
        // emit SwapAllAssetsToUsdcRequested(user);
    }
    /// Rebalance the Portfolio
    function rebalancePortfolio() external onlyUser {
        PortfolioAsset[] storage portf = portfolio;
        require(portf.length > 0, "no target");
        require(uniswapRouter != address(0), "NO_ROUTER"); // Router is needed for swaps

        /// Convert all Assets into USDC
        for (uint i = 0; i < portf.length; i++) {
            address token = portf[i].tokenAddress;
            if (token == address(0) || token == address(USDC)) continue; // Skip zero address and USDC itself
            uint256 bal = IERC20(token).balanceOf(address(this));
            if (bal == 0) continue;

            SafeERC20.safeApprove(IERC20(token), uniswapRouter, bal);
            // Note: Actual swap implementation would go here
            // For now, this is a placeholder - implement based on your router interface
            // Example: router.swapExactTokensForTokens(token, address(WETH), bal, address(this));
        }
 
        // Now rebalance from USDC to target allocation
        uint256 usdcBalance = USDC.balanceOf(address(this));
        
        for (uint i = 0; i < portf.length; i++) {
            address token = portf[i].tokenAddress;
            uint16 bps = portf[i].bps;

            if (token == address(USDC)) continue;

            uint256 targetUsdcAmt = (usdcBalance * bps) / MAX_BPS;
            if (targetUsdcAmt == 0) continue;

            SafeERC20.safeApprove(USDC, uniswapRouter, targetUsdcAmt);
            // Note: Actual swap implementation would go here
            // uint256 out = router.swapExact(address(USDC), token, targetUsdcAmt, address(this));
        }

        for (uint i = 0; i < portf.length; i++) {
            portf[i].lastEdited = block.timestamp;
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
- Contract is denominated in USDC
*/