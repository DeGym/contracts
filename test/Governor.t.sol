// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {DeGymGovernor, IGovernor} from "../src/Governor.sol";
import {DeGymToken} from "../src/token/DGYM.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract GovernorTest is Test {
    DeGymGovernor public governor;
    DeGymToken public token;
    TimelockController public timelock;

    address public deployer = address(0x123);
    address public voter1 = address(0x456);
    address public voter2 = address(0x789);
    address public targetContract = address(0x12345678); // Mock contract for testing

    function setUp() public {
        vm.startPrank(deployer);

        token = new DeGymToken(deployer);

        address[] memory proposers = new address[](1);
        proposers[0] = deployer;

        address[] memory executors = new address[](1);
        executors[0] = address(0); // This means anyone can execute

        timelock = new TimelockController(
            1 days,
            proposers,
            executors,
            deployer
        );

        // Allocate tokens to voters
        token.mint(deployer, 51_000_000e18);
        token.mint(voter1, 850_000_000e18);
        token.mint(voter2, 51_000_000e18);

        vm.warp(block.timestamp + 1);
        governor = new DeGymGovernor(token, timelock);

        // Grant roles to the governor
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        // Revoke admin role from deployer and give it to timelock
        token.grantRole(token.DEFAULT_ADMIN_ROLE(), address(timelock));
        token.revokeRole(token.DEFAULT_ADMIN_ROLE(), deployer);

        vm.stopPrank();
    }

    function testPropose() public {
        vm.startPrank(voter1);
        token.delegate(voter1);
        vm.warp(block.timestamp + 1);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = targetContract;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("someFunction()");

        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "Proposal: Call someFunction"
        );

        assertEq(
            uint(governor.state(proposalId)),
            uint(IGovernor.ProposalState.Pending)
        );

        vm.stopPrank();
    }

    function createProposal() internal returns (uint256) {
        vm.startPrank(voter1);
        token.delegate(voter1);
        vm.warp(block.timestamp + 1);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(token); // Use the correct target
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "setCap(uint256)",
            20_000_000_000e18
        );

        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "Proposal: Change token cap to 20 billion"
        );

        vm.stopPrank();
        return proposalId;
    }

    function targetsForProposal() internal pure returns (address[] memory) {
        address[] memory targets = new address[](1);
        targets[0] = address(0x12345678); // Mock target contract
        return targets;
    }

    function valuesForProposal() internal pure returns (uint256[] memory) {
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        return values;
    }

    function calldataForProposal() internal pure returns (bytes[] memory) {
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "setCap(uint256)",
            20_000_000_000e18
        );
        return calldatas;
    }

    function testVoteFor() public {
        uint256 proposalId = createProposal();

        vm.startPrank(voter1);
        token.delegate(voter1);
        vm.warp(block.timestamp + governor.votingDelay() + 1);

        governor.castVote(proposalId, 1); // 1 = For

        vm.stopPrank();

        assertEq(
            uint(governor.state(proposalId)),
            uint(IGovernor.ProposalState.Active)
        );
    }

    function testVoteAgainst() public {
        uint256 proposalId = createProposal();

        vm.startPrank(voter1);
        token.delegate(voter1);
        vm.warp(block.timestamp + governor.votingDelay() + 1);

        governor.castVote(proposalId, 0); // 0 = Against

        vm.stopPrank();

        assertEq(
            uint(governor.state(proposalId)),
            uint(IGovernor.ProposalState.Active)
        );
    }

    function testVoteAbstain() public {
        uint256 proposalId = createProposal();

        vm.startPrank(voter1);
        token.delegate(voter1);
        vm.warp(block.timestamp + governor.votingDelay() + 1);

        governor.castVote(proposalId, 2); // 2 = Abstain

        vm.stopPrank();

        assertEq(
            uint(governor.state(proposalId)),
            uint(IGovernor.ProposalState.Active)
        );
    }

    function testProposalStateSucceeded() public {
        uint256 proposalId = createProposal();

        vm.startPrank(voter1);
        token.delegate(voter1);
        vm.warp(block.timestamp + governor.votingDelay() + 1);

        governor.castVote(proposalId, 1); // 1 = For
        vm.stopPrank();

        vm.warp(block.timestamp + governor.votingPeriod() + 1);

        assertEq(
            uint(governor.state(proposalId)),
            uint(IGovernor.ProposalState.Succeeded)
        );
    }

    function testProposalStateDefeated() public {
        uint256 proposalId = createProposal();

        vm.startPrank(voter1);
        token.delegate(voter1);
        vm.warp(block.timestamp + governor.votingDelay() + 1);

        governor.castVote(proposalId, 0); // 0 = Against
        vm.stopPrank();

        vm.warp(block.timestamp + governor.votingPeriod() + 1);

        assertEq(
            uint(governor.state(proposalId)),
            uint(IGovernor.ProposalState.Defeated)
        );
    }

    function testQueueAndExecute() public {
        vm.startPrank(voter1);

        // Delegate votes to self
        token.delegate(voter1);

        // Ensure that delegation is recognized by moving forward in time
        vm.warp(block.timestamp + 1);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(token);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "setCap(uint256)",
            15_000_000_000e18
        );

        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "Proposal: Change token cap to 15 billion"
        );

        vm.warp(block.timestamp + governor.votingDelay() + 1);
        governor.castVote(proposalId, 1); // 1 = For

        vm.warp(block.timestamp + governor.votingPeriod() + 1);

        governor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes("Proposal: Change token cap to 15 billion"))
        );

        assertEq(
            uint(governor.state(proposalId)),
            uint(IGovernor.ProposalState.Queued)
        );

        vm.warp(block.timestamp + timelock.getMinDelay() + 1);

        governor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes("Proposal: Change token cap to 15 billion"))
        );

        assertEq(
            uint(governor.state(proposalId)),
            uint(IGovernor.ProposalState.Executed)
        );

        assertEq(token.cap(), 15_000_000_000e18);

        vm.stopPrank();
    }
}
