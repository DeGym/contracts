// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Token.sol";
import "./StakeManager.sol";

contract BondPool is Ownable {
    Token public daoToken;
    address public stakeManager;
    uint256 public totalStaked;
    uint256 public totalEarnings;
    uint256 public totalClaimableRewards;

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

        bonds.push(
            Bond(amount, block.timestamp, lockDuration, isCompound, 0, 0, 0)
        );
        totalStaked += amount;

        StakeManager(stakeManager).updateTotalStaked(amount, true);
        StakeManager(stakeManager).updateMaxDuration(
            block.timestamp,
            lockDuration
        );
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
        daoToken.transfer(msg.sender, amount);

        StakeManager(stakeManager).updateTotalStaked(amount, false);
        emit Unbonded(msg.sender, amount);
    }

    function increaseBondAmount(
        uint256 bondIndex,
        uint256 amount
    ) external onlyOwner validBondIndex(bondIndex) {
        require(amount > 0, "Amount must be greater than 0");

        Bond storage bond = bonds[bondIndex];
        daoToken.transferFrom(msg.sender, address(this), amount);
        bond.amount += amount;
        totalStaked += amount;

        StakeManager(stakeManager).updateTotalStaked(amount, true);
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
        bond.lockDuration += additionalDuration;

        StakeManager(stakeManager).updateMaxDuration(
            bond.startTime,
            bond.lockDuration
        );
        emit LockDurationExtended(msg.sender, bond.lockDuration);
    }

    function updateReward(
        uint256 daoRewards,
        uint256 totalStakedAmount
    ) external onlyStakeManager returns (uint256) {
        uint256 claimableRewardAmount = 0;
        uint256 totalWeightedStake = calculateTotalWeightedStake();

        for (uint256 i = 0; i < bonds.length; i++) {
            Bond storage bond = bonds[i];
            uint256 bondWeightedShare = (calculateWeight(bond.lockDuration) *
                daoRewards) / totalWeightedStake;
            if (bond.isCompound) {
                bond.amount += bondWeightedShare;
                bond.earnings += bondWeightedShare;
                totalEarnings += bondWeightedShare;
                StakeManager(stakeManager).updateTotalStaked(
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

    function claimRewards(
        uint256 bondIndex
    ) external onlyOwner validBondIndex(bondIndex) {
        Bond storage bond = bonds[bondIndex];
        uint256 claimableRewards = bond.claimableReward;
        require(claimableRewards > 0, "No rewards to claim");
        bond.claimableReward = 0;
        totalClaimableRewards -= claimableRewards;

        StakeManager(stakeManager).updateClaimableRewards(
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

    function calculateWeight(
        uint256 lockDuration
    ) internal view returns (uint256) {
        uint256 remainingDuration = block.timestamp +
            lockDuration -
            block.timestamp;
        if (remainingDuration < 0) {
            remainingDuration = 1 days;
        }
        uint256 absoluteMaxDuration = StakeManager(stakeManager)
            .getAbsoluteMaxRemainingDuration();
        uint256 totalWeight = StakeManager(stakeManager).absTotalBondWeight();
        return (remainingDuration * 1e18) / (absoluteMaxDuration * totalWeight);
    }

    function calculateTotalWeightedStake() internal view returns (uint256) {
        uint256 totalWeightedStake = 0;
        for (uint256 i = 0; i < bonds.length; i++) {
            totalWeightedStake +=
                bonds[i].amount *
                calculateWeight(bonds[i].lockDuration);
        }
        return totalWeightedStake;
    }
}
