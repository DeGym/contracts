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
    address[] public stakeholders;
    uint256 public totalStaked;
    uint256 public totalBondWeight;
    uint256 public lastUpdateTime;

    uint256 public constant DECAY_CONSTANT = 46; // 0.046% daily decay
    uint256 public constant BASIS_POINTS = 10000;

    event BondPoolDeployed(address indexed stakeholder, address bondPool);
    event RewardsDistributed(uint256 totalReward);

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
        stakeholders.push(msg.sender);
        emit BondPoolDeployed(msg.sender, address(bondPool));
    }

    function calculateInflationRate() public view returns (uint256) {
        uint256 currentSupply = token.totalSupply();
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

    function bond(uint256 _amount, uint256 _lockDuration) external {
        require(
            bondPools[msg.sender] != address(0),
            "Deploy a bond pool first"
        );
        updateRewards();

        BondPool bondPool = BondPool(bondPools[msg.sender]);
        uint256 oldWeight = bondPool.getTotalBondWeight();

        token.safeTransferFrom(msg.sender, address(bondPool), _amount);
        bondPool.bond(_amount, _lockDuration);

        uint256 newWeight = bondPool.getTotalBondWeight();
        totalBondWeight = totalBondWeight - oldWeight + newWeight;
        totalStaked += _amount;
    }

    function unbond(uint256 _bondIndex) external {
        require(bondPools[msg.sender] != address(0), "No bond pool found");
        updateRewards();

        BondPool bondPool = BondPool(bondPools[msg.sender]);
        uint256 oldWeight = bondPool.getTotalBondWeight();
        uint256 oldBondsCount = bondPool.getBondsCount();

        bondPool.unbond(_bondIndex);

        uint256 newWeight = bondPool.getTotalBondWeight();
        uint256 newBondsCount = bondPool.getBondsCount();
        totalBondWeight = totalBondWeight - oldWeight + newWeight;
        totalStaked -= (oldBondsCount - newBondsCount);
    }

    function claimReward(uint256 _bondIndex) external {
        require(bondPools[msg.sender] != address(0), "No bond pool found");
        updateRewards();

        BondPool bondPool = BondPool(bondPools[msg.sender]);
        bondPool.claimReward(_bondIndex);
    }

    function getTotalBondWeight() external view returns (uint256) {
        return totalBondWeight;
    }

    function getStakeholderCount() external view returns (uint256) {
        return stakeholders.length;
    }
}
