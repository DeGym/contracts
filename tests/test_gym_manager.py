import pytest


def test_add_gym(gym_manager, gym):
    gym = gym.address if type(gym) != str else gym
    tx = gym_manager.addGym(gym, 1, "Geolocation", "metadata", ["USDT"], sender=gym)
    tx.wait()
    assert gym_manager.getGymDetails(1)["tier"] == 1


def test_update_gym(gym_manager, gym):
    gym = gym.address if type(gym) != str else gym
    gym_manager.addGym(gym, 1, "Geolocation", "metadata", ["USDT"], sender=gym).wait()
    tx = gym_manager.updateGym(
        1, 2, "NewGeolocation", "new_metadata", ["USDT"], sender=gym
    )
    tx.wait()
    assert gym_manager.getGymDetails(1)["tier"] == 2


def test_remove_gym(gym_manager, gym):
    gym = gym.address if type(gym) != str else gym
    gym_manager.addGym(gym, 1, "Geolocation", "metadata", ["USDT"], sender=gym).wait()
    tx = gym_manager.removeGym(1, sender=gym)
    tx.wait()
    with pytest.raises(Exception):
        gym_manager.getGymDetails(1)
