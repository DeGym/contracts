// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MockToken} from "../mocks/MockToken.sol";
import {VoucherNFT} from "../../src/user/VoucherNFT.sol";
import {GymNFT} from "../../src/gym/GymNFT.sol";
import {Treasury} from "../../src/treasury/Treasury.sol";
import {GymManager} from "../../src/gym/GymManager.sol";
import {StakeManager} from "../../src/staking/StakeManager.sol";
import {DeGymToken} from "../../src/token/DGYM.sol";
import {console} from "forge-std/console.sol";

/**
 * @title BaseTest
 * @dev Base contract for all test suites
 */
abstract contract BaseTest is Test {
    // Common addresses
    address public owner;
    address public user1;
    address public user2;
    address public gymOwner;

    // Commonly used tokens
    MockToken public USDT;
    MockToken public testToken;
    MockToken public DGYM_token;

    // Core contracts
    Treasury public treasury;
    GymNFT public gymNFT;
    GymManager public gymManager;
    StakeManager public stakeManager;
    VoucherNFT public voucherNFT;

    function setUp() public virtual {
        // Setup common addresses
        owner = address(this);
        user1 = address(0x123);
        user2 = address(0x456);
        gymOwner = address(0x789);

        // Label addresses for better trace output
        vm.label(owner, "Owner");
        vm.label(user1, "User1");
        vm.label(user2, "User2");
        vm.label(gymOwner, "GymOwner");

        // Initialize with a clean timestamp
        vm.warp(1000000);

        // Deploy tokens
        USDT = new MockToken("Tether", "USDT", 18);
        testToken = new MockToken("Test Token", "TEST", 18);

        // Mint tokens for users
        testToken.mint(user1, 1000 * 10 ** 18);
        testToken.mint(user2, 1000 * 10 ** 18);
        testToken.mint(owner, 10000 * 10 ** 18);
        USDT.mint(user1, 1000 * 10 ** 18);
        USDT.mint(user2, 1000 * 10 ** 18);
        USDT.mint(owner, 10000 * 10 ** 18);

        // Deploy core contracts
        deployCore();

        // Approve DGYM token for stakeManager
        vm.startPrank(user1);
        DGYM_token.approve(address(stakeManager), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        DGYM_token.approve(address(stakeManager), type(uint256).max);
        vm.stopPrank();
    }

    // Deploy core contracts
    function deployCore() internal {
        // Deploy in the correct order based on dependencies
        treasury = new Treasury();
        gymNFT = new GymNFT(address(treasury));

        // Use o DeGymToken real
        DeGymToken dgymToken = new DeGymToken(owner);

        // Armazene também como DGYM_token para outros testes
        DGYM_token = new MockToken("DeGym Token", "DGYM", 18);
        DGYM_token.mint(owner, 1000000 * 10 ** 18);
        DGYM_token.mint(user1, 1000 * 10 ** 18);
        DGYM_token.mint(user2, 1000 * 10 ** 18);

        // Use o StakeManager real com o token DGYM
        stakeManager = new StakeManager(address(dgymToken), address(treasury));

        // Distribua tokens para todos que precisam
        dgymToken.transfer(address(stakeManager), 10000 * 10 ** 18);
        dgymToken.transfer(user1, 1000 * 10 ** 18);
        dgymToken.transfer(user2, 1000 * 10 ** 18);

        gymManager = new GymManager(
            address(gymNFT),
            address(treasury),
            address(stakeManager)
        );

        voucherNFT = new VoucherNFT(
            address(treasury),
            address(gymManager),
            address(gymNFT),
            address(treasury)
        );

        // Fornecer tokens para o VoucherNFT
        dgymToken.transfer(address(voucherNFT), 1000 * 10 ** 18);

        // Aprovar stakeManager para usar os tokens
        vm.startPrank(address(voucherNFT));
        dgymToken.approve(address(stakeManager), type(uint256).max);
        vm.stopPrank();

        // Initialize contracts
        treasury.setGymNFT(address(gymNFT));
        treasury.addAcceptedToken(address(testToken));
        treasury.addAcceptedToken(address(USDT));

        // Setup price parameters
        setupTokenPriceParams();
    }

    // Setup token pricing parameters
    function setupTokenPriceParams() internal {
        treasury.updateTokenPriceParams(
            address(testToken),
            100 * 10 ** 18, // basePrice
            50, // minFactor (50%)
            5 // decayRate (5%)
        );

        treasury.updateTokenPriceParams(
            address(USDT),
            100 * 10 ** 18, // basePrice
            50, // minFactor (50%)
            5 // decayRate (5%)
        );
    }

    // Helper to create a gym
    function createGym(
        address gymOwnerAddress,
        uint8 tier
    ) internal returns (uint256) {
        vm.startPrank(owner);
        uint256 gymId = gymNFT.mintGymNFT(gymOwnerAddress, tier);
        vm.stopPrank();

        vm.startPrank(gymOwnerAddress);
        gymNFT.addAcceptedToken(gymId, address(testToken));
        gymNFT.addAcceptedToken(gymId, address(USDT));
        vm.stopPrank();

        return gymId;
    }

    // Helper to mint vouchers
    function mintVoucher(
        address to,
        uint8 tier,
        uint16 duration,
        int8 timezone
    ) internal returns (uint256) {
        vm.startPrank(to);
        testToken.approve(address(treasury), 1000 * 10 ** 18);
        uint256 voucherId = voucherNFT.mint(
            tier,
            duration,
            timezone,
            address(testToken)
        );
        vm.stopPrank();

        return voucherId;
    }

    // Helper for mocking vouchers in tests
    function setupMockVoucher(
        uint256 tokenId,
        address recipient,
        uint256 gymId
    ) internal {
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
