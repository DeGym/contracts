// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/gym/GymManager.sol";
import "../../src/gym/GymNFT.sol";
import "../../src/treasury/Treasury.sol";
import "../../src/stake/StakeManager.sol";
import "../../src/stake/IStakeManager.sol";
import "../mocks/MockToken.sol";

contract GymManagerStakeIntegrationTest is Test {
    GymManager public gymManager;
    GymNFT public gymNFT;
    Treasury public treasury;
    StakeManager public stakeManager;

    // Tokens padronizados para testes
    MockToken public DGYM;
    MockToken public USDT;

    address public owner;
    address public user;

    function setUp() public {
        owner = address(this);
        user = address(0x123);

        // Deploy tokens para testes
        DGYM = new MockToken("DeGym Token", "DGYM", 18);
        USDT = new MockToken("Tether USD", "USDT", 6);

        // Mint tokens para testes
        DGYM.mint(owner, 1000000 * 10 ** 18);
        DGYM.mint(user, 10000 * 10 ** 18);
        USDT.mint(owner, 1000000 * 10 ** 6);
        USDT.mint(user, 10000 * 10 ** 6);

        // Deploy contratos reais
        treasury = new Treasury();
        gymNFT = new GymNFT(address(treasury));
        stakeManager = new StakeManager(address(DGYM));

        // Deploy GymManager com dependências
        gymManager = new GymManager(
            address(gymNFT),
            address(treasury),
            address(0) // Começar sem StakeManager
        );

        // Dar permissões ao gymManager
        gymNFT.transferOwnership(address(gymManager));

        // Configurar USDT como token aceito
        treasury.addAcceptedToken(address(USDT));

        // Configurar parâmetros de preço para USDT
        treasury.updateTokenPriceParams(
            address(USDT),
            10 * 10 ** 6, // preço base
            50, // minFactor (50%)
            5 // decayRate (5%)
        );
    }

    function testSetStakeManager() public {
        // Inicialmente não deve haver StakeManager definido
        assertEq(address(0), address(gymManager.stakeManager()));

        // Definir StakeManager
        gymManager.setStakeManager(address(stakeManager));

        // Verificar se StakeManager está definido
        assertEq(address(stakeManager), address(gymManager.stakeManager()));
    }

    function testRegisterGymWithoutStakeManager() public {
        // Registrar academia sem StakeManager
        // Isso deve funcionar porque o fallback retorna true
        uint256 gymId = gymManager.registerGym(
            "Test Gym",
            [uint256(12345), uint256(67890)],
            1
        );

        // Verificar se a academia foi registrada
        assertTrue(gymId > 0);
    }

    function testRegisterGymWithStakeManager() public {
        // Definir StakeManager
        gymManager.setStakeManager(address(stakeManager));

        // Tentar registrar sem staking (deve falhar)
        vm.expectRevert("Insufficient staking amount");
        gymManager.registerGym(
            "Failed Gym",
            [uint256(12345), uint256(67890)],
            1
        );

        // Fazer stake com DGYM para passar na validação
        vm.startPrank(user);
        DGYM.approve(address(stakeManager), 2000 * 10 ** 18);
        stakeManager.stake(2000 * 10 ** 18);
        vm.stopPrank();

        // Verificar saldo de staking
        assertGe(
            stakeManager.getStakedAmount(user),
            stakeManager.minimumGymStakingAmount()
        );

        // Agora deve conseguir registrar a academia
        vm.prank(user);
        uint256 gymId = gymManager.registerGym(
            "Success Gym",
            [uint256(12345), uint256(67890)],
            1
        );

        // Verificar se a academia foi registrada
        assertTrue(gymId > 0);
    }

    function testUpdateMinimumStakingAmount() public {
        // Definir StakeManager
        gymManager.setStakeManager(address(stakeManager));

        // Atualizar quantidade mínima de stake
        uint256 newAmount = 5000 * 10 ** 18;
        stakeManager.setMinimumGymStakingAmount(newAmount);

        // Verificar se foi atualizado
        assertEq(stakeManager.minimumGymStakingAmount(), newAmount);

        // Fazer stake insuficiente
        vm.startPrank(user);
        DGYM.approve(address(stakeManager), 3000 * 10 ** 18);
        stakeManager.stake(3000 * 10 ** 18);
        vm.stopPrank();

        // Tentar registrar (deve falhar)
        vm.prank(user);
        vm.expectRevert("Insufficient staking amount");
        gymManager.registerGym(
            "Failed Gym",
            [uint256(12345), uint256(67890)],
            1
        );

        // Completar stake para atingir o mínimo
        vm.startPrank(user);
        DGYM.approve(address(stakeManager), 2000 * 10 ** 18);
        stakeManager.stake(2000 * 10 ** 18);
        vm.stopPrank();

        // Agora deve conseguir registrar
        vm.prank(user);
        uint256 gymId = gymManager.registerGym(
            "Success Gym",
            [uint256(12345), uint256(67890)],
            1
        );

        // Verificar se a academia foi registrada
        assertTrue(gymId > 0);
    }
}
