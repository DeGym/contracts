// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DeGymToken} from "./DGYM.sol";

contract Crowdfund is Ownable {
    using SafeERC20 for DeGymToken;

    DeGymToken public token;
    address public wallet;
    string[] public phaseNames;

    struct Phase {
        uint256 rate; // Rate in percentage (e.g., 100 means 1%)
        uint256 allocation; // in tokens
        uint256 sold;
        bool burnable;
        uint256 startTime;
        uint256 endTime;
        bool active;
        uint64 cliffDuration;
        uint64 vestingDuration;
    }

    mapping(string => Phase) public phases;
    mapping(address => address) public vestingWallets;

    event TokensPurchased(
        address indexed purchaser,
        uint256 value,
        uint256 amount
    );
    event PhaseEnded(string phaseName, uint256 unsoldTokensBurned);

    constructor(
        address tokenAddress,
        address walletAddress
    ) Ownable(msg.sender) {
        token = DeGymToken(tokenAddress);
        wallet = walletAddress;
    }

    receive() external payable {
        buyTokens(msg.sender);
    }

    function createPhase(
        string memory phaseName,
        uint256 rate, // Rate in percentage (100 = 1%)
        uint256 allocation,
        uint256 startTime,
        uint256 duration,
        bool burnable,
        uint64 cliffDuration,
        uint64 vestingDuration
    ) public onlyOwner {
        uint256 endTime = startTime + duration;
        require(endTime > startTime, "End time must be after start time");

        phases[phaseName] = Phase({
            rate: rate,
            allocation: allocation,
            sold: 0,
            burnable: burnable,
            startTime: startTime,
            endTime: endTime,
            active: false,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration
        });
        phaseNames.push(phaseName);
    }

    function activatePhaseAutomatically() public {
        for (uint i = 0; i < phaseNames.length; i++) {
            Phase storage phase = phases[phaseNames[i]];
            if (
                !phase.active &&
                phase.startTime <= block.timestamp &&
                phase.endTime > block.timestamp
            ) {
                phase.active = true;
            }
        }
    }

    function deactivatePhaseAutomatically() public {
        for (uint i = 0; i < phaseNames.length; i++) {
            Phase storage phase = phases[phaseNames[i]];
            if (
                phase.active &&
                (phase.endTime <= block.timestamp ||
                    phase.sold >= phase.allocation)
            ) {
                phase.active = false;
                if (phase.burnable) {
                    uint256 unsoldTokens = phase.allocation - phase.sold;
                    if (unsoldTokens > 0) {
                        token.burnFrom(owner(), unsoldTokens);
                        emit PhaseEnded(phaseNames[i], unsoldTokens);
                    }
                }
                createVestingWallet(
                    msg.sender,
                    uint64(block.timestamp + phase.cliffDuration),
                    uint64(phase.vestingDuration)
                );
            }
        }
    }

    function buyTokens(address beneficiary) public payable {
        activatePhaseAutomatically();
        deactivatePhaseAutomatically();

        uint256 weiAmount = msg.value;
        uint256 tokens;

        require(beneficiary != address(0), "Beneficiary address cannot be 0");
        require(weiAmount != 0, "Wei amount cannot be 0");

        string memory activePhaseName = getActivePhase();
        require(bytes(activePhaseName).length > 0, "No active sale phase");

        Phase storage phase = phases[activePhaseName];

        // Calculate tokens based on percentage rate
        tokens = (weiAmount * phase.rate) / 10000; // Assuming rate is in basis points (10000 = 100%)

        require(
            phase.sold + tokens <= phase.allocation,
            "Exceeds phase allocation"
        );

        phase.sold += tokens;

        if (phase.cliffDuration > 0 || phase.vestingDuration > 0) {
            createVestingWallet(
                beneficiary,
                uint64(block.timestamp + phase.cliffDuration),
                uint64(phase.vestingDuration)
            );
            address vestingWallet = vestingWallets[beneficiary];
            token.safeTransferFrom(owner(), vestingWallet, tokens);
        } else {
            token.safeTransferFrom(owner(), beneficiary, tokens);
        }

        emit TokensPurchased(beneficiary, weiAmount, tokens);

        payable(wallet).transfer(weiAmount);
    }

    function getActivePhase() public view returns (string memory) {
        for (uint i = 0; i < phaseNames.length; i++) {
            Phase storage phase = phases[phaseNames[i]];
            if (phase.active) {
                return phaseNames[i];
            }
        }
        return "";
    }

    function createVestingWallet(
        address beneficiary,
        uint64 startTimestamp,
        uint64 durationSeconds
    ) internal {
        if (vestingWallets[beneficiary] == address(0)) {
            VestingWallet vestingWallet = new VestingWallet(
                beneficiary,
                startTimestamp,
                durationSeconds
            );
            vestingWallets[beneficiary] = address(vestingWallet);
        }
    }

    function transferToVestingWallet(
        address beneficiary,
        uint256 amount
    ) external onlyOwner {
        require(
            vestingWallets[beneficiary] != address(0),
            "Vesting wallet does not exist for beneficiary"
        );
        token.safeTransferFrom(owner(), vestingWallets[beneficiary], amount);
    }
}
