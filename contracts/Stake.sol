// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Stake is Ownable {
    IERC20 public daoToken;
    IERC20 public fiatToken;

    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lockDuration;
        bool isCompound;
    }

    mapping(address => StakeInfo[]) public stakes;
    uint256 public totalStaked;

    event Staked(
        address indexed user,
        uint256 amount,
        uint256 lockDuration,
        bool isCompound
    );
    event Unstaked(address indexed user, uint256 amount);
    event RewardDistributed(
        address indexed user,
        uint256 amount,
        bool isCompound
    );

    constructor(address _daoToken, address _fiatToken) {
        daoToken = IERC20(_daoToken);
        fiatToken = IERC20(_fiatToken);
    }

    function stake(
        uint256 amount,
        uint256 lockDuration,
        bool isCompound
    ) public {
        require(amount > 0, "Amount must be greater than 0");
        require(lockDuration > 0, "Lock duration must be greater than 0");
        daoToken.transferFrom(msg.sender, address(this), amount);

        stakes[msg.sender].push(
            StakeInfo(amount, block.timestamp, lockDuration, isCompound)
        );
        totalStaked += amount;

        emit Staked(msg.sender, amount, lockDuration, isCompound);
    }

    function unstake(uint256 stakeIndex) public {
        require(stakes[msg.sender].length > stakeIndex, "Invalid stake index");
        StakeInfo storage userStake = stakes[msg.sender][stakeIndex];
        require(
            block.timestamp >= userStake.startTime + userStake.lockDuration,
            "Stake is still locked"
        );
        uint256 amount = userStake.amount;

        // Remove stake from array
        stakes[msg.sender][stakeIndex] = stakes[msg.sender][
            stakes[msg.sender].length - 1
        ];
        stakes[msg.sender].pop();

        totalStaked -= amount;
        daoToken.transfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    function distributeRewards(
        address recipient,
        uint256 amount,
        bool isCompound
    ) external onlyOwner {
        if (isCompound) {
            daoToken.transfer(recipient, amount);
        } else {
            fiatToken.transfer(recipient, amount);
        }

        emit RewardDistributed(recipient, amount, isCompound);
    }

    function calculateTotalStakedDuration(
        address user
    ) public view returns (uint256) {
        uint256 totalWeightedDuration = 0;
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < stakes[user].length; i++) {
            StakeInfo storage userStake = stakes[user][i];
            totalWeightedDuration += userStake.amount * userStake.lockDuration;
            totalAmount += userStake.amount;
        }

        if (totalAmount == 0) {
            return 0;
        }

        return totalWeightedDuration / totalAmount;
    }

    function calculateRewards(address user) public view returns (uint256) {
        // Implement your reward calculation logic based on staked amount and lock duration
        uint256 totalRewards = 0;
        uint256 totalWeightedDuration = calculateTotalStakedDuration(user);

        for (uint256 i = 0; i < stakes[user].length; i++) {
            StakeInfo storage userStake = stakes[user][i];
            uint256 weight = (userStake.amount * userStake.lockDuration) /
                totalWeightedDuration;
            totalRewards += weight; // Placeholder calculation
        }

        return totalRewards;
    }
}
