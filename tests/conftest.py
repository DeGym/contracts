import pytest
import os
from ape import project, accounts
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()


def __get(Contract, key, deployer, contract, *args, **kwargs):
    address = os.getenv(key)
    contract = (
        Contract[address] if address else deployer.deploy(contract, *args, **kwargs)
    )
    return contract


def __generate_account():
    return accounts.test_accounts.generate_test_account()


@pytest.fixture
def deployer():
    address = os.getenv("DEPLOYER_ADDRESS")
    return accounts[address] if address else __generate_account()


@pytest.fixture
def costumer():
    address = os.getenv("COSTUMER_ADDRESS")
    return accounts[address] if address else __generate_account()


@pytest.fixture
def stakeholder():
    address = os.getenv("STAKEHOLDER_ADDRESS")
    return accounts[address] if address else __generate_account()


@pytest.fixture
def gym():
    address = os.getenv("GYM_ADDRESS")
    return accounts[address] if address else __generate_account()


@pytest.fixture
def dgym_token(Contract, deployer):
    return __get(Contract, "DGYM_ADDRESS", deployer, project.DeGymToken)


@pytest.fixture
def fiat_token(Contract, deployer):
    return __get(
        Contract, "USDT_ADDRESS", deployer, project.DeGymToken, 1000000
    )  # Any stable coin


@pytest.fixture
def voucher_manager(Contract, deployer, fiat_token):
    return __get(
        Contract,
        "VOUCHER_MANAGER_ADDRESS",
        deployer,
        project.VoucherManager,
        fiat_token.address,
    )


@pytest.fixture
def stake_manager(Contract, deployer, dgym_token):
    return __get(
        Contract,
        "STAKE_MANAGER_ADDRESS",
        deployer,
        project.StakeManager,
        dgym_token.address,
    )


@pytest.fixture
def bond_pool(Contract, deployer, dgym_token, stake_manager):
    bond_pool_contract = __get(
        Contract,
        "BOND_POOL_ADDRESS",
        deployer,
        project.BondPool,
        deployer.address,
        stake_manager.address,
    )
    stake_manager.deployBondPool({"from": deployer})
    return bond_pool_contract


@pytest.fixture
def gym_manager(Contract, deployer, stake_manager):
    return __get(
        Contract,
        "GYM_MANAGER_ADDRESS",
        deployer,
        project.GymManager,
        stake_manager.address,
        1000,
    )


@pytest.fixture
def checkin(Contract, deployer, gym_manager, voucher_manager):
    return __get(
        Contract,
        "CHECKIN_ADDRESS",
        deployer,
        project.Checkin,
        gym_manager.address,
        voucher_manager.address,
    )


@pytest.fixture
def treasury(Contract, deployer):
    return __get(Contract, "TREASURY_ADDRESS", deployer, project.Treasury)


@pytest.fixture
def vesting(Contract, deployer):
    return __get(
        Contract,
        "VESTING_ADDRESS",
        deployer,
        project.Vesting,
    )


@pytest.fixture
def sale_contract(Contract, deployer, dgym_token, vesting):
    return __get(
        Contract,
        "SALE_CONTRACT_ADDRESS",
        deployer,
        project.SaleContract,
        dgym_token.address,
        vesting.address,
    )


@pytest.fixture
def governor(
    Contract,
    deployer,
    gym_manager,
    stake_manager,
    treasury,
    dgym_token,
    voucher_manager,
    vesting,
):
    return __get(
        Contract,
        "GOVERNOR_ADDRESS",
        deployer,
        project.DeGymGovernor,
        gym_manager.address,
        stake_manager.address,
        treasury.address,
        dgym_token.address,
        voucher_manager.address,
    )
