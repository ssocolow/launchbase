// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Interfaces.sol";
import "./Libraries.sol";

/// @title LiquidityVault - payment-style vault for USDC/WETH
/// - Fund once with USDC/WETH
/// - Users can request WETH (drip) directly
/// - Users can swap at a fixed hard-coded rate between ETH<->USDC (demo)
contract LiquidityVault is ReentrancyGuard {
	using SafeERC20 for IERC20;

	IERC20 public immutable USDC;
	IERC20 public immutable WETH;

	address public owner;
	uint8 public immutable usdcDecimals;
	uint8 public constant WETH_DECIMALS = 18;

	// Hard-coded price: 1 ETH = 4,550 USD. Store as USDC 6dp for clean math.
	uint256 public constant USD_PER_ETH_6D = 4_550_000000; // 4550.000000

	event Funded(address indexed token, address indexed from, uint256 amount);
	event WethDrip(address indexed to, uint256 amount);
	event EthForUsdc(address indexed payer, address indexed recipient, uint256 ethIn, uint256 usdcOut);
	event UsdcForWeth(address indexed payer, address indexed recipient, uint256 usdcIn, uint256 wethOut);
	event WethForUsdc(address indexed payer, address indexed recipient, uint256 wethIn, uint256 usdcOut);

	modifier onlyOwner() { require(msg.sender == owner, "ONLY_OWNER"); _; }

	constructor(address _usdc, address _weth) {
		require(_usdc != address(0) && _weth != address(0), "BAD_TOKEN");
		USDC = IERC20(_usdc);
		WETH = IERC20(_weth);
		owner = msg.sender;
		usdcDecimals = IERC20(_usdc).decimals(); // expect 6
	}

	/* -------------------------- Funding -------------------------- */

	function fundUSDC(uint256 amount) external nonReentrant {
		require(amount > 0, "ZERO");
		SafeERC20.safeTransferFrom(USDC, msg.sender, address(this), amount);
		emit Funded(address(USDC), msg.sender, amount);
	}

	function fundWETH(uint256 amount) external nonReentrant {
		require(amount > 0, "ZERO");
		SafeERC20.safeTransferFrom(WETH, msg.sender, address(this), amount);
		emit Funded(address(WETH), msg.sender, amount);
	}

	/* --------------------------- Payments ------------------------ */

	/// @notice Unconditional WETH drip to caller (demo). Transfers `amount` WETH to msg.sender.
	function requestWETH(uint256 amount) external nonReentrant {
		require(amount > 0, "ZERO");
		require(WETH.balanceOf(address(this)) >= amount, "INSUFFICIENT_WETH");
		SafeERC20.safeTransfer(WETH, msg.sender, amount);
		emit WethDrip(msg.sender, amount);
	}

	receive() external payable {}

	

	/// @notice Fixed-rate: user sends WETH (ERC-20), vault returns USDC using 1 ETH = 4550 USD (6dp)
	function swapExactWETHForUSDCFixed(uint256 wethIn, address recipient) external nonReentrant returns (uint256 usdcOut) {
		require(wethIn > 0, "ZERO_IN");
		require(recipient != address(0), "BAD_RECIP");
		// Pull WETH from payer
		SafeERC20.safeTransferFrom(WETH, msg.sender, address(this), wethIn);
		// usdcOut (6dp) = wethIn * USD_PER_ETH_6D / 1e18
		usdcOut = (wethIn * USD_PER_ETH_6D) / 1e18;
		require(usdcOut > 0, "TOO_SMALL");
		require(USDC.balanceOf(address(this)) >= usdcOut, "INSUFFICIENT_USDC");
		SafeERC20.safeTransfer(USDC, recipient, usdcOut);
		emit WethForUsdc(msg.sender, recipient, wethIn, usdcOut);
	}

	/* --------------------------- Admin --------------------------- */

	function transferOwnership(address newOwner) external onlyOwner { require(newOwner != address(0), "BAD_OWNER"); owner = newOwner; }
} 