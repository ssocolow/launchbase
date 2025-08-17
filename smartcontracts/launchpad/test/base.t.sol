// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import "forge-std/Test.sol";
// import "../src/Interfaces.sol";
// import "../src/PortfolioFactory.sol";
// import "../src/UserPortfolio.sol";
// import "./mocks/MockUSDC.sol";
// import "./mocks/MockWETH.sol";
// import "./mocks/MockRouter.sol";

// // Minimal mock Chainlink aggregator
// contract MockAggregator is AggregatorV3Interface {
//     uint8 private immutable _decimals;
//     int256 private _answer;

//     constructor(uint8 decimals_, int256 answer_) {
//         _decimals = decimals_;
//         _answer = answer_;
//     }

//     function decimals() external view returns (uint8) { return _decimals; }

//     function latestRoundData()
//         external
//         view
//         returns (
//             uint80 roundId,
//             int256 answer,
//             uint256 startedAt,
//             uint256 updatedAt,
//             uint80 answeredInRound
//         )
//     {
//         return (0, _answer, block.timestamp, block.timestamp, 0);
//     }
// }

// contract PortfolioDepositTest is Test {
//     MockUSDC usdc;
//     MockAggregator usdcFeed;
//     MockAggregator wethFeed;
//     MockV3Router router;
//     MockWETH weth;

//     PortfolioFactory factory;
//     UserPortfolio portfolio;

//     address user = address(0xBEEF);

//     function setUp() public {
//         usdc = new MockUSDC();
//         weth = new MockWETH();
//         // Price feeds with 8 decimals: USDC = 1.00, WETH = 2000.00
//         usdcFeed = new MockAggregator(8, 1e8);
//         wethFeed = new MockAggregator(8, 2000e8);
//         router = new MockV3Router(address(usdc), address(weth), address(usdcFeed), address(wethFeed));

//         factory = new PortfolioFactory(
//             address(usdc),
//             address(usdcFeed),
//             address(wethFeed),
//             address(router)
//         );

//         // Configure defaults for USDC (0) and WETH (1)
//         factory.setDefaultAssetConfig(0, address(usdc), bytes(""), bytes(""));
//         bytes memory buyPath  = abi.encodePacked(address(usdc), uint24(3000), address(weth));
//         bytes memory sellPath = abi.encodePacked(address(weth), uint24(3000), address(usdc));
//         factory.setDefaultAssetConfig(1, address(weth), buyPath, sellPath);

//         // Mint 1,000 USDC to user and seed router token reserves (optional)
//         usdc.mint(user, 1_000_000_000); // 1000 * 1e6
//         // Seed router with some WETH to pay out during swaps
//         weth.mint(address(router), 1_000 ether);

//         // User creates their portfolio instance via the factory
//         vm.prank(user);
//         factory.createUserPortfolio();

//         portfolio = UserPortfolio(factory.getUserPortfolio(user));

//         // Approve portfolio to spend user USDC
//         vm.prank(user);
//         usdc.approve(address(portfolio), type(uint256).max);

//         // Also allow portfolio to transferFrom router during sell leg (mock router pulls from msg.sender)
//         // Not required in first deposit (no sells occur), but harmless.
//         vm.prank(address(portfolio));
//         weth.approve(address(router), type(uint256).max);
//     }

//     function test_DepositUsdcAndRebalanceWithDefaults_USDCOnly() public {
//         uint256 deposit = 500_000_000; // 500 USDC

//         UserPortfolio.PortfolioAsset[] memory desired = new UserPortfolio.PortfolioAsset[](1);
//         desired[0] = UserPortfolio.PortfolioAsset({
//             assetId: 0,
//             units: 0,
//             bps: 10_000,
//             lastPrice: 0,
//             lastEdited: 0
//         });

//         uint256[] memory sellMins = new uint256[](0);
//         uint256[] memory buyMins = new uint256[](0);

//         vm.prank(user);
//         portfolio.depositUsdcAndRebalanceWithDefaults(deposit, desired, sellMins, buyMins);

//         assertEq(usdc.balanceOf(address(portfolio)), deposit, "portfolio holds USDC");
//         UserPortfolio.PortfolioAsset[] memory p = portfolio.getPortfolio();
//         assertEq(p.length, 1, "one asset recorded");
//         assertEq(p[0].assetId, 0, "asset is USDC");
//         assertEq(p[0].bps, 10_000, "100% USDC bps");

//         uint256 pv = portfolio.getTotalPortfolioValue();
//         assertEq(pv, deposit, "PV equals deposit");
//     }

//     function test_DepositUsdcAndRebalanceWithDefaults_USDC_WETH() public {
//         uint256 deposit = 600_000_000; // 600 USDC

//         // Desired allocation: 60% USDC / 40% WETH
//         UserPortfolio.PortfolioAsset[] memory desired = new UserPortfolio.PortfolioAsset[](2);
//         desired[0] = UserPortfolio.PortfolioAsset({ assetId: 0, units: 0, bps: 6000, lastPrice: 0, lastEdited: 0 });
//         desired[1] = UserPortfolio.PortfolioAsset({ assetId: 1, units: 0, bps: 4000, lastPrice: 0, lastEdited: 0 });

//         // Non-USDC rows = 1 (WETH). First-time deposit: no sells, so sellMins empty or [0].
//         uint256[] memory sellMins = new uint256[](1); sellMins[0] = 0;
//         // Quote min-outs roughly using our feed ratio: 600 USDC * 40% = 240 USDC to WETH, price 2000 USD/ETH.
//         // 240 USDC -> 0.12 WETH expected; set min 0.119 WETH to allow tiny rounding
//         uint256[] memory buyMins = new uint256[](1); buyMins[0] = 0.119 ether;

//         vm.prank(user);
//         portfolio.depositUsdcAndRebalanceWithDefaults(deposit, desired, sellMins, buyMins);

//         // After rebalancing, portfolio should hold some WETH
//         assertGt(IERC20(address(weth)).balanceOf(address(portfolio)), 0, "WETH bought");

//         // Portfolio should have two entries
//         UserPortfolio.PortfolioAsset[] memory p = portfolio.getPortfolio();
//         assertEq(p.length, 2, "two assets recorded");
//         assertEq(p[0].bps + p[1].bps, 10_000, "bps sum to 100%");
//     }
// }
