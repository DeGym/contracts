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

    // Voucher structure otimizada para packed storage
    struct Voucher {
        uint8 tier; // 1 byte
        int8 timezone; // 1 byte
        uint40 expiryDate; // 5 bytes - Suficiente até 2100+
        uint40 issueDate; // 5 bytes
        uint40 lastDcpResetTime; // 5 bytes
        uint128 dcpBalance; // 16 bytes - Mais que suficiente mesmo para tiers altos
        uint128 dcpLastConsumed; // 16 bytes
        uint16 duration; // 2 bytes - Em dias, max ~179 anos
        address paymentToken; // 20 bytes - Não pode ser packed com os outros
        address tokenUsed; // 20 bytes - Não pode ser packed com os outros
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
        uint8 tier,
        uint16 duration,
        int8 timezone,
        address paymentToken
    );
    event VoucherExtended(uint256 indexed tokenId, uint256 additionalDuration);
    event VoucherUpgraded(uint256 indexed tokenId, uint8 newTier);
    event CheckInCreated(
        uint256 indexed tokenId,
        uint256 indexed gymId,
        uint256 timestamp
    );
    event DCPReset(uint256 indexed tokenId, uint256 newBalance);
    event DCPConsumed(
        uint256 indexed tokenId,
        uint256 indexed gymId,
        uint128 amount
    );
    event AllDCPReset(int8 indexed timezone, uint256 vouchersCount);

    /**
     * @dev Constructor
     * @param _treasuryAddress Address of the Treasury contract
     * @param _gymManagerAddress Address of the GymManager contract
     * @param _gymNFTAddress Address of the GymNFT contract
     * @param _treasuryContractAddress Address of the ITreasury contract
     */
    constructor(
        address _treasuryAddress,
        address _gymManagerAddress,
        address _gymNFTAddress,
        address _treasuryContractAddress
    ) ERC721("DeGym Voucher", "DGV") Ownable(msg.sender) {
        treasury = Treasury(_treasuryAddress);
        gymManager = GymManager(_gymManagerAddress);
        gymNFT = GymNFT(_gymNFTAddress);
        treasuryContract = ITreasury(_treasuryContractAddress);
    }

    /**
     * @dev Creates a new voucher
     * @param tier Tier level (1-99)
     * @param duration Duration in days
     * @param timezone User's timezone (-12 to 14)
     * @param tokenAddress Address of the token used for payment
     * @return tokenId ID of the created voucher
     */
    function mint(
        uint8 tier,
        uint256 duration,
        int8 timezone,
        address tokenAddress
    ) external returns (uint256) {
        require(tier > 0 && tier <= 99, "Invalid tier");
        require(duration > 0, "Invalid duration");
        require(timezone >= -12 && timezone <= 14, "Invalid timezone");
        require(
            treasuryContract.isTokenAccepted(tokenAddress),
            "Token not accepted"
        );

        // Calculate voucher price
        uint256 price = treasury.calculatePrice(tokenAddress, tier, duration);

        // Logic to handle token payment via Treasury would be here
        // For now, just assume payment is processed elsewhere

        // Generate new token ID
        uint256 tokenId = _nextTokenId++;

        // Calculate expiry date and DCP balance
        uint256 expiryDateCalc = block.timestamp + (duration * 1 days);
        uint128 dcpBalance = uint128(calculateDailyDCP(tier)); // Convert to uint128 safely

        // Mint NFT
        _mint(msg.sender, tokenId);

        // Store voucher details with proper type conversions
        vouchers[tokenId] = Voucher({
            tier: tier,
            duration: uint16(duration), // Convert to uint16
            expiryDate: uint40(expiryDateCalc), // Convert to uint40
            timezone: timezone,
            dcpBalance: dcpBalance,
            lastDcpResetTime: uint40(_getTodayStartTimestamp(timezone)), // Convert to uint40
            dcpLastConsumed: 0,
            issueDate: uint40(block.timestamp), // Convert to uint40
            paymentToken: tokenAddress,
            tokenUsed: tokenAddress
        });

        emit VoucherCreated(
            tokenId,
            msg.sender,
            tier,
            uint16(duration),
            timezone,
            tokenAddress
        );

        return tokenId;
    }

    /**
     * @dev Extends the duration of a voucher
     * @param tokenId ID of the voucher to extend
     * @param additionalDuration Additional duration in days
     * @param tokenAddress Address of the token used for payment
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
        require(validateVoucher(tokenId), "Voucher is expired");
        require(additionalDuration > 0, "Invalid additional duration");

        // Ensure additionalDuration doesn't exceed uint16 max
        require(additionalDuration <= type(uint16).max, "Duration too large");

        Voucher storage voucher = vouchers[tokenId];

        // Calculate price for extension
        uint256 price = treasury.calculatePrice(
            tokenAddress,
            voucher.tier,
            additionalDuration
        );

        // Logic to handle token payment via Treasury would be here
        // For now, just assume payment is processed elsewhere

        voucher.duration += uint16(additionalDuration);
        voucher.expiryDate += uint40(additionalDuration * 1 days);

        emit VoucherExtended(tokenId, additionalDuration);
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

        // Get gym tier
        uint8 gymTier = gymNFT.getCurrentTier(gymId);

        // Calculate DCP required for check-in (2^gym_tier)
        uint128 dcpRequired = uint128(calculateDCP(gymTier));

        // Check if user has enough DCP
        require(voucher.dcpBalance >= dcpRequired, "Insufficient DCP balance");

        // Check today's date in user's timezone
        uint256 today = _getTodayStartTimestamp(voucher.timezone);

        // Update DCP balance with proper type conversions
        voucher.dcpBalance -= dcpRequired;
        voucher.dcpLastConsumed = dcpRequired;

        // Record check-in
        checkInsPerGymPerDay[tokenId][today][gymId]++;

        // Add to check-in history
        checkInHistory[tokenId].push(
            CheckInRecord({gymId: gymId, timestamp: block.timestamp})
        );

        // Notify GymNFT about the check-in
        gymNFT.receiveDCP(gymId, voucher.tokenUsed, dcpRequired);

        emit CheckInCreated(tokenId, gymId, block.timestamp);
        emit DCPConsumed(tokenId, gymId, dcpRequired);

        return true;
    }

    /**
     * @dev Calculate number of check-ins for a voucher at a gym on a specific day
     * @param tokenId ID of the voucher
     * @param timestamp Timestamp for the day
     * @param gymId ID of the gym
     * @return count Number of check-ins
     */
    function getCheckInsForDay(
        uint256 tokenId,
        uint256 timestamp,
        uint256 gymId
    ) external view returns (uint256 count) {
        uint256 dayStart = _getTodayStartTimestamp(vouchers[tokenId].timezone);
        return checkInsPerGymPerDay[tokenId][dayStart][gymId];
    }

    /**
     * @dev Get all check-in history for a voucher
     * @param tokenId ID of the voucher
     * @return history Array of check-in records
     */
    function getCheckInHistory(
        uint256 tokenId
    ) external view returns (CheckInRecord[] memory) {
        return checkInHistory[tokenId];
    }

    /**
     * @dev Validates if a voucher is still valid (not expired)
     * @param tokenId ID of the voucher
     * @return isValid True if voucher is valid
     */
    function validateVoucher(uint256 tokenId) public view returns (bool) {
        // Check if voucher exists
        if (!exists(tokenId)) return false;

        // Check if voucher is expired
        return vouchers[tokenId].expiryDate >= block.timestamp;
    }

    /**
     * @dev Calculate today's start timestamp in a specific timezone
     * @param timezone User's timezone (-12 to 14)
     * @return timestamp Start of the day in user's timezone
     */
    function _getTodayStartTimestamp(
        int8 timezone
    ) internal view returns (uint256) {
        // Calculate the offset in seconds from UTC
        int256 timezoneOffset = int256(timezone) * 3600;

        // Calculate local time
        int256 localTime = int256(block.timestamp) + timezoneOffset;

        // Calculate start of day in local time
        int256 startOfDayLocal = localTime - (localTime % 86400);

        // Convert back to UTC
        return uint256(startOfDayLocal - timezoneOffset);
    }

    /**
     * @dev Check if daily DCP should be reset
     * @param tokenId ID of the voucher
     * @return shouldReset True if DCP should be reset
     */
    function _shouldResetDCP(uint256 tokenId) internal view returns (bool) {
        Voucher storage voucher = vouchers[tokenId];

        // Get today's start in user's timezone
        uint256 todayStart = _getTodayStartTimestamp(voucher.timezone);

        // Check if last reset was before today
        return voucher.lastDcpResetTime < todayStart;
    }

    /**
     * @dev Reset daily DCP balance for a voucher
     * @param tokenId ID of the voucher
     */
    function _resetDailyDCP(uint256 tokenId) internal {
        Voucher storage voucher = vouchers[tokenId];
        voucher.dcpBalance = uint128(calculateDailyDCP(voucher.tier));
        voucher.lastDcpResetTime = uint40(
            _getTodayStartTimestamp(voucher.timezone)
        );
        emit DCPReset(tokenId, uint256(voucher.dcpBalance));
    }

    /**
     * @dev Calculate daily DCP for a specific tier
     * @param tier Tier level
     * @return dcp Daily DCP amount
     */
    function calculateDailyDCP(uint8 tier) public pure returns (uint256) {
        return calculateDCP(tier);
    }

    /**
     * @dev Calcula os pontos DCP com verificação de overflow
     * @param tier O tier para calcular o DCP
     * @return O valor de DCP para o tier especificado
     */
    function calculateDCP(uint8 tier) public pure returns (uint256) {
        require(tier <= 77, "Tier too high, overflow risk");
        return 1 << tier; // Bit shift já implementado no código original
    }

    /**
     * @dev Verifica se um voucher tem DCP suficiente para uma academia
     * @param tokenId ID do voucher
     * @param gymTier Tier da academia
     * @return hasEnough True se tiver DCP suficiente
     */
    function hasSufficientDCP(
        uint256 tokenId,
        uint8 gymTier
    ) public view returns (bool) {
        uint256 requiredDCP = calculateDCP(gymTier);
        return vouchers[tokenId].dcpBalance >= requiredDCP;
    }

    /**
     * @dev Check if token exists
     * @param tokenId ID of the token
     * @return bool True if the token exists
     */
    function exists(uint256 tokenId) public view returns (bool) {
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

    /**
     * @dev Retorna o saldo atual de DCP de um voucher
     * @param tokenId ID do voucher
     * @return dcpBalance Saldo de DCP do voucher
     */
    function getDCPBalance(uint256 tokenId) public view returns (uint256) {
        return vouchers[tokenId].dcpBalance;
    }

    /**
     * @dev Calcula quando o próximo reset de DCP deve ocorrer com base no timezone
     * @param lastResetTime O timestamp do último reset
     * @param timezone O fuso horário do usuário (-12 a +14)
     * @return O timestamp quando o próximo reset deve ocorrer
     */
    function calculateNextResetTime(
        uint256 lastResetTime,
        int8 timezone
    ) public pure returns (uint256) {
        // Converte o timezone de horas para segundos
        int256 timezoneOffset = int256(timezone) * 3600;

        // Determina a hora UTC que representa meia-noite no fuso horário do usuário
        // Exemplo: se timezone = -3, meia-noite local = 3:00 UTC
        uint256 secondsInDay = 24 hours;

        // Ajusta o timestamp inicial para o fuso horário do usuário
        uint256 userLocalTime = uint256(int256(lastResetTime) + timezoneOffset);

        // Calcula o início do dia (meia-noite) no fuso horário do usuário
        uint256 startOfUserDay = userLocalTime - (userLocalTime % secondsInDay);

        // Calcula o início do próximo dia
        uint256 startOfNextUserDay = startOfUserDay + secondsInDay;

        // Converte de volta para UTC
        return uint256(int256(startOfNextUserDay) - timezoneOffset);
    }

    /**
     * @dev Reseta o DCP de todos os vouchers em um determinado timezone
     * @param timezone O fuso horário para resetar (-12 a +14)
     */
    function resetAllVouchersDCP(int8 timezone) external onlyOwner {
        require(timezone >= -12 && timezone <= 14, "Invalid timezone");

        uint256 totalSupply = totalSupply();
        uint256 count = 0;

        // Calcular o timestamp que representa o início do dia atual neste timezone
        uint256 todayTimestamp = _getTodayStartTimestamp(timezone);

        for (uint256 i = 0; i < totalSupply; i++) {
            uint256 tokenId = tokenByIndex(i);
            Voucher storage voucher = vouchers[tokenId];

            // Verifica se o voucher está no timezone especificado
            if (voucher.timezone == timezone) {
                // Verifica se o voucher ainda não foi resetado hoje
                if (voucher.lastDcpResetTime < todayTimestamp) {
                    // Reseta o DCP e atualiza o timestamp
                    voucher.dcpBalance = uint128(calculateDCP(voucher.tier));
                    voucher.lastDcpResetTime = uint40(block.timestamp);

                    emit DCPReset(tokenId, uint256(voucher.dcpBalance));
                    count++;
                }
            }
        }

        emit AllDCPReset(timezone, count);
    }

    /**
     * @dev Consome uma quantidade de DCP de um voucher
     * @param tokenId ID do voucher
     * @param amount Quantidade de DCP a ser consumida
     */
    function consumeDCP(uint256 tokenId, uint256 amount) external {
        require(exists(tokenId), "VoucherNFT: token does not exist");
        require(
            vouchers[tokenId].dcpBalance >= amount,
            "VoucherNFT: insufficient DCP"
        );

        // Reduz o saldo de DCP
        vouchers[tokenId].dcpBalance -= uint128(amount);
        // Registra o último valor consumido
        vouchers[tokenId].dcpLastConsumed = uint128(amount);

        emit DCPConsumed(tokenId, 0, uint128(amount)); // gymId é 0 pois será registrado em registerCheckIn
    }

    /**
     * @dev Registra um check-in para um voucher em uma academia específica
     * @param tokenId ID do voucher
     * @param gymId ID da academia
     */
    function registerCheckIn(uint256 tokenId, uint256 gymId) external {
        require(exists(tokenId), "VoucherNFT: token does not exist");

        // Adiciona o check-in ao histórico
        checkInHistory[tokenId].push(
            CheckInRecord({gymId: gymId, timestamp: block.timestamp})
        );

        // Registra check-in por dia (para limites diários, se necessário)
        uint256 today = block.timestamp / 1 days;
        checkInsPerGymPerDay[tokenId][gymId][today]++;

        emit CheckInCreated(tokenId, gymId, block.timestamp);
    }

    /**
     * @dev Retorna o token usado para mintar o voucher
     * @param tokenId ID do voucher
     * @return Endereço do token usado na mintagem
     */
    function getTokenUsed(uint256 tokenId) external view returns (address) {
        require(exists(tokenId), "VoucherNFT: token does not exist");
        return vouchers[tokenId].tokenUsed;
    }
}
