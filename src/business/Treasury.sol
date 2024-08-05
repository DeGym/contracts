// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./staking/StakeManager.sol";

contract Treasury is Ownable {
    StakeManager public stakeManager;
    uint256 public inflationDecayConstant;
    IERC20 public daoToken;

    event RewardsCalculated(uint256 daoRewards);

    /**
     * @dev Initializes the contract with the stake manager, decay constant, and DAO token.
     * @param _stakeManager The address of the stake manager contract.
     * @param _inflationDecayConstant The decay constant used in reward calculation.
     * @param _daoToken The address of the DAO token contract.
     */
    constructor(
        address _stakeManager,
        uint256 _inflationDecayConstant,
        address _daoToken
    ) {
        stakeManager = StakeManager(_stakeManager);
        inflationDecayConstant = _inflationDecayConstant;
        daoToken = Token(_daoToken);
    }

    /**
     * @dev Calculates and updates rewards for all stakeholders.
     * Can only be called by the contract owner.
     */
    function calculateRewards() external onlyOwner {
        uint256 claimableRewards = stakeManager.absTotalClaimableRewards();
        uint256 currentSupply = daoToken.currentSupply();
        uint256 maxSupply = daoToken.maxSupply();

        uint256 inflationRate = (inflationDecayConstant *
            (maxSupply - (currentSupply + claimableRewards))) / maxSupply;
        uint256 daoRewards = (currentSupply + claimableRewards) * inflationRate;

        stakeManager.updateRewards(daoRewards);
        emit RewardsCalculated(daoRewards);
    }

    /**
     * @dev Sets a new decay constant for reward calculation.
     * Can only be called by the contract owner.
     * @param newInflationDecayConstant The new decay constant.
     */
    function setInflationDecayConstant(
        uint256 newInflationDecayConstant
    ) external onlyOwner {
        inflationDecayConstant = newInflationDecayConstant;
    }
}
