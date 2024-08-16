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
    uint256 private bobPrivateKey = 0xb0b;
    address public alice = vm.addr(alicePrivateKey);
    address public bob = vm.addr(bobPrivateKey);
    address public owner = address(0x3);
    BondPool public aliceBondPool;
    BondPool public bobBondPool;

    function setUp() public {
        vm.startPrank(owner);
        token = new DeGymToken(owner);
        stakeManager = new StakeManager(address(token), owner);
        token.grantRole(token.MINTER_ROLE(), address(stakeManager));

        token.mint(alice, 1_000_000_000 * 10 ** 18);
        token.mint(bob, 10000 * 10 ** 18);

        vm.stopPrank();

        vm.startPrank(alice);
        token.approve(address(stakeManager), type(uint256).max);
        stakeManager.deployBondPool();
        aliceBondPool = BondPool(stakeManager.bondPools(alice));
        token.approve(address(aliceBondPool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(stakeManager), type(uint256).max);
        stakeManager.deployBondPool();
        bobBondPool = BondPool(stakeManager.bondPools(bob));
        token.approve(address(bobBondPool), type(uint256).max);
        vm.stopPrank();
    }

    function testDeployBondPool() public view {
        assertEq(address(aliceBondPool), stakeManager.bondPools(alice));
        assertEq(address(bobBondPool), stakeManager.bondPools(bob));
    }

    function testGetStakeholderCount() public view {
        assertEq(stakeManager.getStakeholderCount(), 2);
    }

    function testGetTotalBondWeight() public {
        vm.startPrank(alice);
        aliceBondPool.bond(1000 * 10 ** 18, 30 days);
        vm.stopPrank();

        vm.startPrank(bob);
        bobBondPool.bond(500 * 10 ** 18, 60 days);
        vm.stopPrank();

        assertGt(stakeManager.getTotalBondWeight(), 0);
    }

    function testNotifyStakeChange() public {
        uint256 initialStake = stakeManager.totalStaked();

        vm.prank(alice);
        aliceBondPool.bond(1000 * 10 ** 18, 30 days);

        assertEq(stakeManager.totalStaked(), initialStake + 1000 * 10 ** 18);
    }

    function testNotifyWeightChange() public {
        uint256 initialWeight = stakeManager.totalBondWeight();

        vm.prank(alice);
        aliceBondPool.bond(1000 * 10 ** 18, 30 days);

        assertGt(stakeManager.totalBondWeight(), initialWeight);
    }

    function testOnlyBondPoolCanCallRestrictedFunctions() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                stakeManager.BOND_POOL_ROLE()
            )
        );
        stakeManager.notifyWeightChange(1000);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                stakeManager.BOND_POOL_ROLE()
            )
        );
        stakeManager.notifyStakeChange(1000, true);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                stakeManager.BOND_POOL_ROLE()
            )
        );
        stakeManager.claimReward(alice, 1000);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                stakeManager.BOND_POOL_ROLE()
            )
        );
        stakeManager.transferToUser(alice, 1000);
    }

    function testUpdateRewards() public {
        vm.prank(alice);
        aliceBondPool.bond(1000 * 10 ** 18, 30 days);

        vm.warp(block.timestamp + 15 days);

        stakeManager.updateRewards();

        assertGt(stakeManager.totalUnclaimedRewards(), 0);
    }

    function testClaimReward() public {
        vm.startPrank(alice);
        aliceBondPool.bond(1000 * 10 ** 18, 30 days);
        vm.stopPrank();

        // Simulate time passing and update rewards
        vm.warp(block.timestamp + 15 days);
        stakeManager.updateRewards();

        uint256 totalUnclaimedRewards = stakeManager.totalUnclaimedRewards();
        console.log("Total unclaimed rewards:", totalUnclaimedRewards);

        // Ensure we're not trying to claim more than available
        uint256 rewardAmount = totalUnclaimedRewards > 0
            ? totalUnclaimedRewards
            : 1;

        uint256 initialBalance = token.balanceOf(alice);
        console.log("Alice's initial balance:", initialBalance);

        vm.prank(address(aliceBondPool));
        stakeManager.claimReward(alice, rewardAmount);

        uint256 finalBalance = token.balanceOf(alice);
        console.log("Alice's final balance:", finalBalance);

        assertEq(
            finalBalance,
            initialBalance + rewardAmount,
            "Alice should receive the claimed reward"
        );
        assertEq(
            stakeManager.totalUnclaimedRewards(),
            0,
            "All rewards should be claimed"
        );
    }
}
