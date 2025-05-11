// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../treasury/Treasury.sol";
import "../gym/GymManager.sol";
import "../gym/GymNFT.sol";
import "../treasury/ITreasury.sol";

/**
 * @title VoucherNFT
 * @dev NFT representing gym membership vouchers in the DeGym ecosystem
 */
contract VoucherNFT is ERC721Enumerable, Ownable {
    // References to other contracts
    Treasury public treasury;
    GymManager public gymManager;
    GymNFT public gymNFT;
    ITreasury public treasuryContract;

    // Voucher structure
    struct Voucher {
        uint8 tier;
        uint256 duration;
        uint256 expiryDate;
        int8 timezone;
        uint256 dcpBalance;
        uint256 lastDcpResetTime;
        uint256 dcpLastConsumed;
        uint256 issueDate;
        address paymentToken;
    }

    // Check-in structure
    struct CheckInRecord {
        uint256 gymId;
        uint256 timestamp;
    }

    // Mapping from voucherId to Voucher details
    mapping(uint256 => Voucher) public vouchers;

    // Mapping from voucherId to check-in history
    mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256)))
        public checkInsPerGymPerDay;
    mapping(uint256 => CheckInRecord[]) public checkInHistory;

    // Counter for voucher IDs
    uint256 private _nextTokenId = 1;

    // DCP constant (maximum is 2^99 which is huge, so we'll use a reasonable limit)
    uint256 public constant MAX_DCP = type(uint128).max; // Large enough for all practical tiers

    // Events
    event VoucherCreated(
        uint256 indexed tokenId,
        address indexed owner,
        uint8 tier
    );
    event VoucherExtended(uint256 indexed tokenId, uint256 additionalDuration);
    event VoucherUpgraded(uint256 indexed tokenId, uint8 newTier);
    event CheckInCreated(
        uint256 indexed tokenId,
        uint256 indexed gymId,
        uint256 timestamp
    );
    event DCPReset(uint256 indexed tokenId, uint256 newDcpBalance);
    event DCPConsumed(uint256 indexed tokenId, uint256 amount, uint256 gymId);

    /**
     * @dev Constructor
     * @param _treasury Address of the Treasury contract
     * @param _gymManager Address of the GymManager contract
     * @param _gymNFT Address of the GymNFT contract
     * @param _treasuryContract Address of the Treasury contract
     */
    constructor(
        address _treasury,
        address _gymManager,
        address _gymNFT,
        address _treasuryContract
    ) ERC721("DeGym Membership Voucher", "DGYMV") Ownable(msg.sender) {
        treasury = Treasury(_treasury);
        gymManager = GymManager(_gymManager);
        gymNFT = GymNFT(_gymNFT);
        treasuryContract = ITreasury(_treasuryContract);
    }

    /**
     * @dev Creates a new voucher NFT
     * @param tier Tier level of the voucher (1-99)
     * @param duration Duration of the voucher in days
     * @param timezone User timezone offset (-12 to +14)
     * @param tokenAddress Address of token used for payment
     * @return tokenId The ID of the newly minted NFT
     */
    function mint(
        uint8 tier,
        uint256 duration,
        int8 timezone,
        address tokenAddress
    ) external returns (uint256 tokenId) {
        require(tier > 0 && tier <= 99, "Invalid tier");
        require(duration > 0, "Duration must be greater than zero");
        require(timezone >= -12 && timezone <= 14, "Invalid timezone");

        uint256 price = treasury.calculatePrice(tokenAddress, tier, duration);

        // Logic to handle token payment via Treasury would be here
        // For now, just assume payment is processed elsewhere

        tokenId = _nextTokenId++;
        _mint(msg.sender, tokenId);

        uint256 expiryDate = block.timestamp + (duration * 1 days);
        uint256 dcpBalance = calculateDailyDCP(tier);

        vouchers[tokenId] = Voucher({
            tier: tier,
            duration: duration,
            expiryDate: expiryDate,
            timezone: timezone,
            dcpBalance: dcpBalance,
            lastDcpResetTime: _getTodayStartTimestamp(timezone),
            dcpLastConsumed: 0,
            issueDate: block.timestamp,
            paymentToken: tokenAddress
        });

        emit VoucherCreated(tokenId, msg.sender, tier);
        return tokenId;
    }

    /**
     * @dev Extends the duration of a voucher
     * @param tokenId ID of the voucher to extend
     * @param additionalDuration Additional duration in days
     * @param tokenAddress Address of token used for payment
     */
    function extendVoucher(
        uint256 tokenId,
        uint256 additionalDuration,
        address tokenAddress
    ) external {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "Not approved or owner"
        );
        require(
            additionalDuration > 0,
            "Additional duration must be greater than zero"
        );
        require(validateVoucher(tokenId), "Voucher is expired");

        Voucher storage voucher = vouchers[tokenId];

        uint256 price = treasury.calculatePrice(
            tokenAddress,
            voucher.tier,
            additionalDuration
        );

        // Logic to handle token payment via Treasury would be here
        // For now, just assume payment is processed elsewhere

        voucher.duration += additionalDuration;
        voucher.expiryDate += (additionalDuration * 1 days);

        emit VoucherExtended(tokenId, additionalDuration);
    }

    /**
     * @dev Upgrades the tier of a voucher
     * @param tokenId ID of the voucher to upgrade
     * @param newTier New tier level (must be higher than current)
     * @param tokenAddress Address of token used for payment
     */
    function upgradeVoucher(
        uint256 tokenId,
        uint8 newTier,
        address tokenAddress
    ) external {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "Not approved or owner"
        );
        require(validateVoucher(tokenId), "Voucher is expired");

        Voucher storage voucher = vouchers[tokenId];
        require(newTier > voucher.tier, "New tier must be higher than current");
        require(newTier <= 99, "Invalid tier");

        // Calculate remaining duration in days
        uint256 remainingDuration = (voucher.expiryDate - block.timestamp) /
            1 days;

        // Calculate price difference for upgrade
        uint256 newPrice = treasury.calculatePrice(
            tokenAddress,
            newTier,
            remainingDuration
        );
        uint256 oldPrice = treasury.calculatePrice(
            tokenAddress,
            voucher.tier,
            remainingDuration
        );
        uint256 priceDifference = newPrice > oldPrice ? newPrice - oldPrice : 0;

        // Logic to handle token payment via Treasury would be here
        // For now, just assume payment is processed elsewhere

        voucher.tier = newTier;

        // Reset DCP to new tier value
        _resetDailyDCP(tokenId);

        emit VoucherUpgraded(tokenId, newTier);
    }

    /**
     * @dev Records a check-in for a voucher at a specific gym
     * @param tokenId ID of the voucher
     * @param gymId ID of the gym
     * @return success True if check-in was successful
     */
    function requestCheckIn(
        uint256 tokenId,
        uint256 gymId
    ) external returns (bool success) {
        // In production, restrict this to only be called by the Checkin contract
        require(validateVoucher(tokenId), "Voucher is expired");
        require(gymId > 0, "Invalid gym ID");

        Voucher storage voucher = vouchers[tokenId];

        // Reset DCP if it's a new day
        if (_shouldResetDCP(tokenId)) {
            _resetDailyDCP(tokenId);
        }

        // Calculate DCP consumption based on gym tier
        // In a real implementation, we would get the gym tier from GymNFT
        uint8 gymTier = 1; // Placeholder, replace with actual gym tier lookup
        uint256 dcpRequired = calculateGymDCPRequirement(gymTier);

        // Check if user has enough DCP
        require(voucher.dcpBalance >= dcpRequired, "Insufficient DCP balance");

        // Check if user has reached the daily limit for this gym
        uint256 today = _getTodayAsNumber(voucher.timezone);
        require(
            checkInsPerGymPerDay[tokenId][today][gymId] < voucher.tier,
            "Daily check-in limit reached for this gym"
        );

        // Update DCP balance
        voucher.dcpBalance -= dcpRequired;
        voucher.dcpLastConsumed = dcpRequired;

        // Record check-in
        checkInsPerGymPerDay[tokenId][today][gymId]++;
        checkInHistory[tokenId].push(
            CheckInRecord({gymId: gymId, timestamp: block.timestamp})
        );

        emit CheckInCreated(tokenId, gymId, block.timestamp);
        emit DCPConsumed(tokenId, dcpRequired, gymId);

        return true;
    }

    /**
     * @dev Calculates the daily DCP allocation based on voucher tier
     * @param tier Tier level of the voucher
     * @return amount Daily DCP amount
     */
    function calculateDailyDCP(
        uint8 tier
    ) public pure returns (uint256 amount) {
        // DCP = 2^tier
        if (tier >= 128) {
            return MAX_DCP; // Avoid overflow
        }
        return 1 << tier; // 2^tier using bit shift
    }

    /**
     * @dev Calculates the DCP requirement for a gym based on tier
     * @param gymTier Tier level of the gym
     * @return amount DCP required to check in
     */
    function calculateGymDCPRequirement(
        uint8 gymTier
    ) public pure returns (uint256 amount) {
        // DCP required = 2^gymTier
        if (gymTier >= 128) {
            return MAX_DCP; // Avoid overflow
        }
        return 1 << gymTier; // 2^gymTier using bit shift
    }

    /**
     * @dev Validates if a voucher is still valid (not expired)
     * @param tokenId ID of the voucher to validate
     * @return isValid True if the voucher is valid
     */
    function validateVoucher(
        uint256 tokenId
    ) public view returns (bool isValid) {
        require(_exists(tokenId), "Voucher does not exist");
        return vouchers[tokenId].expiryDate >= block.timestamp;
    }

    /**
     * @dev Checks if a voucher has sufficient DCP for a specific gym
     * @param tokenId ID of the voucher
     * @param gymTier Tier of the gym
     * @return hasEnough True if the voucher has enough DCP
     */
    function hasSufficientDCP(
        uint256 tokenId,
        uint8 gymTier
    ) public view returns (bool hasEnough) {
        require(_exists(tokenId), "Voucher does not exist");

        Voucher storage voucher = vouchers[tokenId];

        // If we need to reset DCP, return based on the reset amount
        if (_shouldResetDCP(tokenId)) {
            return
                calculateDailyDCP(voucher.tier) >=
                calculateGymDCPRequirement(gymTier);
        }

        return voucher.dcpBalance >= calculateGymDCPRequirement(gymTier);
    }

    /**
     * @dev Returns the remaining DCP balance for a voucher
     * @param tokenId ID of the voucher
     * @return balance Current DCP balance
     */
    function getDCPBalance(
        uint256 tokenId
    ) public view returns (uint256 balance) {
        require(_exists(tokenId), "Voucher does not exist");

        Voucher storage voucher = vouchers[tokenId];

        // If we need to reset DCP, return the full amount
        if (_shouldResetDCP(tokenId)) {
            return calculateDailyDCP(voucher.tier);
        }

        return voucher.dcpBalance;
    }

    /**
     * @dev Returns the check-in history for a voucher
     * @param tokenId ID of the voucher
     * @return history Array of check-in records
     */
    function getCheckInHistory(
        uint256 tokenId
    ) external view returns (CheckInRecord[] memory) {
        require(_exists(tokenId), "Voucher does not exist");
        return checkInHistory[tokenId];
    }

    /**
     * @dev Gets the number of check-ins at a specific gym on the current day
     * @param tokenId ID of the voucher
     * @param gymId ID of the gym
     * @return count Number of check-ins
     */
    function getTodayCheckInCount(
        uint256 tokenId,
        uint256 gymId
    ) public view returns (uint256 count) {
        require(_exists(tokenId), "Voucher does not exist");
        Voucher storage voucher = vouchers[tokenId];
        uint256 today = _getTodayAsNumber(voucher.timezone);
        return checkInsPerGymPerDay[tokenId][today][gymId];
    }

    /**
     * @dev Checks if a reset of the daily DCP is needed
     * @param tokenId ID of the voucher
     * @return needsReset True if DCP should be reset
     */
    function _shouldResetDCP(
        uint256 tokenId
    ) internal view returns (bool needsReset) {
        Voucher storage voucher = vouchers[tokenId];
        uint256 todayStart = _getTodayStartTimestamp(voucher.timezone);
        return voucher.lastDcpResetTime < todayStart;
    }

    /**
     * @dev Resets the daily DCP allocation
     * @param tokenId ID of the voucher
     */
    function _resetDailyDCP(uint256 tokenId) internal {
        Voucher storage voucher = vouchers[tokenId];
        voucher.dcpBalance = calculateDailyDCP(voucher.tier);
        voucher.lastDcpResetTime = _getTodayStartTimestamp(voucher.timezone);
        emit DCPReset(tokenId, voucher.dcpBalance);
    }

    /**
     * @dev Gets the start timestamp of the current day in the user's timezone
     * @param timezone User timezone offset (-12 to +14)
     * @return timestamp Start of the day in user's timezone
     */
    function _getTodayStartTimestamp(
        int8 timezone
    ) internal view returns (uint256 timestamp) {
        // Convert timezone offset to seconds
        int256 timezoneOffset = int256(timezone) * 3600;

        // Get current timestamp adjusted for timezone
        int256 adjustedTimestamp = int256(block.timestamp) + timezoneOffset;

        // Calculate the start of the day in the user's timezone
        int256 secondsInDay = 86400; // 24 * 60 * 60
        int256 startOfDay = (adjustedTimestamp / secondsInDay) *
            secondsInDay -
            timezoneOffset;

        return startOfDay > 0 ? uint256(startOfDay) : 0;
    }

    /**
     * @dev Gets a numerical representation of the current day in the user's timezone
     * @param timezone User timezone offset (-12 to +14)
     * @return dayNumber Numerical representation of the day (days since epoch)
     */
    function _getTodayAsNumber(
        int8 timezone
    ) internal view returns (uint256 dayNumber) {
        // Convert timezone offset to seconds
        int256 timezoneOffset = int256(timezone) * 3600;

        // Get current timestamp adjusted for timezone
        int256 adjustedTimestamp = int256(block.timestamp) + timezoneOffset;

        // Calculate the day number
        return uint256(adjustedTimestamp / 86400);
    }

    /**
     * @dev Check if token exists
     * @param tokenId ID of the token
     * @return bool True if the token exists
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
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

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     * Requirements:
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(
        address spender,
        uint256 tokenId
    ) internal view returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner ||
            isApprovedForAll(owner, spender) ||
            getApproved(tokenId) == spender);
    }

    /**
     * @dev Retorna o tier de um voucher
     * @param tokenId ID do voucher
     * @return tier Tier do voucher
     */
    function getTier(uint256 tokenId) public view returns (uint8) {
        return vouchers[tokenId].tier;
    }

    /**
     * @dev Retorna a data de expiração de um voucher
     * @param tokenId ID do voucher
     * @return expiryDate Data de expiração do voucher
     */
    function getExpiryDate(uint256 tokenId) public view returns (uint256) {
        return vouchers[tokenId].expiryDate;
    }

    /**
     * @dev Retorna o timezone de um voucher
     * @param tokenId ID do voucher
     * @return timezone Timezone do voucher
     */
    function getTimezone(uint256 tokenId) public view returns (int8) {
        return vouchers[tokenId].timezone;
    }

    /**
     * @dev Retorna a data de emissão de um voucher
     * @param tokenId ID do voucher
     * @return issueDate Data de emissão do voucher
     */
    function getIssueDate(uint256 tokenId) public view returns (uint256) {
        return vouchers[tokenId].issueDate;
    }

    /**
     * @dev Retorna o token de pagamento usado para um voucher
     * @param tokenId ID do voucher
     * @return paymentToken Endereço do token de pagamento
     */
    function getPaymentToken(uint256 tokenId) public view returns (address) {
        return vouchers[tokenId].paymentToken;
    }
}
