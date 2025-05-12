// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ITreasury
 * @dev Interface para o contrato Treasury
 */
interface ITreasury {
    /**
     * @dev Verifica se um token é aceito pelo treasury
     * @param token Endereço do token a ser verificado
     * @return bool Verdadeiro se o token for aceito
     */
    function isTokenAccepted(address token) external view returns (bool);

    /**
     * @dev Calcula o preço de um voucher
     * @param token Endereço do token a ser usado
     * @param tier Nível do voucher
     * @param duration Duração do voucher em dias
     * @return price Preço calculado
     */
    function calculatePrice(
        address token,
        uint8 tier,
        uint256 duration
    ) external view returns (uint256 price);

    /**
     * @dev Adiciona um token à lista de tokens aceitos
     * @param token Endereço do token
     */
    function addAcceptedToken(address token) external;

    /**
     * @dev Valida se um endereço fez staking suficiente para registro de academia
     * @param staker Endereço a ser validado
     * @param token Token usado para staking
     * @param amount Quantidade de tokens em staking
     * @return valid Se o staking é válido
     */
    function validateGymStaking(
        address staker,
        address token,
        uint256 amount
    ) external view returns (bool valid);

    /**
     * @dev Processa recompensas para donos de academias
     * @param recipient Endereço do dono da academia
     * @param token Endereço do token para recompensa
     * @param dcpAmount Quantidade da recompensa
     */
    function processGymReward(
        address recipient,
        address token,
        uint256 dcpAmount
    ) external;
}
