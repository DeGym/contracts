// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../../src/treasury/Treasury.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock token for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
}

contract TreasuryTest is Test {
    // Contracts
    Treasury public treasury;
    MockToken public mockToken;
    MockToken public secondToken;

    // Test addresses
    address public owner = address(0x123);
    address public user = address(0x456);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy contracts
        mockToken = new MockToken();
        secondToken = new MockToken();
        treasury = new Treasury();

        // Transfer tokens to user
        mockToken.transfer(user, 1000 * 10 ** 18);
        secondToken.transfer(user, 1000 * 10 ** 18);

        vm.stopPrank();
    }

    function testAddRemoveAcceptedToken() public {
        vm.startPrank(owner);

        // Initially token should not be accepted
        assertFalse(treasury.acceptedTokens(address(mockToken)));

        // Add token
        treasury.addAcceptedToken(address(mockToken));

        // Now token should be accepted
        assertTrue(treasury.acceptedTokens(address(mockToken)));

        // Remove token
        treasury.removeAcceptedToken(address(mockToken));

        // Token should no longer be accepted
        assertFalse(treasury.acceptedTokens(address(mockToken)));

        vm.stopPrank();
    }

    function testOnlyOwnerCanManageTokens() public {
        vm.prank(user);

        // Non-owner should not be able to add tokens
        vm.expectRevert();
        treasury.addAcceptedToken(address(mockToken));

        // Add a token as owner
        vm.prank(owner);
        treasury.addAcceptedToken(address(mockToken));

        // Non-owner should not be able to remove tokens
        vm.prank(user);
        vm.expectRevert();
        treasury.removeAcceptedToken(address(mockToken));
    }

    function testSetVoucherPrice() public {
        vm.startPrank(owner);

        // Add token to accepted tokens
        treasury.addAcceptedToken(address(mockToken));

        // Set voucher price for token
        uint256 price = 10 * 10 ** 18;
        treasury.setVoucherPrice(address(mockToken), price);

        // Verify updated price
        assertEq(treasury.voucherPrices(address(mockToken)), price);

        // Change price
        uint256 newPrice = 20 * 10 ** 18;
        treasury.setVoucherPrice(address(mockToken), newPrice);

        // Verify new price
        assertEq(treasury.voucherPrices(address(mockToken)), newPrice);

        vm.stopPrank();
    }

    function testSetMinimumGymStakingAmount() public {
        vm.startPrank(owner);

        // Check initial value
        uint256 initialAmount = treasury.minimumGymStakingAmount();

        // Update minimum staking amount
        uint256 newAmount = 2000 * 10 ** 18;
        treasury.setMinimumGymStakingAmount(newAmount);

        // Verify updated amount
        assertEq(treasury.minimumGymStakingAmount(), newAmount);

        vm.stopPrank();
    }

    function testCalculatePrice() public {
        vm.startPrank(owner);

        // Add token to accepted tokens
        treasury.addAcceptedToken(address(mockToken));

        // Set token price
        treasury.setVoucherPrice(address(mockToken), 10 * 10 ** 18);

        // Test price calculations
        uint256 voucherPrice = treasury.calculatePrice(
            address(mockToken),
            10,
            30
        );
        assertGt(voucherPrice, 0, "Voucher price should be positive");

        vm.stopPrank();
    }

    function testValidateToken() public {
        vm.startPrank(owner);

        // Add first token
        treasury.addAcceptedToken(address(mockToken));

        // Validate tokens
        assertTrue(
            treasury.validateToken(address(mockToken)),
            "First token should be accepted"
        );
        assertFalse(
            treasury.validateToken(address(secondToken)),
            "Second token should not be accepted"
        );

        // Add second token
        treasury.addAcceptedToken(address(secondToken));

        // Both should now be accepted
        assertTrue(
            treasury.validateToken(address(mockToken)),
            "First token should still be accepted"
        );
        assertTrue(
            treasury.validateToken(address(secondToken)),
            "Second token should now be accepted"
        );

        vm.stopPrank();
    }
}
