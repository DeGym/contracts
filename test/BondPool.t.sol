// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/staking/StakeManager.sol";
import "../src/staking/BondPool.sol";
import {DeGymToken} from "../src/token/DGYM.sol";

contract BondPoolTest is Test {
    StakeManager public stakeManager;
    DeGymToken public token;
    BondPool public bondPool;
    address public alice = address(0x1);
    address public owner = address(0x3);

    function setUp() public {
        console.log("Setting up test environment");
        // Deploy DeGymToken
        token = new DeGymToken(owner);
        console.log("DeGymToken deployed at:", address(token));

        // Deploy StakeManager with DeGymToken
        stakeManager = new StakeManager(address(token));
        console.log("StakeManager deployed at:", address(stakeManager));

        // Deploy BondPool for Alice
        vm.prank(alice);
        stakeManager.deployBondPool();
        bondPool = BondPool(stakeManager.bondPools(alice));
        console.log("BondPool deployed at:", address(bondPool));

        // Fund Alice with DGYM tokens
        vm.prank(owner);
        token.mint(alice, 10000 * 10 ** 18);
        console.log("Alice funded with 10,000 DGYM tokens");

        vm.prank(alice);
        token.approve(address(bondPool), type(uint256).max);
        console.log("Alice approved BondPool to spend her DGYM tokens");
    }

    function testBond() public {
        console.log("Testing bond function");
        vm.startPrank(alice);

        uint256 amount = 1000 * 10 ** 18;
        uint256 lockDuration = 30 days;

        uint256 initialTotalWeight = bondPool.getTotalBondWeight();
        console.log("Initial total bond weight:", initialTotalWeight);

        bondPool.bond(amount, lockDuration);

        uint256 finalTotalWeight = bondPool.getTotalBondWeight();
        console.log("Final total bond weight:", finalTotalWeight);

        assertTrue(
            finalTotalWeight > initialTotalWeight,
            "Total bond weight should increase after bonding"
        );

        vm.stopPrank();
    }

    function testUnbond() public {
        console.log("Testing unbond function");
        vm.startPrank(alice);

        uint256 amount = 1000 * 10 ** 18;
        uint256 lockDuration = 30 days;

        bondPool.bond(amount, lockDuration);

        uint256 initialTotalWeight = bondPool.getTotalBondWeight();
        console.log("Initial total bond weight:", initialTotalWeight);

        vm.warp(block.timestamp + lockDuration + 1);
        console.log("Time warped to after lock duration");

        bondPool.unbond(0);

        uint256 finalTotalWeight = bondPool.getTotalBondWeight();
        console.log("Final total bond weight:", finalTotalWeight);

        assertTrue(
            finalTotalWeight < initialTotalWeight,
            "Total bond weight should decrease after unbonding"
        );

        vm.stopPrank();
    }

    function testExtendBondPeriod() public {
        console.log("Testing extendBondPeriod function");
        vm.startPrank(alice);

        uint256 amount = 1000 * 10 ** 18;
        uint256 initialLockDuration = 30 days;
        uint256 additionalDuration = 15 days;

        bondPool.bond(amount, initialLockDuration);

        uint256 initialTotalWeight = bondPool.getTotalBondWeight();
        console.log("Initial total bond weight:", initialTotalWeight);

        bondPool.extendBondPeriod(0, additionalDuration);

        uint256 finalTotalWeight = bondPool.getTotalBondWeight();
        console.log("Final total bond weight:", finalTotalWeight);

        assertTrue(
            finalTotalWeight > initialTotalWeight,
            "Total bond weight should increase after extending bond period"
        );

        vm.stopPrank();
    }

    function testAddToBond() public {
        console.log("Testing addToBond function");
        vm.startPrank(alice);

        uint256 initialAmount = 1000 * 10 ** 18;
        uint256 additionalAmount = 500 * 10 ** 18;
        uint256 lockDuration = 30 days;

        bondPool.bond(initialAmount, lockDuration);

        uint256 initialTotalWeight = bondPool.getTotalBondWeight();
        console.log("Initial total bond weight:", initialTotalWeight);

        bondPool.addToBond(0, additionalAmount);

        uint256 finalTotalWeight = bondPool.getTotalBondWeight();
        console.log("Final total bond weight:", finalTotalWeight);

        assertTrue(
            finalTotalWeight > initialTotalWeight,
            "Total bond weight should increase after adding to bond"
        );

        vm.stopPrank();
    }
}
