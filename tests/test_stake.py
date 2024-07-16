import pytest


def test_deploy_stake_pool(stake_manager, stakeholder):
    tx = stake_manager.deployUserStakePool({'from': stakeholder})
    tx.wait()
    stake_pool_address = stake_manager.stakePools(stakeholder)
    assert stake_pool_address != '0x0000000000000000000000000000000000000000'


def test_stake_tokens(stake_pool, stakeholder, token):
    initial_balance = token.balanceOf(stakeholder)
    stake_amount = 1000
    token.approve(stake_pool.address, stake_amount, {"from": stakeholder})
    tx = stake_pool.stake(stake_amount, 30, False, {"from": stakeholder})
    tx.wait()
    assert token.balanceOf(stakeholder) == initial_balance - stake_amount
    assert stake_pool.totalStaked() == stake_amount


# TODO
def test_unstake_tokens(stake_pool, stakeholder, token):
    stake_amount = 1000
    token.approve(stake_pool.address, stake_amount, {"from": stakeholder})
    stake_pool.stake(stake_amount, 1, False, {"from": stakeholder})
    chain.sleep(60 * 60 * 24 * 2)  # Fast forward time by 2 days
    initial_balance = token.balanceOf(stakeholder)
    stake_pool.unstake(0, {"from": stakeholder})
    assert token.balanceOf(stakeholder) == initial_balance + stake_amount
    assert stake_pool.totalStaked() == 0


def test_receive_rewards(stake_pool, stakeholder, token, deployer):
    reward_amount = 500
    token.transfer(stake_pool.address, reward_amount, {"from": deployer})
    initial_balance = token.balanceOf(stakeholder)
    stake_pool.receiveRewards(reward_amount, {"from": deployer})
    assert token.balanceOf(stake_pool.address) == reward_amount
    stake_pool.claimDGYMRewards({"from": stakeholder})
    assert token.balanceOf(stakeholder) == initial_balance + reward_amount


def test_claim_dgym_rewards(stake_pool, stakeholder, token, deployer):
    reward_amount = 500
    token.transfer(stake_pool.address, reward_amount, {"from": deployer})
    stake_pool.receiveRewards(reward_amount, {"from": deployer})
    initial_balance = token.balanceOf(stakeholder)
    stake_pool.claimDGYMRewards({"from": stakeholder})
    assert token.balanceOf(stakeholder) == initial_balance + reward_amount


def test_calculate_total_staked_duration(stake_pool, stakeholder, token):
    token.approve(stake_pool.address, 1000, {"from": stakeholder})
    stake_pool.stake(500, 10, False, {"from": stakeholder})
    stake_pool.stake(500, 20, False, {"from": stakeholder})
    assert stake_pool.calculateTotalStakedDuration() == 15


def test_calculate_rewards(stake_pool, stakeholder, token):
    token.approve(stake_pool.address, 1000, {"from": stakeholder})
    stake_pool.stake(500, 10, False, {"from": stakeholder})
    stake_pool.stake(500, 20, False, {"from": stakeholder})
    total_rewards = stake_pool.calculateRewards()
    assert total_rewards > 0
