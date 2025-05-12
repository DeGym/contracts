// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "../utils/BaseTest.sol";
import {Checkin} from "../../src/dao/Checkin.sol";

/**
 * @title CheckinIntervalTest
 * @dev Test suite for the interval functionality in the Checkin contract
 */
contract CheckinIntervalTest is BaseTest {
    Checkin public checkin;
    uint256 public testGymId;
    uint256 public testVoucherId;

    function setUp() public override {
        super.setUp();

        // Deploy Checkin contract
        checkin = new Checkin(address(voucherNFT), address(gymNFT));

        // Create a gym
        testGymId = gymNFT.mintGymNFT(gymOwner, 1);

        // Add token acceptance
        vm.startPrank(gymOwner);
        gymNFT.addAcceptedToken(testGymId, address(testToken));
        vm.stopPrank();

        // Create a voucher
        vm.startPrank(user1);
        testVoucherId = voucherNFT.mint(1, 30, 0, address(testToken));
        vm.stopPrank();

        // Configure o contrato Checkin no GymNFT
        vm.startPrank(owner);
        gymNFT.setCheckinContract(address(checkin));
        vm.stopPrank();
    }

    function testContractReferences() public {
        assertEq(address(checkin.voucherNFT()), address(voucherNFT));
        assertEq(address(checkin.gymNFT()), address(gymNFT));
    }

    function testDefaultCheckInInterval() public {
        // Check default value
        assertEq(
            checkin.minTimeBetweenCheckins(),
            6 hours,
            "Default should be 6 hours"
        );
    }

    function testUpdateMinTimeBetweenCheckins() public {
        uint256 newValue = 12 hours;

        vm.startPrank(owner);
        checkin.setMinTimeBetweenCheckins(newValue);
        vm.stopPrank();

        assertEq(
            checkin.minTimeBetweenCheckins(),
            newValue,
            "Should be updated"
        );

        // Test that non-owner cannot update
        vm.startPrank(user1);
        vm.expectRevert();
        checkin.setMinTimeBetweenCheckins(1 hours);
        vm.stopPrank();
    }

    function testCanCheckIn() public {
        // First check-in should be allowed
        assertTrue(
            checkin.canCheckIn(testVoucherId),
            "First check-in should be allowed"
        );

        // Check in
        vm.startPrank(user1);
        checkin.checkin(testVoucherId, testGymId);
        vm.stopPrank();

        // Should not be allowed immediately after
        assertFalse(
            checkin.canCheckIn(testVoucherId),
            "Should not be allowed right after"
        );

        // Advance time past interval
        vm.warp(block.timestamp + checkin.minTimeBetweenCheckins() + 1);

        // Should be allowed again
        assertTrue(
            checkin.canCheckIn(testVoucherId),
            "Should be allowed after interval"
        );
    }

    function testFailCheckInTooSoon() public {
        // First check-in
        vm.startPrank(user1);
        checkin.checkin(testVoucherId, testGymId);

        // Try checking in again immediately (should fail)
        checkin.checkin(testVoucherId, testGymId);
        vm.stopPrank();
    }
}
