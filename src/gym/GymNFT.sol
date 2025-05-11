// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../treasury/Treasury.sol";

/**
 * @title GymNFT
 * @dev NFT representing gym ownership in the DeGym ecosystem
 */
contract GymNFT is ERC721, Ownable {
    // References to other contracts
    Treasury public treasury;

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
        uint256 dcpBalance;
        uint256 lastTierUpdateTime;
    }

    // Mapping from gymId to tier info
    mapping(uint256 => GymTierInfo) public gymTierInfo;

    // Mapping from gymId to stats
    mapping(uint256 => Stats) public gymStats;

    // Counter for gym IDs
    uint256 private _nextGymId = 1;

    // Events
    event GymNFTCreated(
        uint256 indexed gymId,
        address indexed owner,
        uint8 tier
    );
    event TierUpdated(uint256 indexed gymId, uint8 oldTier, uint8 newTier);
    event DCPReceived(
        uint256 indexed gymId,
        uint256 amount,
        uint256 rewardAmount
    );
    event DCPRedeemed(
        uint256 indexed gymId,
        uint256 amount,
        uint256 rewardAmount
    );

    /**
     * @dev Constructor
     * @param _treasury Address of the Treasury contract
     */
    constructor(
        address _treasury
    ) ERC721("DeGym Fitness Center", "GYM") Ownable(msg.sender) {
        treasury = Treasury(_treasury);
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
            dcpBalance: 0,
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
     * @dev Receive DCP from check-ins
     * @param gymId ID of the gym
     * @param amount Amount of DCP
     */
    function receiveDCP(uint256 gymId, uint256 amount) external {
        // Only authorized contracts should call this
        // In production, add appropriate access control

        // Update DCP balance
        gymTierInfo[gymId].dcpBalance += amount;

        // Calculate reward based on tier
        uint8 tier = gymTierInfo[gymId].tier;
        uint256 rewardAmount = calculateReward(amount, tier);

        // Update stats
        Stats storage stats = gymStats[gymId];
        stats.totalCheckIns += 1;
        stats.totalDCPReceived += amount;
        stats.totalRewardsEarned += rewardAmount;
        stats.lastActivityTime = block.timestamp;

        // Process reward through treasury
        treasury.processGymReward(ownerOf(gymId), rewardAmount);

        emit DCPReceived(gymId, amount, rewardAmount);
    }

    /**
     * @dev Redeem DCP for rewards
     * @param gymId ID of the gym
     * @param amount Amount of DCP to redeem
     */
    function redeemDCP(uint256 gymId, uint256 amount) external {
        // Verify caller is the gym owner
        require(ownerOf(gymId) == msg.sender, "Not the gym owner");

        // Validate balance
        require(
            gymTierInfo[gymId].dcpBalance >= amount,
            "Insufficient DCP balance"
        );

        // Update balance
        gymTierInfo[gymId].dcpBalance -= amount;

        // Calculate reward
        uint8 tier = gymTierInfo[gymId].tier;
        uint256 rewardAmount = calculateReward(amount, tier);

        // Process redemption through treasury
        treasury.processRedemption(gymId, amount);

        emit DCPRedeemed(gymId, amount, rewardAmount);
    }

    /**
     * @dev Calculate reward based on amount and tier
     * @param amount Amount of DCP
     * @param tier Tier level
     * @return rewardAmount Calculated reward
     */
    function calculateReward(
        uint256 amount,
        uint8 tier
    ) public pure returns (uint256 rewardAmount) {
        // Simple linear model: higher tiers get more rewards per DCP
        return (amount * (100 + tier)) / 100;
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
}
