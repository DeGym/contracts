// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IProviderCertificate {
    function validateCertificate(uint256 tokenId) external view returns (bool);
    function getTier(uint256 tokenId) external view returns (uint256);
}

interface IVoucher {
    function checkin(
        uint256 voucherId,
        uint256 gymId,
        uint256 dcpUsed
    ) external;
}

contract Checkin is Ownable {
    IProviderCertificate public providerCertificate;
    IVoucher public voucher;

    event CheckinSuccessful(
        uint256 voucherId,
        uint256 certificateId,
        uint256 tier
    );

    constructor(address providerCertificateAddress, address voucherAddress) {
        providerCertificate = IProviderCertificate(providerCertificateAddress);
        voucher = IVoucher(voucherAddress);
    }

    function checkin(
        uint256 voucherId,
        uint256 certificateId,
        uint256 dcpUsed
    ) public {
        require(
            providerCertificate.validateCertificate(certificateId),
            "Provider certificate is not active"
        );
        uint256 tier = providerCertificate.getTier(certificateId);
        voucher.checkin(voucherId, tier, dcpUsed);
        emit CheckinSuccessful(voucherId, certificateId, tier);
    }
}
