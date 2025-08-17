// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {PortfolioFactory} from "src/base.sol";

contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        // TODO: replace with real addresses on Base Sepolia
        address usdc = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
        address usdcFeed = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
        address wethFeed = 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1;
        address router = 0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4;

        PortfolioFactory factory = new PortfolioFactory(usdc, usdcFeed, wethFeed, router);
        // Optionally set defaults here with setDefaultAssetConfig(...)

        vm.stopBroadcast();
    }
}