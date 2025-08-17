// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {PortfolioFactory} from "../src/PortfolioFactory.sol";

contract DeployScript is Script {
    function run() external {
        string memory privateKeyString = vm.envString("PRIVATE_KEY");
        
        // Add 0x prefix if missing (vm.parseUint requires it for hex strings)
        if (bytes(privateKeyString).length == 64) {
            privateKeyString = string.concat("0x", privateKeyString);
        }
        
        uint256 deployerPrivateKey = vm.parseUint(privateKeyString);
        
        // Base Sepolia addresses
        address usdcAddress = vm.envAddress("USDC_ADDRESS");
        address usdcPriceFeed = vm.envAddress("USDC_PRICE_FEED");
        address wethPriceFeed = vm.envAddress("WETH_PRICE_FEED");
        address uniswapRouter = vm.envAddress("UNISWAP_V3_ROUTER");
        
        vm.startBroadcast(deployerPrivateKey);
        
        PortfolioFactory factory = new PortfolioFactory(
            usdcAddress,
            usdcPriceFeed,
            wethPriceFeed,
            uniswapRouter
        );
        
        console.log("PortfolioFactory deployed at:", address(factory));
        console.log("Deployment completed!");
        console.log("Factory address:", address(factory));
        
        vm.stopBroadcast();
    }
}