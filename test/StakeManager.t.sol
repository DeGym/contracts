// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/staking/StakeManager.sol";
import "../src/staking/BondPool.sol";
import {DeGymToken} from "../src/token/DGYM.sol";

contract StakeManagerTest is Test {
    StakeManager public stakeManager;
    DeGymToken public dgymToken;
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public owner = address(0x3);
    uint256 private alicePrivateKey;

    function setUp() public {
        console.log("Setting up test environment");
        // Deploy DeGymToken
        dgymToken = new DeGymToken(owner);
        console.log("DeGymToken deployed at:", address(dgymToken));

        // Deploy StakeManager with DeGymToken
        stakeManager = new StakeManager(address(dgymToken));
        console.log("StakeManager deployed at:", address(stakeManager));

        // Fund the stake manager with DGYM tokens for rewards
        vm.prank(owner);
        dgymToken.mint(address(stakeManager), 1000000 * 10 ** 18);
        console.log("StakeManager funded with 1,000,000 DGYM tokens");

        // Give Alice and Bob some DGYM tokens
        vm.prank(owner);
        dgymToken.mint(alice, 10000 * 10 ** 18);
        console.log("Alice funded with 10,000 DGYM tokens");
        vm.prank(owner);
        dgymToken.mint(bob, 10000 * 10 ** 18);
        console.log("Bob funded with 10,000 DGYM tokens");

        vm.startPrank(alice);
        dgymToken.approve(address(stakeManager), type(uint256).max);
        console.log("Alice approved StakeManager to spend her DGYM tokens");
        vm.stopPrank();

        vm.startPrank(bob);
        dgymToken.approve(address(stakeManager), type(uint256).max);
        console.log("Bob approved StakeManager to spend his DGYM tokens");
        vm.stopPrank();

        alicePrivateKey = 0xa11ce; // Replace with an actual private key
        alice = vm.addr(alicePrivateKey);
    }

    function _permitForStaking(
        address owner,
        uint256 amount,
        uint256 deadline
    ) internal {
        uint256 nonce = dgymToken.nonces(owner);

        // Generate signature using private key of owner
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                dgymToken.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256(
                            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                        ),
                        owner,
                        address(stakeManager),
                        amount,
                        nonce,
                        deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);
        // Call permit on the token contract
        dgymToken.permit(
            owner,
            address(stakeManager),
            amount,
            deadline,
            v,
            r,
            s
        );
        console.log(
            "Amount permitted to be spent by StakeManager using permit:",
            amount
        );
    }

    function testDeployBondPool() public {
        console.log("Testing deployBondPool function");
        vm.startPrank(alice);
        stakeManager.deployBondPool();
        address bondPoolAddress = stakeManager.bondPools(alice);
        assertTrue(
            bondPoolAddress != address(0),
            "Bond pool should be deployed"
        );
        console.log("Alice's BondPool deployed at:", bondPoolAddress);
        vm.stopPrank();
    }

    function testBond() public {
        console.log("Testing bond function");
        vm.startPrank(alice);
        stakeManager.deployBondPool();
        console.log("Alice deployed her BondPool");

        uint256 amount = 1000 * 10 ** 18;
        uint256 lockDuration = 30 days;

        uint256 initialTotalStaked = stakeManager.totalStaked();
        console.log("Initial total staked:", initialTotalStaked / 1e18, "DGYM");

        // Use permit instead of approve
        uint256 deadline = block.timestamp + 1 hours;
        _permitForStaking(alice, amount, deadline);

        stakeManager.bond(amount, lockDuration);

        uint256 finalTotalStaked = stakeManager.totalStaked();
        console.log("Final total staked:", finalTotalStaked / 1e18, "DGYM");

        assertEq(
            finalTotalStaked,
            initialTotalStaked + amount,
            "Total staked should increase by the bonded amount"
        );
        console.log("Total staked increased by", amount / 1e18, "DGYM");

        vm.stopPrank();
    }

    function testUnbond() public {
        console.log("Testing unbond function");
        vm.startPrank(alice);
        stakeManager.deployBondPool();
        console.log("Alice deployed her BondPool");

        uint256 amount = 1000 * 10 ** 18;
        uint256 lockDuration = 30 days;

        stakeManager.bond(amount, lockDuration);

        uint256 initialTotalStaked = stakeManager.totalStaked();
        console.log("Initial total staked:", initialTotalStaked / 1e18, "DGYM");

        vm.warp(block.timestamp + lockDuration + 1);
        console.log("Time warped to after lock duration");

        stakeManager.unbond(0);
        console.log("Alice unbonded her stake");

        uint256 finalTotalStaked = stakeManager.totalStaked();
        console.log("Final total staked:", finalTotalStaked / 1e18, "DGYM");

        assertEq(
            finalTotalStaked,
            initialTotalStaked - amount,
            "Total staked should decrease by the unbonded amount"
        );
        console.log("Total staked decreased by", amount / 1e18, "DGYM");

        vm.stopPrank();
    }

    function testClaimReward() public {
        console.log("Testing claimReward function");
        vm.startPrank(alice);
        stakeManager.deployBondPool();
        console.log("Alice deployed her BondPool");

        uint256 amount = 1000 * 10 ** 18;
        uint256 lockDuration = 365 days;

        stakeManager.bond(amount, lockDuration);

        vm.warp(block.timestamp + 30 days);
        console.log("Time warped 30 days into the future");

        uint256 initialBalance = dgymToken.balanceOf(alice);
        console.log("Alice's initial DGYM balance:", initialBalance / 1e18);

        stakeManager.claimReward(0);
        console.log("Alice claimed her reward");

        uint256 finalBalance = dgymToken.balanceOf(alice);
        console.log("Alice's final DGYM balance:", finalBalance / 1e18);

        assertTrue(
            finalBalance > initialBalance,
            "Balance should increase after claiming reward"
        );
        console.log(
            "Alice's balance increased by",
            (finalBalance - initialBalance) / 1e18,
            "DGYM"
        );

        vm.stopPrank();
    }

    function testMultipleStakeholders() public {
        console.log("Testing multiple stakeholders");
        vm.startPrank(alice);
        stakeManager.deployBondPool();
        console.log("Alice deployed her BondPool");
        stakeManager.bond(500 * 10 ** 18, 30 days);
        console.log("Alice bonded 500 DGYM for 30 days");
        vm.stopPrank();

        vm.startPrank(bob);
        stakeManager.deployBondPool();
        console.log("Bob deployed his BondPool");
        stakeManager.bond(1000 * 10 ** 18, 60 days);
        console.log("Bob bonded 1000 DGYM for 60 days");
        vm.stopPrank();

        uint256 totalStaked = stakeManager.totalStaked();
        console.log("Total staked:", totalStaked / 1e18, "DGYM");
        assertEq(
            totalStaked,
            1500 * 10 ** 18,
            "Total staked should be 1500 DGYM"
        );

        uint256 stakeholderCount = stakeManager.getStakeholderCount();
        console.log("Stakeholder count:", stakeholderCount);
        assertEq(stakeholderCount, 2, "There should be 2 stakeholders");
    }
}
