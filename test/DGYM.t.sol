// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {DeGymToken} from "../src/token/DGYM.sol";

contract TokenTest is Test {
    DeGymToken token;
    address owner = address(0x123);
    address user1 = address(0x456);
    address user2 = address(0x789);

    function setUp() public {
        token = new DeGymToken(owner);
    }

    function testInitialSupply() public view {
        uint256 expectedTotalSupply = 1_000_000_000e18;
        assertEq(token.totalSupply(), expectedTotalSupply);
    }

    function testMinting() public {
        uint256 amountToMint = 100e18;
        vm.prank(owner);
        token.mint(user1, amountToMint);
        assertEq(token.balanceOf(user1), amountToMint);
    }

    function testMintExceedingCap() public {
        uint256 amountToMint = token.cap() + 1;
        vm.prank(owner);
        vm.expectRevert("ERC20Capped: cap exceeded");
        token.mint(user1, amountToMint);
    }

    function testSetCap() public {
        uint256 newCap = 20_000_000_000e18; // Ensure correct decimal scaling
        vm.prank(owner);
        token.setCap(newCap);
        assertEq(token.cap(), newCap); // Ensure the cap matches the expected value
    }

    function testBurning() public {
        uint256 amountToMint = 100e18;
        vm.prank(owner);
        token.mint(user1, amountToMint);

        vm.prank(user1);
        token.burn(50e18);

        assertEq(token.balanceOf(user1), 50e18);
    }

    function testBurnFrom() public {
        uint256 amountToMint = 100e18;
        vm.prank(owner);
        token.mint(user1, amountToMint);

        vm.prank(user1);
        token.approve(user2, 50e18);

        vm.prank(user2);
        token.burnFrom(user1, 50e18);

        assertEq(token.balanceOf(user1), 50e18);
    }

    function testNonces() public view {
        assertEq(token.nonces(owner), 0);
    }

    function testPermit() public {
        // Set up
        uint256 amount = 100e18;
        uint256 deadline = block.timestamp + 1 hours;

        // Manually define a private key for user1
        uint256 user3PrivateKey = 0xA11CE; // Example private key (replace with your own key)
        address user3 = vm.addr(user3PrivateKey); // Derive the address from the private key

        // Fund the wallets if needed
        vm.deal(owner, 1 ether);
        vm.deal(user3, 1 ether);
        vm.deal(user2, 1 ether);

        // Mint some tokens to user1
        vm.prank(owner);
        token.mint(user3, amount);

        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();

        // Create the permit hash as defined by EIP-2612
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                ),
                user3,
                user2,
                amount,
                token.nonces(user3),
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        // Sign the permit digest with user1's private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user3PrivateKey, digest);

        // Perform the permit
        vm.prank(user3);
        token.permit(user3, user2, amount, deadline, v, r, s);

        // Validate the allowance
        assertEq(token.allowance(user3, user2), amount);
    }
}
