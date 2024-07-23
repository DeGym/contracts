import pytest


def test_tge(governance, dgym_token, stakeholder):
    initial_balance = dgym_token.balanceOf(stakeholder)
    tge_amount = 1000

    # Simulate TGE event
    governance.distributeTokens(stakeholder, tge_amount, {"from": governance.owner()})
    assert dgym_token.balanceOf(stakeholder) == initial_balance + tge_amount


def test_vesting(vesting, dgym_token, stakeholder, chain):
    vesting_amount = 1000
    initial_balance = dgym_token.balanceOf(stakeholder)

    # Ensure the stakeholder has tokens vested
    vesting.setVesting(
        stakeholder,
        vesting_amount,
        chain.time(),
        365 * 24 * 60 * 60,
        {"from": vesting.owner()},
    )
    assert vesting.balanceOf(stakeholder) == vesting_amount

    # Fast forward time to halfway through the vesting period
    chain.sleep(365 * 24 * 60 * 60 / 2)
    vesting.claim({"from": stakeholder})

    # Verify that half of the tokens have been vested and claimed
    assert dgym_token.balanceOf(stakeholder) >= initial_balance + vesting_amount / 2


def test_purchase_tokens(sale_contract, dgym_token, stakeholder, deployer):
    purchase_amount = 1000
    initial_balance = dgym_token.balanceOf(stakeholder)

    # Ensure stakeholder can purchase tokens
    dgym_token.approve(sale_contract.address, purchase_amount, {"from": stakeholder})
    sale_contract.purchaseTokens(purchase_amount, {"from": stakeholder})

    assert dgym_token.balanceOf(stakeholder) == initial_balance - purchase_amount
    assert dgym_token.balanceOf(sale_contract.address) == purchase_amount


def test_unsold_tokens_burn(governance, dgym_token, deployer):
    unsold_amount = 1000
    initial_supply = dgym_token.totalSupply()

    # Ensure the governance can burn unsold tokens
    dgym_token.mint(governance.address, unsold_amount, {"from": deployer})
    governance.burnUnsoldTokens(unsold_amount, {"from": governance.owner()})

    assert dgym_token.totalSupply() == initial_supply
