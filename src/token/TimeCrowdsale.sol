// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/finance/VestingWallet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {IDeGymToken} from "../../token/DGYM.sol";

/**
 * @title DeGymCrowdsale
 * @dev DeGymCrowdsale is a contract for managing a token crowdsale,
 * allowing investors to purchase tokens with ether. The contract has multiple phases,
 * each with its own rate and allocation. It also includes vesting wallet functionality.
 */
contract DeGymCrowdsale is Ownable {
    using SafeERC20 for IERC20;

    // The token being sold
    IDeGymToken public token;

    // Address where funds are collected
    address public wallet;

    // Array of phase names
    string[] public phaseNames;

    // Struct representing a phase in the crowdsale
    struct Phase {
        uint256 rate; // Number of token units a buyer gets per wei
        uint256 allocation; // Tokens allocated for this phase
        uint256 sold; // Tokens sold in this phase
        bool burnable; // Whether unsold tokens in this phase are burnable
        uint256 startTime; // Start time of this phase
        uint256 endTime; // End time of this phase
        bool active; // Whether this phase is currently active
    }

    // Mapping from phase name to phase details
    mapping(string => Phase) public phases;

    // Mapping from beneficiary address to vesting wallet address
    mapping(address => address) public vestingWallets;

    // Event for token purchase logging
    event TokensPurchased(
        address indexed purchaser,
        uint256 value,
        uint256 amount
    );

    // Event for phase ending logging
    event PhaseEnded(string phaseName, uint256 unsoldTokensBurned);

    /**
     * @dev Constructor initializes the contract with the token and wallet addresses.
     * @param tokenAddress Address of the token being sold
     * @param walletAddress Address where collected funds will be forwarded to
     */
    constructor(
        address tokenAddress,
        address walletAddress
    ) Ownable(walletAddress) {
        token = IDeGymToken(tokenAddress);
        wallet = walletAddress;
    }

    // Fallback function to receive ether payments
    receive() external payable {
        buyTokens(msg.sender);
    }

    /**
     * @dev Sets up a phase in the crowdsale.
     * @param phaseName Name of the phase
     * @param rate Number of token units a buyer gets per wei
     * @param allocation Tokens allocated for this phase
     * @param startTime Start time of this phase
     * @param endTime End time of this phase
     * @param burnable Whether unsold tokens in this phase are burnable
     */
    function setPhase(
        string memory phaseName,
        uint256 rate,
        uint256 allocation,
        uint256 startTime,
        uint256 endTime,
        bool burnable
    ) external onlyOwner {
        require(endTime > startTime, "End time must be after start time");
        require(
            startTime > block.timestamp,
            "Start time must be in the future"
        );

        phases[phaseName] = Phase({
            rate: rate,
            allocation: allocation,
            sold: 0,
            burnable: burnable,
            startTime: startTime,
            endTime: endTime,
            active: false
        });
        phaseNames.push(phaseName); // Add phase name to the list
    }

    /**
     * @dev Activates a phase in the crowdsale.
     * @param phaseName Name of the phase to activate
     */
    function activatePhase(string memory phaseName) external onlyOwner {
        Phase storage phase = phases[phaseName];
        require(
            phase.startTime <= block.timestamp,
            "Phase has not started yet"
        );
        require(phase.endTime > block.timestamp, "Phase has ended");
        require(!phase.active, "Phase is already active");

        phase.active = true;
    }

    /**
     * @dev Deactivates a phase in the crowdsale.
     * @param phaseName Name of the phase to deactivate
     */
    function deactivatePhase(string memory phaseName) external onlyOwner {
        Phase storage phase = phases[phaseName];
        require(phase.active, "Phase is not active");

        phase.active = false;

        if (phase.burnable) {
            uint256 unsoldTokens = phase.allocation - phase.sold;
            if (unsoldTokens > 0) {
                token.burn(unsoldTokens);
                emit PhaseEnded(phaseName, unsoldTokens);
            }
        }
    }

    /**
     * @dev Buys tokens for a beneficiary address.
     * @param beneficiary Address receiving the tokens
     */
    function buyTokens(address beneficiary) public payable {
        uint256 weiAmount = msg.value;
        uint256 tokens;

        require(beneficiary != address(0), "Beneficiary address cannot be 0");
        require(weiAmount != 0, "Wei amount cannot be 0");

        string memory activePhaseName = getActivePhase();
        require(bytes(activePhaseName).length > 0, "No active sale phase");

        Phase storage phase = phases[activePhaseName];
        tokens = weiAmount * phase.rate;
        require(
            phase.sold + tokens <= phase.allocation,
            "Exceeds phase allocation"
        );

        phase.sold += tokens;

        IERC20(address(token)).safeTransfer(beneficiary, tokens); // Using SafeERC20 library explicitly
        emit TokensPurchased(beneficiary, weiAmount, tokens);

        payable(wallet).transfer(weiAmount);
    }

    /**
     * @dev Returns the name of the active phase.
     * @return The name of the active phase
     */
    function getActivePhase() public view returns (string memory) {
        for (uint i = 0; i < phaseNames.length; i++) {
            Phase storage phase = phases[phaseNames[i]];
            if (phase.active) {
                return phaseNames[i];
            }
        }
        return "";
    }

    /**
     * @dev Creates a vesting wallet for a beneficiary.
     * @param beneficiary Address receiving the vested tokens
     * @param startTimestamp Start timestamp of the vesting period
     * @param durationSeconds Duration of the vesting period in seconds
     */
    function createVestingWallet(
        address beneficiary,
        uint64 startTimestamp,
        uint64 durationSeconds
    ) external onlyOwner {
        require(
            vestingWallets[beneficiary] == address(0),
            "Vesting wallet already exists for beneficiary"
        );
        VestingWallet vestingWallet = new VestingWallet(
            beneficiary,
            startTimestamp,
            durationSeconds
        );
        vestingWallets[beneficiary] = address(vestingWallet);
    }

    /**
     * @dev Transfers tokens to a vesting wallet.
     * @param beneficiary Address receiving the vested tokens
     * @param amount Amount of tokens to transfer
     */
    function transferToVestingWallet(
        address beneficiary,
        uint256 amount
    ) external onlyOwner {
        require(
            vestingWallets[beneficiary] != address(0),
            "Vesting wallet does not exist for beneficiary"
        );
        IERC20(address(token)).safeTransfer(
            vestingWallets[beneficiary],
            amount
        ); // Using SafeERC20 library explicitly
    }

    /**
     * @dev Withdraws tokens from the contract to the wallet address.
     * @param tokenAddress Address of the token to withdraw
     */
    function withdrawTokens(IERC20 tokenAddress) external onlyOwner {
        uint256 balance = tokenAddress.balanceOf(address(this));
        tokenAddress.safeTransfer(wallet, balance);
    }

    /**
     * @dev Withdraws ether from the contract to the wallet address.
     */
    function withdraw() external onlyOwner {
        payable(wallet).transfer(address(this).balance);
    }
}
