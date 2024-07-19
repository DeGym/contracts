// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./BondPool.sol";

contract StakeManager is Ownable {
    IERC20 public daoToken;
    mapping(address => address) public bondPools;
    address[] public stakeholders;
    uint256 public totalStaked;
    uint256 public totalUnclaimedRewards;
    uint256 public maxDuration;
    uint256 public maxStartTime;

    event BondPoolDeployed(address indexed stakeholder, address bondPool);
    event StakeUpdated(address indexed stakeholder, uint256 newTotalStaked);
    event RewardsUpdated(uint256 totalUnclaimedRewards);
    event MaxDurationUpdated(uint256 maxStartTime, uint256 maxDuration);

    constructor(address _daoToken) {
        daoToken = IERC20(_daoToken);
    }

    function deployBondPool() external {
        require(
            bondPools[msg.sender] == address(0),
            "Bond pool already exists"
        );
        BondPool bondPool = new BondPool(msg.sender, address(this));
        bondPools[msg.sender] = address(bondPool);
        stakeholders.push(msg.sender);
        emit BondPoolDeployed(msg.sender, address(bondPool));
    }

    function getBondPool(address stakeholder) external view returns (address) {
        return bondPools[stakeholder];
    }

    function updateRewards(uint256 daoRewards) external onlyOwner {
        uint256 totalStakedAmount = totalStaked;
        uint256 totalRewardAmount = 0;
        for (uint256 i = 0; i < stakeholders.length; i++) {
            address stakeholder = stakeholders[i];
            uint256 rewardAmount = BondPool(bondPools[stakeholder])
                .updateReward(daoRewards, totalStakedAmount);
            totalRewardAmount += rewardAmount;
        }
        totalUnclaimedRewards += totalRewardAmount;
        emit RewardsUpdated(totalUnclaimedRewards);
    }

    function updateTotalStaked(uint256 amount, bool isStaking) external {
        require(
            bondPools[msg.sender] != address(0),
            "Bond pool does not exist"
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
            bondPools[msg.sender] != address(0),
            "Bond pool does not exist"
        );

        if (isClaiming) {
            totalUnclaimedRewards -= amount;
        } else {
            totalUnclaimedRewards += amount;
        }
    }

    function updateMaxDuration(uint256 startTime, uint256 lockDuration) external {
        require(
            bondPools[msg.sender] != address(0),
            "Bond pool does not exist"
        );

        uint256 remainingDuration = startTime + lockDuration - block.timestamp;
        if (remainingDuration > getAbsoluteMaxRemainingDuration()) {
            maxDuration = lockDuration;
            maxStartTime = startTime;
            emit MaxDurationUpdated(maxStartTime, maxDuration);
        }
    }

    function getAbsoluteMaxRemainingDuration() public view returns (uint256) {
        return maxDuration - (block.timestamp - maxStartTime);
    }

    function getTotalUnclaimedRewards() external view returns (uint256) {
        return totalUnclaimedRewards;
    }
}
