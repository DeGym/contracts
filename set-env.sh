#!/bin/bash

# Load the .env file
set -o allexport
source .env
set +o allexport

# Check the NETWORK variable and set the corresponding addresses
if [ "$NETWORK" = "mainnet" ]; then
    export DEPLOYED_TOKEN_ADDRESS=$DEPLOYED_TOKEN_ADDRESS_MAINNET
    export WALLET_ADDRESS=$WALLET_ADDRESS_MAINNET
    export TARAXA_RPC_URL=$TARAXA_MAINNET_RPC_URL
else
    export DEPLOYED_TOKEN_ADDRESS=$DEPLOYED_TOKEN_ADDRESS_TESTNET
    export WALLET_ADDRESS=$WALLET_ADDRESS_TESTNET
    export TARAXA_RPC_URL=$TARAXA_TESTNET_RPC_URL
fi

# Print the set environment variables for confirmation
echo "Using network: $NETWORK"
echo "DEPLOYED_TOKEN_ADDRESS: $DEPLOYED_TOKEN_ADDRESS"
echo "WALLET_ADDRESS: $WALLET_ADDRESS"
echo "TARAXA_RPC_URL: $TARAXA_RPC_URL"
