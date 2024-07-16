import pytest


def test_add_gym(gym_manager_contract, provider):
    provider = provider.address if type(provider) != str else provider
    tx = gym_manager_contract.addGym(provider, 1, "Geolocation", "metadata", ["USDT"], sender=provider)
    tx.wait()
    assert gym_manager_contract.getGymDetails(1)["tier"] == 1

def test_update_gym(gym_manager_contract, provider):
    provider = provider.address if type(provider) != str else provider
    gym_manager_contract.addGym(provider, 1, "Geolocation", "metadata", ["USDT"], sender=provider).wait()
    tx = gym_manager_contract.updateGym(1, 2, "NewGeolocation", "new_metadata", ["USDT"], sender=provider)
    tx.wait()
    assert gym_manager_contract.getGymDetails(1)["tier"] == 2

def test_remove_gym(gym_manager_contract, provider):
    provider = provider.address if type(provider) != str else provider
    gym_manager_contract.addGym(provider, 1, "Geolocation", "metadata", ["USDT"], sender=provider).wait()
    tx = gym_manager_contract.removeGym(1, sender=provider)
    tx.wait()
    with pytest.raises(Exception):
        gym_manager_contract.getGymDetails(1)

