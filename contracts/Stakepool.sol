// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakePool is Ownable {
    IERC20 public daoToken;
    IERC20 public fiatToken;
    address public stakeManager;

    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lockDuration;
        bool isCompound;
    }

    StakeInfo[] public stakes;
    uint256 public totalStaked;

    event Staked(
        address indexed stakeholder,
        uint256 amount,
        uint256 lockDuration,
        bool isCompound
    );
    event Unstaked(address indexed stakeholder, uint256 amount);
    event RewardDistributed(
        address indexed stakeholder,
        uint256 amount,
        bool isCompound
    );
    event FiatRewardDistributed(address indexed stakeholder, uint256 amount);
    event StakeAmountAdded(address indexed stakeholder, uint256 amount);
    event LockDurationExtended(
        address indexed stakeholder,
        uint256 newDuration
    );

    constructor(
        address _daoToken,
        address _fiatToken,
        address owner,
        address _stakeManager
    ) {
        daoToken = IERC20(_daoToken);
        fiatToken = IERC20(_fiatToken);
        transferOwnership(owner);
        stakeManager = _stakeManager;
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
            StakeInfo(amount, block.timestamp, lockDuration, isCompound)
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
        uint256 amount = stake.amount;

        // Remove stake from array
        stakes[stakeIndex] = stakes[stakes.length - 1];
        stakes.pop();

        totalStaked -= amount;
        daoToken.transfer(msg.sender, amount);

        StakeManager(stakeManager).updateTotalStaked(amount, false);
        emit Unstaked(msg.sender, amount);
    }

    function addStakeAmount(
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
        emit StakeAmountAdded(msg.sender, amount);
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

    function receiveRewards(uint256 amount) external onlyOwner {
        daoToken.transfer(msg.sender, amount);
        emit RewardDistributed(msg.sender, amount, true);
    }

    function receiveFiatRewards(
        uint256 amount,
        address fiatTokenAddress
    ) external onlyOwner {
        IERC20 fiatTokenInstance = IERC20(fiatTokenAddress);
        fiatTokenInstance.transferFrom(msg.sender, address(this), amount);
        emit FiatRewardDistributed(msg.sender, amount);
    }

    function calculateTotalStakedDuration() public view returns (uint256) {
        uint256 totalWeightedDuration = 0;
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < stakes.length; i++) {
            StakeInfo storage stake = stakes[i];
            totalWeightedDuration += stake.amount * stake.lockDuration;
            totalAmount += stake.amount;
        }

        if (totalAmount == 0) {
            return 0;
        }

        return totalWeightedDuration / totalAmount;
    }

    function calculateRewards() public view returns (uint256) {
        uint256 totalRewards = 0;
        uint256 totalWeightedDuration = calculateTotalStakedDuration();

        for (uint256 i = 0; i < stakes.length; i++) {
            StakeInfo storage stake = stakes[i];
            uint256 weight = (stake.amount * stake.lockDuration) /
                totalWeightedDuration;
            totalRewards += weight; // Placeholder calculation
        }

        return totalRewards;
    }
}
