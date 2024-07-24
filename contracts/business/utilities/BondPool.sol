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
            msg.sender == address(stakeManager.owner()),
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
            Bond(amount, block.timestamp, lockDuration, isCompound, 0, 0)
        );
        totalStaked += amount;
        uint256 bondWeight = calculateWeight(amount, lockDuration);
        totalWeight += bondWeight;

        stakeManager.updateAbsTotalStaked(amount, true);
        stakeManager.updateMaxDuration(block.timestamp, lockDuration);
        stakeManager.updateAbsTotalBondWeight(bondWeight);
        emit Bonded(msg.sender, amount, lockDuration, isCompound);
    }

    function unbond(
        uint256 bondIndex
    ) external onlyOwner validBondIndex(bondIndex) {
        Bond storage bond = bonds[bondIndex];
        require(
            block.timestamp >= bond.startTime + bond.lockDuration,
            "Bond is still locked"
        );
        uint256 amount = bond.amount;
        bonds[bondIndex] = bonds[bonds.length - 1];
        bonds.pop();

        totalStaked -= amount;
        uint256 bondWeight = calculateWeight(amount, bond.lockDuration);
        totalWeight -= bondWeight;

        daoToken.transfer(msg.sender, amount);

        stakeManager.updateAbsTotalStaked(amount, false);
        stakeManager.updateAbsTotalBondWeight(-bondWeight);
        emit Unbonded(msg.sender, amount);
    }

    function increaseBondAmount(
        uint256 bondIndex,
        uint256 amount
    ) external onlyOwner validBondIndex(bondIndex) {
        require(amount > 0, "Amount must be greater than 0");

        Bond storage bond = bonds[bondIndex];
        uint256 oldWeight = calculateWeight(bond.amount, bond.lockDuration);
        daoToken.transferFrom(msg.sender, address(this), amount);
        bond.amount += amount;
        totalStaked += amount;

        uint256 newWeight = calculateWeight(bond.amount, bond.lockDuration);
        totalWeight = totalWeight - oldWeight + newWeight;

        stakeManager.updateAbsTotalStaked(amount, true);
        stakeManager.updateAbsTotalBondWeight(newWeight - oldWeight);
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

        Bond storage bond = bonds[bondIndex];
        uint256 oldWeight = calculateWeight(bond.amount, bond.lockDuration);
        bond.lockDuration += additionalDuration;

        uint256 newWeight = calculateWeight(bond.amount, bond.lockDuration);
        totalWeight = totalWeight - oldWeight + newWeight;

        stakeManager.updateMaxDuration(bond.startTime, bond.lockDuration);
        stakeManager.updateAbsTotalBondWeight(newWeight - oldWeight);
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
        stakeManager.updateAbsTotalClaimableRewards(claimableRewards, true);
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

    function calculateWeight(
        uint256 amount,
        uint256 lockDuration
    ) internal view returns (uint256) {
        uint256 end_date = block.timestamp + lockDuration * 7 * 24 * 60 * 60; // convert weeks to seconds
        uint256 remaining_duration = end_date - block.timestamp;
        if (remaining_duration < 0) {
            remaining_duration = 1; // 1 second
        }
        return
            (amount *
                uint256(keccak256(abi.encodePacked(remaining_duration)))) %
            1e18;
    }

    function updateReward(
        uint256 daoRewards,
        uint256 absTotalWeight
    ) external onlyStakeManager returns (uint256) {
        uint256 claimableRewardAmount = 0;
        for (uint256 i = 0; i < bonds.length; i++) {
            Bond storage bond = bonds[i];
            uint256 bondWeight = calculateWeight(
                bond.amount,
                bond.lockDuration
            );
            uint256 bondWeightNormalized = bondWeight / absTotalWeight;
            uint256 bondReward = bondWeightNormalized * daoRewards;
            if (bond.isCompound) {
                bond.amount += bondReward;
                totalStaked += bondReward;
                stakeManager.updateAbsTotalStaked(bondReward, true);
            } else {
                bond.claimableReward += bondReward;
                totalClaimableRewards += bondReward;
            }
            bond.earnings += bondReward;
            totalEarnings += bondReward;
        }
        emit RewardUpdated(owner(), claimableRewardAmount);
        return claimableRewardAmount;
    }
}
