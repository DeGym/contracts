// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakeManager is Ownable {
    IERC20 public daoToken;
    mapping(address => address) public stakePools;
    address[] public stakeholders;
    address[] public supportedFiatTokens;
    mapping(address => mapping(address => uint256)) public fiatRewards; // stakeholder => (fiatToken => rewards)

    event StakePoolDeployed(address indexed stakeholder, address stakePool);
    event RewardsDistributed(uint256 totalRewards);
    event FiatRewardsDistributed(uint256 totalRewards, address fiatToken);

    constructor(address _daoToken) {
        daoToken = IERC20(_daoToken);
    }

    function deployStakePool(address fiatToken) external {
        require(
            stakePools[msg.sender] == address(0),
            "Stake pool already exists"
        );
        StakePool stakePool = new StakePool(address(daoToken), msg.sender);
        stakePools[msg.sender] = address(stakePool);
        stakeholders.push(msg.sender);
        emit StakePoolDeployed(msg.sender, address(stakePool));
    }

    function getStakePool(address stakeholder) external view returns (address) {
        return stakePools[stakeholder];
    }

    function distributeRewards(uint256 totalRewards) external onlyOwner {
        uint256 totalStaked = getTotalStaked();

        for (uint256 i = 0; i < stakeholders.length; i++) {
            address stakeholder = stakeholders[i];
            uint256 stake = StakePool(stakePools[stakeholder]).totalStaked();
            uint256 reward = (stake * totalRewards) / totalStaked;
            StakePool(stakePools[stakeholder]).receiveRewards(reward);
        }

        emit RewardsDistributed(totalRewards);
    }

    function distributeFiatRewards(
        uint256 totalRewards,
        address fiatToken
    ) external onlyOwner {
        uint256 totalStaked = getTotalStaked();

        for (uint256 i = 0; i < stakeholders.length; i++) {
            address stakeholder = stakeholders[i];
            uint256 stake = StakePool(stakePools[stakeholder]).totalStaked();
            uint256 reward = (stake * totalRewards) / totalStaked;
            fiatRewards[stakeholder][fiatToken] += reward;
        }

        emit FiatRewardsDistributed(totalRewards, fiatToken);
    }

    function claimFiatRewards(address fiatToken) external {
        uint256 reward = fiatRewards[msg.sender][fiatToken];
        require(reward > 0, "No rewards to claim");
        fiatRewards[msg.sender][fiatToken] = 0;
        IERC20(fiatToken).transfer(msg.sender, reward);
    }

    function addSupportedFiatToken(address fiatToken) external onlyOwner {
        supportedFiatTokens.push(fiatToken);
    }

    function getTotalStaked() internal view returns (uint256) {
        uint256 totalStaked = 0;
        for (uint256 i = 0; i < stakeholders.length; i++) {
            totalStaked += StakePool(stakePools[stakeholders[i]]).totalStaked();
        }
        return totalStaked;
    }
}

contract StakePool is Ownable {
    IERC20 public daoToken;

    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lockDuration;
        bool isCompound;
    }

    StakeInfo[] public stakes;
    uint256 public totalStaked;
    uint256 public totalDGYMRewards;

    mapping(address => uint256) public dGYMRewards;

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

    constructor(address _daoToken, address owner) {
        daoToken = IERC20(_daoToken);
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

    function claimDGYMRewards() external onlyOwner {
        uint256 reward = dGYMRewards[msg.sender];
        require(reward > 0, "No rewards to claim");
        dGYMRewards[msg.sender] = 0;
        daoToken.transfer(msg.sender, reward);
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
