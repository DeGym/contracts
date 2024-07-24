import pytest
from ape import project, chain
from ape.utils import ZERO_ADDRESS


def test_governor_proposal(deployer, dgym_token, governor, vesting, accounts):
    # Step 1: Create proposal to burn tokens and set max supply
    proposer = accounts[0]
    new_max_supply = 15_000_000_000 * 10 ** dgym_token.decimals()
    burn_amount = 500_000 * 10 ** dgym_token.decimals()

    # Mint some tokens to the proposer to create voting power
    dgym_token.mint(
        proposer, 1_000_000 * 10 ** dgym_token.decimals(), {"from": deployer}
    )

    # Transfer some tokens to vesting contract to simulate a state
    dgym_token.mint(vesting.address, burn_amount, {"from": deployer})

    # Create proposal calldata
    targets = [dgym_token.address, dgym_token.address]
    values = [0, 0]
    calldatas = [
        dgym_token.setMaxSupply.encode_input(new_max_supply),
        dgym_token.burn.encode_input(burn_amount),
    ]
    description = "Proposal #1: Increase max supply and burn unsold tokens"

    # Step 2: Propose
    proposal_id = governor.propose(
        targets, values, calldatas, description, {"from": proposer}
    )

    # Step 3: Vote
    governor.castVote(proposal_id, 1, {"from": proposer})  # 1 means 'for' vote

    # Step 4: Wait for voting period to end
    chain.mine(governor.votingPeriod())

    # Step 5: Queue the proposal
    description_hash = governor.hashProposal(targets, values, calldatas, description)
    governor.queue(targets, values, calldatas, description_hash, {"from": proposer})

    # Step 6: Execute the proposal
    chain.mine(governor.minDelay())
    governor.execute(targets, values, calldatas, description_hash, {"from": proposer})

    # Step 7: Verify changes
    assert dgym_token.maxSupply() == new_max_supply
    assert dgym_token.totalSupply() == (
        1_000_000_000 * 10 ** dgym_token.decimals() + burn_amount - burn_amount
    )


def test_burn_unsold_tokens(deployer, dgym_token, governor, accounts):
    initial_supply = dgym_token.totalSupply()
    burn_amount = 500_000 * 10 ** dgym_token.decimals()

    # Mint some tokens to the deployer to burn
    dgym_token.mint(deployer, burn_amount, {"from": deployer})

    # Set up sale contract in governor
    sale_contract = accounts[1]
    governor.setSaleContract(sale_contract, {"from": deployer})

    # Burn tokens through sale contract (mocked as sale_contract)
    dgym_token.burn(burn_amount, {"from": deployer})

    assert dgym_token.totalSupply() == initial_supply


def test_set_max_supply(deployer, dgym_token, governor, accounts):
    initial_max_supply = dgym_token.maxSupply()
    new_max_supply = 15_000_000_000 * 10 ** dgym_token.decimals()

    # Propose to change max supply
    proposer = accounts[0]
    targets = [dgym_token.address]
    values = [0]
    calldatas = [dgym_token.setMaxSupply.encode_input(new_max_supply)]
    description = "Proposal #2: Increase max supply"

    proposal_id = governor.propose(
        targets, values, calldatas, description, {"from": proposer}
    )
    governor.castVote(proposal_id, 1, {"from": proposer})
    chain.mine(governor.votingPeriod())

    description_hash = governor.hashProposal(targets, values, calldatas, description)
    governor.queue(targets, values, calldatas, description_hash, {"from": proposer})
    chain.mine(governor.minDelay())
    governor.execute(targets, values, calldatas, description_hash, {"from": proposer})

    assert dgym_token.maxSupply() == new_max_supply
