// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./GymNFT.sol";
import "../treasury/Treasury.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title GymManager
 * @dev Manages gym registrations and operations in the DeGym ecosystem
 */
contract GymManager {
    // References to other contracts
    GymNFT public gymNFT;
    Treasury public treasury;

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

    /**
     * @dev Constructor
     * @param _gymNFT Address of the GymNFT contract
     * @param _treasury Address of the Treasury contract
     */
    constructor(address _gymNFT, address _treasury) {
        gymNFT = GymNFT(_gymNFT);
        treasury = Treasury(_treasury);
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
        require(
            treasury.validateGymStaking(msg.sender),
            "Insufficient staking amount"
        );

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

        // Calculate and validate upgrade fee
        uint256 fee = treasury.calculateUpgradeFee(currentTier, newTier);
        require(
            treasury.validateTokenPayment(msg.sender, fee),
            "Fee payment failed"
        );

        // Update tier
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

    function getRegistrationToken() internal view returns (address) {
        // Usar a função pública do Treasury para obter o primeiro token aceito
        return treasury.getFirstAcceptedToken();
    }
}
