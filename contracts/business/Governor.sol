// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IGovernor, Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import "./managers/VoucherManager.sol";
import "./managers/GymManager.sol";
import "./managers/StakeManager.sol";
import "./Treasury.sol";
import "./Token.sol";
import "./utilities/Vesting.sol";

contract DeGymGovernor is
    Governor,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    GymManager public gymManager;
    StakeManager public stakeManager;
    Treasury public treasury;
    DeGymToken public daoToken;
    Vesting public vesting;
    address public saleContract;

    event ListingFactorChanged(uint256 newListingFactor);
    event DecayConstantChanged(uint256 newDecayConstant);
    event MaxSupplyChanged(uint256 newMaxSupply);
    event VoucherManagerBasePriceChanged(
        address voucherManager,
        uint256 newBasePrice
    );
    event SaleContractSet(address saleContract);
    event TokensDistributed(address beneficiary, uint256 amount);
    event UnsoldTokensBurned(uint256 amount);

    constructor(
        IVotes _token,
        TimelockController _timelock
        address _gymManager,
        address _stakeManager,
        address _treasury,
        address _vesting
    )
        Governor("DeGym Governor") 
        GovernorVotes(_token) 
        GovernorVotesQuorumFraction(4) 
        GovernorTimelockControl(_timelock) 
    {
        gymManager = GymManager(_gymManager);
        stakeManager = StakeManager(_stakeManager);
        treasury = Treasury(_treasury);
        daoToken = DeGymToken(_daoToken);
        vesting = Vesting(_vesting);
    }

    function votingDelay() public pure override returns (uint256) {
        return 7200; // 1 day
    }

    function votingPeriod() public pure override returns (uint256) {
        return 50400; // 1 week
    }

    function proposalThreshold() public pure override returns (uint256) {
        return 0;
    }


    function changeListingFactor(uint256 newListingFactor) external onlyOwner {
        gymManager.setListingFactor(newListingFactor);
        emit ListingFactorChanged(newListingFactor);
    }

    function changeDecayConstant(uint256 newDecayConstant) external onlyOwner {
        treasury.setDecayConstant(newDecayConstant);
        emit DecayConstantChanged(newDecayConstant);
    }

    function changeMaxSupply(uint256 newMaxSupply) external onlyOwner {
        daoToken.setMaxSupply(newMaxSupply);
        emit MaxSupplyChanged(newMaxSupply);
    }

    function changeVoucherManagerBasePrice(
        address voucherManagerAddress,
        uint256 newBasePrice
    ) external onlyOwner {
        VoucherManager(voucherManagerAddress).setBasePrice(newBasePrice);
        emit VoucherManagerBasePriceChanged(
            voucherManagerAddress,
            newBasePrice
        );
    }

    function setSaleContract(address _saleContract) external onlyOwner {
        saleContract = _saleContract;
        emit SaleContractSet(_saleContract);
    }

    function distributeTokens(address beneficiary, uint256 amount) external {
        require(
            msg.sender == saleContract,
            "Only sale contract can distribute tokens"
        );
        token.mint(address(vesting), amount);
        vesting.setVesting(beneficiary, amount, block.timestamp, 365 days);
        emit TokensDistributed(beneficiary, amount);
    }

    function burnUnsoldTokens(uint256 amount) external onlyOwner {
        token.burn(amount);
        emit UnsoldTokensBurned(amount);
    }

    // The functions below are overrides required by Solidity.

    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(
        uint256 proposalId
    ) public view virtual override(Governor, GovernorTimelockControl) returns (bool) {
        return super.proposalNeedsQueuing(proposalId);
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }
}
