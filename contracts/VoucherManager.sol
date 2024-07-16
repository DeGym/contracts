// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VoucherManager is ERC721URIStorage, Ownable {
    struct VoucherDetails {
        uint256 tier;
        uint256 duration; // in days
        uint256 remainingDCP;
        uint256 lastReset;
        string timezone;
        uint256 dailyAccessLimit;
    }
    struct CheckinEntry {
        uint256 dcpUsed;
        uint256 tierNumber;
        uint256 gymId;
        uint256 timestamp;
    }

    IERC20 public fiatToken;
    uint256 public nextVoucherId;
    uint256 public basePrice = 15 * 10 ** 18; // Assuming base price in fiat token decimals

    mapping(uint256 => VoucherDetails) public vouchers;
    mapping(uint256 => CheckinEntry[]) public dailyLedger; // voucherId to daily entries

    event VoucherUpgraded(uint256 voucherId, uint256 newTier);
    event VoucherRenewed(uint256 voucherId, uint256 additionalDays);
    event VoucherDowngraded(uint256 voucherId, uint256 newTier);

    constructor(address fiatTokenAddress) ERC721("Voucher", "VCH") {
        fiatToken = IERC20(fiatTokenAddress);
    }

    function purchaseVoucher(
        address owner,
        uint256 tier,
        uint256 duration,
        string memory timezone
    ) public onlyOwner {
        uint256 voucherId = nextVoucherId++;
        _mint(owner, voucherId);
        vouchers[voucherId] = VoucherDetails({
            tier: tier,
            duration: duration,
            remainingDCP: 2 ** tier,
            lastReset: block.timestamp,
            timezone: timezone,
            dailyAccessLimit: 0
        });
        _setTokenURI(voucherId, "");
    }

    function upgradeVoucher(uint256 voucherId, uint256 newTier) public payable {
        require(
            _isApprovedOrOwner(_msgSender(), voucherId),
            "Caller is not owner nor approved"
        );
        require(newTier > vouchers[voucherId].tier, "New tier must be higher");

        VoucherDetails storage voucher = vouchers[voucherId];
        uint256 currentTier = voucher.tier;
        uint256 remainingDCP = voucher.remainingDCP;

        uint256 price = (((remainingDCP * (2 ** (newTier - currentTier))) /
            (2 ** currentTier)) * basePrice) / (2 ** 30);
        require(msg.value >= price, "Insufficient funds for upgrade");

        voucher.tier = newTier;
        voucher.remainingDCP = remainingDCP * (2 ** (newTier - currentTier));

        emit VoucherUpgraded(voucherId, newTier);
    }

    function renewVoucher(
        uint256 voucherId,
        uint256 additionalDays
    ) public payable {
        require(
            _isApprovedOrOwner(_msgSender(), voucherId),
            "Caller is not owner nor approved"
        );

        VoucherDetails storage voucher = vouchers[voucherId];
        uint256 price = (voucher.remainingDCP * additionalDays * basePrice) /
            (voucher.duration * (2 ** 30));
        require(msg.value >= price, "Insufficient funds for renewal");

        voucher.duration += additionalDays;

        emit VoucherRenewed(voucherId, additionalDays);
    }

    function downgradeVoucher(uint256 voucherId, uint256 newTier) public {
        require(
            _isApprovedOrOwner(_msgSender(), voucherId),
            "Caller is not owner nor approved"
        );
        require(newTier < vouchers[voucherId].tier, "New tier must be lower");

        VoucherDetails storage voucher = vouchers[voucherId];
        uint256 remainingDCP = voucher.remainingDCP;

        voucher.tier = newTier;
        voucher.remainingDCP = remainingDCP / (2 ** (voucher.tier - newTier));
        voucher.duration = (voucher.duration * (2 ** (voucher.tier - newTier)));

        emit VoucherDowngraded(voucherId, newTier);
    }

    function getVoucherDetails(
        uint256 voucherId
    ) public view returns (VoucherDetails memory) {
        return vouchers[voucherId];
    }

    function setBasePrice(uint256 _basePrice) external onlyOwner {
        basePrice = _basePrice;
    }

    function setListingFactor(uint256 _listingFactor) external onlyOwner {
        // Implementation to set listing factor
    }
}
