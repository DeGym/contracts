# Running the Scripts

To deploy and interact with your contracts, use the following commands in your terminal:

## Deploy DeGymToken to Taraxa Mainnet
```sh
forge script script/DeployDeGymToken.s.sol --rpc-url ${TARAXA_MAINNET_RPC_URL} --private-key ${PRIVATE_KEY} --broadcast
```

This setup should handle the conversion of addresses from the .env file and configure your project to deploy and interact with contracts on both the Taraxa Mainnet and Testnet using Foundry.