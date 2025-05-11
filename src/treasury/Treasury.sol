// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../gym/GymNFT.sol";

/**
 * @title Treasury
 * @dev Manages tokens and fees for the DeGym platform
 */
contract Treasury is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Accepted tokens for payment
    mapping(address => bool) public acceptedTokens;

    // Voucher prices per accepted token
    mapping(address => uint256) public voucherPrices;

    // Minimum staking amount required for gym registration
    uint256 public minimumGymStakingAmount;

    // Reference to GymNFT contract
    GymNFT public gymNFT;

    // Events
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    event VoucherPriceUpdated(address indexed token, uint256 price);
    event MinimumStakingUpdated(uint256 newAmount);
    event PaymentReceived(address indexed token, uint256 amount, address from);
    event PaymentSent(address indexed token, uint256 amount, address to);
    event Withdrawal(address indexed token, uint256 amount, address to);

    /**
     * @dev Constructor
     */
    constructor() Ownable(msg.sender) {
        minimumGymStakingAmount = 1000 * 10 ** 18; // Default 1000 tokens needed for gym registration
    }

    /**
     * @dev Sets the minimum staking amount required for gym registration
     * @param _amount New minimum amount
     */
    function setMinimumGymStakingAmount(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Treasury: amount must be greater than zero");
        minimumGymStakingAmount = _amount;
        emit MinimumStakingUpdated(_amount);
    }

    /**
     * @dev Adds a token to the list of accepted tokens
     * @param tokenAddress Address of the token to be added
     */
    function addAcceptedToken(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(0), "Treasury: invalid token address");
        require(
            !acceptedTokens[tokenAddress],
            "Treasury: token already accepted"
        );

        acceptedTokens[tokenAddress] = true;
        emit TokenAdded(tokenAddress);
    }

    /**
     * @dev Removes a token from the list of accepted tokens
     * @param tokenAddress Address of the token to be removed
     */
    function removeAcceptedToken(address tokenAddress) external onlyOwner {
        require(acceptedTokens[tokenAddress], "Treasury: token not accepted");

        acceptedTokens[tokenAddress] = false;
        emit TokenRemoved(tokenAddress);
    }

    /**
     * @dev Sets the voucher price for a specific token
     * @param tokenAddress Address of the token
     * @param price Price in the smallest unit of the token
     */
    function setVoucherPrice(
        address tokenAddress,
        uint256 price
    ) external onlyOwner {
        require(acceptedTokens[tokenAddress], "Treasury: token not accepted");
        require(price > 0, "Treasury: price must be greater than zero");

        voucherPrices[tokenAddress] = price;
        emit VoucherPriceUpdated(tokenAddress, price);
    }

    /**
     * @dev Calculates the price of a voucher based on tier and duration
     * @param tokenAddress Address of the token for payment
     * @param tier Tier of the voucher
     * @param duration Duration of the voucher in days
     * @return price Calculated price
     */
    function calculatePrice(
        address tokenAddress,
        uint256 tier,
        uint256 duration
    ) external view returns (uint256 price) {
        require(acceptedTokens[tokenAddress], "Treasury: token not accepted");
        require(tier > 0, "Treasury: tier must be greater than zero");
        require(duration > 0, "Treasury: duration must be greater than zero");

        // Base price of the voucher for the specified token
        uint256 basePrice = voucherPrices[tokenAddress];

        // Price increases based on tier and duration
        // Simple formula: basePrice * tier * (duration / 30)
        // Assuming 30 days is the base period
        return (basePrice * tier * duration) / 30;
    }

    /**
     * @dev Calculates the price of a voucher based on tier
     * @param tokenAddress Address of the token for payment
     * @param tier Tier of the voucher
     * @return price Calculated price
     */
    function calculateVoucherPrice(
        address tokenAddress,
        uint256 tier
    ) public view returns (uint256 price) {
        require(acceptedTokens[tokenAddress], "Treasury: token not accepted");
        require(tier > 0, "Treasury: tier must be greater than zero");

        // Base price of the voucher for the specified token
        uint256 basePrice = voucherPrices[tokenAddress];

        // Price increases based on tier
        // Simple formula: basePrice * tier
        return basePrice * tier;
    }

    /**
     * @dev Validates if a token is accepted
     * @param tokenAddress Address of the token to be validated
     * @return valid True if the token is accepted
     */
    function validateToken(
        address tokenAddress
    ) external view returns (bool valid) {
        return acceptedTokens[tokenAddress];
    }

    /**
     * @dev Validates if an address has sufficient staking for gym registration
     * @param staker Address of the potential gym registrant
     * @return valid True if staking amount is sufficient
     */
    function validateGymStaking(
        address staker
    ) external view returns (bool valid) {
        // Obter o número de academias já registradas pelo staker
        uint256 registeredGyms = getRegisteredGymCount(staker);

        // Calcular o staking mínimo necessário
        // Número de academias atuais + 1 (para a nova academia) * valor mínimo por academia
        uint256 requiredStaking = minimumGymStakingAmount *
            (registeredGyms + 1);

        // Verificar se o staker tem o staking mínimo necessário
        return getStakedAmount(staker) >= requiredStaking;
    }

    /**
     * @dev Returns the number of gyms registered by an address
     * @param owner Address of the gym owner
     * @return count Number of registered gyms
     */
    function getRegisteredGymCount(
        address owner
    ) public view returns (uint256 count) {
        if (address(gymNFT) != address(0)) {
            return gymNFT.balanceOf(owner);
        }
        return 0;
    }

    /**
     * @dev Returns the amount staked by an address
     * @param staker Address of the staker
     * @return amount Staked amount
     */
    function getStakedAmount(
        address staker
    ) public view returns (uint256 amount) {
        // Esta é uma implementação de placeholder
        // Na implementação real, você consultaria o contrato de staking
        return 0; // Substituir por uma chamada real ao contrato de staking
    }

    /**
     * @dev Validates token payment
     * @param user Address of the user
     * @param amount Amount of the payment
     * @return success True if the payment is valid
     */
    function validateTokenPayment(
        address user,
        uint256 amount
    ) external view returns (bool success) {
        // Simple implementation: check if the user has sufficient balance
        // In a real implementation, you would check approvals, etc.

        address tokenAddress = getFirstAcceptedToken();
        require(tokenAddress != address(0), "Treasury: no accepted tokens");

        IERC20 token = IERC20(tokenAddress);
        return
            token.balanceOf(user) >= amount &&
            token.allowance(user, address(this)) >= amount;
    }

    /**
     * @dev Processes gym reward
     * @param gym Address of the gym to reward
     * @param tokenAddress Address of the token for payment
     * @param amount Amount to be rewarded
     */
    function processGymReward(
        address gym,
        address tokenAddress,
        uint256 amount
    ) external nonReentrant onlyOwner {
        require(gym != address(0), "Treasury: invalid gym address");
        require(acceptedTokens[tokenAddress], "Treasury: token not accepted");
        require(amount > 0, "Treasury: amount must be greater than zero");

        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance >= amount, "Treasury: insufficient balance");

        token.safeTransfer(gym, amount);
        emit PaymentSent(tokenAddress, amount, gym);
    }

    /**
     * @dev Processes redemption
     * @param tokenAddress Address of the token for redemption
     * @param to Destination address of the redemption
     * @param amount Amount to be redeemed
     */
    function processRedemption(
        address tokenAddress,
        address to,
        uint256 amount
    ) external nonReentrant onlyOwner {
        require(to != address(0), "Treasury: invalid destination address");
        require(acceptedTokens[tokenAddress], "Treasury: token not accepted");
        require(amount > 0, "Treasury: amount must be greater than zero");

        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance >= amount, "Treasury: insufficient balance");

        token.safeTransfer(to, amount);
        emit PaymentSent(tokenAddress, amount, to);
    }

    /**
     * @dev Withdraws tokens from the treasury (only owner)
     * @param tokenAddress Address of the token to be withdrawn
     * @param to Destination address
     * @param amount Amount to be withdrawn
     */
    function withdrawToken(
        address tokenAddress,
        address to,
        uint256 amount
    ) external nonReentrant onlyOwner {
        require(to != address(0), "Treasury: invalid destination address");
        require(amount > 0, "Treasury: amount must be greater than zero");

        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance >= amount, "Treasury: insufficient balance");

        token.safeTransfer(to, amount);
        emit Withdrawal(tokenAddress, amount, to);
    }

    /**
     * @dev Returns the balance of a specific token in the treasury
     * @param tokenAddress Address of the token
     * @return balance Balance of the token
     */
    function getTokenBalance(
        address tokenAddress
    ) external view returns (uint256 balance) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    /**
     * @dev Calculates the upgrade fee
     * @param currentTier Current tier of the gym
     * @param newTier New tier desired
     * @return fee Calculated fee
     */
    function calculateUpgradeFee(
        uint8 currentTier,
        uint8 newTier
    ) external view returns (uint256 fee) {
        require(
            newTier > currentTier,
            "Treasury: new tier must be higher than current"
        );

        // Simple implementation: charge more for higher tiers
        uint256 tierDifference = newTier - currentTier;

        // Use the price of the voucher of the first accepted token as base
        address tokenAddress = getFirstAcceptedToken();
        require(tokenAddress != address(0), "Treasury: no accepted tokens");

        // Fee is proportional to the tier difference
        return voucherPrices[tokenAddress] * tierDifference;
    }

    /**
     * @dev Gets the first accepted token
     * @return tokenAddress Address of the first accepted token
     */
    function getFirstAcceptedToken()
        public
        view
        returns (address tokenAddress)
    {
        // Simple example to return the first token found
        // In a real implementation, you would have a list or more sophisticated mechanism

        // This is a very inefficient implementation, just for example
        for (uint i = 0; i < 1000; i++) {
            address potentialToken = address(uint160(i + 1));
            if (acceptedTokens[potentialToken]) {
                return potentialToken;
            }
        }

        return address(0); // Returns 0 if no token is found
    }

    function setGymNFT(address _gymNFT) external onlyOwner {
        require(_gymNFT != address(0), "Treasury: invalid GymNFT address");
        gymNFT = GymNFT(_gymNFT);
    }
}
