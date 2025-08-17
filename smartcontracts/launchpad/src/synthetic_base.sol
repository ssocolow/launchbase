// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// -------- Chainlink Minimal Interface --------
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

// -------- ERC20 Minimal Interface + SafeERC20 --------
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

// -------- Reentrancy Guard --------
abstract contract ReentrancyGuard {
    uint256 private _status = 1;
    modifier nonReentrant() {
        require(_status == 1, "REENTRANT");
        _status = 2;
        _;
        _status = 1;
    }
}

// ===================== Synthetic Factory =====================
contract PortfolioFactorySynthetic {
    IERC20 public immutable USDC;
    address public immutable usdcPriceFeed;
    address public immutable wethPriceFeed;
    address public owner;

    mapping(address => address) public userContracts;

    event UserPortfolioCreated(address indexed user, address contractAddress);

    modifier onlyOwner() { require(msg.sender == owner, "ONLY_OWNER"); _; }

    constructor(address _usdc, address _usdcPriceFeed, address _wethPriceFeed) {
        require(_usdc != address(0), "BAD_USDC");
        require(_usdcPriceFeed != address(0) && _wethPriceFeed != address(0), "BAD_FEED");
        USDC = IERC20(_usdc);
        usdcPriceFeed = _usdcPriceFeed;
        wethPriceFeed = _wethPriceFeed;
        owner = msg.sender;
    }

    function createUserPortfolio() external {
        require(userContracts[msg.sender] == address(0), "EXISTS");
        UserPortfolioSynthetic up = new UserPortfolioSynthetic(
            address(USDC),
            msg.sender,
            usdcPriceFeed,
            wethPriceFeed
        );
        userContracts[msg.sender] = address(up);
        emit UserPortfolioCreated(msg.sender, address(up));
    }

    function getUserPortfolio(address user) external view returns (address) {
        return userContracts[user];
    }
}

// ===================== Synthetic User Portfolio =====================
contract UserPortfolioSynthetic is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable USDC;
    address public immutable user;
    uint8 public immutable usdcDec;

    uint16 public constant MAX_BPS = 10_000;
    uint8 public constant PRICE_DECIMALS = 8; // normalized oracle decimals

    // Chainlink price feeds per assetId
    mapping(uint256 => AggregatorV3Interface) public priceFeeds; // 0=USDC, 1=WETH

    // Metadata
    mapping(uint256 => string) public assetNames;
    mapping(uint256 => uint8) public assetDecimals; // 0:6 for USDC, 1:18 for WETH
    mapping(uint256 => bool) public isAssetSupported;

    // Synthetic portfolio rows
    struct PortfolioAsset {
        uint256 assetId;   // 0=USDC, 1=WETH
        uint256 units;     // synthetic units (USDC units for id=0; token units for others)
        uint16 bps;        // target split
        uint256 lastPrice; // last oracle price used (optional)
        uint256 lastEdited;
    }
    PortfolioAsset[] public portfolio;

    // Access control
    modifier onlyUser() { require(msg.sender == user, "ONLY_USER"); _; }

    // Events
    event Deposit(address indexed user, uint256 usdcIn);
    event WithdrawAllUSDC(address indexed user, uint256 usdcOut);

    constructor(address _usdc, address _user, address _usdcFeed, address _wethFeed) {
        USDC = IERC20(_usdc);
        user = _user;
        usdcDec = IERC20(_usdc).decimals();

        // Support USDC/WETH out of the box
        assetNames[0] = "USDC"; assetDecimals[0] = 6; isAssetSupported[0] = true; priceFeeds[0] = AggregatorV3Interface(_usdcFeed);
        assetNames[1] = "WETH"; assetDecimals[1] = 18; isAssetSupported[1] = true; priceFeeds[1] = AggregatorV3Interface(_wethFeed);
    }

    // -------- Core: Synthetic Deposit --------
    function depositUsdc(uint256 usdcIn, PortfolioAsset[] memory desired) external onlyUser nonReentrant {
        require(usdcIn > 0, "ZERO_IN");
        require(desired.length > 0, "EMPTY_ALLOC");

        uint256 totalBps = 0;
        for (uint i=0; i<desired.length; i++) {
            require(isAssetSupported[desired[i].assetId], "ASSET_UNSUPPORTED");
            require(desired[i].bps > 0, "ZERO_BPS");
            totalBps += desired[i].bps;
        }
        require(totalBps == MAX_BPS, "BAD_TOTAL_BPS");

        // Pull USDC
        SafeERC20.safeTransferFrom(USDC, msg.sender, address(this), usdcIn);

        // Rewrite portfolio using oracle-based synthetic units
        delete portfolio;
        for (uint i=0; i<desired.length; i++) {
            uint256 assetId = desired[i].assetId;
            uint256 legUsdc = (usdcIn * desired[i].bps) / MAX_BPS;
            uint256 units;
            if (assetId == 0) {
                units = legUsdc; // in USDC units
            } else {
                units = _usdcToAssetUnitsFromOracle(assetId, legUsdc);
            }
            portfolio.push(PortfolioAsset({
                assetId: assetId,
                units: units,
                bps: desired[i].bps,
                lastPrice: _getAssetPrice(assetId),
                lastEdited: block.timestamp
            }));
        }

        emit Deposit(user, usdcIn);
    }

    // -------- Views --------
    function getPortfolio() external view returns (PortfolioAsset[] memory) { return portfolio; }

    function getTotalPortfolioValue() external view returns (uint256) { return _portfolioValueUsdc(); }

    function getUserAllocationBps() external view returns (uint16[] memory bps) {
        bps = new uint16[](portfolio.length);
        for (uint i=0; i<portfolio.length; i++) { bps[i] = portfolio[i].bps; }
        return bps;
    }

    function getUsdcBalance() external view returns (uint256) { return USDC.balanceOf(address(this)); }

    function getAssetBalance(uint256 assetId) external view returns (uint256) {
        for (uint i=0; i<portfolio.length; i++) if (portfolio[i].assetId == assetId) return portfolio[i].units; return 0;
    }

    // -------- Withdraw (USDC only) --------
    function withdrawAllAsUSDC() external onlyUser nonReentrant {
        uint256 bal = USDC.balanceOf(address(this));
        require(bal > 0, "EMPTY");
        delete portfolio;
        SafeERC20.safeTransfer(USDC, user, bal);
        emit WithdrawAllUSDC(user, bal);
    }

    // -------- Internal: Oracle + Math --------
    function _portfolioValueUsdc() internal view returns (uint256 total) {
        for (uint i=0; i<portfolio.length; i++) {
            uint256 id = portfolio[i].assetId;
            uint256 u  = portfolio[i].units;
            if (id == 0) { total += u; }
            else {
                uint256 p = _getAssetPrice(id); // 8 decimals
                uint256 aDec = assetDecimals[id];
                total += (u * p * (10 ** usdcDec)) / (10 ** (aDec + PRICE_DECIMALS));
            }
        }
    }

    function _usdcToAssetUnitsFromOracle(uint256 assetId, uint256 usdcAmount) internal view returns (uint256) {
        if (assetId == 0) return usdcAmount;
        uint256 price = _getAssetPrice(assetId); // 8 decimals
        uint256 aDec  = assetDecimals[assetId];
        return (usdcAmount * (10 ** (aDec + PRICE_DECIMALS))) / (price * (10 ** usdcDec));
    }

    function _getAssetPrice(uint256 assetId) internal view returns (uint256) {
        AggregatorV3Interface pf = priceFeeds[assetId];
        require(address(pf) != address(0), "ORACLE_NOT_SET");
        (, int256 px, , , ) = pf.latestRoundData();
        require(px > 0, "BAD_PRICE");
        uint8 dec = pf.decimals();
        if (dec > PRICE_DECIMALS) return uint256(px) / (10 ** (dec - PRICE_DECIMALS));
        else return uint256(px) * (10 ** (PRICE_DECIMALS - dec));
    }
} 