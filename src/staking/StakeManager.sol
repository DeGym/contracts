// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./BondPool.sol";
import {DeGymToken} from "../token/DGYM.sol";

contract StakeManager {
    using SafeERC20 for DeGymToken;

    DeGymToken public immutable token;

    mapping(address => address) public bondPools;
    mapping(address => bool) public isBondPool;
    address[] public stakeholders;
    uint256 public totalStaked;
    uint256 public totalBondWeight;
    uint256 public lastUpdateTime;
    uint256 public totalUnclaimedRewards;

    uint256 public constant DECAY_CONSTANT = 46; // 0.046% daily decay
    uint256 public constant BASIS_POINTS = 10000;

    event BondPoolDeployed(address indexed stakeholder, address bondPool);
    event RewardsDistributed(uint256 totalReward);
    event RewardClaimed(address indexed stakeholder, uint256 amount);

    modifier onlyBondPool() {
        require(isBondPool[msg.sender], "Caller is not a valid BondPool");
        _;
    }

    constructor(address _token) {
        token = DeGymToken(_token);
        lastUpdateTime = block.timestamp;
    }

    function deployBondPool() external {
        require(
            bondPools[msg.sender] == address(0),
            "Bond pool already exists"
        );
        BondPool bondPool = new BondPool(msg.sender, address(this), token);
        bondPools[msg.sender] = address(bondPool);
        isBondPool[address(bondPool)] = true;
        stakeholders.push(msg.sender);
        emit BondPoolDeployed(msg.sender, address(bondPool));
    }

    function calculateInflationRate() public view returns (uint256) {
        uint256 currentSupply = token.totalSupply() + totalUnclaimedRewards;
        uint256 maxSupply = token.cap();
        return (DECAY_CONSTANT * (maxSupply - currentSupply)) / maxSupply;
    }

    function updateRewards() public {
        if (block.timestamp <= lastUpdateTime) return;
        if (totalStaked == 0) {
            lastUpdateTime = block.timestamp;
            return;
        }

        uint256 timePassed = block.timestamp - lastUpdateTime;
        uint256 inflationRate = calculateInflationRate();
        uint256 totalReward = (totalStaked * inflationRate * timePassed) /
            (365 days * BASIS_POINTS);

        totalUnclaimedRewards += totalReward;

        for (uint256 i = 0; i < stakeholders.length; i++) {
            address stakeholder = stakeholders[i];
            BondPool bondPool = BondPool(bondPools[stakeholder]);
            uint256 stakeholderWeight = bondPool.getTotalBondWeight();
            uint256 stakeholderReward = (totalReward * stakeholderWeight) /
                totalBondWeight;
            bondPool.updateRewards(stakeholderReward);
        }

        lastUpdateTime = block.timestamp;
        emit RewardsDistributed(totalReward);
    }

    function notifyWeightChange(uint256 _newWeight) external onlyBondPool {
        totalBondWeight = _newWeight;
    }

    function notifyStakeChange(
        uint256 _amount,
        bool _isIncrease
    ) external onlyBondPool {
        if (_isIncrease) {
            totalStaked += _amount;
        } else {
            totalStaked -= _amount;
        }
    }

    function claimReward(
        address _recipient,
        uint256 _amount
    ) external onlyBondPool {
        require(
            _amount <= totalUnclaimedRewards,
            "Insufficient unclaimed rewards"
        );

        totalUnclaimedRewards -= _amount;
        token.mint(_recipient, _amount);
        emit RewardClaimed(_recipient, _amount);
    }

    function transferToUser(
        address _user,
        uint256 _amount
    ) external onlyBondPool {
        token.safeTransfer(_user, _amount);
    }

    function getTotalBondWeight() external view returns (uint256) {
        return totalBondWeight;
    }

    function getStakeholderCount() external view returns (uint256) {
        return stakeholders.length;
    }
}
