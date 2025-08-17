// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Interfaces.sol";
import "./Libraries.sol";

/// @title DummySwap - minimal Uniswap V3 single-hop swapper for WETH <-> USDC (ERC20-only)
/// @notice Uses Uniswap V3 exactInput with enforced single-hop paths. No native ETH handling.
contract DummySwap {
	using SafeERC20 for IERC20;

	address public immutable uniswapRouter; // ISwapRouter (V3)
	IERC20 public immutable USDC;          // USDC token
	IERC20 public immutable WETH;          // WETH9 token (ERC20)
	uint24 public immutable poolFee;       // e.g., 3000

	event SwapWethForUsdc(address indexed sender, address indexed recipient, uint256 wethIn, uint256 usdcOut);
	event SwapUsdcForWeth(address indexed sender, address indexed recipient, uint256 usdcIn, uint256 wethOut);

	constructor(address _router, address _usdc, address _weth, uint24 _fee) {
		require(_router != address(0), "BAD_ROUTER");
		require(_usdc != address(0), "BAD_USDC");
		require(_weth != address(0), "BAD_WETH");
		require(_fee > 0, "BAD_FEE");
		uniswapRouter = _router;
		USDC = IERC20(_usdc);
		WETH = IERC20(_weth);
		poolFee = _fee; // 500, 3000, or 10000 typical
	}

	/// @notice Swap exact WETH for USDC using single-hop path WETH->USDC
	/// @param wethIn Amount of WETH to swap (caller must approve this contract)
	/// @param minUsdcOut Slippage floor for USDC
	/// @param recipient Address to receive USDC
	function swapExactWETHForUSDC(uint256 wethIn, uint256 minUsdcOut, address recipient) external returns (uint256 amountOut) {
		require(wethIn > 0, "ZERO_IN");
		require(recipient != address(0), "BAD_RECIPIENT");

		// Pull WETH and approve router
		SafeERC20.safeTransferFrom(WETH, msg.sender, address(this), wethIn);
		SafeERC20.safeApprove(WETH, uniswapRouter, 0);
		SafeERC20.safeApprove(WETH, uniswapRouter, wethIn);

		// path: WETH -> USDC
		bytes memory path = abi.encodePacked(address(WETH), poolFee, address(USDC));

		IUniswapV3Router.ExactInputParams memory params = IUniswapV3Router.ExactInputParams({
			path: path,
			recipient: recipient,
			deadline: block.timestamp,
			amountIn: wethIn,
			amountOutMinimum: minUsdcOut
		});

		amountOut = IUniswapV3Router(uniswapRouter).exactInput(params);
		emit SwapWethForUsdc(msg.sender, recipient, wethIn, amountOut);
	}

	/// @notice Swap exact USDC for WETH using single-hop path USDC->WETH
	/// @param usdcIn Amount of USDC to swap (caller must approve this contract)
	/// @param minWethOut Slippage floor for WETH
	/// @param recipient Address to receive WETH
	function swapExactUSDCForWETH(uint256 usdcIn, uint256 minWethOut, address recipient) external returns (uint256 amountOut) {
		require(usdcIn > 0, "ZERO_IN");
		require(recipient != address(0), "BAD_RECIPIENT");

		// Pull USDC and approve router
		SafeERC20.safeTransferFrom(USDC, msg.sender, address(this), usdcIn);
		SafeERC20.safeApprove(USDC, uniswapRouter, 0);
		SafeERC20.safeApprove(USDC, uniswapRouter, usdcIn);

		// path: USDC -> WETH
		bytes memory path = abi.encodePacked(address(USDC), poolFee, address(WETH));

		IUniswapV3Router.ExactInputParams memory params = IUniswapV3Router.ExactInputParams({
			path: path,
			recipient: recipient,
			deadline: block.timestamp,
			amountIn: usdcIn,
			amountOutMinimum: minWethOut
		});

		amountOut = IUniswapV3Router(uniswapRouter).exactInput(params);
		emit SwapUsdcForWeth(msg.sender, recipient, usdcIn, amountOut);
	}

	/// @notice Helper: single-hop only
	function isDirectPairOnly() external pure returns (bool) { return true; }
}
