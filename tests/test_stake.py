import pytest


def test_stake_tokens(user_stake_pool, user, token):
    initial_balance = token.balanceOf(user)
    stake_amount = 1000
    token.approve(user_stake_pool.address, stake_amount, {"from": user})
    tx = user_stake_pool.stake(stake_amount, 30, False, {"from": user})
    tx.wait()
    assert token.balanceOf(user) == initial_balance - stake_amount
    assert user_stake_pool.totalStaked() == stake_amount


# TODO
def test_unstake_tokens(user_stake_pool, user, token):
    stake_amount = 1000
    token.approve(user_stake_pool.address, stake_amount, {"from": user})
    user_stake_pool.stake(stake_amount, 1, False, {"from": user})
    chain.sleep(60 * 60 * 24 * 2)  # Fast forward time by 2 days
    initial_balance = token.balanceOf(user)
    user_stake_pool.unstake(0, {"from": user})
    assert token.balanceOf(user) == initial_balance + stake_amount
    assert user_stake_pool.totalStaked() == 0


def test_receive_rewards(user_stake_pool, user, token, deployer):
    reward_amount = 500
    token.transfer(user_stake_pool.address, reward_amount, {"from": deployer})
    initial_balance = token.balanceOf(user)
    user_stake_pool.receiveRewards(reward_amount, {"from": deployer})
    assert token.balanceOf(user_stake_pool.address) == reward_amount
    user_stake_pool.claimDGYMRewards({"from": user})
    assert token.balanceOf(user) == initial_balance + reward_amount


def test_claim_dgym_rewards(user_stake_pool, user, token, deployer):
    reward_amount = 500
    token.transfer(user_stake_pool.address, reward_amount, {"from": deployer})
    user_stake_pool.receiveRewards(reward_amount, {"from": deployer})
    initial_balance = token.balanceOf(user)
    user_stake_pool.claimDGYMRewards({"from": user})
    assert token.balanceOf(user) == initial_balance + reward_amount


def test_calculate_total_staked_duration(user_stake_pool, user, token):
    token.approve(user_stake_pool.address, 1000, {"from": user})
    user_stake_pool.stake(500, 10, False, {"from": user})
    user_stake_pool.stake(500, 20, False, {"from": user})
    assert user_stake_pool.calculateTotalStakedDuration() == 15


def test_calculate_rewards(user_stake_pool, user, token):
    token.approve(user_stake_pool.address, 1000, {"from": user})
    user_stake_pool.stake(500, 10, False, {"from": user})
    user_stake_pool.stake(500, 20, False, {"from": user})
    total_rewards = user_stake_pool.calculateRewards()
    assert total_rewards > 0
