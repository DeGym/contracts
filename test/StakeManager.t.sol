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
        stakeManager = new StakeManager(address(token));
        token.grantRole(token.MINTER_ROLE(), address(stakeManager));
        token.mint(alice, 10000 * 10 ** 18);
        token.mint(bob, 10000 * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(alice);
        _permitForStakeManager(alice, alicePrivateKey);
        stakeManager.deployBondPool();
        aliceBondPool = BondPool(stakeManager.bondPools(alice));
        vm.stopPrank();

        vm.startPrank(bob);
        _permitForStakeManager(bob, bobPrivateKey);
        stakeManager.deployBondPool();
        bobBondPool = BondPool(stakeManager.bondPools(bob));
        vm.stopPrank();
    }

    function _permitForStakeManager(address user, uint256 privateKey) internal {
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(user);
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256(
                            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                        ),
                        user,
                        address(stakeManager),
                        type(uint256).max,
                        nonce,
                        deadline
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        token.permit(
            user,
            address(stakeManager),
            type(uint256).max,
            deadline,
            v,
            r,
            s
        );
    }

    function testDeployBondPool() public {
        assertTrue(
            stakeManager.isBondPool(address(aliceBondPool)),
            "Alice's BondPool should be registered"
        );
        assertTrue(
            stakeManager.isBondPool(address(bobBondPool)),
            "Bob's BondPool should be registered"
        );
    }

    function testUpdateRewards() public {
        vm.startPrank(alice);
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
        vm.startPrank(alice);
        aliceBondPool.bond(1000 * 10 ** 18, 30 days);
        vm.stopPrank();

        uint256 totalWeight = stakeManager.getTotalBondWeight();
        assertTrue(totalWeight > 0, "Total bond weight should be updated");
    }

    function testNotifyStakeChange() public {
        vm.startPrank(alice);
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
        vm.startPrank(alice);
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

    function testOnlyBondPoolCanCallRestrictedFunctions() public {
        vm.expectRevert("Caller is not a valid BondPool");
        vm.prank(alice);
        stakeManager.notifyWeightChange(1000 * 10 ** 18);

        vm.expectRevert("Caller is not a valid BondPool");
        vm.prank(bob);
        stakeManager.notifyStakeChange(1000 * 10 ** 18, true);

        vm.expectRevert("Caller is not a valid BondPool");
        vm.prank(owner);
        stakeManager.claimReward(alice, 100 * 10 ** 18);

        vm.expectRevert("Caller is not a valid BondPool");
        vm.prank(address(0x1234));
        stakeManager.transferToUser(alice, 100 * 10 ** 18);
    }

    function testGetTotalBondWeight() public {
        vm.startPrank(alice);
        aliceBondPool.bond(1000 * 10 ** 18, 30 days);
        vm.stopPrank();

        uint256 totalWeight = stakeManager.getTotalBondWeight();
        assertTrue(
            totalWeight > 0,
            "Total bond weight should be greater than 0"
        );
    }

    function testGetStakeholderCount() public {
        uint256 stakeholderCount = stakeManager.getStakeholderCount();
        assertEq(stakeholderCount, 2, "Stakeholder count should be 2");
    }
}
