// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../user/VoucherNFT.sol";
import "../gym/GymNFT.sol";

/**
 * @title Checkin
 * @dev Manages user check-ins to gyms
 */
contract Checkin is Ownable, ReentrancyGuard {
    // References to other contracts
    VoucherNFT public voucherNFT;
    GymNFT public gymNFT;

    // Mapping from voucher ID to timestamp of last check-in
    mapping(uint256 => uint256) public lastCheckinTime;

    // Minimum time between check-ins (in seconds)
    uint256 public minTimeBetweenCheckins;

    // Events
    event CheckinCompleted(
        uint256 indexed voucherId,
        uint256 indexed gymId,
        uint256 timestamp
    );
    event MinTimeBetweenCheckinsUpdated(uint256 oldValue, uint256 newValue);

    /**
     * @dev Constructor
     * @param _voucherNFT Address of the VoucherNFT contract
     * @param _gymNFT Address of the GymNFT contract
     */
    constructor(address _voucherNFT, address _gymNFT) Ownable(msg.sender) {
        voucherNFT = VoucherNFT(_voucherNFT);
        gymNFT = GymNFT(_gymNFT);
        minTimeBetweenCheckins = 6 hours; // Atualizado para padrão 6 horas
    }

    /**
     * @dev Verifica se um voucher pode fazer check-in
     * @param voucherId ID do voucher
     * @return true se o check-in é permitido
     */
    function canCheckIn(uint256 voucherId) public view returns (bool) {
        if (lastCheckinTime[voucherId] == 0) {
            return true; // Primeiro check-in
        }

        return
            block.timestamp >=
            lastCheckinTime[voucherId] + minTimeBetweenCheckins;
    }

    /**
     * @dev Updates the minimum time required between check-ins
     * @param _minTime New minimum time in seconds
     */
    function setMinTimeBetweenCheckins(uint256 _minTime) external onlyOwner {
        uint256 oldValue = minTimeBetweenCheckins;
        minTimeBetweenCheckins = _minTime;
        emit MinTimeBetweenCheckinsUpdated(oldValue, _minTime);
    }

    /**
     * @dev Processes a check-in request
     * @param voucherId ID of the user's voucher
     * @param gymId ID of the gym
     * @return success True if check-in was successful
     */
    function checkin(
        uint256 voucherId,
        uint256 gymId
    ) external nonReentrant returns (bool success) {
        // Verify the caller is the owner of the voucher
        require(
            voucherNFT.ownerOf(voucherId) == msg.sender,
            "Not the voucher owner"
        );

        // Validate the voucher
        require(
            voucherNFT.validateVoucher(voucherId),
            "Invalid or expired voucher"
        );

        // Check time constraints
        require(
            block.timestamp >=
                lastCheckinTime[voucherId] + minTimeBetweenCheckins,
            "Must wait minimum time between check-ins"
        );

        // Get gym tier
        uint8 gymTier = gymNFT.getCurrentTier(gymId);

        // Check if user has enough DCP for this gym
        require(
            voucherNFT.hasSufficientDCP(voucherId, gymTier),
            "Insufficient DCP for this gym"
        );

        // Check if user has not reached daily limit for this gym
        // This is now handled inside the VoucherNFT contract

        // Update last check-in time
        lastCheckinTime[voucherId] = block.timestamp;

        // Request check-in in VoucherNFT (this will handle DCP deduction and check-in record)
        require(
            voucherNFT.requestCheckIn(voucherId, gymId),
            "Check-in processing failed"
        );

        emit CheckinCompleted(voucherId, gymId, block.timestamp);
        return true;
    }

    /**
     * @dev Checks if a voucher is eligible for check-in
     * @param voucherId ID of the user's voucher
     * @return canCheckIn True if the voucher is eligible for check-in
     * @return timeRemaining Time remaining until eligible if not currently eligible
     */
    function checkEligibility(
        uint256 voucherId
    ) public view returns (bool canCheckIn, uint256 timeRemaining) {
        // Verify the caller is the owner of the voucher
        require(
            voucherNFT.ownerOf(voucherId) == msg.sender,
            "Not the voucher owner"
        );

        // Validate the voucher
        bool isValid = voucherNFT.validateVoucher(voucherId);
        if (!isValid) {
            return (false, 0);
        }

        // Check time constraints
        uint256 nextEligibleTime = lastCheckinTime[voucherId] +
            minTimeBetweenCheckins;
        if (block.timestamp < nextEligibleTime) {
            return (false, nextEligibleTime - block.timestamp);
        }

        // If we got here, the voucher is eligible for check-in
        return (true, 0);
    }
}
