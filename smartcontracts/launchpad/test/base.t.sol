// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/base.sol";
import "./mocks/MockUSDC.sol";

contract PortfolioDepositTest is Test {
    MockUSDC usdc;
    PortfolioFactory factory;
    UserPortfolio portfolio;

    address user = address(0xBEEF);

    function setUp() public {
        usdc = new MockUSDC();
        factory = new PortfolioFactory(address(usdc));

        // Mint 1,000 USDC to user
        usdc.mint(user, 1_000_000_000); // 1000 * 1e6

        // User creates their portfolio instance via the factory
        vm.prank(user);
        factory.createUserPortfolio();

        portfolio = UserPortfolio(factory.getUserPortfolio(user));

        // Approve portfolio to spend user USDC
        vm.prank(user);
        usdc.approve(address(portfolio), type(uint256).max);
    }

    // Helper to build a simple target using concrete token addresses
    function _alloc(address usdcAddr, address wethAddr, uint16 bpsUSDC, uint16 bpsWETH)
        internal
        pure
        returns (UserPortfolio.PortfolioAsset[] memory a)
    {
        a = new UserPortfolio.PortfolioAsset[](2);
        a[0] = UserPortfolio.PortfolioAsset({
            tokenAddress: usdcAddr,
            units: 0,
            bps: bpsUSDC,
            lastEdited: 0
        });
        a[1] = UserPortfolio.PortfolioAsset({
            tokenAddress: wethAddr,
            units: 0,
            bps: bpsWETH,
            lastEdited: 0
        });
    }

    function test_DepositUsdc_HappyPath() public {
        uint256 deposit = 500_000_000; // 500 USDC
        // Use portfolio's WETH address (may be zero address in current setup)
        address wethAddr = address(portfolio.WETH());
        UserPortfolio.PortfolioAsset[] memory desired = _alloc(address(usdc), wethAddr, 6000, 4000);

        // User calls deposit
        vm.prank(user);
        portfolio.depositUsdc(deposit, desired);

        // Contract should physically hold the USDC
        assertEq(usdc.balanceOf(address(portfolio)), deposit, "portfolio holds USDC");

        // Portfolio array should have two entries, USDC and WETH
        UserPortfolio.PortfolioAsset[] memory p = portfolio.getPortfolio();
        assertEq(p.length, 2, "two assets recorded");

        // Quoted portfolio value in USDC should equal the deposit at initial prices (allow 1 unit rounding)
        uint256 pv = portfolio.quotePortfolioValueUsdc();
        assertApproxEqAbs(pv, deposit, 1, "PV approx equals initial deposit");

        // Live allocation should match requested split at t0
        uint16[] memory live = portfolio.getUserCurrentAllocationBps();
        assertEq(live.length, 2);
        assertApproxEqAbs(live[0], 6000, 1, "USDC bps");
        assertApproxEqAbs(live[1], 4000, 1, "WETH bps");

        // WETH synthetic units should be nonzero
        uint256 wethUnits = portfolio.getAssetBalance(wethAddr);
        assertGt(wethUnits, 0, "synthetic WETH units exist");
    }


    function test_DepositUsdc_Rebalance() public {
}
