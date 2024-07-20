import pytest


def test_deploy_bond_pool(stake_manager, stakeholder):
    tx = stake_manager.deployBondPool({"from": stakeholder})
    tx.wait()
    bond_pool_address = stake_manager.getBondPool(stakeholder)
    assert bond_pool_address != "0x0000000000000000000000000000000000000000"


def test_bond_tokens(bond_pool, stakeholder, dgym_token):
    initial_balance = dgym_token.balanceOf(stakeholder)
    bond_amount = 1000
    dgym_token.approve(bond_pool.address, bond_amount, {"from": stakeholder})
    tx = bond_pool.bond(bond_amount, 30, False, {"from": stakeholder})
    tx.wait()
    assert dgym_token.balanceOf(stakeholder) == initial_balance - bond_amount
    assert bond_pool.totalStaked() == bond_amount


def test_unbond_tokens(bond_pool, stakeholder, dgym_token, chain):
    bond_amount = 1000
    dgym_token.approve(bond_pool.address, bond_amount, {"from": stakeholder})
    bond_pool.bond(bond_amount, 1, False, {"from": stakeholder})
    chain.sleep(60 * 60 * 24 * 2)  # Fast forward time by 2 days
    initial_balance = dgym_token.balanceOf(stakeholder)
    bond_pool.unbond(0, {"from": stakeholder})
    assert dgym_token.balanceOf(stakeholder) == initial_balance + bond_amount
    assert bond_pool.totalStaked() == 0


def test_receive_rewards(bond_pool, stakeholder, dgym_token, deployer):
    reward_amount = 500
    dgym_token.transfer(bond_pool.address, reward_amount, {"from": deployer})
    initial_balance = dgym_token.balanceOf(stakeholder)
    bond_pool.updateReward(reward_amount, {"from": deployer})
    assert dgym_token.balanceOf(bond_pool.address) == reward_amount
    bond_pool.claimRewards(0, {"from": stakeholder})
    assert dgym_token.balanceOf(stakeholder) == initial_balance + reward_amount


def test_claim_dgym_rewards(bond_pool, stakeholder, dgym_token, deployer):
    reward_amount = 500
    dgym_token.transfer(bond_pool.address, reward_amount, {"from": deployer})
    bond_pool.updateReward(reward_amount, {"from": deployer})
    initial_balance = dgym_token.balanceOf(stakeholder)
    bond_pool.claimRewards(0, {"from": stakeholder})
    assert dgym_token.balanceOf(stakeholder) == initial_balance + reward_amount


def test_calculate_total_staked_duration(bond_pool, stakeholder, dgym_token):
    dgym_token.approve(bond_pool.address, 1000, {"from": stakeholder})
    bond_pool.bond(500, 10, False, {"from": stakeholder})
    bond_pool.bond(500, 20, False, {"from": stakeholder})
    assert bond_pool.totalWeight() > 0  # total weight should be greater than zero


def test_calculate_rewards(bond_pool, stakeholder, dgym_token):
    dgym_token.approve(bond_pool.address, 1000, {"from": stakeholder})
    bond_pool.bond(500, 10, False, {"from": stakeholder})
    bond_pool.bond(500, 20, False, {"from": stakeholder})
    total_rewards = bond_pool.totalEarnings()
    assert total_rewards > 0
