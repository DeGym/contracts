// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./VoucherManager.sol";
import "./GymManager.sol";
import "./StakeManager.sol";
import "./Treasury.sol";
import "./Token.sol";

contract Governance is Ownable {
    GymManager public gymManager;
    StakeManager public stakeManager;
    Treasury public treasury;
    Token public daoToken;

    event ListingFactorChanged(uint256 newListingFactor);
    event DecayConstantChanged(uint256 newDecayConstant);
    event MaxSupplyChanged(uint256 newMaxSupply);
    event VoucherManagerBasePriceChanged(
        address voucherManager,
        uint256 newBasePrice
    );

    constructor(
        address _gymManager,
        address _stakeManager,
        address _treasury,
        address _daoToken
    ) {
        gymManager = GymManager(_gymManager);
        stakeManager = StakeManager(_stakeManager);
        treasury = Treasury(_treasury);
        daoToken = Token(_daoToken);
    }

    function changeListingFactor(uint256 newListingFactor) external onlyOwner {
        gymManager.setListingFactor(newListingFactor);
        emit ListingFactorChanged(newListingFactor);
    }

    function changeDecayConstant(uint256 newDecayConstant) external onlyOwner {
        treasury.setDecayConstant(newDecayConstant);
        emit DecayConstantChanged(newDecayConstant);
    }

    function changeMaxSupply(uint256 newMaxSupply) external onlyOwner {
        daoToken.setMaxSupply(newMaxSupply);
        emit MaxSupplyChanged(newMaxSupply);
    }

    function changeVoucherManagerBasePrice(
        address voucherManagerAddress,
        uint256 newBasePrice
    ) external onlyOwner {
        VoucherManager(voucherManagerAddress).setBasePrice(newBasePrice);
        emit VoucherManagerBasePriceChanged(
            voucherManagerAddress,
            newBasePrice
        );
    }
}
