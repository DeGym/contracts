// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/token/Crowdfund.sol";
import {DeGymToken} from "../src/token/DGYM.sol";
import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";

contract CrowdfundTest is Test {
    DeGymToken private token;
    Crowdfund private crowdfund;

    uint256 private ownerPrivateKey = 0xA11CE; // Example private key
    address private owner = vm.addr(ownerPrivateKey); // Derive the address from the private key
    address private wallet = address(0x2);
    address private beneficiary = address(0x4);

    function setUp() public {
        console.log("Starting setUp");

        // Initialize the DeGymToken contract
        vm.startPrank(owner);
        token = new DeGymToken(owner);
        console.log("DeGymToken initialized");

        // Initialize the Crowdfund contract
        crowdfund = new Crowdfund(address(token), wallet);
        console.log("Crowdfund initialized");

        // Create the Pre-Seed phase
        crowdfund.createPhase(
            "Pre-Seed",
            10000, // 100% rate in basis points (1 TARA = 1 DGYM)
            (1_000_000_000e18 * 3) / 100, // 3% allocation
            block.timestamp,
            2 * 30 days, // 2 months duration
            true, // burnable
            0, // No cliff for testing
            18 * 30 days // 18 months vesting
        );
        console.log("Pre-Seed phase created");

        // Use permit instead of approve
        _permitPhase("Pre-Seed");
        vm.stopPrank();
    }

    function _permitPhase(string memory phaseName) internal {
        (, uint256 allocation, , , , uint256 endTime, , , ) = crowdfund.phases(
            phaseName
        );

        uint256 nonce = token.nonces(owner);
        uint256 deadline = endTime;
        uint256 amount = allocation;

        // Generate signature using private key of owner
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256(
                            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                        ),
                        owner,
                        address(crowdfund),
                        amount,
                        nonce,
                        deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        // Call permit on the token contract
        token.permit(owner, address(crowdfund), amount, deadline, v, r, s);
        console.log(
            "Amount permitted to be spent by Crowdfund contract using permit for phase:",
            phaseName
        );
    }

    function testActivatePreSeedPhase() public {
        // Test that the phase is not active initially
        assertEq(crowdfund.getActivePhase(), "");

        // Simulate the start of the Pre-Seed phase
        vm.warp(block.timestamp + 1);
        crowdfund.activatePhaseAutomatically();

        // Check that the Pre-Seed phase is active
        assertEq(crowdfund.getActivePhase(), "Pre-Seed");
    }

    function testBuyTokensPreSeed() public {
        uint256 phaseAllocation = (token.totalSupply() * 3) / 100;
        vm.warp(block.timestamp + 1);
        crowdfund.activatePhaseAutomatically();
        console.log("Phase activated automatically.");

        uint256 initialBalance = token.balanceOf(beneficiary);
        console.log("Initial beneficiary token balance:", initialBalance);

        uint256 purchaseAmount = 1 ether;
        console.log("Purchase amount (in Ether):", purchaseAmount);

        // Use permit to allow the Crowdfund contract to spend the required tokens
        _permitPhase("Pre-Seed");
        console.log("Permit phase executed.");

        // Fund the beneficiary's account with Ether
        vm.deal(beneficiary, purchaseAmount);
        console.log("Beneficiary's account funded with Ether.");

        // Transfer Ether to the Crowdfund contract (triggers the receive function)
        vm.prank(beneficiary);
        (bool success, ) = address(crowdfund).call{value: purchaseAmount}("");
        require(success, "Ether transfer failed");
        console.log("Ether transferred to Crowdfund contract.");

        // Since the rate is now 10000 basis points (100%), we expect to get the same amount of tokens as wei sent.
        uint256 expectedTokens = purchaseAmount; // 1 Ether * 100% = 1 DGYM
        console.log(
            "Expected tokens to be received by beneficiary:",
            expectedTokens
        );

        // Check that tokens have been transferred to the vesting wallet
        address payable vestingWalletAddress = payable(
            crowdfund.vestingWallets(beneficiary)
        );
        console.log("Vesting wallet address:", vestingWalletAddress);
        uint256 vestingWalletBalance = token.balanceOf(vestingWalletAddress);
        console.log("Vesting wallet balance:", vestingWalletBalance);

        assertEq(vestingWalletBalance, expectedTokens);

        // Simulate the passage of time to the end of the vesting period
        (, , , , , , , uint64 cliffDuration, uint64 vestingDuration) = crowdfund
            .phases("Pre-Seed");
        uint256 totalVestingTime = cliffDuration + vestingDuration;
        vm.warp(block.timestamp + totalVestingTime);
        console.log("Warped to the end of the vesting period.");

        // Release the vested tokens
        VestingWallet vestingWallet = VestingWallet(vestingWalletAddress);
        vestingWallet.release(address(token));
        console.log("Vested tokens released from the vesting wallet.");

        // Verify the final beneficiary balance
        uint256 finalBalance = token.balanceOf(beneficiary);
        assertEq(finalBalance, initialBalance + expectedTokens);
        console.log("Final beneficiary token balance:", finalBalance);

        (, uint256 allocation, uint256 sold, , , , , , ) = crowdfund.phases(
            "Pre-Seed"
        );
        assertEq(sold, expectedTokens);
        assertEq(allocation, phaseAllocation);
        console.log("Phase allocation:", allocation);
        console.log("Tokens sold during the phase:", sold);
    }

    function testBurnUnsoldTokensPreSeed() public {
        uint256 totalSupplyBeforeBurn = token.totalSupply();

        vm.warp(block.timestamp + 1);
        crowdfund.activatePhaseAutomatically();

        vm.warp(block.timestamp + 2 * 30 days); // End of Pre-Seed phase
        crowdfund.deactivatePhaseAutomatically();

        (, uint256 allocation, uint256 sold, , , , , , ) = crowdfund.phases(
            "Pre-Seed"
        );
        uint256 unsoldTokens = allocation - sold;

        uint256 burnedTokens = unsoldTokens > 0 ? unsoldTokens : 0;

        assertEq(token.totalSupply(), totalSupplyBeforeBurn - burnedTokens);
    }

    function testCreatePrivateSalePhase() public {
        vm.startPrank(owner);
        uint256 totalSupply = token.totalSupply();
        uint256 allocation = (totalSupply * 7) / 100;

        crowdfund.createPhase(
            "Private Sale",
            13000, // 130% rate in basis points (1.3 TARA worth of tokens per TARA sent)
            allocation, // 7% allocation
            block.timestamp + 3 * 30 days, // start after Pre-Seed ends
            3 * 30 days, // 3 months duration
            true, // burnable
            3 * 30 days, // 3 months cliff
            24 * 30 days // 24 months vesting
        );
        console.log("Private Sale phase created.");

        // Use permit for the Crowdfund contract to spend the required tokens for this phase
        _permitPhase("Private Sale");
        console.log("Permit phase executed for Private Sale.");

        (, uint256 returnedAllocation, , , , , , , ) = crowdfund.phases(
            "Private Sale"
        );
        assertEq(returnedAllocation, allocation);
        console.log(
            "Verified allocation for Private Sale phase:",
            returnedAllocation
        );
        vm.stopPrank();
    }

    function testPublicSalePhase() public {
        vm.startPrank(owner);
        uint256 allocation = (token.totalSupply() * 30) / 100;

        crowdfund.createPhase(
            "Public Sale",
            16900, // 169% rate in basis points (1.69 TARA worth of tokens per TARA sent)
            allocation, // 30% allocation
            block.timestamp + 6 * 30 days, // start after Private Sale ends
            3 * 30 days, // 3 months duration
            true, // burnable
            0, // No cliff
            0 // No vesting
        );
        console.log("Public Sale phase created.");

        // Use permit for the Crowdfund contract to spend the required tokens for this phase
        _permitPhase("Public Sale");
        console.log("Permit phase executed for Public Sale.");

        (, uint256 returnedAllocation, , , , , , , ) = crowdfund.phases(
            "Public Sale"
        );
        assertEq(returnedAllocation, allocation);
        console.log(
            "Verified allocation for Public Sale phase:",
            returnedAllocation
        );
        vm.stopPrank();
    }
}
