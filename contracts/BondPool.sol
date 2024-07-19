// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Token.sol";
import "./StakeManager.sol";

contract BondPool is Ownable {
    Token public daoToken;
    StakeManager public stakeManager;
    uint256 public totalStaked;
    uint256 public totalEarnings;
    uint256 public totalClaimableRewards;
    uint256 public totalWeight;

    struct Bond {
        uint256 amount;
        uint256 startTime;
        uint256 lockDuration;
        bool isCompound;
        uint256 reward;
        uint256 earnings;
        uint256 claimableReward;
    }

    Bond[] public bonds;

    event Bonded(
        address indexed stakeholder,
        uint256 amount,
        uint256 lockDuration,
        bool isCompound
    );
    event Unbonded(address indexed stakeholder, uint256 amount);
    event RewardUpdated(address indexed stakeholder, uint256 rewardAmount);
    event RewardClaimed(address indexed stakeholder, uint256 rewardAmount);
    event BondAmountIncreased(address indexed stakeholder, uint256 amount);
    event LockDurationExtended(
        address indexed stakeholder,
        uint256 newDuration
    );
    event CompoundStatusSwitched(
        address indexed stakeholder,
        uint256 bondIndex,
        bool newCompoundStatus
    );

    constructor(address owner, address _stakeManager) {
        transferOwnership(owner);
        stakeManager = _stakeManager;
    }

    modifier onlyStakeManager() {
        require(
            msg.sender == stakeManager,
            "Only stake manager can perform this action"
        );
        _;
    }

    modifier validBondIndex(uint256 bondIndex) {
        require(bondIndex < bonds.length, "Invalid bond index");
        _;
    }

    function bond(
        uint256 amount,
        uint256 lockDuration,
        bool isCompound
    ) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(lockDuration > 0, "Lock duration must be greater than 0");
        daoToken.transferFrom(msg.sender, address(this), amount);

        uint256 oldWeight = totalWeight;

        bonds.push(
            Bond(amount, block.timestamp, lockDuration, isCompound, 0, 0, 0)
        );
        totalStaked += amount;

        StakeManager(stakeManager).updateAbsTotalStaked(amount, true);
        StakeManager(stakeManager).updateMaxDuration(
            block.timestamp,
            lockDuration
        );
        updateTotalBondWeight(oldWeight);
        emit Bonded(msg.sender, amount, lockDuration, isCompound);
    }

    function unbond(
        uint256 bondIndex
    ) external onlyOwner validBondIndex(bondIndex) {
        uint256 oldWeight = totalWeight;

        Bond storage bond = bonds[bondIndex];
        require(
            block.timestamp >= bond.startTime + bond.lockDuration,
            "Bond is still locked"
        );
        uint256 amount = bond.amount;
        bonds[bondIndex] = bonds[bonds.length - 1];
        bonds.pop();

        totalStaked -= amount;

        daoToken.transfer(msg.sender, amount);

        StakeManager(stakeManager).updateAbsTotalStaked(amount, false);
        updateTotalBondWeight(oldWeight);
        emit Unbonded(msg.sender, amount);
    }

    function increaseBondAmount(
        uint256 bondIndex,
        uint256 amount
    ) external onlyOwner validBondIndex(bondIndex) {
        require(amount > 0, "Amount must be greater than 0");

        uint256 oldWeight = totalWeight;

        Bond storage bond = bonds[bondIndex];
        daoToken.transferFrom(msg.sender, address(this), amount);
        bond.amount += amount;
        totalStaked += amount;

        StakeManager(stakeManager).updateAbsTotalStaked(amount, true);
        updateTotalBondWeight(oldWeight);
        emit BondAmountIncreased(msg.sender, amount);
    }

    function extendLockDuration(
        uint256 bondIndex,
        uint256 additionalDuration
    ) external onlyOwner validBondIndex(bondIndex) {
        require(
            additionalDuration > 0,
            "Additional duration must be greater than 0"
        );

        uint256 oldWeight = totalWeight;

        Bond storage bond = bonds[bondIndex];
        bond.lockDuration += additionalDuration;

        StakeManager(stakeManager).updateMaxDuration(
            bond.startTime,
            bond.lockDuration
        );
        updateTotalBondWeight(oldWeight);
        emit LockDurationExtended(msg.sender, bond.lockDuration);
    }

    function claimRewards(
        uint256 bondIndex
    ) external onlyOwner validBondIndex(bondIndex) {
        Bond storage bond = bonds[bondIndex];
        uint256 claimableRewards = bond.claimableReward;
        require(claimableRewards > 0, "No rewards to claim");
        bond.claimableReward = 0;
        totalClaimableRewards -= claimableRewards;
        StakeManager(stakeManager).updateAbsTotalClaimableRewards(
            claimableRewards,
            true
        );
        daoToken.mint(msg.sender, claimableRewards);
        emit RewardClaimed(msg.sender, claimableRewards);
    }

    function switchCompoundStatus(
        uint256 bondIndex
    ) external onlyOwner validBondIndex(bondIndex) {
        Bond storage bond = bonds[bondIndex];
        bond.isCompound = !bond.isCompound;
        emit CompoundStatusSwitched(msg.sender, bondIndex, bond.isCompound);
    }

    function calculateWeightedTime(
        uint256 lockDuration,
        uint256 absMaxRemainDuration
    ) internal view returns (uint256) {
        uint256 remainingDuration = block.timestamp +
            lockDuration -
            block.timestamp;
        if (remainingDuration < 0) {
            remainingDuration = 1 days;
        }
        return (remainingDuration * 1e18) / absMaxRemainDuration;
    }

    function calculateTotalWeightedStake(
        uint256 absMaxRemainDuration
    ) internal view returns (uint256) {
        uint256 totalWeightedStake = 0;
        for (uint256 i = 0; i < bonds.length; i++) {
            totalWeightedStake +=
                bonds[i].amount *
                calculateWeightedTime(
                    bonds[i].lockDuration,
                    absMaxRemainDuration
                );
        }
        return totalWeightedStake;
    }

    function updateTotalBondWeight(uint256 oldWeight) internal {
        totalWeight = calculateTotalWeightedStake(
            StakeManager(stakeManager).getAbsMaxRemainDuration()
        );
        StakeManager(stakeManager).updateAbsTotalBondWeight(
            oldWeight,
            totalWeight
        );
    }

    function updateReward(
        uint256 daoRewards,
        uint256 totalStakedAmount,
        uint256 absMaxRemainDuration
    ) external onlyStakeManager returns (uint256) {
        uint256 claimableRewardAmount = 0;
        uint256 totalWeightedStake = calculateTotalWeightedStake(
            absMaxRemainDuration
        );

        for (uint256 i = 0; i < bonds.length; i++) {
            Bond storage bond = bonds[i];
            uint256 bondWeightedShare = (calculateWeightedTime(
                bond.lockDuration,
                absMaxRemainDuration
            ) * daoRewards) / totalWeightedStake;
            if (bond.isCompound) {
                bond.amount += bondWeightedShare;
                bond.earnings += bondWeightedShare;
                totalEarnings += bondWeightedShare;
                totalStaked += bondWeightedShare;
                StakeManager(stakeManager).updateAbsTotalStaked(
                    bondWeightedShare,
                    true
                );
            } else {
                bond.claimableReward += bondWeightedShare;
                bond.earnings += bondWeightedShare;
                totalEarnings += bondWeightedShare;
                claimableRewardAmount += bondWeightedShare;
            }
        }
        totalClaimableRewards += claimableRewardAmount;
        emit RewardUpdated(owner(), claimableRewardAmount);
        return claimableRewardAmount;
    }
}
