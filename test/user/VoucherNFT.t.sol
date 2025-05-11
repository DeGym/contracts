// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../../src/user/VoucherNFT.sol";
import "../../src/gym/GymManager.sol";
import "../../src/gym/GymNFT.sol";
import "../../src/treasury/Treasury.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock token for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
}

contract VoucherNFTTest is Test {
    // Contracts
    VoucherNFT public voucherNFT;
    GymManager public gymManager;
    GymNFT public gymNFT;
    Treasury public treasury;
    MockToken public USDT;

    // Test addresses
    address public owner = address(0x123);
    address public gymOwner = address(0x456);
    address public user1 = address(0x789);
    address public user2 = address(0xabc);

    // Test data
    uint256 public gymId;

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

        // Setup permissions
        gymNFT.transferOwnership(address(gymManager));

        // Add tokens to treasury
        treasury.addAcceptedToken(address(USDT));

        // Set voucher price for USDT
        treasury.setVoucherPrice(address(USDT), 10 * 10 ** 18);

        // Transfer tokens to users
        USDT.transfer(user1, 10000 * 10 ** 18);
        USDT.transfer(user2, 1000 * 10 ** 18);
        USDT.transfer(gymOwner, 10000 * 10 ** 18);

        vm.stopPrank();

        // Register a gym
        vm.startPrank(gymOwner);
        USDT.approve(address(treasury), 10000 * 10 ** 18);

        uint256[2] memory location = [uint256(40000000), uint256(74000000)]; // NYC coords
        gymId = gymManager.registerGym("Test Gym", location, 5);

        vm.stopPrank();
    }

    function testMintVoucher() public {
        vm.startPrank(user1);

        USDT.approve(address(treasury), 100 * 10 ** 18);

        uint256 voucherId = voucherNFT.mint(10, 30, "UTC", address(USDT));

        // Verify voucher exists and user1 is the owner
        assertEq(voucherNFT.ownerOf(voucherId), user1);

        // Verify voucher details
        (
            uint256 tier,
            uint256 duration,
            string memory timezone,
            uint256 expiry,
            address token,
            ,
            bool isActive
        ) = voucherNFT.vouchers(voucherId);

        assertEq(tier, 10);
        assertEq(duration, 30);
        assertEq(
            keccak256(abi.encodePacked(timezone)),
            keccak256(abi.encodePacked("UTC"))
        );
        assertGt(expiry, block.timestamp);
        assertEq(token, address(USDT));
        assertTrue(isActive);

        vm.stopPrank();
    }

    function testRequestCheckIn() public {
        vm.startPrank(user1);

        USDT.approve(address(treasury), 100 * 10 ** 18);

        uint256 voucherId = voucherNFT.mint(10, 30, "UTC", address(USDT));

        // Request check-in
        voucherNFT.requestCheckIn(voucherId, gymId);

        // Verify check-in history
        VoucherNFT.CheckIn[] memory checkIns = voucherNFT.getCheckInHistory(
            voucherId
        );
        VoucherNFT.CheckIn memory checkIn = checkIns[0];
        assertEq(checkIn.gymId, gymId);
        assertEq(checkIn.timestamp, block.timestamp);
        assertGt(checkIn.dcpAmount, 0);

        vm.stopPrank();
    }

    function testValidateVoucher() public {
        vm.startPrank(user1);

        USDT.approve(address(treasury), 100 * 10 ** 18);

        uint256 voucherId = voucherNFT.mint(10, 30, "UTC", address(USDT));

        // Voucher should be valid
        bool isValid = voucherNFT.validateVoucher(voucherId);
        assertTrue(isValid, "Voucher should be valid");

        // Make voucher expire
        uint256 farFuture = block.timestamp + 31 days;
        vm.warp(farFuture);

        // Voucher should now be expired
        isValid = voucherNFT.validateVoucher(voucherId);
        assertFalse(isValid, "Voucher should be expired");

        vm.stopPrank();
    }

    function testTransferVoucher() public {
        vm.startPrank(user1);
        USDT.approve(address(treasury), 100 * 10 ** 18);
        uint256 voucherId = voucherNFT.mint(10, 30, "UTC", address(USDT));

        // Use standard ERC721 transfer method
        voucherNFT.transferFrom(user1, user2, voucherId);

        // Verify new owner
        assertEq(voucherNFT.ownerOf(voucherId), user2);
        vm.stopPrank();

        // Original owner can't check in anymore
        vm.startPrank(user1);
        vm.expectRevert("Not the voucher owner");
        voucherNFT.requestCheckIn(voucherId, gymId);
        vm.stopPrank();

        // New owner can check in
        vm.startPrank(user2);
        voucherNFT.requestCheckIn(voucherId, gymId);
        vm.stopPrank();
    }

    function testGetVouchers() public {
        vm.startPrank(user1);

        USDT.approve(address(treasury), 300 * 10 ** 18);

        // Mint 3 vouchers
        uint256 voucherId1 = voucherNFT.mint(10, 30, "UTC", address(USDT));
        uint256 voucherId2 = voucherNFT.mint(20, 60, "GMT", address(USDT));
        uint256 voucherId3 = voucherNFT.mint(5, 15, "EST", address(USDT));

        // Get all vouchers for user1
        uint256 balance = voucherNFT.balanceOf(user1);
        assertEq(balance, 3, "User should have 3 vouchers");

        // Check each voucher ID
        assertEq(voucherNFT.tokenOfOwnerByIndex(user1, 0), voucherId1);
        assertEq(voucherNFT.tokenOfOwnerByIndex(user1, 1), voucherId2);
        assertEq(voucherNFT.tokenOfOwnerByIndex(user1, 2), voucherId3);

        vm.stopPrank();
    }

    function testCalculateCheckInDCP() public {
        vm.startPrank(user1);

        USDT.approve(address(treasury), 100 * 10 ** 18);

        // Mint vouchers with different tiers
        uint256 voucherId1 = voucherNFT.mint(10, 30, "UTC", address(USDT));
        uint256 voucherId2 = voucherNFT.mint(20, 30, "UTC", address(USDT));

        // Calculate DCP for each
        uint256 dcp1 = voucherNFT.calculateCheckInDCP(voucherId1);
        uint256 dcp2 = voucherNFT.calculateCheckInDCP(voucherId2);

        // Verify tier affects DCP (simple calculation in contract is tier * 10)
        assertEq(dcp1, 100, "Tier 10 should give 100 DCP");
        assertEq(dcp2, 200, "Tier 20 should give 200 DCP");

        vm.stopPrank();
    }
}
