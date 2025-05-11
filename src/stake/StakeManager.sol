// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title StakeManager
 * @dev Gerencia o staking de tokens DGYM para validação de academias
 */
contract StakeManager is Ownable, ReentrancyGuard {
    // Token DGYM da DAO
    IERC20 public dgymToken;

    // Quantidade mínima de staking para registro de academias
    uint256 public minimumGymStakingAmount;

    // Mapeamento de staker para quantidade em staking
    mapping(address => uint256) public stakedAmounts;

    // Eventos
    event Staked(address indexed staker, uint256 amount);
    event Unstaked(address indexed staker, uint256 amount);
    event MinimumStakingUpdated(uint256 newAmount);

    /**
     * @dev Construtor
     * @param _dgymToken Endereço do token DGYM
     */
    constructor(address _dgymToken) Ownable(msg.sender) {
        dgymToken = IERC20(_dgymToken);
        minimumGymStakingAmount = 1000 * 10 ** 18; // Default 1000 DGYM
    }

    /**
     * @dev Define a quantidade mínima de staking para academias
     * @param newAmount Nova quantidade mínima
     */
    function setMinimumGymStakingAmount(uint256 newAmount) external onlyOwner {
        require(
            newAmount > 0,
            "StakeManager: amount must be greater than zero"
        );
        minimumGymStakingAmount = newAmount;
        emit MinimumStakingUpdated(newAmount);
    }

    /**
     * @dev Realiza o staking de tokens DGYM
     * @param amount Quantidade a ser colocada em stake
     */
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "StakeManager: amount must be greater than zero");

        // Transfere tokens para o contrato
        dgymToken.transferFrom(msg.sender, address(this), amount);

        // Atualiza o saldo em staking
        stakedAmounts[msg.sender] += amount;

        emit Staked(msg.sender, amount);
    }

    /**
     * @dev Retira tokens do staking
     * @param amount Quantidade a ser retirada
     */
    function unstake(uint256 amount) external nonReentrant {
        require(amount > 0, "StakeManager: amount must be greater than zero");
        require(
            stakedAmounts[msg.sender] >= amount,
            "StakeManager: insufficient staked amount"
        );

        // Atualiza o saldo em staking
        stakedAmounts[msg.sender] -= amount;

        // Transfere tokens de volta para o staker
        dgymToken.transfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    /**
     * @dev Valida se um endereço tem stake suficiente para registro de academia
     * @param staker Endereço a ser validado
     * @return valid Se o staking é válido
     */
    function validateGymStaking(address staker) external view returns (bool) {
        return stakedAmounts[staker] >= minimumGymStakingAmount;
    }

    /**
     * @dev Obtém o saldo em staking de um endereço
     * @param staker Endereço do staker
     * @return amount Quantidade em staking
     */
    function getStakedAmount(address staker) external view returns (uint256) {
        return stakedAmounts[staker];
    }
}
