// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Token.sol";
import "./StakeManager.sol";

contract StakePool is Ownable {
    Token public daoToken;
    address public stakeManager;
    uint256 public totalStaked;
    uint256 public rewards;

    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lockDuration;
        bool isCompound;
        uint256 reward;
    }

    StakeInfo[] public stakes;

    event Staked(
        address indexed stakeholder,
        uint256 amount,
        uint256 lockDuration,
        bool isCompound
    );
    event Unstaked(address indexed stakeholder, uint256 amount);
    event RewardUpdated(address indexed stakeholder, uint256 rewardAmount);
    event RewardClaimed(address indexed stakeholder, uint256 rewardAmount);

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

    function stake(
        uint256 amount,
        uint256 lockDuration,
        bool isCompound
    ) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(lockDuration > 0, "Lock duration must be greater than 0");
        daoToken.transferFrom(msg.sender, address(this), amount);

        stakes.push(
            StakeInfo(amount, block.timestamp, lockDuration, isCompound, 0)
        );
        totalStaked += amount;

        StakeManager(stakeManager).updateTotalStaked(amount, true);
        emit Staked(msg.sender, amount, lockDuration, isCompound);
    }

    function unstake(uint256 stakeIndex) external onlyOwner {
        require(stakes.length > stakeIndex, "Invalid stake index");
        StakeInfo storage stake = stakes[stakeIndex];
        require(
            block.timestamp >= stake.startTime + stake.lockDuration,
            "Stake is still locked"
        );
        require(
            !stake.isCompound,
            "Compound stakes cannot be unstaked before lock duration ends"
        );

        uint256 amount = stake.amount;
        stakes[stakeIndex] = stakes[stakes.length - 1];
        stakes.pop();

        totalStaked -= amount;
        daoToken.transfer(msg.sender, amount);

        StakeManager(stakeManager).updateTotalStaked(amount, false);
        emit Unstaked(msg.sender, amount);
    }

    function increaseStakeAmount(
        uint256 stakeIndex,
        uint256 amount
    ) external onlyOwner {
        require(stakes.length > stakeIndex, "Invalid stake index");
        require(amount > 0, "Amount must be greater than 0");

        StakeInfo storage stake = stakes[stakeIndex];
        daoToken.transferFrom(msg.sender, address(this), amount);
        stake.amount += amount;
        totalStaked += amount;

        StakeManager(stakeManager).updateTotalStaked(amount, true);
        emit StakeAmountIncreased(msg.sender, amount);
    }

    function extendLockDuration(
        uint256 stakeIndex,
        uint256 additionalDuration
    ) external onlyOwner {
        require(stakes.length > stakeIndex, "Invalid stake index");
        require(
            additionalDuration > 0,
            "Additional duration must be greater than 0"
        );

        StakeInfo storage stake = stakes[stakeIndex];
        stake.lockDuration += additionalDuration;

        emit LockDurationExtended(msg.sender, stake.lockDuration);
    }

    function updateReward(
        uint256 daoRewards,
        uint256 totalStakedAmount
    ) external onlyStakeManager returns (uint256) {
        uint256 rewardAmount = (totalStaked * daoRewards) / totalStakedAmount;
        rewards += rewardAmount;
        emit RewardUpdated(owner(), rewardAmount);
        return rewardAmount;
    }

    function claimRewards() external onlyOwner {
        uint256 claimableRewards = rewards;
        require(claimableRewards > 0, "No rewards to claim");
        rewards = 0;
        StakeManager(stakeManager).updateUnclaimedRewards(
            claimableRewards,
            true
        );
        daoToken.mint(msg.sender, claimableRewards);
        emit RewardClaimed(msg.sender, claimableRewards);
    }
}
