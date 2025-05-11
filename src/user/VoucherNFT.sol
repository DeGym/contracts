// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../treasury/Treasury.sol";
import "../gym/GymManager.sol";
import "../gym/GymNFT.sol";

/**
 * @title VoucherNFT
 * @dev NFT representing gym membership vouchers in the DeGym ecosystem
 */
contract VoucherNFT is ERC721Enumerable, Ownable {
    // References to other contracts
    Treasury public treasury;
    GymManager public gymManager;
    GymNFT public gymNFT;

    // Voucher structure
    struct Voucher {
        uint256 tier;
        uint256 duration;
        string timezone;
        uint256 expiryTime;
        address tokenAddress;
        uint256 dcpBalance;
        bool isActive;
    }

    // Check-in structure
    struct CheckIn {
        uint256 gymId;
        uint256 timestamp;
        uint256 dcpAmount;
    }

    // Mapping from voucherId to Voucher details
    mapping(uint256 => Voucher) public vouchers;

    // Mapping from voucherId to check-in history
    mapping(uint256 => CheckIn[]) public checkInHistory;

    // Counter for voucher IDs
    uint256 private _nextVoucherId = 1;

    // Events
    event VoucherCreated(
        uint256 indexed voucherId,
        address indexed owner,
        uint256 tier
    );
    event VoucherRenewed(uint256 indexed voucherId, uint256 newExpiry);
    event CheckInCreated(
        uint256 indexed voucherId,
        uint256 indexed gymId,
        uint256 timestamp
    );

    /**
     * @dev Constructor
     * @param _treasury Address of the Treasury contract
     * @param _gymManager Address of the GymManager contract
     * @param _gymNFT Address of the GymNFT contract
     */
    constructor(
        address _treasury,
        address _gymManager,
        address _gymNFT
    ) ERC721("DeGym Membership Voucher", "DGYMV") Ownable(msg.sender) {
        treasury = Treasury(_treasury);
        gymManager = GymManager(_gymManager);
        gymNFT = GymNFT(_gymNFT);
    }

    /**
     * @dev Mint a new voucher
     * @param tier Tier level of the voucher (1-100)
     * @param duration Duration in days
     * @param timezone User's timezone for renewal
     * @param tokenAddress Address of the token used for payment
     * @return voucherId The ID of the newly minted voucher
     */
    function mint(
        uint256 tier,
        uint256 duration,
        string memory timezone,
        address tokenAddress
    ) external returns (uint256 voucherId) {
        // Calculate price
        uint256 price = treasury.calculatePrice(tokenAddress, tier, duration);

        require(treasury.validateToken(tokenAddress), "Invalid token");
        require(
            treasury.validateTokenPayment(msg.sender, tokenAddress, price),
            "Payment failed"
        );

        voucherId = _nextVoucherId++;
        _mint(msg.sender, voucherId);

        uint256 dcpBalance = generateDCP(tier, duration, timezone);

        vouchers[voucherId] = Voucher({
            tier: tier,
            duration: duration,
            timezone: timezone,
            expiryTime: block.timestamp + duration * 1 days,
            tokenAddress: tokenAddress,
            dcpBalance: dcpBalance,
            isActive: true
        });

        emit VoucherCreated(voucherId, msg.sender, tier);
        return voucherId;
    }

    /**
     * @dev Request a check-in at a gym
     * @param voucherId ID of the voucher
     * @param gymId ID of the gym
     */
    function requestCheckIn(uint256 voucherId, uint256 gymId) public {
        require(ownerOf(voucherId) == msg.sender, "Not the voucher owner");
        require(validateVoucher(voucherId), "Voucher is not valid");

        Voucher memory voucher = vouchers[voucherId];

        uint256 dcpAmount = calculateCheckInDCP(voucherId);

        CheckIn memory newCheckIn = CheckIn({
            gymId: gymId,
            timestamp: block.timestamp,
            dcpAmount: dcpAmount
        });

        checkInHistory[voucherId].push(newCheckIn);
        vouchers[voucherId].dcpBalance += dcpAmount;

        emit CheckInCreated(voucherId, gymId, block.timestamp);
    }

    /**
     * @dev Check if a voucher needs renewal and renew it
     * @param voucherId ID of the voucher
     */
    function checkRenewal(uint256 voucherId) external {
        Voucher storage voucher = vouchers[voucherId];

        // Check if renewal is needed
        if (block.timestamp >= voucher.expiryTime && voucher.isActive) {
            // Calculate renewal price
            uint256 price = treasury.calculatePrice(
                voucher.tokenAddress,
                voucher.tier,
                voucher.duration
            );

            // Validate payment
            require(
                treasury.validateTokenPayment(
                    ownerOf(voucherId),
                    voucher.tokenAddress,
                    price
                ),
                "Renewal payment failed"
            );

            // Renew voucher
            voucher.expiryTime = block.timestamp + voucher.duration * 1 days;
            voucher.dcpBalance += generateDCP(
                voucher.tier,
                voucher.duration,
                voucher.timezone
            );

            emit VoucherRenewed(voucherId, voucher.expiryTime);
        }
    }

    /**
     * @dev Get vouchers owned by a user
     * @param user Address of the user
     * @return Array of voucher IDs
     */
    function getVouchers(
        address user
    ) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(user);
        uint256[] memory result = new uint256[](balance);

        for (uint256 i = 0; i < balance; i++) {
            result[i] = tokenOfOwnerByIndex(user, i);
        }

        return result;
    }

    /**
     * @dev Get check-in history for a voucher
     * @param voucherId ID of the voucher
     * @return Array of check-ins
     */
    function getCheckInHistory(
        uint256 voucherId
    ) external view returns (CheckIn[] memory) {
        return checkInHistory[voucherId];
    }

    /**
     * @dev Check if a voucher is valid
     * @param voucherId ID of the voucher
     * @return isValid True if the voucher is valid
     */
    function validateVoucher(
        uint256 voucherId
    ) public view returns (bool isValid) {
        Voucher memory voucher = vouchers[voucherId];
        return voucher.isActive && block.timestamp < voucher.expiryTime;
    }

    /**
     * @dev Calculate the DCP amount for a check-in
     * @param voucherId ID of the voucher
     * @return dcpAmount Amount of DCP for the check-in
     */
    function calculateCheckInDCP(
        uint256 voucherId
    ) public view returns (uint256 dcpAmount) {
        // In a real implementation, this could depend on tier, time since last check-in, etc.
        Voucher memory voucher = vouchers[voucherId];
        return voucher.tier * 10; // Simple calculation: 10 DCP per tier level
    }

    /**
     * @dev Generate DCP based on tier, duration, and timezone
     * @param tier Tier level
     * @param duration Duration in days
     * @param timezone User's timezone
     * @return dcpAmount Amount of DCP generated
     */
    function generateDCP(
        uint256 tier,
        uint256 duration,
        string memory timezone
    ) internal pure returns (uint256 dcpAmount) {
        // Simple calculation: tier * duration * base DCP rate
        return tier * duration * 100;
    }

    /**
     * @dev Get the last check-in for a voucher
     * @param voucherId ID of the voucher
     * @return CheckIn The last check-in record
     */
    function getLastCheckIn(
        uint256 voucherId
    ) external view returns (CheckIn memory) {
        require(checkInHistory[voucherId].length > 0, "No check-ins found");
        return checkInHistory[voucherId][checkInHistory[voucherId].length - 1];
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _increaseBalance(
        address account,
        uint128 amount
    ) internal override(ERC721Enumerable) {
        super._increaseBalance(account, amount);
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }
}
