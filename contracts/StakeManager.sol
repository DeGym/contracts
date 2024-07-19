// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./BondPool.sol";

contract StakeManager is Ownable {
    IERC20 public daoToken;
    mapping(address => address) public bondPools;
    address[] public stakeholders;
    uint256 public absTotalStaked;
    uint256 public absTotalEarnings;
    uint256 public absTotalClaimableRewards;
    uint256 public absTotalBondWeight;
    uint256 public maxDuration;
    uint256 public maxStartTime;

    event BondPoolDeployed(address indexed stakeholder, address bondPool);
    event StakeUpdated(address indexed stakeholder, uint256 newTotalStaked);
    event RewardsUpdated(uint256 absTotalClaimableRewards);
    event MaxDurationUpdated(uint256 maxStartTime, uint256 maxDuration);
    event BondWeightUpdated(uint256 oldWeight, uint256 newWeight);

    constructor(address _daoToken) {
        daoToken = IERC20(_daoToken);
    }

    modifier onlyBondPool() {
        require(
            bondPools[msg.sender] != address(0),
            "Only bond pool can perform this action"
        );
        _;
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
        uint256 totalStakedAmount = absTotalStaked;
        uint256 totalRewardAmount = 0;
        for (uint256 i = 0; i < stakeholders.length; i++) {
            address stakeholder = stakeholders[i];
            uint256 rewardAmount = BondPool(bondPools[stakeholder])
                .updateReward(daoRewards, totalStakedAmount);
            totalRewardAmount += rewardAmount;
        }
        absTotalClaimableRewards += totalRewardAmount;
        emit RewardsUpdated(absTotalClaimableRewards);
    }

    function updateTotalStaked(
        uint256 amount,
        bool isStaking
    ) external onlyBondPool {
        if (isStaking) {
            absTotalStaked += amount;
        } else {
            absTotalStaked -= amount;
        }
        emit StakeUpdated(msg.sender, absTotalStaked);
    }

    function updateClaimableRewards(
        uint256 amount,
        bool isClaiming
    ) external onlyBondPool {
        if (isClaiming) {
            absTotalClaimableRewards -= amount;
        } else {
            absTotalClaimableRewards += amount;
        }
    }

    function updateMaxDuration(
        uint256 startTime,
        uint256 lockDuration
    ) external onlyBondPool {
        uint256 remainingDuration = startTime + lockDuration - block.timestamp;
        if (remainingDuration > getAbsoluteMaxRemainingDuration()) {
            maxDuration = lockDuration;
            maxStartTime = startTime;
            emit MaxDurationUpdated(maxStartTime, maxDuration);
        }
    }

    function updateAbsTotalEarnings(
        uint256 amount,
        bool isAdding
    ) external onlyBondPool {
        if (isAdding) {
            absTotalEarnings += amount;
        } else {
            absTotalEarnings -= amount;
        }
    }

    function updateAbsTotalClaimableRewards(
        uint256 amount,
        bool isAdding
    ) external onlyBondPool {
        if (isAdding) {
            absTotalClaimableRewards += amount;
        } else {
            absTotalClaimableRewards -= amount;
        }
    }

    function updateBondWeight(
        uint256 oldWeight, 
        uint256 newWeight
    ) external onlyBondPool {
        absTotalBondWeight = absTotalBondWeight - oldWeight + newWeight;
        emit BondWeightUpdated(oldWeight, newWeight);
    }

    function getAbsoluteMaxRemainingDuration() public view returns (uint256) {
        return maxDuration - (block.timestamp - maxStartTime);
    }
}
