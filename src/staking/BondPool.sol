// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract BondPool {
    using SafeERC20 for IERC20;

    struct Bond {
        uint256 amount;
        uint256 lockDuration;
        uint256 startTime;
        uint256 lastUpdateTime;
        uint256 rewardDebt;
    }

    address public immutable owner;
    address public immutable stakeManager;
    IERC20 public immutable dgymToken;

    Bond[] public bonds;
    uint256 public totalBondWeight;

    event Bonded(uint256 amount, uint256 lockDuration);
    event Unbonded(uint256 bondIndex, uint256 amount);
    event RewardClaimed(uint256 bondIndex, uint256 reward);

    constructor(address _owner, address _stakeManager, IERC20 _dgymToken) {
        owner = _owner;
        stakeManager = _stakeManager;
        dgymToken = _dgymToken;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyStakeManager() {
        require(
            msg.sender == stakeManager,
            "Only StakeManager can call this function"
        );
        _;
    }

    function bond(uint256 _amount, uint256 _lockDuration) external onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");

        dgymToken.safeTransferFrom(msg.sender, address(this), _amount);

        uint256 weight = calculateWeight(_amount, _lockDuration);
        totalBondWeight += weight;

        bonds.push(
            Bond({
                amount: _amount,
                lockDuration: _lockDuration,
                startTime: block.timestamp,
                lastUpdateTime: block.timestamp,
                rewardDebt: 0
            })
        );

        emit Bonded(_amount, _lockDuration);
    }

    function unbond(uint256 _bondIndex) external onlyOwner {
        require(_bondIndex < bonds.length, "Invalid bond index");
        Bond storage bond = bonds[_bondIndex];
        require(
            block.timestamp >= bond.startTime + bond.lockDuration,
            "Lock period not ended"
        );

        uint256 amount = bond.amount;
        uint256 weight = calculateWeight(bond.amount, bond.lockDuration);
        totalBondWeight -= weight;

        dgymToken.safeTransfer(msg.sender, amount);

        // Remove the bond by swapping with the last element and popping
        bonds[_bondIndex] = bonds[bonds.length - 1];
        bonds.pop();

        emit Unbonded(_bondIndex, amount);
    }

    function calculateWeight(
        uint256 _amount,
        uint256 _lockDuration
    ) public pure returns (uint256) {
        return _amount * Math.log2(_lockDuration + 1 days);
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
            uint256 weight = calculateWeight(bond.amount, bond.lockDuration);
            uint256 reward = (_rewardAmount * weight) / totalBondWeight;
            bond.rewardDebt += reward;
        }
    }

    function claimReward(uint256 _bondIndex) external onlyOwner {
        require(_bondIndex < bonds.length, "Invalid bond index");
        Bond storage bond = bonds[_bondIndex];

        uint256 reward = bond.rewardDebt;
        bond.rewardDebt = 0;

        if (reward > 0) {
            dgymToken.safeTransfer(msg.sender, reward);
            emit RewardClaimed(_bondIndex, reward);
        }
    }
}
