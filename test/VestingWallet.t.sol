// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {DeGymToken} from "../src/token/DGYM.sol";
import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";

contract VestingWalletTest is Test {
    DeGymToken token;

    // Vesting wallets addresses
    address ecosystemWallet;
    address teamGrowthWallet;
    address teamGrowthWallet2;
    address communityWallet;
    address marketingWallet;

    function setUp() public {
        // Deploy the DeGymToken contract with the deployer as the initial owner
        token = new DeGymToken(address(this));

        // Retrieve vesting wallet addresses via getter functions
        ecosystemWallet = token.ecosystemDevelopmentVestingWallet();
        teamGrowthWallet = token.teamGrowthVestingWallet();
        communityWallet = token.communityEngagementVestingWallet();
        marketingWallet = token.marketingPromotionVestingWallet();
    }

    function testVestingWalletBalances() public view {
        // Verify the initial balances in the vesting wallets
        assertEq(
            token.balanceOf(ecosystemWallet),
            token.ecosystemDevelopment()
        );
        assertEq(token.balanceOf(teamGrowthWallet), token.teamGrowth());
        assertEq(token.balanceOf(communityWallet), token.communityEngagement());
        assertEq(token.balanceOf(marketingWallet), token.marketingPromotion());
    }

    function testVestingRelease() public {
        // Simulate time passing (2 months)
        vm.warp(block.timestamp + 60 days);

        // Release tokens from the vesting wallets
        VestingWallet(payable(ecosystemWallet)).release(address(token));
        VestingWallet(payable(teamGrowthWallet)).release(address(token));
        VestingWallet(payable(communityWallet)).release(address(token));
        VestingWallet(payable(marketingWallet)).release(address(token));

        // Check if tokens were released correctly (some tokens should still be vesting)
        uint256 ecosystemReleased = VestingWallet(payable(ecosystemWallet))
            .released(address(token));
        uint256 teamGrowthReleased = VestingWallet(payable(teamGrowthWallet))
            .released(address(token));
        uint256 communityReleased = VestingWallet(payable(communityWallet))
            .released(address(token));
        uint256 marketingReleased = VestingWallet(payable(marketingWallet))
            .released(address(token));

        assertGt(ecosystemReleased, 0);
        assertGt(teamGrowthReleased, 0);
        assertGt(communityReleased, 0);
        assertGt(marketingReleased, 0);
    }

    function testBeneficiaryCanWithdraw() public {
        // Simulate time passing to fully vest the tokens
        vm.warp(block.timestamp + 360 days);

        // Check the balance before releasing
        uint256 balanceBefore = token.balanceOf(
            0xaDcB2f54F652BFD7Ac1d7D7b12213b4519F0265D
        );

        // Set the VM to act as the real beneficiary
        vm.prank(0xaDcB2f54F652BFD7Ac1d7D7b12213b4519F0265D);

        // Release tokens from one of the vesting wallets
        VestingWallet(payable(teamGrowthWallet)).release(address(token));

        // Check the balance after releasing
        uint256 balanceAfter = token.balanceOf(
            0xaDcB2f54F652BFD7Ac1d7D7b12213b4519F0265D
        );

        // Assert that the beneficiary's balance has increased
        assertGt(balanceAfter, balanceBefore);
    }
}
