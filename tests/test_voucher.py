import pytest


def test_create_voucher(voucher_manager, deployer, costumer):
    costumer = costumer.address if type(costumer) != str else costumer
    deployer = deployer.address if type(deployer) != str else deployer
    initial_balance = voucher_manager.balanceOf(costumer)
    tx = voucher_manager.createVoucher(costumer, 1, 30, "UTC", sender=deployer)
    tx.wait()
    assert voucher_manager.balanceOf(costumer) == initial_balance + 1
    assert voucher_manager.getVoucherDetails(0)["tier"] == 1


def test_upgrade_voucher(voucher_manager, deployer, costumer):
    costumer = costumer.address if type(costumer) != str else costumer
    deployer = deployer.address if type(deployer) != str else deployer
    voucher_manager.createVoucher(costumer, 1, 30, "UTC", sender=deployer).wait()
    initial_dcp = voucher_manager.getVoucherDetails(0)["remainingDCP"]
    tx = voucher_manager.upgradeVoucher(0, 2, sender=costumer, value="0.1 ether")
    tx.wait()
    assert voucher_manager.getVoucherDetails(0)["tier"] == 2
    assert voucher_manager.getVoucherDetails(0)["remainingDCP"] > initial_dcp


def test_renew_voucher(voucher_manager, deployer, costumer):
    costumer = costumer.address if type(costumer) != str else costumer
    deployer = deployer.address if type(deployer) != str else deployer
    voucher_manager.createVoucher(costumer, 1, 30, "UTC", sender=deployer).wait()
    initial_duration = voucher_manager.getVoucherDetails(0)["duration"]
    tx = voucher_manager.renewVoucher(0, 15, sender=costumer, value="0.05 ether")
    tx.wait()
    assert voucher_manager.getVoucherDetails(0)["duration"] == initial_duration + 15


def test_downgrade_voucher(voucher_manager, deployer, costumer):
    costumer = costumer.address if type(costumer) != str else costumer
    deployer = deployer.address if type(deployer) != str else deployer
    voucher_manager.createVoucher(costumer, 2, 30, "UTC", sender=deployer).wait()
    initial_tier = voucher_manager.getVoucherDetails(0)["tier"]
    tx = voucher_manager.downgradeVoucher(0, 1, sender=costumer)
    tx.wait()
    assert voucher_manager.getVoucherDetails(0)["tier"] == 1
    assert voucher_manager.getVoucherDetails(0)["tier"] < initial_tier
