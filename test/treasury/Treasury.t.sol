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
    address public treasuryWallet = address(0x789);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy contracts
        mockToken = new MockToken();
        secondToken = new MockToken();
        treasury = new Treasury(treasuryWallet);

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

    function testSetPrices() public {
        vm.startPrank(owner);

        // Check initial prices
        assertEq(treasury.voucherBasePriceUSD(), 10 * 10 ** 18);
        assertEq(treasury.gymRegistrationBaseFeeUSD(), 100 * 10 ** 18);
        assertEq(treasury.tierUpgradeBaseFeeUSD(), 50 * 10 ** 18);

        // Update prices
        treasury.setVoucherBasePrice(20 * 10 ** 18);
        treasury.setGymRegistrationBaseFee(200 * 10 ** 18);
        treasury.setTierUpgradeBaseFee(75 * 10 ** 18);

        // Verify updated prices
        assertEq(treasury.voucherBasePriceUSD(), 20 * 10 ** 18);
        assertEq(treasury.gymRegistrationBaseFeeUSD(), 200 * 10 ** 18);
        assertEq(treasury.tierUpgradeBaseFeeUSD(), 75 * 10 ** 18);

        vm.stopPrank();
    }

    function testCalculatePrice() public {
        vm.startPrank(owner);

        // Add token to accepted tokens
        treasury.addAcceptedToken(address(mockToken));

        // Default price calculations
        uint256 voucherPrice = treasury.calculatePrice(
            address(mockToken),
            10,
            30
        );
        assertGt(voucherPrice, 0, "Voucher price should be positive");

        uint256 upgradeFee = treasury.calculateUpgradeFee(3, 5);
        assertGt(upgradeFee, 0, "Upgrade fee should be positive");

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

    function testChangeTreasuryWallet() public {
        vm.startPrank(owner);

        address newWallet = address(0xabc);

        // Change treasury wallet
        treasury.setTreasuryWallet(newWallet);

        // Verify change
        assertEq(treasury.treasuryWallet(), newWallet);

        vm.stopPrank();
    }
}
