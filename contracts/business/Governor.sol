// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./managers/VoucherManager.sol";
import "./managers/GymManager.sol";
import "./managers/StakeManager.sol";
import "./Treasury.sol";
import "./Token.sol";
import "./utilities/Vesting.sol";

contract DeGymGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl,
    Ownable
{
    GymManager public gymManager;
    StakeManager public stakeManager;
    Treasury public treasury;
    Token public daoToken;
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
        TimelockController _timelock,
        address _gymManager,
        address _stakeManager,
        address _treasury,
        address _daoToken,
        address _vesting
    )
        Governor("DeGymGovernor")
        GovernorSettings(1 /* 1 block */, 45818 /* 1 week */, 1e18)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(4)
        GovernorTimelockControl(_timelock)
    {
        gymManager = GymManager(_gymManager);
        stakeManager = StakeManager(_stakeManager);
        treasury = Treasury(_treasury);
        daoToken = Token(_daoToken);
        vesting = Vesting(_vesting);
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
        daoToken.mint(address(vesting), amount);
        vesting.setVesting(beneficiary, amount, block.timestamp, 365 days);
        emit TokensDistributed(beneficiary, amount);
    }

    function burnUnsoldTokens(uint256 amount) external onlyOwner {
        daoToken.burn(amount);
        emit UnsoldTokensBurned(amount);
    }

    // The following functions are overrides required by Solidity.
    function votingDelay()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(
        uint256 blockNumber
    )
        public
        view
        override(IGovernor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function state(
        uint256 proposalId
    )
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(Governor, IGovernor) returns (uint256) {
        return super.propose(targets, values, calldatas, description);
    }

    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        public
        payable
        override(Governor, GovernorTimelockControl)
        returns (uint256)
    {
        return super.execute(targets, values, calldatas, descriptionHash);
    }

    function cancel(
        bytes32 id
    ) public override(GovernorTimelockControl) returns (uint256) {
        return super.cancel(id);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
