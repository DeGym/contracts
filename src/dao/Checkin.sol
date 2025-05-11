// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../user/VoucherNFT.sol";
import "../gym/GymNFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Checkin
 * @dev Manages check-in validation and processing
 */
contract Checkin is Ownable {
    // References to other contracts
    VoucherNFT public voucherNFT;
    GymNFT public gymNFT;

    // Mapeamento para armazenar o último tempo de check-in por voucher
    mapping(uint256 => uint256) public lastCheckinTime;

    // Mapeamento para rastrear DCP diário usado por voucher (resetado diariamente)
    mapping(uint256 => mapping(uint256 => uint256)) private dailyDCPUsed; // voucherId => day => amount

    // Events
    event CheckinCompleted(
        uint256 indexed voucherId,
        uint256 indexed gymId,
        uint256 timestamp
    );
    event CheckinRejected(
        uint256 indexed voucherId,
        uint256 indexed gymId,
        string reason
    );

    /**
     * @dev Constructor
     * @param _voucherNFT Address of the VoucherNFT contract
     * @param _gymNFT Address of the GymNFT contract
     */
    constructor(address _voucherNFT, address _gymNFT) Ownable(msg.sender) {
        voucherNFT = VoucherNFT(_voucherNFT);
        gymNFT = GymNFT(_gymNFT);
    }

    /**
     * @dev Process a check-in
     * @param voucherId ID of the voucher
     * @param gymId ID of the gym
     * @return success True if check-in is successful
     */
    function checkin(uint256 voucherId, uint256 gymId) public returns (bool) {
        // Verificar se o chamador é o dono do voucher
        require(
            voucherNFT.ownerOf(voucherId) == msg.sender,
            "Not the voucher owner"
        );

        // Verificar se o voucher é válido
        require(voucherNFT.validateVoucher(voucherId), "Voucher is not valid");

        // Verificar se a academia existe
        require(gymNFT.ownerOf(gymId) != address(0), "Gym does not exist");

        // Atualizar timestamp do último check-in
        lastCheckinTime[voucherId] = block.timestamp;

        // Processar o check-in
        voucherNFT.requestCheckIn(voucherId, gymId);

        emit CheckinCompleted(voucherId, gymId, block.timestamp);

        return true;
    }

    /**
     * @dev Check if a user can check in
     * @param voucherId ID of the voucher
     * @return canCheckIn True if the user can check in
     * @return timeRemaining Time remaining until next check-in is allowed
     */
    function checkEligibility(
        uint256 voucherId
    ) public view returns (bool canCheckIn, uint256 timeRemaining) {
        // Verificar se o chamador é o dono do voucher
        if (voucherNFT.ownerOf(voucherId) != msg.sender) {
            return (false, 0);
        }

        // Verificar se o voucher é válido
        if (!voucherNFT.validateVoucher(voucherId)) {
            return (false, 0);
        }

        // Sempre pode fazer check-in se o voucher for válido e pertencer ao usuário
        return (true, 0);
    }

    /**
     * @dev Update VoucherNFT contract address (only owner)
     * @param _newVoucherNFT Address of the new VoucherNFT contract
     */
    function setVoucherNFT(address _newVoucherNFT) external onlyOwner {
        require(_newVoucherNFT != address(0), "Invalid address");
        voucherNFT = VoucherNFT(_newVoucherNFT);
    }

    /**
     * @dev Update GymNFT contract address (only owner)
     * @param _newGymNFT Address of the new GymNFT contract
     */
    function setGymNFT(address _newGymNFT) external onlyOwner {
        require(_newGymNFT != address(0), "Invalid address");
        gymNFT = GymNFT(_newGymNFT);
    }
}
