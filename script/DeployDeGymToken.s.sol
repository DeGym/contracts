// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DeGymToken} from "../src/token/DGYM.sol";

contract DeployDeGymToken is Script {
    function run() external {
        address deployer = vm.envAddress("DEPLOYER");
        // Start broadcasting transactions
        vm.startBroadcast();

        // Set legacy gas price
        uint256 gasPrice = 1000000000; // 1 gwei, adjust as needed
        vm.txGasPrice(gasPrice);

        DeGymToken token = new DeGymToken(deployer);
        // Stop broadcasting transactions
        vm.stopBroadcast();
        console.log("DeGymToken deployed at:", address(token));
    }
}
