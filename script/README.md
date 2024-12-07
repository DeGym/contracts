# Running the Scripts

To deploy and interact with your contracts, use the following commands in your terminal:

# Load .env

```sh
source .env
```

## Deploy DeGymToken to Taraxa Mainnet

```sh
forge script script/DeployDeGymToken.s.sol --rpc-url $TESTNET_RPC_URL --broadcast --legacy --private-key $PRIVATE_KEY
```

This setup should handle the conversion of addresses from the .env file and configure your project to deploy and interact with contracts on both the Taraxa Mainnet and Testnet using Foundry.