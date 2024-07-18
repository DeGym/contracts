// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./StakeManager.sol";

contract Treasury is Ownable {
    StakeManager public stakeManager;
    uint256 public decayConstant;
    Token public daoToken;

    event RewardsCalculated(uint256 daoRewards);

    constructor(
        address _stakeManager,
        uint256 _decayConstant,
        address _daoToken
    ) {
        stakeManager = StakeManager(_stakeManager);
        decayConstant = _decayConstant;
        daoToken = Token(_daoToken);
    }

    function calculateRewards() external onlyOwner {
        uint256 totalStaked = stakeManager.totalStaked();
        uint256 unclaimedRewards = stakeManager.totalUnclaimedRewards();
        uint256 currentSupply = daoToken.currentSupply();
        uint256 maxSupply = daoToken.maxSupply();

        uint256 inflationRate = (decayConstant *
            (maxSupply - (currentSupply + unclaimedRewards))) / maxSupply;
        uint256 daoRewards = (currentSupply + unclaimedRewards) * inflationRate;

        stakeManager.updateRewards(daoRewards);
        emit RewardsCalculated(daoRewards);
    }

    function setDecayConstant(uint256 newDecayConstant) external onlyOwner {
        decayConstant = newDecayConstant;
    }
}
