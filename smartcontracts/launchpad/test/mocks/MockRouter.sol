// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../src/Interfaces.sol"; // for IUniswapV3Router interface

interface IERC20Like {
    function balanceOf(address) external view returns (uint256);
    function allowance(address,address) external view returns (uint256);
    function approve(address,uint256) external returns (bool);
    function transfer(address,uint256) external returns (bool);
    function transferFrom(address,address,uint256) external returns (bool);
    function decimals() external view returns (uint8);
}

interface FeedLike {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
    function decimals() external view returns (uint8);
}

contract MockV3Router is ISwapRouter {
    address public immutable USDC;
    address public immutable WETH;
    FeedLike public immutable usdcFeed;
    FeedLike public immutable wethFeed;

    constructor(address _usdc, address _weth, address _usdcFeed, address _wethFeed) {
        USDC = _usdc; WETH = _weth; usdcFeed = FeedLike(_usdcFeed); wethFeed = FeedLike(_wethFeed);
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut) {
        require(params.tokenIn == USDC || params.tokenIn == WETH, "BAD_IN");
        require(params.tokenOut == USDC || params.tokenOut == WETH, "BAD_OUT");
        require(params.tokenIn != params.tokenOut, "SAME_TOKEN");

        // Pull tokenIn from caller (portfolio contract)
        IERC20Like tokenInCtr = IERC20Like(params.tokenIn);
        IERC20Like tokenOutCtr = IERC20Like(params.tokenOut);
        require(tokenInCtr.transferFrom(msg.sender, address(this), params.amountIn), "PULL_FAIL");

        // Price ratio using feeds: amountOut = amountIn * priceIn / priceOut, normalized to token decimals
        (, int256 pIn,,,) = (params.tokenIn == USDC) ? usdcFeed.latestRoundData() : wethFeed.latestRoundData();
        (, int256 pOut,,,) = (params.tokenOut == USDC) ? usdcFeed.latestRoundData() : wethFeed.latestRoundData();
        require(pIn > 0 && pOut > 0, "BAD_PRICE");
        uint8 dIn = tokenInCtr.decimals();
        uint8 dOut = tokenOutCtr.decimals();

        // Normalize to compute: out = amountIn * priceIn * 10^dOut / (priceOut * 10^dIn)
        amountOut = (params.amountIn * uint256(pIn) * (10 ** dOut)) / (uint256(pOut) * (10 ** dIn));
        require(amountOut >= params.amountOutMinimum, "SLIPPAGE");

        // Send tokenOut to the recipient
        require(tokenOutCtr.transfer(params.recipient, amountOut), "PAY_OUT_FAIL");

        return amountOut;
    }

    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn) {
        require(params.tokenIn == USDC || params.tokenIn == WETH, "BAD_IN");
        require(params.tokenOut == USDC || params.tokenOut == WETH, "BAD_OUT");
        require(params.tokenIn != params.tokenOut, "SAME_TOKEN");

        // Pull tokenIn from caller (portfolio contract)
        IERC20Like tokenInCtr = IERC20Like(params.tokenIn);
        IERC20Like tokenOutCtr = IERC20Like(params.tokenOut);
        require(tokenInCtr.transferFrom(msg.sender, address(this), params.amountInMaximum), "PULL_FAIL");

        // Price ratio using feeds: amountIn = amountOut * priceOut / priceIn, normalized to token decimals
        (, int256 pIn,,,) = (params.tokenIn == USDC) ? usdcFeed.latestRoundData() : wethFeed.latestRoundData();
        (, int256 pOut,,,) = (params.tokenOut == USDC) ? usdcFeed.latestRoundData() : wethFeed.latestRoundData();
        require(pIn > 0 && pOut > 0, "BAD_PRICE");
        uint8 dIn = tokenInCtr.decimals();
        uint8 dOut = tokenOutCtr.decimals();

        // Normalize to compute: in = amountOut * priceOut * 10^dIn / (priceIn * 10^dOut)
        amountIn = (params.amountOut * uint256(pOut) * (10 ** dIn)) / (uint256(pIn) * (10 ** dOut));
        require(amountIn <= params.amountInMaximum, "EXCEEDS_MAX");

        // Send tokenOut to the recipient
        require(tokenOutCtr.transfer(params.recipient, params.amountOut), "PAY_OUT_FAIL");

        // Refund excess tokenIn if needed
        if (amountIn < params.amountInMaximum) {
            require(tokenInCtr.transfer(msg.sender, params.amountInMaximum - amountIn), "REFUND_FAIL");
        }

        return amountIn;
    }
} 