// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {DummySwap} from "../src/dummySwap.sol";

contract DeploySwapScript is Script {
	function run() external {
		string memory privateKeyString = vm.envString("PRIVATE_KEY");
		if (bytes(privateKeyString).length == 64) {
			privateKeyString = string.concat("0x", privateKeyString);
		}
		uint256 deployerPrivateKey = vm.parseUint(privateKeyString);

		address uniswapRouter = vm.envAddress("UNISWAP_V3_ROUTER");
		address usdc = vm.envAddress("USDC_ADDRESS");
		address weth = vm.envAddress("WETH_ADDRESS");
		uint24 fee = uint24(3000);

		console.log("UNISWAP_V3_ROUTER:", uniswapRouter);
		console.log("USDC_ADDRESS     :", usdc);
		console.log("WETH_ADDRESS     :", weth);
		console.log("POOL FEE         :", fee);

		vm.startBroadcast(deployerPrivateKey);
		DummySwap swapper = new DummySwap(uniswapRouter, usdc, weth, fee);
		console.log("DummySwap deployed at:", address(swapper));
		vm.stopBroadcast();
	}
}
