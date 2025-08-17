// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import {Script, console} from "forge-std/Script.sol";
import {LiquidityVault} from "../src/LiquidityVault.sol";


contract DeployVaultScript is Script {
 function run() external {
   string memory privateKeyString = vm.envString("PRIVATE_KEY");
   if (bytes(privateKeyString).length == 64) {
     privateKeyString = string.concat("0x", privateKeyString);
   }
   uint256 deployerPrivateKey = vm.parseUint(privateKeyString);


   address usdc = vm.envAddress("USDC_ADDRESS");
   address weth = vm.envAddress("WETH_ADDRESS");


   console.log("USDC_ADDRESS:", usdc);
   console.log("WETH_ADDRESS:", weth);


   vm.startBroadcast(deployerPrivateKey);
   LiquidityVault vault = new LiquidityVault(usdc, weth);
   console.log("LiquidityVault deployed at:", address(vault));
   vm.stopBroadcast();
 }
}


