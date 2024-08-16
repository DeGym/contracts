// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {StakeManager} from "../src/staking/StakeManager.sol";
import {BondPool} from "../src/staking/BondPool.sol";
import {DeGymToken} from "../src/token/DGYM.sol";

contract BondPoolTest is Test {
    StakeManager public stakeManager;
    DeGymToken public token;
    BondPool public bondPool;
    uint256 private alicePrivateKey = 0xa11ce;
    address public alice = vm.addr(alicePrivateKey);
    address public owner = address(0x3);

    function setUp() public {
        vm.startPrank(owner);
        token = new DeGymToken(owner);
        stakeManager = new StakeManager(address(token), owner);
        token.grantRole(token.MINTER_ROLE(), address(stakeManager));
        token.mint(alice, 1_000_000_000 * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(alice);
        token.approve(address(stakeManager), type(uint256).max);
        stakeManager.deployBondPool();
        bondPool = BondPool(stakeManager.bondPools(alice));
        token.approve(address(bondPool), type(uint256).max);
        vm.stopPrank();

        console.log("StakeManager address:", address(stakeManager));
        console.log("BondPool address:", address(bondPool));
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

        // Check that tokens were transferred to StakeManager
        assertEq(token.balanceOf(address(stakeManager)), amount);

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

        uint256 initialBalance = token.balanceOf(alice);
        bondPool.unbond(0);
        uint256 finalBalance = token.balanceOf(alice);

        uint256 finalTotalWeight = bondPool.getTotalBondWeight();
        console.log("Final total bond weight:", finalTotalWeight);

        assertTrue(
            finalTotalWeight < initialTotalWeight,
            "Total bond weight should decrease after unbonding"
        );
        assertEq(
            finalBalance,
            initialBalance + amount,
            "Alice should receive back her bonded amount"
        );

        vm.stopPrank();
    }

    function testUpdateRewards() public {
        console.log("Testing updateRewards function");
        vm.startPrank(alice);

        uint256 amount = 1000 * 10 ** 18;
        uint256 lockDuration = 30 days;
        bondPool.bond(amount, lockDuration);

        vm.stopPrank();

        vm.prank(address(stakeManager));
        bondPool.updateRewards(100 * 10 ** 18);

        (, , , , , uint256 rewardDebt, ) = bondPool.bonds(0);
        assertTrue(
            rewardDebt > 0,
            "Reward debt should be greater than 0 after updating rewards"
        );
    }

    function testGetTotalBondWeight() public {
        console.log("Testing getTotalBondWeight function");
        vm.startPrank(alice);

        uint256 amount1 = 1000 * 10 ** 18;
        uint256 amount2 = 500 * 10 ** 18;
        uint256 lockDuration = 30 days;

        bondPool.bond(amount1, lockDuration);
        bondPool.bond(amount2, lockDuration);

        uint256 totalWeight = bondPool.getTotalBondWeight();
        assertTrue(
            totalWeight > 0,
            "Total bond weight should be greater than 0"
        );

        vm.stopPrank();
    }

    function testGetBondsCount() public {
        console.log("Testing getBondsCount function");
        vm.startPrank(alice);

        bondPool.bond(1000 * 10 ** 18, 30 days);
        bondPool.bond(500 * 10 ** 18, 60 days);

        uint256 bondsCount = bondPool.getBondsCount();
        assertEq(bondsCount, 2, "Bonds count should be 2");

        vm.stopPrank();
    }
}
