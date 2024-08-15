// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import {StakeManager} from "./StakeManager.sol";
import {DeGymToken} from "../token/DGYM.sol";

contract BondPool {
    using SafeERC20 for DeGymToken;

    struct Bond {
        uint256 amount;
        uint256 lockDuration;
        uint256 startTime;
        uint256 endTime;
        uint256 lastUpdateTime;
        uint256 rewardDebt;
    }

    address public immutable owner;
    StakeManager public immutable stakeManager;
    DeGymToken public immutable token;

    Bond[] public bonds;
    uint256 public totalBondWeight;

    event Bonded(uint256 amount, uint256 lockDuration);
    event Unbonded(uint256 bondIndex, uint256 amount);
    event RewardClaimed(uint256 bondIndex, uint256 reward);
    event BondExtended(uint256 bondIndex, uint256 additionalDuration);
    event BondIncreased(uint256 bondIndex, uint256 additionalAmount);

    constructor(address _owner, address _stakeManager, DeGymToken _token) {
        owner = _owner;
        stakeManager = StakeManager(_stakeManager);
        token = _token;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyStakeManager() {
        require(
            msg.sender == address(stakeManager),
            "Only StakeManager can call this function"
        );
        _;
    }

    function bond(uint256 _amount, uint256 _lockDuration) external onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");

        token.safeTransferFrom(msg.sender, address(this), _amount);

        uint256 endTime = block.timestamp + _lockDuration;
        uint256 weight = calculateWeight(_amount, _lockDuration);
        totalBondWeight += weight;

        bonds.push(
            Bond({
                amount: _amount,
                lockDuration: _lockDuration,
                startTime: block.timestamp,
                endTime: endTime,
                lastUpdateTime: block.timestamp,
                rewardDebt: 0
            })
        );

        stakeManager.notifyWeightChange(totalBondWeight);
        stakeManager.notifyStakeChange(totalBondWeight, true);

        emit Bonded(_amount, _lockDuration);
    }

    function unbond(uint256 _bondIndex) external onlyOwner {
        require(_bondIndex < bonds.length, "Invalid bond index");
        Bond storage bond = bonds[_bondIndex];
        require(block.timestamp >= bond.endTime, "Lock period not ended");

        uint256 amount = bond.amount;
        uint256 weight = calculateWeight(
            bond.amount,
            bond.endTime - block.timestamp
        );
        totalBondWeight -= weight;

        token.safeTransfer(msg.sender, amount);

        // Remove the bond by swapping with the last element and popping
        bonds[_bondIndex] = bonds[bonds.length - 1];
        bonds.pop();

        stakeManager.notifyWeightChange(totalBondWeight);
        stakeManager.notifyStakeChange(amount, false);

        emit Unbonded(_bondIndex, amount);
    }

    function calculateWeight(
        uint256 _amount,
        uint256 _remainingLockDuration
    ) public pure returns (uint256) {
        return _amount * Math.log2(_remainingLockDuration + 1 days);
    }

    function extendBondPeriod(
        uint256 _bondIndex,
        uint256 _additionalDuration
    ) external onlyOwner {
        require(_bondIndex < bonds.length, "Invalid bond index");
        Bond storage bond = bonds[_bondIndex];
        require(block.timestamp < bond.endTime, "Bond has already ended");

        uint256 oldWeight = calculateWeight(
            bond.amount,
            bond.endTime - block.timestamp
        );
        bond.endTime += _additionalDuration;
        bond.lockDuration += _additionalDuration;
        uint256 newWeight = calculateWeight(
            bond.amount,
            bond.endTime - block.timestamp
        );

        totalBondWeight = totalBondWeight - oldWeight + newWeight;
        stakeManager.notifyWeightChange(totalBondWeight);

        emit BondExtended(_bondIndex, _additionalDuration);
    }

    function addToBond(
        uint256 _bondIndex,
        uint256 _additionalAmount
    ) external onlyOwner {
        require(_bondIndex < bonds.length, "Invalid bond index");
        Bond storage bond = bonds[_bondIndex];
        require(block.timestamp < bond.endTime, "Bond has already ended");

        uint256 oldWeight = calculateWeight(
            bond.amount,
            bond.endTime - block.timestamp
        );
        bond.amount += _additionalAmount;
        uint256 newWeight = calculateWeight(
            bond.amount,
            bond.endTime - block.timestamp
        );

        totalBondWeight = totalBondWeight - oldWeight + newWeight;
        stakeManager.notifyWeightChange(totalBondWeight);
        stakeManager.notifyStakeChange(_additionalAmount, true);

        token.safeTransferFrom(msg.sender, address(this), _additionalAmount);

        emit BondIncreased(_bondIndex, _additionalAmount);
    }

    function getTotalBondWeight() external view returns (uint256) {
        return totalBondWeight;
    }

    function getBondsCount() external view returns (uint256) {
        return bonds.length;
    }

    function updateRewards(uint256 _rewardAmount) external onlyStakeManager {
        if (totalBondWeight == 0) return;

        for (uint256 i = 0; i < bonds.length; i++) {
            Bond storage bond = bonds[i];
            uint256 weight = calculateWeight(
                bond.amount,
                bond.endTime - block.timestamp
            );
            uint256 reward = (_rewardAmount * weight) / totalBondWeight;
            bond.rewardDebt += reward;
        }
    }

    function claimReward(
        uint256 _bondIndex
    ) external onlyOwner returns (uint256) {
        require(_bondIndex < bonds.length, "Invalid bond index");
        Bond storage bond = bonds[_bondIndex];

        uint256 reward = bond.rewardDebt;
        bond.rewardDebt = 0;

        if (reward > 0) {
            emit RewardClaimed(_bondIndex, reward);
        }

        return reward;
    }
}
