// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./StakePool.sol";
import "./Token.sol";

contract StakeManager is Ownable {
    IERC20 public daoToken;
    mapping(address => address) public stakePools;
    address[] public stakeholders;
    uint256 public totalStaked;
    uint256 public totalUnclaimedRewards;

    event StakePoolDeployed(address indexed stakeholder, address stakePool);
    event StakeUpdated(address indexed stakeholder, uint256 newTotalStaked);
    event RewardsUpdated(uint256 totalUnclaimedRewards);

    constructor(address _daoToken) {
        daoToken = IERC20(_daoToken);
    }

    function deployStakePool() external {
        require(
            stakePools[msg.sender] == address(0),
            "Stake pool already exists"
        );
        StakePool stakePool = new StakePool(
            address(daoToken),
            msg.sender,
            address(this)
        );
        stakePools[msg.sender] = address(stakePool);
        stakeholders.push(msg.sender);
        emit StakePoolDeployed(msg.sender, address(stakePool));
    }

    function getStakePool(address stakeholder) external view returns (address) {
        return stakePools[stakeholder];
    }

    function updateRewards(uint256 daoRewards) external onlyOwner {
        uint256 totalStakedAmount = totalStaked;
        uint256 totalRewardAmount = 0;
        for (uint256 i = 0; i < stakeholders.length; i++) {
            address stakeholder = stakeholders[i];
            uint256 rewardAmount = StakePool(stakePools[stakeholder])
                .updateReward(daoRewards, totalStakedAmount);
            totalRewardAmount += rewardAmount;
        }
        totalUnclaimedRewards += totalRewardAmount;
        emit RewardsUpdated(totalUnclaimedRewards);
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
