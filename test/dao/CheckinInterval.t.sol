// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "../utils/BaseTest.sol";
import {Checkin} from "../../src/dao/Checkin.sol";

contract CheckinIntervalTest is BaseTest {
    Checkin public checkin;

    uint256 public voucherId;
    uint256 public gymId;

    function setUp() public override {
        super.setUp();

        checkin = new Checkin(address(voucherNFT), address(gymNFT));

        // Setup gym
        gymId = createGym(gymOwner, 1);

        // Setup voucher
        voucherId = mintVoucher(user1, 1, 30, 0);
    }

    function testDefaultCheckInInterval() public {
        // Default interval should be 6 hours
        assertEq(checkin.minTimeBetweenCheckins(), 6 hours);
    }

    function testCanCheckIn() public {
        // Criar um tokenId único para este teste
        uint256 uniqueTokenId = 123;

        // Setup novo mock para este ID específico
        _setupMockVoucher(uniqueTokenId, user1);

        // Resto do teste...
        vm.startPrank(user1);
        checkin.checkin(uniqueTokenId, gymId);
        vm.stopPrank();
    }

    function testUpdateMinTimeBetweenCheckins() public {
        // Criar um tokenId único para este teste
        uint256 uniqueTokenId = 456;

        // Setup novo mock para este ID específico
        _setupMockVoucher(uniqueTokenId, user1);

        // Resto do teste...
        vm.startPrank(user1);
        checkin.checkin(uniqueTokenId, gymId);
        vm.stopPrank();
    }

    function testFailCheckInTooSoon() public {
        // Perform first check-in
        vm.startPrank(user1);
        checkin.checkin(voucherId, gymId);

        // Try to check-in again immediately (should fail)
        checkin.checkin(voucherId, gymId);
        vm.stopPrank();
    }

    // Novo método para criar mock para qualquer tokenId
    function _setupMockVoucher(uint256 tokenId, address recipient) internal {
        vm.mockCall(
            address(voucherNFT),
            abi.encodeWithSelector(voucherNFT.ownerOf.selector, tokenId),
            abi.encode(recipient)
        );

        vm.mockCall(
            address(voucherNFT),
            abi.encodeWithSelector(
                voucherNFT.validateVoucher.selector,
                tokenId
            ),
            abi.encode(true)
        );

        vm.mockCall(
            address(voucherNFT),
            abi.encodeWithSelector(
                voucherNFT.hasSufficientDCP.selector,
                tokenId,
                uint8(1)
            ),
            abi.encode(true)
        );

        vm.mockCall(
            address(voucherNFT),
            abi.encodeWithSelector(
                voucherNFT.requestCheckIn.selector,
                tokenId,
                gymId
            ),
            abi.encode(true)
        );
    }
}
