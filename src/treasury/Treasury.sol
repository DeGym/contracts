// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Treasury
 * @dev Manages funds and pricing for the DeGym ecosystem
 */
contract Treasury is Ownable {
    // Mapping of accepted tokens
    mapping(address => bool) public acceptedTokens;

    // Base prices for various services
    uint256 public voucherBasePriceUSD;
    uint256 public gymRegistrationBaseFeeUSD;
    uint256 public tierUpgradeBaseFeeUSD;

    // Treasury address to receive payments
    address public treasuryWallet;

    // Events
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    event PriceUpdated(string priceType, uint256 newPrice);
    event PaymentReceived(
        address indexed from,
        address indexed token,
        uint256 amount
    );
    event PaymentSent(
        address indexed to,
        address indexed token,
        uint256 amount
    );

    /**
     * @dev Constructor
     * @param _treasuryWallet Address of the treasury wallet
     */
    constructor(address _treasuryWallet) Ownable(msg.sender) {
        treasuryWallet = _treasuryWallet;

        // Set initial prices
        voucherBasePriceUSD = 10 * 10 ** 18; // $10 with 18 decimals
        gymRegistrationBaseFeeUSD = 100 * 10 ** 18; // $100 with 18 decimals
        tierUpgradeBaseFeeUSD = 50 * 10 ** 18; // $50 with 18 decimals
    }

    /**
     * @dev Add a token to the accepted tokens list
     * @param token Address of the token
     */
    function addAcceptedToken(address token) external onlyOwner {
        acceptedTokens[token] = true;
        emit TokenAdded(token);
    }

    /**
     * @dev Remove a token from the accepted tokens list
     * @param token Address of the token
     */
    function removeAcceptedToken(address token) external onlyOwner {
        acceptedTokens[token] = false;
        emit TokenRemoved(token);
    }

    /**
     * @dev Update base prices
     * @param _voucherPrice New voucher base price
     * @param _gymRegistrationFee New gym registration fee
     * @param _tierUpgradeFee New tier upgrade fee
     */
    function updatePrices(
        uint256 _voucherPrice,
        uint256 _gymRegistrationFee,
        uint256 _tierUpgradeFee
    ) external onlyOwner {
        voucherBasePriceUSD = _voucherPrice;
        gymRegistrationBaseFeeUSD = _gymRegistrationFee;
        tierUpgradeBaseFeeUSD = _tierUpgradeFee;

        emit PriceUpdated("voucherBase", _voucherPrice);
        emit PriceUpdated("gymRegistration", _gymRegistrationFee);
        emit PriceUpdated("tierUpgrade", _tierUpgradeFee);
    }

    /**
     * @dev Calculate price for a voucher
     * @param tokenAddress Address of the token used for payment
     * @param tier Tier level of the voucher
     * @param duration Duration in days
     * @return price Calculated price
     */
    function calculatePrice(
        address tokenAddress,
        uint256 tier,
        uint256 duration
    ) external view returns (uint256 price) {
        // Basic calculation: base price * tier factor * duration factor
        uint256 tierFactor = 100 + tier;
        uint256 durationFactor = duration;

        // Calculate price in USD
        uint256 priceUSD = (voucherBasePriceUSD * tierFactor * durationFactor) /
            10000;

        // In a real implementation, convert USD to token amount using oracles
        // For simplicity, we'll assume 1:1 conversion here
        return priceUSD;
    }

    /**
     * @dev Calculate fee for upgrading a gym tier
     * @param currentTier Current tier level
     * @param newTier New tier level
     * @return fee Calculated upgrade fee
     */
    function calculateUpgradeFee(
        uint8 currentTier,
        uint8 newTier
    ) external view returns (uint256 fee) {
        require(newTier > currentTier, "New tier must be higher");

        // Basic calculation: base fee * tier difference
        uint256 tierDifference = newTier - currentTier;

        return tierUpgradeBaseFeeUSD * tierDifference;
    }

    /**
     * @dev Validate if a token is accepted
     * @param tokenAddress Address of the token
     * @return isValid True if the token is accepted
     */
    function validateToken(
        address tokenAddress
    ) external view returns (bool isValid) {
        return acceptedTokens[tokenAddress];
    }

    /**
     * @dev Validate and process a payment
     * @param tier Tier level for the payment
     * @return success True if the payment is valid
     */
    function validatePayment(uint8 tier) external view returns (bool success) {
        // In a real implementation, this would verify payment amounts
        // For this skeleton, we'll just return true
        return true;
    }

    /**
     * @dev Validate and process a token payment
     * @param payer Address of the payer
     * @param amount Amount to pay
     * @return success True if the payment is successful
     */
    function validateTokenPayment(
        address payer,
        uint256 amount
    ) external view returns (bool success) {
        // In a real implementation, this would verify token transfers
        // For this skeleton, we'll just return true
        return true;
    }

    /**
     * @dev Process gym reward payment
     * @param gym Address of the gym to reward
     * @param amount Amount to pay
     */
    function processGymReward(address gym, uint256 amount) external {
        // In a real implementation, this would transfer tokens to the gym
        // For now, emit an event to simulate the transfer
        emit PaymentSent(gym, address(0), amount);
    }

    /**
     * @dev Process DCP redemption
     * @param gymId ID of the gym
     * @param amount Amount of DCP to redeem
     */
    function processRedemption(uint256 gymId, uint256 amount) external {
        // In a real implementation, this would calculate and transfer tokens
        // For now, emit an event to simulate the process
        emit PaymentReceived(msg.sender, address(0), amount);
    }

    /**
     * @dev Set voucher base price
     * @param _price New voucher base price
     */
    function setVoucherBasePrice(uint256 _price) external onlyOwner {
        voucherBasePriceUSD = _price;
        emit PriceUpdated("voucherBasePrice", _price);
    }

    /**
     * @dev Set gym registration base fee
     * @param _fee New gym registration base fee
     */
    function setGymRegistrationBaseFee(uint256 _fee) external onlyOwner {
        gymRegistrationBaseFeeUSD = _fee;
        emit PriceUpdated("gymRegistrationBaseFee", _fee);
    }

    /**
     * @dev Set tier upgrade base fee
     * @param _fee New tier upgrade base fee
     */
    function setTierUpgradeBaseFee(uint256 _fee) external onlyOwner {
        tierUpgradeBaseFeeUSD = _fee;
        emit PriceUpdated("tierUpgradeBaseFee", _fee);
    }

    /**
     * @dev Set treasury wallet address
     * @param _wallet New treasury wallet address
     */
    function setTreasuryWallet(address _wallet) external onlyOwner {
        treasuryWallet = _wallet;
    }
}
