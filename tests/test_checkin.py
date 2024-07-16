import pytest


def test_checkin(
    checkin_contract, gym_manager_contract, voucher_manager_contract, provider, consumer
):
    consumer = consumer.address if type(consumer) != str else consumer
    provider = provider.address if type(provider) != str else provider
    voucher_manager_contract.createVoucher(
        consumer, 1, 30, "UTC", sender=provider
    ).wait()
    gym_manager_contract.addGym(
        provider, 1, "Geolocation", "metadata", ["USDT"], sender=provider
    ).wait()
    voucher_manager_contract.approve(checkin_contract.address, 0, sender=consumer)
    tx = checkin_contract.checkin(0, 1, 1, sender=consumer)
    tx.wait()
    assert checkin_contract.getCheckinStatus(consumer, 1)


def test_invalid_checkin(
    checkin_contract, gym_manager_contract, voucher_manager_contract, provider, consumer
):
    consumer = consumer.address if type(consumer) != str else consumer
    provider = provider.address if type(provider) != str else provider
    voucher_manager_contract.createVoucher(
        consumer, 1, 30, "UTC", sender=provider
    ).wait()
    gym_manager_contract.addGym(
        provider, 2, "Geolocation", "metadata", ["USDT"], sender=provider
    ).wait()
    voucher_manager_contract.approve(checkin_contract.address, 0, sender=consumer)
    with pytest.raises(Exception):
        checkin_contract.checkin(0, 1, 1, sender=consumer)
