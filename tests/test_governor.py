import pytest
from ape import reverts


def test_initial_setup(
    governor, gym_manager, stake_manager, treasury, dao_token, vesting
):
    assert governor.gymManager() == gym_manager.address
    assert governor.stakeManager() == stake_manager.address
    assert governor.treasury() == treasury.address
    assert governor.daoToken() == dao_token.address
    assert governor.vesting() == vesting.address


def test_change_listing_factor(governor, gym_manager, deployer):
    new_listing_factor = 2000
    tx = governor.changeListingFactor(new_listing_factor, {"from": deployer})
    tx.wait()
    assert gym_manager.listingFactor() == new_listing_factor


def test_change_decay_constant(governor, treasury, deployer):
    new_decay_constant = 1500
    tx = governor.changeDecayConstant(new_decay_constant, {"from": deployer})
    tx.wait()
    assert treasury.decayConstant() == new_decay_constant


def test_change_max_supply(governor, dao_token, deployer):
    new_max_supply = 20_000_000_000 * 10 ** dao_token.decimals()
    tx = governor.changeMaxSupply(new_max_supply, {"from": deployer})
    tx.wait()
    assert dao_token.maxSupply() == new_max_supply


def test_change_voucher_manager_base_price(governor, voucher_manager, deployer):
    new_base_price = 500
    tx = governor.changeVoucherManagerBasePrice(
        voucher_manager.address, new_base_price, {"from": deployer}
    )
    tx.wait()
    assert voucher_manager.basePrice() == new_base_price


def test_set_sale_contract(governor, deployer):
    new_sale_contract = "0x1234567890abcdef1234567890abcdef12345678"
    tx = governor.setSaleContract(new_sale_contract, {"from": deployer})
    tx.wait()
    assert governor.saleContract() == new_sale_contract


def test_distribute_tokens(governor, dgym_token, vesting, deployer):
    beneficiary = "0x1234567890abcdef1234567890abcdef12345678"
    amount = 1000
    initial_balance = dgym_token.balanceOf(vesting.address)

    tx = governor.setSaleContract(deployer.address, {"from": deployer})
    tx.wait()

    tx = governor.distributeTokens(beneficiary, amount, {"from": deployer})
    tx.wait()

    assert dgym_token.balanceOf(vesting.address) == initial_balance + amount
    vesting_entry = vesting.vestings(beneficiary)
    assert vesting_entry.amount == amount


def test_burn_unsold_tokens(governor, dgym_token, deployer):
    initial_supply = dgym_token.totalSupply()
    burn_amount = 1000
    dgym_token.mint(deployer.address, burn_amount, {"from": deployer})

    tx = governor.burnUnsoldTokens(burn_amount, {"from": deployer})
    tx.wait()

    assert dgym_token.totalSupply() == initial_supply


def test_voting(governor, deployer, stakeholder, dao_token):
    # Give some voting power to the stakeholder
    dao_token.mint(stakeholder.address, 1000, {"from": deployer})
    dao_token.delegate(stakeholder.address, {"from": stakeholder})

    proposal_id = governor.propose(
        [governor.address],
        [0],
        [governor.interface.encodeABI(fn_name="changeListingFactor", args=[3000])],
        "Change listing factor to 3000",
        {"from": stakeholder},
    )
    assert governor.state(proposal_id) == 0  # Pending

    # Simulate voting
    tx = governor.castVote(proposal_id, 1, {"from": stakeholder})
    tx.wait()
    assert governor.hasVoted(proposal_id, stakeholder.address) is True

    # Simulate passing time and execute the proposal
    governor.queue(
        [governor.address],
        [0],
        [governor.interface.encodeABI(fn_name="changeListingFactor", args=[3000])],
        governor.hashProposal(
            [governor.address],
            [0],
            [governor.interface.encodeABI(fn_name="changeListingFactor", args=[3000])],
            "Change listing factor to 3000",
        ),
        {"from": stakeholder},
    )

    tx = governor.execute(
        [governor.address],
        [0],
        [governor.interface.encodeABI(fn_name="changeListingFactor", args=[3000])],
        governor.hashProposal(
            [governor.address],
            [0],
            [governor.interface.encodeABI(fn_name="changeListingFactor", args=[3000])],
            "Change listing factor to 3000",
        ),
        {"from": stakeholder},
    )
    tx.wait()

    assert governor.state(proposal_id) == 7  # Executed
    assert governor.gymManager().listingFactor() == 3000
