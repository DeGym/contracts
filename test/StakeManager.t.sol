// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/staking/StakeManager.sol";
import "../src/staking/BondPool.sol";
import {DeGymToken} from "../src/token/DGYM.sol";

contract StakeManagerTest is Test {
    StakeManager public stakeManager;
    DeGymToken public token;
    uint256 private alicePrivateKey = 0xa11ce;
    address public alice = vm.addr(alicePrivateKey);
    address public bob = address(0x2);
    address public owner = address(0x3);
    BondPool public aliceBondPool;
    BondPool public bobBondPool;

    function setUp() public {
        vm.startPrank(owner);
        console.log("Setting up test environment");
        token = new DeGymToken(owner);
        console.log("DeGymToken deployed at:", address(token));
        stakeManager = new StakeManager(address(token));
        console.log("StakeManager deployed at:", address(stakeManager));
        token.grantRole(token.MINTER_ROLE(), address(stakeManager));
        console.log("MINTER_ROLE granted to StakeManager");
        token.mint(alice, 10000 * 10 ** 18);
        console.log("Alice funded with 10,000 DGYM tokens");
        token.mint(bob, 10000 * 10 ** 18);
        console.log("Bob funded with 10,000 DGYM tokens");
        vm.stopPrank();

        vm.startPrank(alice);
        token.approve(address(stakeManager), type(uint256).max);
        console.log("Alice approved StakeManager to spend her DGYM tokens");
        stakeManager.deployBondPool();
        aliceBondPool = BondPool(stakeManager.bondPools(alice));
        console.log("Alice's BondPool deployed at:", address(aliceBondPool));
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(stakeManager), type(uint256).max);
        console.log("Bob approved StakeManager to spend his DGYM tokens");
        stakeManager.deployBondPool();
        bobBondPool = BondPool(stakeManager.bondPools(bob));
        console.log("Bob's BondPool deployed at:", address(bobBondPool));
        vm.stopPrank();
    }

    function testDeployBondPool() public {
        console.log("Testing deployBondPool function");
        address aliceBondPoolAddress = stakeManager.bondPools(alice);
        assertTrue(
            aliceBondPoolAddress != address(0),
            "Alice's Bond pool should be deployed"
        );
        console.log("Alice's BondPool deployed at:", aliceBondPoolAddress);

        address bobBondPoolAddress = stakeManager.bondPools(bob);
        assertTrue(
            bobBondPoolAddress != address(0),
            "Bob's Bond pool should be deployed"
        );
        console.log("Bob's BondPool deployed at:", bobBondPoolAddress);
    }

    function testUpdateRewards() public {
        console.log("Testing updateRewards function");
        vm.startPrank(alice);
        token.approve(address(aliceBondPool), type(uint256).max);
        aliceBondPool.bond(1000 * 10 ** 18, 30 days);
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days);
        stakeManager.updateRewards();

        uint256 totalUnclaimedRewards = stakeManager.totalUnclaimedRewards();
        assertTrue(
            totalUnclaimedRewards > 0,
            "Total unclaimed rewards should be greater than 0"
        );
    }

    function testNotifyWeightChange() public {
        console.log("Testing notifyWeightChange function");
        vm.startPrank(alice);
        token.approve(address(aliceBondPool), type(uint256).max);
        aliceBondPool.bond(1000 * 10 ** 18, 30 days);
        vm.stopPrank();

        uint256 totalWeight = stakeManager.getTotalBondWeight();
        assertEq(
            totalWeight,
            1000 * 10 ** 18,
            "Total bond weight should be updated"
        );
    }

    function testNotifyStakeChange() public {
        console.log("Testing notifyStakeChange function");
        vm.startPrank(alice);
        token.approve(address(aliceBondPool), type(uint256).max);
        aliceBondPool.bond(1000 * 10 ** 18, 30 days);
        vm.stopPrank();

        uint256 totalStaked = stakeManager.totalStaked();
        assertEq(
            totalStaked,
            1000 * 10 ** 18,
            "Total staked should be updated"
        );
    }

    function testClaimReward() public {
        console.log("Testing claimReward function");
        vm.startPrank(alice);
        token.approve(address(aliceBondPool), type(uint256).max);
        aliceBondPool.bond(1000 * 10 ** 18, 30 days);
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days);
        stakeManager.updateRewards();

        uint256 initialBalance = token.balanceOf(alice);
        vm.prank(address(aliceBondPool));
        stakeManager.claimReward(alice, 100 * 10 ** 18);

        uint256 finalBalance = token.balanceOf(alice);
        assertEq(
            finalBalance,
            initialBalance + 100 * 10 ** 18,
            "Alice should receive claimed rewards"
        );
    }

    function testGetTotalBondWeight() public {
        console.log("Testing getTotalBondWeight function");
        vm.startPrank(alice);
        token.approve(address(aliceBondPool), type(uint256).max);
        aliceBondPool.bond(1000 * 10 ** 18, 30 days);
        vm.stopPrank();

        uint256 totalWeight = stakeManager.getTotalBondWeight();
        assertTrue(
            totalWeight > 0,
            "Total bond weight should be greater than 0"
        );
    }

    function testGetStakeholderCount() public {
        console.log("Testing getStakeholderCount function");
        uint256 stakeholderCount = stakeManager.getStakeholderCount();
        assertEq(stakeholderCount, 2, "Stakeholder count should be 2");
    }
}
