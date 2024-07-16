// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./VoucherManager.sol";
import "./GymManager.sol";
import "./StakeManager.sol";
import "./Treasury.sol";

contract Governance is Ownable {
    VoucherManager public voucherManager;
    GymManager public gymManager;
    StakeManager public stakeManager;
    Treasury public treasury;

    event BasePriceChanged(uint256 newBasePrice);
    event ListingFactorChanged(uint256 newListingFactor);
    event DecayConstantChanged(uint256 newDecayConstant);
    event VoucherManagerBasePriceChanged(
        address voucherManager,
        uint256 newBasePrice
    );
    event TreasuryInflationParamsChanged(
        uint256 newDecayConstant,
        uint256 newMaxSupply
    );

    constructor(
        address _voucherManager,
        address _gymManager,
        address _stakeManager,
        address _treasury
    ) {
        voucherManager = VoucherManager(_voucherManager);
        gymManager = GymManager(_gymManager);
        stakeManager = StakeManager(_stakeManager);
        treasury = Treasury(_treasury);
    }

    function changeBasePrice(uint256 newBasePrice) external onlyOwner {
        voucherManager.setBasePrice(newBasePrice);
        gymManager.setBasePrice(newBasePrice);
        emit BasePriceChanged(newBasePrice);
    }

    function changeListingFactor(uint256 newListingFactor) external onlyOwner {
        gymManager.setListingFactor(newListingFactor);
        emit ListingFactorChanged(newListingFactor);
    }

    function changeDecayConstant(uint256 newDecayConstant) external onlyOwner {
        stakeManager.setDecayConstant(newDecayConstant);
        treasury.setDecayConstant(newDecayConstant);
        emit DecayConstantChanged(newDecayConstant);
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

    function changeTreasuryInflationParams(
        uint256 newDecayConstant,
        uint256 newMaxSupply
    ) external onlyOwner {
        treasury.setDecayConstant(newDecayConstant);
        treasury.setMaxSupply(newMaxSupply);
        emit TreasuryInflationParamsChanged(newDecayConstant, newMaxSupply);
    }
}
