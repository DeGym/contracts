// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import {StakeManager} from "./StakeManager.sol";
import {DeGymToken} from "../token/DGYM.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract BondPool is Ownable {
    using SafeERC20 for DeGymToken;

    struct Bond {
        uint256 amount;
        uint256 lockDuration;
        uint256 startTime;
        uint256 endTime;
        uint256 lastUpdateTime;
        uint256 rewardDebt;
        bool isCompound;
    }

    StakeManager public immutable stakeManager;
    DeGymToken public immutable token;

    Bond[] public bonds;
    uint256 public totalBondWeight;

    event Bonded(
        uint256 bondIndex,
        uint256 amount,
        uint256 lockDuration,
        bool isCompound
    );
    event Unbonded(uint256 bondIndex, uint256 amount);
    event RewardClaimed(uint256 bondIndex, uint256 reward);
    event BondExtended(uint256 bondIndex, uint256 additionalDuration);
    event BondIncreased(uint256 bondIndex, uint256 additionalAmount);

    constructor(
        address _owner,
        address _stakeManager,
        DeGymToken _token
    ) Ownable(_owner) {
        stakeManager = StakeManager(_stakeManager);
        token = _token;
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
                rewardDebt: 0,
                isCompound: true // All bonds are now auto-compound by default
            })
        );

        stakeManager.notifyWeightChange(totalBondWeight);
        stakeManager.notifyStakeChange(_amount, true);

        emit Bonded(bonds.length - 1, _amount, _lockDuration, true);
    }

    function unbond(uint256 _bondIndex) external onlyOwner {
        require(_bondIndex < bonds.length, "Invalid bond index");
        Bond storage bond = bonds[_bondIndex];
        require(block.timestamp >= bond.endTime, "Lock period not ended");

        uint256 amount = bond.amount + bond.rewardDebt;
        uint256 weight = calculateWeight(amount, 0);
        totalBondWeight -= weight;

        token.safeTransfer(msg.sender, bond.amount);
        stakeManager.claimReward(msg.sender, bond.rewardDebt);

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

    function updateRewards(uint256 _rewardAmount) external onlyStakeManager {
        if (totalBondWeight == 0) return;

        for (uint256 i = 0; i < bonds.length; i++) {
            Bond storage bond = bonds[i];
            uint256 weight = calculateWeight(
                bond.amount + bond.rewardDebt,
                bond.endTime - block.timestamp
            );
            uint256 reward = (_rewardAmount * weight) / totalBondWeight;
            bond.rewardDebt += reward;

            uint256 oldWeight = calculateWeight(
                bond.amount + bond.rewardDebt - reward,
                bond.endTime - block.timestamp
            );
            uint256 newWeight = calculateWeight(
                bond.amount + bond.rewardDebt,
                bond.endTime - block.timestamp
            );
            totalBondWeight = totalBondWeight - oldWeight + newWeight;
        }

        stakeManager.notifyWeightChange(totalBondWeight);
    }

    function getTotalBondWeight() external view returns (uint256) {
        return totalBondWeight;
    }

    function getBondsCount() external view returns (uint256) {
        return bonds.length;
    }
}
