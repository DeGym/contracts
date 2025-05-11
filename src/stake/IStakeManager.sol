// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IStakeManager
 * @dev Interface para o contrato StakeManager
 */
interface IStakeManager {
    /**
     * @dev Valida se um endereço tem stake suficiente para registro de academia
     * @param staker Endereço a ser validado
     * @return valid Se o staking é válido
     */
    function validateGymStaking(address staker) external view returns (bool);

    /**
     * @dev Obtém o saldo em staking de um endereço
     * @param staker Endereço do staker
     * @return amount Quantidade em staking
     */
    function getStakedAmount(address staker) external view returns (uint256);
}
