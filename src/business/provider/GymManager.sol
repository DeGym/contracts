// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../staking/StakeManager.sol";

contract GymManager is Ownable {
    struct GymDetails {
        uint256 tier;
        string geolocation;
        string metadata;
        mapping(address => bool) acceptableFiatTokens;
        uint256 stakedAmount;
    }

    mapping(uint256 => GymDetails) public gyms;
    uint256 public nextGymId;
    uint256 public basePrice;
    uint256 public listingFactor = 50;
    StakeManager public stakeManager;

    event GymAdded(
        uint256 gymId,
        uint256 tier,
        string geolocation,
        string metadata
    );
    event GymUpdated(
        uint256 gymId,
        uint256 tier,
        string geolocation,
        string metadata
    );
    event GymRemoved(uint256 gymId);

    constructor(address stakeManagerAddress, uint256 _basePrice) {
        stakeManager = StakeManager(stakeManagerAddress);
        basePrice = _basePrice;
    }

    function addGym(
        uint256 tier,
        string memory geolocation,
        string memory metadata,
        address[] memory fiatTokens
    ) public {
        require(
            stakeManager.getUserTotalStake(msg.sender) >=
                basePrice * listingFactor,
            "Insufficient stake to list gym"
        );

        GymDetails storage newGym = gyms[nextGymId];
        newGym.tier = tier;
        newGym.geolocation = geolocation;
        newGym.metadata = metadata;

        for (uint256 i = 0; i < fiatTokens.length; i++) {
            newGym.acceptableFiatTokens[fiatTokens[i]] = true;
        }

        emit GymAdded(nextGymId, tier, geolocation, metadata);
        nextGymId++;
    }

    function updateGym(
        uint256 gymId,
        uint256 tier,
        string memory geolocation,
        string memory metadata,
        address[] memory fiatTokens
    ) public {
        require(gyms[gymId].stakedAmount > 0, "Gym does not exist");

        GymDetails storage gym = gyms[gymId];
        gym.tier = tier;
        gym.geolocation = geolocation;
        gym.metadata = metadata;

        for (uint256 i = 0; i < fiatTokens.length; i++) {
            gym.acceptableFiatTokens[fiatTokens[i]] = true;
        }

        emit GymUpdated(gymId, tier, geolocation, metadata);
    }

    function removeGym(uint256 gymId) public {
        require(gyms[gymId].stakedAmount > 0, "Gym does not exist");

        delete gyms[gymId];
        emit GymRemoved(gymId);
    }

    function getGymDetails(
        uint256 gymId
    ) public view returns (GymDetails memory) {
        require(gyms[gymId].stakedAmount > 0, "Gym does not exist");
        return gyms[gymId];
    }

    function setBasePrice(uint256 _basePrice) external onlyOwner {
        basePrice = _basePrice;
    }

    function setListingFactor(uint256 _listingFactor) external onlyOwner {
        listingFactor = _listingFactor;
    }

    function validateGymEligibility(
        uint256 gymId
    ) external view returns (bool) {
        return
            stakeManager.getUserTotalStake(owner()) >=
            basePrice * listingFactor;
    }

    function recordCheckin(uint256 gymId) external {
        gyms[gymId].stakedAmount += 1;
    }
}
