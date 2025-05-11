// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./GymNFT.sol";
import "../treasury/Treasury.sol";
import "../stake/IStakeManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title GymManager
 * @dev Manages gym registrations and operations in the DeGym ecosystem
 */
contract GymManager {
    // References to other contracts
    GymNFT public gymNFT;
    Treasury public treasury;
    IStakeManager public stakeManager;

    // Gym details structure
    struct Gym {
        string name;
        uint256[2] location; // [latitude, longitude]
        string details;
        bool isActive;
        uint256 registrationTime;
    }

    // Mapping from gymId to Gym details
    mapping(uint256 => Gym) public gyms;

    // Events
    event GymRegistered(
        uint256 indexed gymId,
        string name,
        uint256[2] location
    );
    event GymInfoUpdated(
        uint256 indexed gymId,
        string name,
        uint256[2] location
    );

    // Added for the new validateGymStaking function
    address public preferredToken;
    uint256 public stakingAmount;

    // Contract owner with admin rights
    address public owner;

    /**
     * @dev Constructor
     * @param _gymNFT Address of the GymNFT contract
     * @param _treasury Address of the Treasury contract
     * @param _stakeManager Address of the StakeManager contract
     */
    constructor(address _gymNFT, address _treasury, address _stakeManager) {
        gymNFT = GymNFT(_gymNFT);
        treasury = Treasury(_treasury);
        stakeManager = IStakeManager(_stakeManager);
        stakingAmount = 1000 * 10 ** 18; // Valor padrão
        owner = msg.sender; // Set deployer as owner
    }

    /**
     * @dev Register a new gym
     * @param name Name of the gym
     * @param location Location coordinates [latitude, longitude]
     * @param tier Tier level for the gym
     * @return gymId The ID of the newly registered gym
     */
    function registerGym(
        string memory name,
        uint256[2] memory location,
        uint8 tier
    ) external returns (uint256 gymId) {
        // Validate that the user has sufficient staking
        require(validateGymStaking(msg.sender), "Insufficient staking amount");

        // Mint GymNFT
        gymId = gymNFT.mintGymNFT(msg.sender, tier);

        // Store gym details
        gyms[gymId] = Gym({
            name: name,
            location: location,
            details: "",
            isActive: true,
            registrationTime: block.timestamp
        });

        emit GymRegistered(gymId, name, location);
        return gymId;
    }

    /**
     * @dev Update gym information
     * @param gymId ID of the gym to update
     * @param name New name for the gym
     * @param location New location coordinates
     * @param details Additional details about the gym
     */
    function updateGymInfo(
        uint256 gymId,
        string memory name,
        uint256[2] memory location,
        string memory details
    ) external {
        // Validate ownership
        require(
            gymNFT.validateOwnership(gymId, msg.sender),
            "Not the gym owner"
        );

        // Update gym details
        Gym storage gym = gyms[gymId];
        gym.name = name;
        gym.location = location;
        gym.details = details;

        emit GymInfoUpdated(gymId, name, location);
    }

    /**
     * @dev Request a tier upgrade for a gym
     * @param gymId ID of the gym
     * @param newTier New tier level
     */
    function requestTierUpdate(uint256 gymId, uint8 newTier) external {
        // Validate ownership
        require(
            gymNFT.validateOwnership(gymId, msg.sender),
            "Not the gym owner"
        );

        // Get current tier
        uint8 currentTier = gymNFT.getCurrentTier(gymId);

        // Garantir que o novo tier é maior que o atual
        require(newTier > currentTier, "New tier must be higher than current");

        // Validar staking adequado para o novo tier
        require(validateGymStaking(msg.sender), "Insufficient staking amount");

        // Update tier sem cobrar taxa
        gymNFT.updateTier(gymId, newTier);
    }

    /**
     * @dev Validate if a gym is active and registered
     * @param gymId ID of the gym to validate
     * @return isValid True if the gym is valid
     */
    function validateGym(uint256 gymId) external view returns (bool isValid) {
        return gyms[gymId].isActive;
    }

    /**
     * @dev Get statistics for a gym
     * @param gymId ID of the gym
     * @return stats Gym statistics
     */
    function getGymStats(
        uint256 gymId
    ) external view returns (GymNFT.Stats memory stats) {
        return gymNFT.getStats(gymId);
    }

    /**
     * @dev Get nearby gyms based on location
     * @param lat Latitude
     * @param long Longitude
     * @param radius Search radius
     * @return Array of gym IDs
     */
    function getNearbyGyms(
        uint256 lat,
        uint256 long,
        uint256 radius
    ) external view returns (uint256[] memory) {
        // Implementation would require off-chain components or complex on-chain logic
        // This is a placeholder
        uint256[] memory result = new uint256[](0);
        return result;
    }

    /**
     * @dev Define o endereço do contrato StakeManager
     * @param _stakeManager Endereço do contrato StakeManager
     */
    function setStakeManager(address _stakeManager) external {
        require(_isAuthorized(msg.sender), "Not authorized");
        stakeManager = IStakeManager(_stakeManager);
    }

    /**
     * @dev Checks if an address is authorized for administrative functions
     * @param addr Address to check
     * @return True if the address is authorized
     */
    function _isAuthorized(address addr) internal view returns (bool) {
        // For simplicity, only the contract owner is authorized
        // In a real implementation, this could check against a role system
        return addr == owner;
    }

    // Substitua a validação temporária pela integração real com StakeManager
    function validateGymStaking(address staker) internal view returns (bool) {
        if (address(stakeManager) != address(0)) {
            return stakeManager.validateGymStaking(staker);
        }
        // Fallback para desenvolvimento, pode ser removido em produção
        return true;
    }
}
