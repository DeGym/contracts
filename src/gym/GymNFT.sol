// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../treasury/Treasury.sol";
import "../treasury/ITreasury.sol";

/**
 * @title GymNFT
 * @dev NFT representing gym ownership in the DeGym ecosystem
 */
contract GymNFT is ERC721, Ownable {
    // References to other contracts
    ITreasury public treasury;

    // Gym statistics structure
    struct Stats {
        uint256 totalCheckIns;
        uint256 totalDCPReceived;
        uint256 totalRewardsEarned;
        uint256 lastActivityTime;
    }

    // Gym tier information
    struct GymTierInfo {
        uint8 tier;
        uint256 lastTierUpdateTime;
    }

    // Mapping from gymId to tier info
    mapping(uint256 => GymTierInfo) public gymTierInfo;

    // Mapping from gymId to stats
    mapping(uint256 => Stats) public gymStats;

    // Counter for gym IDs
    uint256 private _nextGymId = 1;

    // Adicionando uma nova estrutura para gerenciar tokens aceitos por academia
    struct AcceptedTokens {
        address[] tokens;
        address preferredToken;
    }

    // Mapeamento de academias para seus tokens aceitos
    mapping(uint256 => AcceptedTokens) private gymAcceptedTokens;

    // Mapeamento de academias para balanço de DCP por token aceito
    mapping(uint256 => mapping(address => uint256)) private gymTokenDCPBalance;

    // Events
    event GymNFTCreated(
        uint256 indexed gymId,
        address indexed owner,
        uint8 tier
    );
    event TierUpdated(uint256 indexed gymId, uint8 oldTier, uint8 newTier);
    event DCPReceived(
        uint256 indexed gymId,
        address indexed token,
        uint256 amount
    );
    event DCPRedeemed(
        uint256 indexed gymId,
        address indexed token,
        uint256 amount,
        uint256 rewardAmount
    );
    event TokenAccepted(uint256 indexed gymId, address indexed token);
    event PreferredTokenSet(uint256 indexed gymId, address indexed token);

    /**
     * @dev Constructor
     * @param _treasury Address of the Treasury contract
     */
    constructor(
        address _treasury
    ) ERC721("DeGym Fitness Center", "GYM") Ownable(msg.sender) {
        treasury = ITreasury(_treasury);
    }

    /**
     * @dev Mint a new gym NFT
     * @param owner Address of the gym owner
     * @param tier Initial tier level
     * @return gymId The ID of the newly minted gym NFT
     */
    function mintGymNFT(
        address owner,
        uint8 tier
    ) external onlyOwner returns (uint256 gymId) {
        gymId = _nextGymId++;

        // Mint the NFT
        _mint(owner, gymId);

        // Initialize tier info
        gymTierInfo[gymId] = GymTierInfo({
            tier: tier,
            lastTierUpdateTime: block.timestamp
        });

        // Initialize stats
        gymStats[gymId] = Stats({
            totalCheckIns: 0,
            totalDCPReceived: 0,
            totalRewardsEarned: 0,
            lastActivityTime: block.timestamp
        });

        emit GymNFTCreated(gymId, owner, tier);
        return gymId;
    }

    /**
     * @dev Update the tier of a gym
     * @param gymId ID of the gym
     * @param newTier New tier level
     */
    function updateTier(uint256 gymId, uint8 newTier) external onlyOwner {
        uint8 oldTier = gymTierInfo[gymId].tier;
        gymTierInfo[gymId].tier = newTier;
        gymTierInfo[gymId].lastTierUpdateTime = block.timestamp;

        emit TierUpdated(gymId, oldTier, newTier);
    }

    /**
     * @dev Adds DCP to a gym for a specific token
     * @param gymId ID of the gym
     * @param token Address of the token
     * @param amount Amount of DCP to add
     */
    function addDCP(uint256 gymId, address token, uint256 amount) external {
        require(_ownerOf(gymId) != address(0), "GymNFT: gym does not exist");
        require(
            isTokenAccepted(gymId, token),
            "GymNFT: token not accepted by gym"
        );

        // Adiciona DCP ao balanço específico do token
        gymTokenDCPBalance[gymId][token] += amount;

        // Atualiza as estatísticas gerais
        gymStats[gymId].totalDCPReceived += amount;
        gymStats[gymId].lastActivityTime = block.timestamp;

        emit DCPReceived(gymId, token, amount);
    }

    /**
     * @dev Returns the DCP balance for a specific token
     * @param gymId ID of the gym
     * @param token Address of the token
     * @return Balance of DCP for the specified token
     */
    function getDCPBalance(
        uint256 gymId,
        address token
    ) public view returns (uint256) {
        return gymTokenDCPBalance[gymId][token];
    }

    /**
     * @dev Processes redemption of DCP for rewards
     * @param gymId ID of the gym
     * @param token Address of the token to redeem rewards in
     * @return Amount of tokens the gym owner will receive
     */
    function redeemDCP(
        uint256 gymId,
        address token
    ) external returns (uint256) {
        require(_ownerOf(gymId) != address(0), "GymNFT: gym does not exist");
        require(
            ownerOf(gymId) == msg.sender,
            "GymNFT: caller is not the gym owner"
        );
        require(
            isTokenAccepted(gymId, token),
            "GymNFT: token not accepted by gym"
        );

        uint256 dcpAmount = gymTokenDCPBalance[gymId][token];
        require(dcpAmount > 0, "GymNFT: no DCP balance for this token");

        // Calcula a quantidade de tokens a serem recompensados
        // Este cálculo seria baseado em alguma fórmula definida pelo projeto
        uint256 rewardAmount = calculateReward(dcpAmount, token);

        // Zera o balanço de DCP para este token
        gymTokenDCPBalance[gymId][token] = 0;

        // Processa a recompensa através do Treasury
        treasury.processGymReward(msg.sender, token, rewardAmount);

        // Atualiza as estatísticas
        gymStats[gymId].totalRewardsEarned += rewardAmount;

        emit DCPRedeemed(gymId, token, dcpAmount, rewardAmount);

        return rewardAmount;
    }

    /**
     * @dev Checks if a token is accepted by a gym
     * @param gymId ID of the gym
     * @param token Address of the token
     * @return Whether the token is accepted
     */
    function isTokenAccepted(
        uint256 gymId,
        address token
    ) public view returns (bool) {
        address[] memory tokens = gymAcceptedTokens[gymId].tokens;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == token) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Calculate reward based on DCP amount and token
     * @param dcpAmount Amount of DCP to convert
     * @param token Address of the token
     * @return Amount of tokens to reward
     */
    function calculateReward(
        uint256 dcpAmount,
        address token
    ) internal view returns (uint256) {
        // Esta função implementaria a lógica específica para calcular recompensas
        // Por exemplo, pode usar alguma taxa de conversão ou chamar o Treasury

        // Implementação simplificada para exemplo
        return dcpAmount; // 1:1 conversion for simplicity
    }

    /**
     * @dev Get the current tier of a gym
     * @param gymId ID of the gym
     * @return tier Current tier level
     */
    function getCurrentTier(uint256 gymId) external view returns (uint8 tier) {
        return gymTierInfo[gymId].tier;
    }

    /**
     * @dev Validate if an address is the owner of a gym
     * @param gymId ID of the gym
     * @param addr Address to check
     * @return isOwner True if the address is the owner
     */
    function validateOwnership(
        uint256 gymId,
        address addr
    ) external view returns (bool isOwner) {
        return ownerOf(gymId) == addr;
    }

    /**
     * @dev Get statistics for a gym
     * @param gymId ID of the gym
     * @return stats Gym statistics
     */
    function getStats(
        uint256 gymId
    ) external view returns (Stats memory stats) {
        return gymStats[gymId];
    }

    /**
     * @dev Adicionar um token aceito para uma academia
     * @param gymId ID da academia
     * @param token Endereço do token
     */
    function addAcceptedToken(uint256 gymId, address token) public {
        require(
            ownerOf(gymId) == msg.sender || msg.sender == owner(),
            "Not authorized"
        );
        require(token != address(0), "Invalid token address");
        require(!isTokenAccepted(gymId, token), "Token already accepted");

        // Verificar se o token é aceito pelo treasury
        require(
            treasury.isTokenAccepted(token),
            "Token not accepted by treasury"
        );

        gymAcceptedTokens[gymId].tokens.push(token);

        // Se for o primeiro token, definir como preferencial
        if (
            gymAcceptedTokens[gymId].tokens.length == 1 &&
            gymAcceptedTokens[gymId].preferredToken == address(0)
        ) {
            gymAcceptedTokens[gymId].preferredToken = token;
            emit PreferredTokenSet(gymId, token);
        }

        emit TokenAccepted(gymId, token);
    }

    /**
     * @dev Definir o token preferencial para uma academia
     * @param gymId ID da academia
     * @param token Endereço do token
     */
    function setPreferredToken(uint256 gymId, address token) public {
        require(ownerOf(gymId) == msg.sender, "Not the gym owner");
        require(
            isTokenAccepted(gymId, token),
            "Token not accepted by this gym"
        );

        gymAcceptedTokens[gymId].preferredToken = token;
        emit PreferredTokenSet(gymId, token);
    }

    /**
     * @dev Obter o token preferencial de uma academia
     * @param gymId ID da academia
     * @return address Endereço do token preferencial
     */
    function getPreferredToken(uint256 gymId) public view returns (address) {
        return gymAcceptedTokens[gymId].preferredToken;
    }

    /**
     * @dev Obter o primeiro token aceito por uma academia
     * @param gymId ID da academia
     * @return address Endereço do primeiro token aceito
     */
    function getFirstAcceptedToken(
        uint256 gymId
    ) public view returns (address) {
        address[] memory tokens = gymAcceptedTokens[gymId].tokens;
        if (tokens.length > 0) {
            return tokens[0];
        }
        return address(0);
    }

    /**
     * @dev Obter todos os tokens aceitos por uma academia
     * @param gymId ID da academia
     * @return tokens Array de endereços de tokens aceitos
     */
    function getAcceptedTokens(
        uint256 gymId
    ) public view returns (address[] memory) {
        return gymAcceptedTokens[gymId].tokens;
    }

    /**
     * @dev Returns the number of gyms owned by an address
     * @param owner Address of the owner
     * @return count Number of gyms owned
     */
    function balanceOf(
        address owner
    ) public view virtual override returns (uint256 count) {
        return super.balanceOf(owner);
    }

    /**
     * @dev Recebe DCP durante um check-in e usa o token preferencial da academia
     * @param gymId ID da academia
     * @param amount Quantidade de DCP
     */
    function receiveDCP(uint256 gymId, uint256 amount) external {
        require(_ownerOf(gymId) != address(0), "GymNFT: gym does not exist");

        // Usa o token preferencial da academia ou o primeiro token aceito
        address token = getPreferredToken(gymId);
        if (token == address(0)) {
            token = getFirstAcceptedToken(gymId);
        }

        require(token != address(0), "GymNFT: no accepted token");

        // Adiciona DCP ao balanço do token
        gymTokenDCPBalance[gymId][token] += amount;

        // Atualiza estatísticas
        gymStats[gymId].totalDCPReceived += amount;
        gymStats[gymId].lastActivityTime = block.timestamp;
        gymStats[gymId].totalCheckIns += 1;

        emit DCPReceived(gymId, token, amount);
    }

    /**
     * @dev Retorna o tier atual de uma academia
     * @param gymId ID da academia
     * @return tier Tier atual da academia
     */
    function getTier(uint256 gymId) public view returns (uint8) {
        require(_ownerOf(gymId) != address(0), "GymNFT: gym does not exist");
        return gymTierInfo[gymId].tier;
    }
}
