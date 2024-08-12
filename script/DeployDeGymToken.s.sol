// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DeGymToken} from "../src/token/DGYM.sol";

contract DeployTaraChatToken is Script {
    function run() external {
        address deployer = vm.envAddress("DEPLOYER");
        // Start broadcasting transactions
        vm.startBroadcast();
        DeGymToken token = new DeGymToken(deployer);
        // Stop broadcasting transactions
        vm.stopBroadcast();
        console.log("DeGymToken deployed at:", address(token));
    }
}
