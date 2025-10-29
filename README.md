# Miner Smart Contract — Deployment Guide

## Step 1 — Build the Contracts
forge build

## Step 2 — Local Test Deployment (optional)

You can simulate deployment in a local environment first:

forge script script/DeployMinerScript.s.sol --fork-url http://127.0.0.1:8545

## Step 3 — Deploy to a Real Network

To broadcast the deployment:

forge script script/DeployMinerScript.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify

### Example:

export RPC_URL="https://eth-sepolia.g.alchemy.com/v2/<YOUR_KEY>"
export PRIVATE_KEY="0xYOUR_PRIVATE_KEY"

forge script script/DeployMinerScript.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify

##  Step 4 — Verify Deployment
forge verify-contract <DEPLOYED_ADDRESS> src/Miner.sol:Miner --chain-id <CHAIN_ID> --watch
forge verify-contract 0xYourContractAddress src/Miner.sol:Miner --chain-id 11155111 --watch

