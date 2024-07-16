import pytest, os
from ape import project, accounts


def __get(Contract, key, deployer, contract, *args, **kwargs):
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
def costumer():
    address = os.environ.get("COSTUMER_ADDRESS")
    return accounts[address] if address else accounts[1]


@pytest.fixture
def stakeholder():
    address = os.environ.get("STAKEHOLDER_ADDRESS")
    return accounts[address] if address else accounts[1]


@pytest.fixture
def gym():
    address = os.environ.get("GYM_ADDRESS")
    return accounts[address] if address else accounts[2]


@pytest.fixture
def dgym_token(Contract, deployer):
    return __get(Contract, "DGYM_ADDRESS", deployer, project.Token, 1000000)


@pytest.fixture
def fiat_token(Contract, deployer):
    return __get(Contract, "USDT_ADDRESS", deployer, project.Token, 1000000)


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
def stake_pool(Contract, deployer, dgym_token, fiat_token):
    return __get(
        Contract,
        "STAKE_POOL_ADDRESS",
        deployer,
        project.UserStakePool,
        dgym_token.address,
        fiat_token.address,
    )


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
def governance(
    Contract,
    deployer,
    treasury,
    voucher_manager,
    gym_manager,
    stake_manager,
):
    return __get(
        Contract,
        "GOVERNANCE_ADDRESS",
        deployer,
        project.Governance,
        treasury.address,
        voucher_manager.address,
        gym_manager.address,
        stake_manager.address,
    )
