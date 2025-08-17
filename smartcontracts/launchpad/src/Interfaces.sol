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

// LiquidityVault interface for fixed-rate swaps
interface ILiquidityVault {
    function swapExactWETHForUSDCFixed(uint256 wethIn, address recipient) external returns (uint256 usdcOut);
    function requestWETH(uint256 amount) external;
    function USDC() external view returns (address);
    function WETH() external view returns (address);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function allowance(address,address) external view returns (uint256);
    function approve(address,uint256) external returns (bool);
    function transfer(address,uint256) external returns (bool);
    function transferFrom(address,address,uint256) external returns (bool);
    function decimals() external view returns (uint8);
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
