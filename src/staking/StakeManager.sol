// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./BondPool.sol";
import {DeGymToken} from "../token/DGYM.sol";

contract StakeManager is AccessControl {
    using SafeERC20 for DeGymToken;

    DeGymToken public immutable token;

    mapping(address => address) public bondPools;
    address[] public stakeholders;
    uint256 public totalStaked;
    uint256 public totalBondWeight;
    uint256 public lastUpdateTime;
    uint256 public totalUnclaimedRewards;

    uint256 public decayConstant;
    uint256 public basisPoints;

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant BOND_POOL_ROLE = keccak256("BOND_POOL_ROLE");

    event BondPoolDeployed(address indexed stakeholder, address bondPool);
    event RewardsDistributed(uint256 totalReward);
    event RewardClaimed(address indexed stakeholder, uint256 amount);
    event DecayConstantUpdated(uint256 newValue);
    event BasisPointsUpdated(uint256 newValue);

    constructor(address _token, address _timelock) {
        token = DeGymToken(_token);
        lastUpdateTime = block.timestamp;
        decayConstant = 46; // Initial value: 0.046% daily decay
        basisPoints = 10000; // Initial value: 10000
        _grantRole(GOVERNOR_ROLE, _timelock);
    }

    function deployBondPool() external {
        require(
            bondPools[msg.sender] == address(0),
            "Bond pool already exists"
        );
        BondPool bondPool = new BondPool(msg.sender, address(this), token);
        bondPools[msg.sender] = address(bondPool);
        _grantRole(BOND_POOL_ROLE, address(bondPool));
        stakeholders.push(msg.sender);
        emit BondPoolDeployed(msg.sender, address(bondPool));
    }

    function calculateInflationRate() public view returns (uint256) {
        uint256 currentSupply = token.totalSupply() + totalUnclaimedRewards;
        uint256 maxSupply = token.cap();
        return (decayConstant * (maxSupply - currentSupply)) / maxSupply;
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
            (365 days * basisPoints);

        totalUnclaimedRewards += totalReward;

        for (uint256 i = 0; i < stakeholders.length; i++) {
            address stakeholder = stakeholders[i];
            BondPool bondPool = BondPool(bondPools[stakeholder]);
            uint256 stakeholderWeight = bondPool.getTotalBondWeight();
            if (totalBondWeight > 0) {
                uint256 stakeholderReward = (totalReward * stakeholderWeight) /
                    totalBondWeight;
                bondPool.updateRewards(stakeholderReward);
            }
        }

        lastUpdateTime = block.timestamp;
        emit RewardsDistributed(totalReward);
    }

    function notifyWeightChange(
        uint256 _newWeight
    ) external onlyRole(BOND_POOL_ROLE) {
        totalBondWeight = _newWeight;
    }

    function notifyStakeChange(
        uint256 _amount,
        bool _isIncrease
    ) external onlyRole(BOND_POOL_ROLE) {
        if (_isIncrease) {
            totalStaked += _amount;
        } else {
            totalStaked -= _amount;
        }
    }

    function claimReward(
        address _recipient,
        uint256 _amount
    ) external onlyRole(BOND_POOL_ROLE) {
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
    ) external onlyRole(BOND_POOL_ROLE) {
        token.safeTransfer(_user, _amount);
    }

    function getTotalBondWeight() external view returns (uint256) {
        return totalBondWeight;
    }

    function getStakeholderCount() external view returns (uint256) {
        return stakeholders.length;
    }

    function setDecayConstant(
        uint256 _newValue
    ) external onlyRole(GOVERNOR_ROLE) {
        decayConstant = _newValue;
        emit DecayConstantUpdated(_newValue);
    }

    function setBasisPoints(
        uint256 _newValue
    ) external onlyRole(GOVERNOR_ROLE) {
        basisPoints = _newValue;
        emit BasisPointsUpdated(_newValue);
    }
}
