// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/stake/IStakeManager.sol";

/**
 * @title MockStakeManager
 * @dev Mock para StakeManager usado em testes
 */
contract MockStakeManager is IStakeManager {
    // Mapeamento para simular staking
    mapping(address => uint256) public stakedAmounts;

    // Para testes, qualquer um pode passar na validação
    bool public mockValidationResult = true;

    /**
     * @dev Define o resultado da validação para testes
     */
    function setValidationResult(bool result) external {
        mockValidationResult = result;
    }

    /**
     * @dev Simula stake para um endereço
     */
    function mockStake(address staker, uint256 amount) external {
        stakedAmounts[staker] = amount;
    }

    /**
     * @dev Implementação da interface - sempre retorna o valor configurado
     */
    function validateGymStaking(address) external view override returns (bool) {
        return mockValidationResult;
    }

    /**
     * @dev Implementação da interface
     */
    function getStakedAmount(
        address staker
    ) external view override returns (uint256) {
        return stakedAmounts[staker];
    }
}
