// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CentralStaking is Ownable {
    IERC20 public daoToken;
    IERC20 public fiatToken;
    mapping(address => address) public userStakingContracts;

    event UserStakingContractDeployed(address indexed user, address stakingContract);

    constructor(address _daoToken, address _fiatToken) {
        daoToken = IERC20(_daoToken);
        fiatToken = IERC20(_fiatToken);
    }

    function deployUserStakingContract() external {
        require(userStakingContracts[msg.sender] == address(0), "User staking contract already exists");
        UserStaking stakingContract = new UserStaking(address(daoToken), address(fiatToken), msg.sender);
        userStakingContracts[msg.sender] = address(stakingContract);
        emit UserStakingContractDeployed(msg.sender, address(stakingContract));
    }

    function getUserStakingContract(address user) external view returns (address) {
        return userStakingContracts[user];
    }
}

contract UserStaking is Ownable {
    IERC20 public daoToken;
    IERC20 public fiatToken;

    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lockDuration;
        bool isCompound;
    }

    StakeInfo[] public stakes;
    uint256 public totalStaked;

    event Staked(address indexed user, uint256 amount, uint256 lockDuration, bool isCompound);
    event Unstaked(address indexed user, uint256 amount);
    event RewardDistributed(address indexed user, uint256 amount, bool isCompound);

    constructor(address _daoToken, address _fiatToken, address owner) {
        daoToken = IERC20(_daoToken);
        fiatToken = IERC20(_fiatToken);
        transferOwnership(owner);
    }

    function stake(uint256 amount, uint256 lockDuration, bool isCompound) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(lockDuration > 0, "Lock duration must be greater than 0");
        daoToken.transferFrom(msg.sender, address(this), amount);

        stakes.push(StakeInfo(amount, block.timestamp, lockDuration, isCompound));
        totalStaked += amount;

        emit Staked(msg.sender, amount, lockDuration, isCompound);
    }

    function unstake(uint256 stakeIndex) external onlyOwner {
        require(stakes.length > stakeIndex, "Invalid stake index");
        StakeInfo storage userStake = stakes[stakeIndex];
        require(block.timestamp >= userStake.startTime + userStake.lockDuration, "Stake is still locked");
        uint256 amount = userStake.amount;

        // Remove stake from array
        stakes[stakeIndex] = stakes[stakes.length - 1];
        stakes.pop();

        totalStaked -= amount;
        daoToken.transfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    function distributeRewards(uint256 amount, bool isCompound) external onlyOwner {
        if (isCompound) {
            daoToken.transfer(msg.sender, amount);
        } else {
            fiatToken.transfer(msg.sender, amount);
        }

        emit RewardDistributed(msg.sender, amount, isCompound);
    }

    function calculateTotalStakedDuration() public view returns (uint256) {
        uint256 totalWeightedDuration = 0;
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < stakes.length; i++) {
            StakeInfo storage userStake = stakes[i];
            totalWeightedDuration += userStake.amount * userStake.lockDuration;
            totalAmount += userStake.amount;
        }

        if (totalAmount == 0) {
            return 0;
        }

        return totalWeightedDuration / totalAmount;
    }

    function calculateRewards() public view returns (uint256) {
        // Implement your reward calculation logic based on staked amount and lock duration
        uint256 totalRewards = 0;
        uint256 totalWeightedDuration = calculateTotalStakedDuration();

        for (uint256 i = 0; i < stakes.length; i++) {
            StakeInfo storage userStake = stakes[i];
            uint256 weight = userStake.amount * userStake.lockDuration / totalWeightedDuration;
            totalRewards += weight; // Placeholder calculation
        }

        return totalRewards;
    }
}
