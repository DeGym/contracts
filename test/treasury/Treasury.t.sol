// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
    address public gymOwner = address(0x789);

    // Test values
    uint256 constant BASE_PRICE = 10 * 10 ** 18;
    uint256 constant MIN_FACTOR = 50; // 50%
    uint256 constant DECAY_RATE = 5; // 5%

    function setUp() public {
        vm.startPrank(owner);

        // Deploy contracts
        mockToken = new MockToken();
        secondToken = new MockToken();
        treasury = new Treasury();

        // Transfer tokens to user
        mockToken.transfer(user, 1000 * 10 ** 18);
        secondToken.transfer(user, 1000 * 10 ** 18);
        mockToken.transfer(gymOwner, 2000 * 10 ** 18);

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
        assertTrue(treasury.isTokenAccepted(address(mockToken)));

        // Remove token
        treasury.removeAcceptedToken(address(mockToken));

        // Token should no longer be accepted
        assertFalse(treasury.acceptedTokens(address(mockToken)));
        assertFalse(treasury.isTokenAccepted(address(mockToken)));

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

    function testUpdateTokenPriceParams() public {
        vm.startPrank(owner);

        // Add token to accepted tokens
        treasury.addAcceptedToken(address(mockToken));

        // Set price parameters
        treasury.updateTokenPriceParams(
            address(mockToken),
            BASE_PRICE,
            MIN_FACTOR,
            DECAY_RATE
        );

        // Verify updated parameters
        (uint256 basePrice, uint256 minFactor, uint256 decayRate) = treasury
            .getTokenPriceParams(address(mockToken));

        assertEq(basePrice, BASE_PRICE, "Base price should match");
        assertEq(minFactor, MIN_FACTOR, "Min factor should match");
        assertEq(decayRate, DECAY_RATE, "Decay rate should match");

        // Change parameters
        uint256 newBasePrice = 20 * 10 ** 18;
        uint256 newMinFactor = 60;
        uint256 newDecayRate = 10;

        treasury.updateTokenPriceParams(
            address(mockToken),
            newBasePrice,
            newMinFactor,
            newDecayRate
        );

        // Verify new parameters
        (basePrice, minFactor, decayRate) = treasury.getTokenPriceParams(
            address(mockToken)
        );

        assertEq(basePrice, newBasePrice, "New base price should match");
        assertEq(minFactor, newMinFactor, "New min factor should match");
        assertEq(decayRate, newDecayRate, "New decay rate should match");

        vm.stopPrank();
    }

    function testSetDefaultPriceParams() public {
        vm.startPrank(owner);

        // Update default parameters
        uint256 newDefaultBase = 200 * 10 ** 18;
        uint256 newDefaultFactor = 70;
        uint256 newDefaultDecay = 15;

        treasury.setDefaultPriceParams(
            newDefaultBase,
            newDefaultFactor,
            newDefaultDecay
        );

        // Verify default parameters were updated
        assertEq(
            treasury.defaultBaseMonthlyPrice(),
            newDefaultBase,
            "Default base price should match"
        );
        assertEq(
            treasury.defaultMinPriceFactor(),
            newDefaultFactor,
            "Default min factor should match"
        );
        assertEq(
            treasury.defaultPriceDecayRate(),
            newDefaultDecay,
            "Default decay rate should match"
        );

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

        // Set token price with reasonable parameters
        uint256 basePrice = 10 * 10 ** 18; // 10 tokens
        uint256 minFactor = 50; // 50%
        uint256 decayRate = 5; // 5%

        treasury.updateTokenPriceParams(
            address(mockToken),
            basePrice,
            minFactor,
            decayRate
        );

        // Test price calculations com argumentos razoáveis
        uint8 tier = 1; // Tier pequeno
        uint256 duration = 30; // Duração razoável

        // Calcular preço
        uint256 voucherPrice = treasury.calculatePrice(
            address(mockToken),
            tier,
            duration
        );

        // Verificar que o preço é razoável
        assertTrue(voucherPrice > 0, "Voucher price should be positive");

        // Verificar que tiers maiores custam mais
        uint256 higherTierPrice = treasury.calculatePrice(
            address(mockToken),
            tier + 1, // Um tier acima
            duration
        );

        assertTrue(
            higherTierPrice > voucherPrice,
            "Higher tier should cost more"
        );

        vm.stopPrank();
    }

    function testIsTokenAccepted() public {
        vm.startPrank(owner);

        // Add first token
        treasury.addAcceptedToken(address(mockToken));

        // Validate tokens
        assertTrue(
            treasury.isTokenAccepted(address(mockToken)),
            "First token should be accepted"
        );
        assertFalse(
            treasury.isTokenAccepted(address(secondToken)),
            "Second token should not be accepted"
        );

        // Add second token
        treasury.addAcceptedToken(address(secondToken));

        // Both should now be accepted
        assertTrue(
            treasury.isTokenAccepted(address(mockToken)),
            "First token should still be accepted"
        );
        assertTrue(
            treasury.isTokenAccepted(address(secondToken)),
            "Second token should now be accepted"
        );

        vm.stopPrank();
    }

    function testValidateGymStaking() public {
        vm.startPrank(gymOwner);

        // Initially should fail as token is not accepted
        vm.expectRevert("Treasury: token not accepted");
        treasury.validateGymStaking(
            gymOwner,
            address(mockToken),
            1000 * 10 ** 18
        );

        vm.stopPrank();

        // Add token as accepted
        vm.prank(owner);
        treasury.addAcceptedToken(address(mockToken));

        // Set approval for Treasury
        vm.prank(gymOwner);
        mockToken.approve(address(treasury), 2000 * 10 ** 18);

        // Now validation should pass
        bool isValid = treasury.validateGymStaking(
            gymOwner,
            address(mockToken),
            1000 * 10 ** 18
        );
        assertTrue(
            isValid,
            "Staking should be valid with sufficient funds and approval"
        );

        // Test with insufficient amount
        isValid = treasury.validateGymStaking(
            gymOwner,
            address(mockToken),
            3000 * 10 ** 18
        );
        assertFalse(
            isValid,
            "Staking should be invalid with insufficient funds"
        );
    }

    function testProcessGymReward() public {
        vm.startPrank(owner);

        console.log("Step 1: Setting up test");

        // Add token as accepted
        treasury.addAcceptedToken(address(mockToken));

        // Transfer tokens to treasury
        mockToken.transfer(address(treasury), 100 * 10 ** 18);

        // Como owner, defina o owner como o endereço do GymNFT para que apenas ele possa processar recompensas
        address mockGymNFT = address(0xABCD);
        treasury.setGymNFT(mockGymNFT);
        console.log("GymNFT set to:", mockGymNFT);

        vm.stopPrank();

        // Armazenar saldo inicial do gymOwner
        uint256 initialBalance = mockToken.balanceOf(gymOwner);
        console.log("Initial gym owner balance:", initialBalance);

        // O principal problema: não estamos verificando a chamada não autorizada corretamente
        // Vamos usar vm.expectRevert para garantir que a chamada reverta
        console.log("Step 2: Testing unauthorized call (should fail)");
        vm.prank(user); // user não é o GymNFT

        // Esperar que a chamada reverta com uma mensagem específica
        vm.expectRevert("Treasury: caller is not GymNFT");
        treasury.processGymReward(gymOwner, address(mockToken), 50 * 10 ** 18);

        // Agora testamos com chamador autorizado (deve suceder)
        console.log("Step 3: Testing authorized call (should succeed)");
        vm.prank(mockGymNFT);
        treasury.processGymReward(gymOwner, address(mockToken), 50 * 10 ** 18);

        // Verificar se o gymOwner recebeu os tokens
        uint256 finalBalance = mockToken.balanceOf(gymOwner);
        console.log("Final gym owner balance:", finalBalance);

        assertEq(
            finalBalance - initialBalance,
            50 * 10 ** 18,
            "Gym owner should receive correct reward amount"
        );
    }
}
