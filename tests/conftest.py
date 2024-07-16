import pytest, os
from ape import project, accounts


def __get_contract(Contract, key, deployer, contract, *args, **kwargs):
    address = os.environ.get(key)
    contract = (
        Contract[address] if address else deployer.deploy(contract, *args, **kwargs)
    )
    return contract


@pytest.fixture
def deployer():
    address = os.environ.get("DEPLOYER_ADDRESS")
    return accounts[address] if address else accounts[0]


@pytest.fixture
def consumer():
    address = os.environ.get("CONSUMER_ADDRESS")
    return accounts[address] if address else accounts[1]


@pytest.fixture
def provider():
    address = os.environ.get("PROVIDER_ADDRESS")
    return accounts[address] if address else accounts[2]


@pytest.fixture
def dGym_token(Contract, deployer):
    return __get_contract(Contract, "DGYM_ADDRESS", deployer, project.Token, 1000000)


@pytest.fixture
def fiat_token(Contract, deployer):
    return __get_contract(Contract, "USDT_ADDRESS", deployer, project.Token, 1000000)


@pytest.fixture
def voucher_manager_contract(Contract, deployer, fiat_token):
    return __get_contract(
        Contract,
        "VOUCHER_MANAGER_ADDRESS",
        deployer,
        project.VoucherManager,
        fiat_token.address,
    )


@pytest.fixture
def stake_manager_contract(Contract, deployer, dGym_token):
    return __get_contract(
        Contract,
        "STAKE_MANAGER_ADDRESS",
        deployer,
        project.StakeManager,
        dGym_token.address,
    )


@pytest.fixture
def user_stake_pool_contract(Contract, deployer, dGym_token, fiat_token):
    return __get_contract(
        Contract,
        "USER_STAKE_POOL_ADDRESS",
        deployer,
        project.UserStakePool,
        dGym_token.address,
        fiat_token.address,
    )


@pytest.fixture
def gym_manager_contract(Contract, deployer, stake_manager_contract):
    return __get_contract(
        Contract,
        "GYM_MANAGER_ADDRESS",
        deployer,
        project.GymManager,
        stake_manager_contract.address,
        1000,
    )


@pytest.fixture
def checkin_contract(
    Contract, deployer, gym_manager_contract, voucher_manager_contract
):
    return __get_contract(
        Contract,
        "CHECKIN_ADDRESS",
        deployer,
        project.Checkin,
        gym_manager_contract.address,
        voucher_manager_contract.address,
    )


@pytest.fixture
def treasury_contract(Contract, deployer):
    return __get_contract(Contract, "TREASURY_ADDRESS", deployer, project.Treasury)


@pytest.fixture
def governance_contract(
    Contract,
    deployer,
    treasury_contract,
    voucher_manager_contract,
    gym_manager_contract,
    stake_manager_contract,
):
    return __get_contract(
        Contract,
        "GOVERNANCE_ADDRESS",
        deployer,
        project.Governance,
        treasury_contract.address,
        voucher_manager_contract.address,
        gym_manager_contract.address,
        stake_manager_contract.address,
    )
