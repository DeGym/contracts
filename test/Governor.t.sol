// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {DeGymGovernor, IGovernor} from "../src/Governor.sol";
import {DeGymToken} from "../src/token/DGYM.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import "../src/staking/StakeManager.sol";
import "../src/staking/BondPool.sol";

contract GovernorTest is Test {
    DeGymGovernor public governor;
    DeGymToken public token;
    TimelockController public timelock;
    StakeManager public stakeManager;
    BondPool public bondPool;

    address public deployer = address(0x123);
    address public voter1 = address(0x456);
    address public voter2 = address(0x789);
    address public targetContract = address(0x12345678);

    function setUp() public {
        vm.startPrank(deployer);

        token = new DeGymToken(deployer);
        token.grantRole(token.DEFAULT_ADMIN_ROLE(), deployer);
        token.grantRole(token.MINTER_ROLE(), deployer);

        address[] memory proposers = new address[](1);
        proposers[0] = deployer;
        address[] memory executors = new address[](1);
        executors[0] = address(0);

        timelock = new TimelockController(
            1 days,
            proposers,
            executors,
            deployer
        );

        token.mint(deployer, 51_000_000e18);
        token.mint(voter1, 850_000_000e18);
        token.mint(voter2, 51_000_000e18);
        token.mint(voter1, 1_000_000e18); // Mint 1 million tokens to voter1

        vm.warp(block.timestamp + 1);
        governor = new DeGymGovernor(token, timelock);

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        token.grantRole(token.DEFAULT_ADMIN_ROLE(), address(timelock));

        stakeManager = new StakeManager(address(token), address(timelock));
        token.grantRole(token.MINTER_ROLE(), address(stakeManager));
        token.revokeRole(token.DEFAULT_ADMIN_ROLE(), deployer);
        vm.stopPrank();

        vm.prank(voter1);
        stakeManager.deployBondPool();
        bondPool = BondPool(stakeManager.bondPools(voter1));
    }

    function testQueueAndExecute() public {
        vm.startPrank(voter1);

        token.delegate(voter1);
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
        governor.castVote(proposalId, 1);

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

    function testUpdateDecayConstant() public {
        vm.startPrank(address(timelock));
        uint256 newDecayConstant = 50;
        stakeManager.setDecayConstant(newDecayConstant);
        assertEq(
            stakeManager.decayConstant(),
            newDecayConstant,
            "Decay constant should be updated"
        );
        vm.stopPrank();
    }

    function testUpdateBasisPoints() public {
        vm.startPrank(address(timelock));
        uint256 newBasisPoints = 12000;
        stakeManager.setBasisPoints(newBasisPoints);
        assertEq(
            stakeManager.basisPoints(),
            newBasisPoints,
            "Basis points should be updated"
        );
        vm.stopPrank();
    }

    function testBondAfterParameterUpdate() public {
        vm.startPrank(address(timelock));
        stakeManager.setDecayConstant(50);
        stakeManager.setBasisPoints(12000);
        vm.stopPrank();

        vm.startPrank(voter1);

        uint256 amount = 1000 * 10 ** 18;
        uint256 lockDuration = 30 days;

        // Approve the BondPool to spend tokens on behalf of voter1
        token.approve(address(bondPool), amount);

        uint256 initialTotalWeight = bondPool.getTotalBondWeight();
        bondPool.bond(amount, lockDuration);
        uint256 finalTotalWeight = bondPool.getTotalBondWeight();

        assertTrue(
            finalTotalWeight > initialTotalWeight,
            "Total bond weight should increase after bonding"
        );
        assertEq(token.balanceOf(address(stakeManager)), amount);

        vm.stopPrank();
    }
}
