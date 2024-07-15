// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./GymManager.sol";
import "./VoucherManager.sol";
import "./StakeManager.sol";

contract Checkin is Ownable {
    GymManager public gymManager;
    VoucherManager public voucherManager;
    StakeManager public stakeManager;

    event CheckinSuccessful(uint256 voucherId, uint256 gymId, uint256 tier);

    constructor(
        address gymManagerAddress,
        address voucherManagerAddress,
        address stakeManagerAddress
    ) {
        gymManager = GymManager(gymManagerAddress);
        voucherManager = VoucherManager(voucherManagerAddress);
        stakeManager = StakeManager(stakeManagerAddress);
    }

    function checkin(uint256 voucherId, uint256 gymId, uint256 dcpUsed) public {
        VoucherManager.VoucherDetails memory voucher = voucherManager
            .getVoucherDetails(voucherId);
        GymManager.GymDetails memory gym = gymManager.getGymDetails(gymId);

        require(voucher.tier >= gym.tier, "Voucher tier too low");
        require(
            gym.acceptsFiatToken(voucherManager.fiatToken()),
            "Gym does not accept voucher fiat token"
        );
        require(
            stakeManager.validateGymEligibility(gymId),
            "Gym not eligible for listing"
        );

        voucherManager.checkin(voucherId, gymId, dcpUsed);
        gymManager.recordCheckin(gymId);

        emit CheckinSuccessful(voucherId, gymId, voucher.tier);
    }
}
