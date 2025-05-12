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
     * @dev Realiza o check-in de um usuário em uma academia
     * @param voucherId ID do voucher do usuário
     * @param gymId ID da academia
     */
    function checkin(uint256 voucherId, uint256 gymId) public {
        // Verificar se o check-in pode ser realizado
        require(
            canCheckIn(voucherId),
            "Must wait minimum time between check-ins"
        );

        // Obter o tier da academia
        uint8 gymTier = gymNFT.getTier(gymId);

        // Verificar se o voucher tem DCP suficiente
        require(
            voucherNFT.hasSufficientDCP(voucherId, gymTier),
            "Insufficient DCP for this gym"
        );

        // Calcular o DCP necessário (2^gymTier)
        uint256 dcpRequired = 1 << gymTier;

        // Consumir o DCP do VoucherNFT
        voucherNFT.consumeDCP(voucherId, dcpRequired);

        // Obter o token associado ao voucher
        address tokenUsed = voucherNFT.getTokenUsed(voucherId);

        // Transferir o DCP para a academia
        gymNFT.receiveDCP(gymId, tokenUsed, dcpRequired);

        // Registrar o check-in no histórico do voucher
        voucherNFT.registerCheckIn(voucherId, gymId);

        // Atualizar o timestamp do último check-in
        lastCheckinTime[voucherId] = block.timestamp;

        emit CheckinCompleted(voucherId, gymId, block.timestamp);
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
