// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
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

contract GymManagerTest is Test {
    // Contracts
    GymManager public gymManager;
    GymNFT public gymNFT;
    Treasury public treasury;
    MockToken public mockToken;

    // Test addresses
    address public owner = address(0x123);
    address public gymOwner = address(0x456);
    address public user = address(0x789);
    address public treasuryWallet = address(0xabc);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy contracts
        mockToken = new MockToken();
        treasury = new Treasury(treasuryWallet);
        gymNFT = new GymNFT(address(treasury));
        gymManager = new GymManager(address(gymNFT), address(treasury));

        // Setup permissions
        gymNFT.transferOwnership(address(gymManager));

        // Add tokens to treasury
        treasury.addAcceptedToken(address(mockToken));

        // Transfer tokens to gym owner
        mockToken.transfer(gymOwner, 10000 * 10 ** 18);

        vm.stopPrank();
    }

    function testRegisterGym() public {
        vm.startPrank(gymOwner);

        mockToken.approve(address(treasury), 1000 * 10 ** 18);

        uint256[2] memory location = [uint256(40000000), uint256(74000000)]; // NYC coords
        uint256 gymId = gymManager.registerGym("New York Fitness", location, 3);

        // Verify gym is registered
        assertTrue(gymId > 0, "Gym ID should be positive");

        // Verify gym ownership
        assertEq(gymNFT.ownerOf(gymId), gymOwner);

        vm.stopPrank();
    }

    function testUpdateGymInfo() public {
        vm.startPrank(gymOwner);
        mockToken.approve(address(treasury), 1000 * 10 ** 18);

        uint256[2] memory location = [uint256(40000000), uint256(74000000)];
        uint256 gymId = gymManager.registerGym("New York Fitness", location, 3);

        // Now update gym info
        uint256[2] memory newLocation = [uint256(40000100), uint256(74000100)];
        gymManager.updateGymInfo(
            gymId,
            "NYC Premium Fitness",
            newLocation,
            "Premium gym in Manhattan"
        );

        vm.stopPrank();
    }

    function testNonOwnerCannotUpdateGym() public {
        // First register a gym
        vm.startPrank(gymOwner);
        mockToken.approve(address(treasury), 1000 * 10 ** 18);

        uint256[2] memory location = [uint256(40000000), uint256(74000000)];
        uint256 gymId = gymManager.registerGym("New York Fitness", location, 3);
        vm.stopPrank();

        // Try to update as non-owner
        vm.startPrank(user);
        uint256[2] memory newLocation = [uint256(40000100), uint256(74000100)];

        vm.expectRevert();
        gymManager.updateGymInfo(
            gymId,
            "Hacked Name",
            newLocation,
            "Hacked details"
        );

        vm.stopPrank();
    }

    function testTierUpgrade() public {
        vm.startPrank(gymOwner);
        mockToken.approve(address(treasury), 1000 * 10 ** 18);

        uint256[2] memory location = [uint256(40000000), uint256(74000000)];
        uint256 gymId = gymManager.registerGym("New York Fitness", location, 3);

        // Tier should be 3
        assertEq(gymNFT.getCurrentTier(gymId), 3);

        // Request tier upgrade
        gymManager.requestTierUpdate(gymId, 5);

        // Tier should now be 5
        assertEq(gymNFT.getCurrentTier(gymId), 5);

        vm.stopPrank();
    }

    function testValidateGym() public {
        vm.startPrank(gymOwner);
        mockToken.approve(address(treasury), 1000 * 10 ** 18);

        uint256[2] memory location = [uint256(40000000), uint256(74000000)];
        uint256 gymId = gymManager.registerGym("New York Fitness", location, 3);
        vm.stopPrank();

        // Validate gym
        bool isValid = gymManager.validateGym(gymId);
        assertTrue(isValid, "Gym should be valid");

        // Non-existent gym
        bool isInvalid = gymManager.validateGym(999);
        assertFalse(isInvalid, "Non-existent gym should be invalid");
    }
}
