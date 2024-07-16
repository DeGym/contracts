// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakeManager is Ownable {
    IERC20 public daoToken;
    mapping(address => address) public stakePools;
    address[] public supportedFiatTokens;

    event StakePoolDeployed(address indexed user, address stakePool);

    constructor(address _daoToken) {
        daoToken = IERC20(_daoToken);
    }

    function deployStakePool(address fiatToken) external {
        require(
            stakePools[msg.sender] == address(0),
            "Stake pool already exists"
        );
        StakePool stakePool = new StakePool(
            address(daoToken),
            fiatToken,
            msg.sender
        );
        stakePools[msg.sender] = address(stakePool);
        emit StakePoolDeployed(msg.sender, address(stakePool));
    }

    function getStakePool(address user) external view returns (address) {
        return stakePools[user];
    }

    function distributeRewards(uint256 totalRewards) external onlyOwner {
        uint256 totalStaked = getTotalStaked();
        
        for (uint256 i = 0; i < supportedFiatTokens.length; i++) {
            address fiatToken = supportedFiatTokens[i];
            uint256 totalFiatRewards = totalRewards * IERC20(fiatToken).balanceOf(address(this)) / totalStaked;

            for (uint256 j = 0; j < stakePools.length; j++) {
                address user = stakePools[j];
                uint256 stake = StakePool(stakePools[user]).totalStaked();
                uint256 reward = (stake * totalFiatRewards) / totalStaked;
                StakePool(stakePools[user]).receiveRewards(fiatToken, reward);
            }
        }
}


    function distributeFiatRewards(uint256 totalRewards, address fiatToken) external onlyOwner {
        uint256 totalStaked = getTotalStaked();
        for (address user : stakePools) {
            uint256 stake = StakePool(stakePools[user]).totalStaked();
            uint256 reward = (stake * totalRewards) / totalStaked;
            StakePool(stakePools[user]).receiveFiatRewards(reward, fiatToken);
        }
    }

    function claimFiatRewards(address fiatToken) external {
        StakePool userPool = StakePool(stakePools[msg.sender]);
        userPool.claimFiatRewards(fiatToken);
    }

    function addSupportedFiatToken(address fiatToken) external onlyOwner {
        supportedFiatTokens.push(fiatToken);
    }

    function getTotalStaked() internal view returns (uint256) {
        uint256 totalStaked = 0;
        for (address user : stakePools) {
            totalStaked += StakePool(stakePools[user]).totalStaked();
        }
        return totalStaked;
    }
}

contract StakePool is Ownable {
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
    uint256 public totalFiatRewards;
    uint256 public totalDGYMRewards;

    mapping(address => uint256) public fiatRewards;
    mapping(address => uint256) public dGYMRewards;

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
    event FiatRewardDistributed(address indexed user, uint256 amount);

    constructor(address _daoToken, address _fiatToken, address owner) {
        daoToken = IERC20(_daoToken);
        fiatToken = IERC20(_fiatToken);
        transferOwnership(owner);
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

        emit Unstaked(msg.sender, amount);
    }

    function receiveRewards(uint256 amount) external onlyOwner {
        totalDGYMRewards += amount;
        dGYMRewards[msg.sender] += amount;
        emit RewardDistributed(msg.sender, amount, true);
    }

    function receiveFiatRewards(uint256 amount, address fiatTokenAddress) external onlyOwner {
        IERC20 fiatTokenInstance = IERC20(fiatTokenAddress);
        totalFiatRewards += amount;
        fiatRewards[fiatTokenAddress] += amount;
        fiatTokenInstance.transferFrom(msg.sender, address(this), amount);
        emit FiatRewardDistributed(msg.sender, amount);
    }

    function claimDGYMRewards() external onlyOwner {
        uint256 reward = dGYMRewards[msg.sender];
        require(reward > 0, "No rewards to claim");
        dGYMRewards[msg.sender] = 0;
        daoToken.transfer(msg.sender, reward);
    }

    function claimFiatRewards(address fiatTokenAddress) external onlyOwner {
        uint256 reward = fiatRewards[fiatTokenAddress];
        require(reward > 0, "No rewards to claim");
        fiatRewards[fiatTokenAddress] = 0;
        IERC20(fiatTokenAddress).transfer(msg.sender, reward);
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
            uint256 weight = (stake.amount * stake.lockDuration) / totalWeightedDuration;
            totalRewards += weight; // Placeholder calculation
        }

        return totalRewards;
    }
}
