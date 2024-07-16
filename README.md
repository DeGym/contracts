# DeGym Smart Contracts

This repository contains the smart contracts for the DeGym project. The project includes several contracts to manage tokens, vouchers, certificates, check-ins, and staking.

## Contracts

- `Token`: Manages the issuance and transfer of DGYM tokens.
- `VoucherManager`: Manages the issuance and management of vouchers (NFTs).
- `GymManager`: Manages gym catalog, CRUD operations for gyms, and validates gym stakes based on counterpart stakes.
- `Checkin`: Manages the check-in process using vouchers and triggers payment.
- `StakeManager`: Manages the deployment of user-specific stake pools and staking parameters.
- `StakePool`: Manages the staking and reward distribution for a specific user.
- `Treasure`: Manages the staking and reward distribution for a specific user. Manages the issuance of DGYM tokens.

## Setup

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
    ```

2. Compile contracts:
    ```bash
    ape compile
    ```

2.1 Add Account (generate or import if not exists)
    ```bash
    ape accounts list
    ape accounts generate account_alias
    ```

2.2 Make sure your account has some testnet TARA for deploying contracts and running tests. You can use the Taraxa testnet faucet to get testnet TARA.


1. Run tests:
    ```bash
    ape test --network taraxa:testnet
    ```

2. Deploy contracts:
    ```bash
    ape run --network taraxa:testnet scripts/deploy.py
    ```

## Configuration

Update the `ape-config.yaml` file with your specific configuration needs.
