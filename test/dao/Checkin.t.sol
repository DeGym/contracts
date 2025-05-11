// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../../src/dao/Checkin.sol";
import "../../src/user/VoucherNFT.sol";
import "../../src/gym/GymNFT.sol";
import "../../src/gym/GymManager.sol";
import "../../src/treasury/Treasury.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock token for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
}

contract CheckinTest is Test {
    // Contracts
    Checkin public checkin;
    VoucherNFT public voucherNFT;
    GymNFT public gymNFT;
    GymManager public gymManager;
    Treasury public treasury;
    MockToken public USDT;

    // Test addresses
    address public owner = address(0x123);
    address public gymOwner = address(0x456);
    address public user1 = address(0x789);
    address public user2 = address(0xabc);

    // Test data
    uint256 public gymId;
    uint256 public voucherId;

    function setUp() public {
        vm.startPrank(owner);

        // Deploy contracts
        USDT = new MockToken();
        treasury = new Treasury();
        gymNFT = new GymNFT(address(treasury));
        gymManager = new GymManager(address(gymNFT), address(treasury));
        voucherNFT = new VoucherNFT(
            address(treasury),
            address(gymManager),
            address(gymNFT)
        );
        checkin = new Checkin(address(voucherNFT), address(gymNFT));

        // Setup permissions
        gymNFT.transferOwnership(address(gymManager));

        // Add tokens to treasury
        treasury.addAcceptedToken(address(USDT));

        // Set voucher price for USDT
        treasury.setVoucherPrice(address(USDT), 10 * 10 ** 18);

        // Transfer tokens to users
        USDT.transfer(gymOwner, 10000 * 10 ** 18);
        USDT.transfer(user1, 1000 * 10 ** 18);
        vm.stopPrank();

        // Register a gym
        vm.startPrank(gymOwner);
        USDT.approve(address(treasury), 10000 * 10 ** 18);

        uint256[2] memory location = [uint256(40000000), uint256(74000000)]; // NYC coords
        gymId = gymManager.registerGym("Test Gym", location, 5);

        vm.stopPrank();

        // Create a voucher for user1
        vm.startPrank(user1);
        USDT.approve(address(treasury), 100 * 10 ** 18);

        voucherId = voucherNFT.mint(10, 30, "UTC", address(USDT));

        vm.stopPrank();
    }

    function testSuccessfulCheckin() public {
        vm.startPrank(user1);

        bool success = checkin.checkin(voucherId, gymId);

        assertTrue(success, "Check-in should be successful");

        // Verify last check-in time is updated
        assertEq(checkin.lastCheckinTime(voucherId), block.timestamp);

        vm.stopPrank();
    }

    function testMultipleCheckinsInSameDay() public {
        vm.startPrank(user1);

        // Primeiro check-in
        bool success1 = checkin.checkin(voucherId, gymId);
        assertTrue(success1, "First check-in should be successful");

        // Segundo check-in logo em seguida (agora deve funcionar)
        bool success2 = checkin.checkin(voucherId, gymId);
        assertTrue(success2, "Second check-in should also be successful");

        vm.stopPrank();
    }

    function testCheckinOnDifferentDays() public {
        vm.startPrank(user1);

        // Primeiro check-in
        checkin.checkin(voucherId, gymId);

        // Avançar para o próximo dia
        vm.warp(block.timestamp + 1 days);

        // Check-in no próximo dia
        bool success = checkin.checkin(voucherId, gymId);
        assertTrue(success, "Check-in on different day should be successful");

        vm.stopPrank();
    }

    function testNonOwnerCannotCheckin() public {
        vm.startPrank(user2);

        // User2 is not the voucher owner
        vm.expectRevert("Not the voucher owner");
        checkin.checkin(voucherId, gymId);

        vm.stopPrank();
    }

    function testCanCheckInFunction() public {
        vm.startPrank(user1);

        // Verificar elegibilidade inicial
        (bool canCheckIn, uint256 timeRemaining) = checkin.checkEligibility(
            voucherId
        );
        assertTrue(canCheckIn, "Should be able to check in initially");
        assertEq(
            timeRemaining,
            0,
            "No time remaining as restriction is removed"
        );

        // Fazer um check-in
        checkin.checkin(voucherId, gymId);

        // Verificar elegibilidade imediatamente depois (deve ainda ser possível)
        (canCheckIn, timeRemaining) = checkin.checkEligibility(voucherId);
        assertTrue(
            canCheckIn,
            "Should still be able to check in after a previous check-in"
        );
        assertEq(timeRemaining, 0, "No time restriction between check-ins");

        vm.stopPrank();
    }
}
