// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/treasury/Treasury.sol";
import "../../src/gym/GymNFT.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../mocks/MockToken.sol";

contract TreasuryPauseTest is Test {
    Treasury public treasury;
    MockToken public USDT;
    address public owner;
    address public user;
    address public gymNftAddress;

    function setUp() public {
        owner = address(this);
        user = address(0x123);

        // Deploy mock contracts
        treasury = new Treasury();
        USDT = new MockToken("Tether", "USDT", 18);

        // Mock GymNFT address for testing
        gymNftAddress = address(0x456);
        treasury.setGymNFT(gymNftAddress);

        // Mint tokens to user
        USDT.mint(user, 10000 * 10 ** 18);

        // Add test token as accepted token
        treasury.addAcceptedToken(address(USDT));
    }

    function testPauseUnpause() public {
        // Verify initial state is unpaused
        assertEq(treasury.paused(), false);

        // Pause the contract
        treasury.pause();
        assertEq(treasury.paused(), true);

        // Unpause the contract
        treasury.unpause();
        assertEq(treasury.paused(), false);
    }

    function testFailAddAcceptedTokenWhenPaused() public {
        // Pause the contract
        treasury.pause();

        // This should fail because contract is paused
        address newToken = address(0x789);
        treasury.addAcceptedToken(newToken);
    }

    function testFailProcessGymRewardWhenPaused() public {
        // Pause the contract
        treasury.pause();

        // Use the gymNftAddress to call processGymReward
        vm.prank(gymNftAddress);

        // This should fail because contract is paused
        treasury.processGymReward(address(0x123), address(USDT), 100);
    }

    function testOnlyOwnerCanPause() public {
        // Try to pause as non-owner
        vm.prank(user);
        vm.expectRevert();
        treasury.pause();

        // Owner can pause
        vm.prank(owner);
        treasury.pause();
        assertEq(treasury.paused(), true);
    }

    function testProcessGymRewardWhenNotPaused() public {
        // Mint tokens to treasury
        USDT.mint(address(treasury), 1000 * 10 ** 18);

        // Check initial balance
        uint256 initialBalance = USDT.balanceOf(user);

        // Call processGymReward from gymNFT address
        vm.prank(gymNftAddress);
        treasury.processGymReward(user, address(USDT), 100);

        // Verify tokens were transferred
        assertEq(USDT.balanceOf(user), initialBalance + 100);
    }

    function testWhenPaused() public {
        // Pause the contract
        treasury.pause();

        // Check if modifier is working
        vm.expectRevert("Treasury: paused");
        vm.prank(gymNftAddress);
        treasury.processGymReward(user, address(USDT), 100);

        // Unpause should work
        treasury.unpause();

        // Now this should work
        USDT.mint(address(treasury), 1000);
        vm.prank(gymNftAddress);
        treasury.processGymReward(user, address(USDT), 100);
    }
}
