// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../gym/GymNFT.sol";
import "./ITreasury.sol";

/**
 * @title Treasury
 * @dev Manages tokens and fees for the DeGym platform
 */
contract Treasury is Ownable, ReentrancyGuard, ITreasury {
    using SafeERC20 for IERC20;

    // Pausabilidade para emergências
    bool public paused;

    // Eventos para pausabilidade
    event Paused(address account);
    event Unpaused(address account);

    // Estrutura para parâmetros de preço específicos por token
    struct PriceParams {
        uint256 baseMonthlyPrice; // Preço base mensal para Tier 1
        uint256 minPriceFactor; // Fator mínimo de preço (percentual do preço base)
        uint256 priceDecayRate; // Taxa de decaimento de preço por duração
        bool initialized; // Flag para verificar se os parâmetros foram inicializados
    }

    // Accepted tokens for payment
    mapping(address => bool) public acceptedTokens;

    // Voucher prices per accepted token
    mapping(address => uint256) public voucherPrices;

    // Parâmetros de preço por token
    mapping(address => PriceParams) public tokenPriceParams;

    // Minimum staking amount required for gym registration
    uint256 public minimumGymStakingAmount;

    // Reference to GymNFT contract
    GymNFT public gymNFT;

    // Lista de tokens aceitos pelo Treasury
    address[] public acceptedTokenList;

    // Valores padrão para novos tokens (podem ser alterados pelo owner)
    uint256 public defaultBaseMonthlyPrice = 100 * 10 ** 18;
    uint256 public defaultMinPriceFactor = 50; // 50%
    uint256 public defaultPriceDecayRate = 5; // 5%

    // Events
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    event VoucherPriceUpdated(address indexed token, uint256 price);
    event MinimumStakingUpdated(uint256 newAmount);
    event PaymentReceived(address indexed token, uint256 amount, address from);
    event PaymentSent(address indexed token, uint256 amount, address to);
    event Withdrawal(address indexed token, uint256 amount, address to);
    event GymRewardProcessed(
        address indexed gymOwner,
        address indexed token,
        uint256 amount
    );
    event TokenPriceParamsUpdated(
        address indexed token,
        uint256 basePrice,
        uint256 minFactor,
        uint256 decayRate
    );
    event DefaultPriceParamsUpdated(
        uint256 basePrice,
        uint256 minFactor,
        uint256 decayRate
    );

    /**
     * @dev Modificador para funções que só podem ser executadas quando não pausado
     */
    modifier whenNotPaused() {
        require(!paused, "Treasury: paused");
        _;
    }

    /**
     * @dev Modificador para funções que só podem ser executadas quando pausado
     */
    modifier whenPaused() {
        require(paused, "Treasury: not paused");
        _;
    }

    /**
     * @dev Pausa o contrato
     */
    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @dev Despausa o contrato
     */
    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /**
     * @dev Constructor
     */
    constructor() Ownable(msg.sender) {
        minimumGymStakingAmount = 1000 * 10 ** 18; // Default 1000 tokens needed for gym registration
    }

    /**
     * @dev Sets the default price parameters for new tokens
     * @param basePrice Default base monthly price
     * @param minFactor Default minimum price factor (percentage)
     * @param decayRate Default price decay rate (percentage)
     */
    function setDefaultPriceParams(
        uint256 basePrice,
        uint256 minFactor,
        uint256 decayRate
    ) external onlyOwner {
        defaultBaseMonthlyPrice = basePrice;
        defaultMinPriceFactor = minFactor;
        defaultPriceDecayRate = decayRate;

        emit DefaultPriceParamsUpdated(basePrice, minFactor, decayRate);
    }

    /**
     * @dev Sets the minimum staking amount required for gym registration
     * @param _amount New minimum amount
     */
    function setMinimumGymStakingAmount(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Treasury: amount must be greater than zero");
        minimumGymStakingAmount = _amount;
        emit MinimumStakingUpdated(_amount);
    }

    /**
     * @dev Adds a token to the list of accepted tokens
     * @param tokenAddress Address of the token to be added
     */
    function addAcceptedToken(
        address tokenAddress
    ) external override onlyOwner whenNotPaused {
        require(tokenAddress != address(0), "Treasury: invalid token address");
        require(
            !acceptedTokens[tokenAddress],
            "Treasury: token already accepted"
        );

        acceptedTokens[tokenAddress] = true;
        acceptedTokenList.push(tokenAddress);

        // Inicializar parâmetros de preço com valores padrão
        tokenPriceParams[tokenAddress] = PriceParams({
            baseMonthlyPrice: defaultBaseMonthlyPrice,
            minPriceFactor: defaultMinPriceFactor,
            priceDecayRate: defaultPriceDecayRate,
            initialized: true
        });

        // Definir preço base para voucherPrices também para compatibilidade
        voucherPrices[tokenAddress] = defaultBaseMonthlyPrice;

        emit TokenAdded(tokenAddress);
        emit TokenPriceParamsUpdated(
            tokenAddress,
            defaultBaseMonthlyPrice,
            defaultMinPriceFactor,
            defaultPriceDecayRate
        );
    }

    /**
     * @dev Updates price parameters for a specific token
     * @param tokenAddress Address of the token
     * @param basePrice Base monthly price
     * @param minFactor Minimum price factor (percentage)
     * @param decayRate Price decay rate (percentage)
     */
    function updateTokenPriceParams(
        address tokenAddress,
        uint256 basePrice,
        uint256 minFactor,
        uint256 decayRate
    ) external onlyOwner {
        require(acceptedTokens[tokenAddress], "Treasury: token not accepted");

        tokenPriceParams[tokenAddress].baseMonthlyPrice = basePrice;
        tokenPriceParams[tokenAddress].minPriceFactor = minFactor;
        tokenPriceParams[tokenAddress].priceDecayRate = decayRate;

        // Atualizar voucherPrices para compatibilidade
        voucherPrices[tokenAddress] = basePrice;

        emit TokenPriceParamsUpdated(
            tokenAddress,
            basePrice,
            minFactor,
            decayRate
        );
    }

    /**
     * @dev Removes a token from the list of accepted tokens
     * @param tokenAddress Address of the token to be removed
     */
    function removeAcceptedToken(address tokenAddress) external onlyOwner {
        require(acceptedTokens[tokenAddress], "Treasury: token not accepted");

        acceptedTokens[tokenAddress] = false;
        uint256 length = acceptedTokenList.length;
        for (uint256 i = 0; i < length; i++) {
            if (acceptedTokenList[i] == tokenAddress) {
                acceptedTokenList[i] = acceptedTokenList[length - 1];
                acceptedTokenList.pop();
                break;
            }
        }
        emit TokenRemoved(tokenAddress);
    }

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
    ) public view returns (uint256 price) {
        require(acceptedTokens[token], "Token not accepted");
        require(tier > 0, "Treasury: tier must be greater than zero");
        require(duration > 0, "Treasury: duration must be greater than zero");

        // Obter parâmetros específicos para este token
        PriceParams storage params = tokenPriceParams[token];

        // Verificar se os parâmetros foram inicializados
        if (!params.initialized) {
            // Fallback para valores padrão (não deve acontecer se addAcceptedToken for chamado corretamente)
            return (defaultBaseMonthlyPrice * tier * duration) / 30;
        }

        // Implementar a fórmula de preço conforme documentação:
        // Price = max(B_P×(1−D_R×(30/D−1)),M_P×B_P)×T×(30/D)

        uint256 durationFactor;
        if (duration >= 30) {
            durationFactor = (30 * 1e18) / duration; // Usando 1e18 para precisão em cálculos
        } else {
            durationFactor = 1e18; // Para duração menor que 30 dias, sem desconto
        }

        uint256 decayDiscount = (params.priceDecayRate *
            (durationFactor - 1e18)) / 100; // D_R×(30/D−1)
        uint256 discountedPrice = (params.baseMonthlyPrice *
            (1e18 - decayDiscount)) / 1e18; // B_P×(1−D_R×(30/D−1))

        uint256 minPrice = (params.baseMonthlyPrice * params.minPriceFactor) /
            100; // M_P×B_P

        // Escolhendo o máximo entre o preço com desconto e o preço mínimo
        uint256 finalBasePrice = discountedPrice > minPrice
            ? discountedPrice
            : minPrice;

        // Multiplicando pelo tier e pelo fator de duração
        price = (finalBasePrice * tier * durationFactor) / 1e18;

        return price;
    }

    /**
     * @dev Verifica se um token é aceito pelo treasury
     * @param token Endereço do token a ser verificado
     * @return bool Verdadeiro se o token for aceito
     */
    function isTokenAccepted(address token) public view returns (bool) {
        return acceptedTokens[token];
    }

    /**
     * @dev Obtém a lista completa de tokens aceitos
     * @return tokens Lista de endereços de tokens aceitos
     */
    function getAcceptedTokens() public view returns (address[] memory) {
        return acceptedTokenList;
    }

    /**
     * @dev Define o GymNFT contract
     * @param _gymNFT Endereço do contrato GymNFT
     */
    function setGymNFT(address _gymNFT) external onlyOwner {
        require(_gymNFT != address(0), "Treasury: invalid GymNFT address");
        gymNFT = GymNFT(_gymNFT);
    }

    /**
     * @dev Withdraws tokens from the treasury (only owner)
     * @param tokenAddress Address of the token to be withdrawn
     * @param to Destination address
     * @param amount Amount to be withdrawn
     */
    function withdrawToken(
        address tokenAddress,
        address to,
        uint256 amount
    ) external nonReentrant onlyOwner {
        require(to != address(0), "Treasury: invalid destination address");
        require(amount > 0, "Treasury: amount must be greater than zero");

        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance >= amount, "Treasury: insufficient balance");

        token.safeTransfer(to, amount);
        emit Withdrawal(tokenAddress, amount, to);
    }

    /**
     * @dev Returns the balance of a specific token in the treasury
     * @param tokenAddress Address of the token
     * @return balance Balance of the token
     */
    function getTokenBalance(
        address tokenAddress
    ) external view returns (uint256 balance) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    /**
     * @dev Get price parameters for a specific token
     * @param token Address of the token
     * @return basePrice Base monthly price
     * @return minFactor Minimum price factor (percentage)
     * @return decayRate Price decay rate (percentage)
     */
    function getTokenPriceParams(
        address token
    )
        external
        view
        returns (uint256 basePrice, uint256 minFactor, uint256 decayRate)
    {
        require(acceptedTokens[token], "Token not accepted");

        PriceParams storage params = tokenPriceParams[token];
        return (
            params.baseMonthlyPrice,
            params.minPriceFactor,
            params.priceDecayRate
        );
    }

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
    ) external view returns (bool valid) {
        // Verificar se o token é aceito
        require(acceptedTokens[token], "Treasury: token not accepted");

        // Obter dados do token
        IERC20 tokenContract = IERC20(token);

        // Verificar se o staker tem o saldo suficiente
        uint256 balance = tokenContract.balanceOf(staker);

        // Verificar se o staker tem permissão para o Treasury gastar seus tokens
        uint256 allowance = tokenContract.allowance(staker, address(this));

        // Verificar se atende aos requisitos mínimos
        return
            balance >= amount &&
            allowance >= amount &&
            amount >= minimumGymStakingAmount;
    }

    /**
     * @dev Processa recompensas para academias com base no DCP acumulado
     * @param recipient Endereço do destinatário das recompensas
     * @param token Endereço do token para recompensa
     * @param dcpAmount Quantidade de DCP a ser convertida em tokens
     */
    function processGymReward(
        address recipient,
        address token,
        uint256 dcpAmount
    ) external {
        require(
            msg.sender == address(gymNFT),
            "Treasury: Only GymNFT can call this function"
        );
        require(isTokenAccepted(token), "Treasury: Token not accepted");

        // Calcular a quantidade de tokens com base no DCP (implemente sua lógica aqui)
        uint256 tokenAmount = calculatePrice(token, 1, 30);

        // Transferir tokens para o destinatário
        IERC20(token).safeTransfer(recipient, tokenAmount);
    }
}
