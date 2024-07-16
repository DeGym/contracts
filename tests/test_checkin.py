import pytest


def test_checkin(checkin, gym_manager, voucher_manager, gym, costumer):
    costumer = costumer.address if type(costumer) != str else costumer
    gym = gym.address if type(gym) != str else gym
    voucher_manager.createVoucher(costumer, 1, 30, "UTC", sender=gym).wait()
    gym_manager.addGym(gym, 1, "Geolocation", "metadata", ["USDT"], sender=gym).wait()
    voucher_manager.approve(checkin.address, 0, sender=costumer)
    tx = checkin.checkin(0, 1, 1, sender=costumer)
    tx.wait()
    assert checkin.getCheckinStatus(costumer, 1)


def test_invalid_checkin(checkin, gym_manager, voucher_manager, gym, costumer):
    costumer = costumer.address if type(costumer) != str else costumer
    gym = gym.address if type(gym) != str else gym
    voucher_manager.createVoucher(costumer, 1, 30, "UTC", sender=gym).wait()
    gym_manager.addGym(gym, 2, "Geolocation", "metadata", ["USDT"], sender=gym).wait()
    voucher_manager.approve(checkin.address, 0, sender=costumer)
    with pytest.raises(Exception):
        checkin.checkin(0, 1, 1, sender=costumer)
