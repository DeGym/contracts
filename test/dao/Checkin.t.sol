// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "../utils/BaseTest.sol";
import {Checkin} from "../../src/dao/Checkin.sol";

/**
 * @title CheckinTest
 * @dev Test suite for the Checkin contract
 */
contract CheckinTest is BaseTest {
    Checkin public checkin;

    uint256 public gymId;
    uint256 public voucherId;

    // Handle errors for functions that might not exist in contracts
    bool voucherHasValidateFunction = true;
    bool voucherHasDCPFunction = true;
    bool voucherHasDailyDCPFunction = true;

    function setUp() public override {
        super.setUp();

        // Deploy Checkin contract
        checkin = new Checkin(address(voucherNFT), address(gymNFT));

        // Mint a gym for testing
        gymId = gymNFT.mintGymNFT(gymOwner, 1);

        // Add tokens to the gym
        vm.startPrank(gymOwner);
        gymNFT.addAcceptedToken(gymId, address(testToken));
        vm.stopPrank();

        // Mint a voucher for testing
        vm.startPrank(user1);
        voucherId = voucherNFT.mint(1, 30, 0, address(testToken));
        vm.stopPrank();

        // Reset expectations
        voucherHasValidateFunction = true;
        voucherHasDCPFunction = true;
        voucherHasDailyDCPFunction = true;

        // Configure o contrato Checkin no GymNFT
        vm.startPrank(owner);
        gymNFT.setCheckinContract(address(checkin));
        vm.stopPrank();
    }

    function testCheckin() public {
        vm.startPrank(user1);

        // Should be able to check in
        checkin.checkin(voucherId, gymId);

        // Check that the check-in was recorded
        (, uint256 timeRemaining) = checkin.checkEligibility(voucherId);
        assertEq(timeRemaining > 0, true, "Time remaining should be > 0");

        vm.stopPrank();
    }

    function testCheckinTimeConstraint() public {
        // Mint a high tier voucher para ter DCP suficiente para múltiplos check-ins
        vm.startPrank(user1);
        uint256 highTierVoucherId = voucherNFT.mint(
            3,
            30,
            0,
            address(testToken)
        );
        vm.stopPrank();

        vm.startPrank(user1);

        // First check-in
        checkin.checkin(highTierVoucherId, gymId);

        // Try to check in again immediately
        vm.expectRevert("Must wait minimum time between check-ins");
        checkin.checkin(highTierVoucherId, gymId);

        // Advance time past the minimum interval
        vm.warp(block.timestamp + 6 hours + 1);

        // Should be able to check in again
        checkin.checkin(highTierVoucherId, gymId);

        vm.stopPrank();
    }

    function testMultipleDayCheckins() public {
        vm.startPrank(user1);

        // Initial DCP balance
        uint256 initialDcp = voucherNFT.getDCPBalance(voucherId);

        // First day check-in
        checkin.checkin(voucherId, gymId);

        // DCP balance should be reduced
        uint256 afterCheckInDcp = voucherNFT.getDCPBalance(voucherId);
        assertLt(
            afterCheckInDcp,
            initialDcp,
            "DCP should decrease after check-in"
        );

        // Advance time to next day
        vm.warp(block.timestamp + 24 hours);

        // Reset DCP for the new day (usando a nova função de timezone=0)
        vm.stopPrank();
        vm.startPrank(owner);
        voucherNFT.resetAllVouchersDCP(0); // Reset timezone 0
        vm.stopPrank();
        vm.startPrank(user1);

        // DCP should be reset
        uint256 resetDcp = voucherNFT.getDCPBalance(voucherId);
        assertEq(resetDcp, 2, "DCP should be reset for new day");

        // Can check in again after 6 hours on the new day
        vm.warp(block.timestamp + 6 hours);
        checkin.checkin(voucherId, gymId);

        vm.stopPrank();
    }

    function testInsufficientDCP() public {
        vm.startPrank(user1);

        // Create a low tier voucher
        uint256 lowTierVoucherId = voucherNFT.mint(
            1,
            30,
            0,
            address(testToken)
        );

        // Create a high tier gym
        vm.stopPrank();
        uint256 highTierGymId = gymNFT.mintGymNFT(gymOwner, 5);
        vm.startPrank(gymOwner);
        // Add token acceptance for the gym
        gymNFT.addAcceptedToken(highTierGymId, address(testToken));
        vm.stopPrank();

        vm.startPrank(user1);

        // Try to check-in with a low tier voucher to a high tier gym
        // This should fail due to insufficient DCP
        vm.expectRevert("Insufficient DCP for this gym");
        checkin.checkin(lowTierVoucherId, highTierGymId);

        vm.stopPrank();
    }

    // Utility function to emit logs
    function logError(string memory message) internal {
        emit log(message);
    }
}
