// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {Base} from "../src/base.sol"; // <-- import from base.sol

contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        Base base = new Base(); // <-- deploy your Base contract

        vm.stopBroadcast();
    }
}
