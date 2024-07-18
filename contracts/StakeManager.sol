// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./StakePool.sol";

contract StakeManager is Ownable {
    mapping(address => address) public stakePools;
    address[] public stakeholders;

    uint256 public totalStaked;
    uint256 public totalUnclaimedRewards;

    event StakePoolDeployed(address indexed stakeholder, address stakePool);
    event StakeUpdated(address indexed stakeholder, uint256 newTotalStaked);
    event RewardsUpdated(address indexed stakeholder, uint256 rewardAmount);

    constructor() {}

    function deployStakePool() external {
        require(
            stakePools[msg.sender] == address(0),
            "Stake pool already exists"
        );
        StakePool stakePool = new StakePool(msg.sender, address(this));
        stakePools[msg.sender] = address(stakePool);
        stakeholders.push(msg.sender);
        emit StakePoolDeployed(msg.sender, address(stakePool));
    }

    function getStakePool(address stakeholder) external view returns (address) {
        return stakePools[stakeholder];
    }

    function distributeRewards(uint256 daoRewards) external onlyOwner {
        uint256 totalStakedAmount = totalStaked;
        for (uint256 i = 0; i < stakeholders.length; i++) {
            address stakeholder = stakeholders[i];
            uint256 stakeholderStake = StakePool(stakePools[stakeholder])
                .totalStaked();
            uint256 rewardAmount = (stakeholderStake * daoRewards) /
                totalStakedAmount;
            StakePool(stakePools[stakeholder]).updateReward(rewardAmount);
            totalUnclaimedRewards += rewardAmount;
            emit RewardsUpdated(stakeholder, rewardAmount);
        }
    }

    function updateTotalStaked(uint256 amount, bool isStaking) external {
        require(
            stakePools[msg.sender] != address(0),
            "Stake pool does not exist"
        );

        if (isStaking) {
            totalStaked += amount;
        } else {
            totalStaked -= amount;
        }

        emit StakeUpdated(msg.sender, totalStaked);
    }

    function updateUnclaimedRewards(uint256 amount, bool isClaiming) external {
        require(
            stakePools[msg.sender] != address(0),
            "Stake pool does not exist"
        );

        if (isClaiming) {
            totalUnclaimedRewards -= amount;
        } else {
            totalUnclaimedRewards += amount;
        }
    }

    function getTotalUnclaimedRewards() external view returns (uint256) {
        return totalUnclaimedRewards;
    }
}
