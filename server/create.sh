#!/bin/bash

# Check if required environment variables are set
if [ -z "$FACTORY_CONTRACT" ]; then
    echo "Error: FACTORY_CONTRACT environment variable is not set"
    echo "Please set it to your factory contract address"
    echo "Example: export FACTORY_CONTRACT=0x1234567890123456789012345678901234567890"
    exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY environment variable is not set"
    echo "Please set it to your private key (without 0x prefix)"
    echo "Example: export PRIVATE_KEY=1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    exit 1
fi

if [ -z "$BASE_SEPOLIA_RPC_URL" ]; then
    echo "Error: BASE_SEPOLIA_RPC_URL environment variable is not set"
    echo "Please set it to your Base Sepolia RPC URL"
    echo "Example: export BASE_SEPOLIA_RPC_URL=https://sepolia.base.org"
    exit 1
fi

# Validate addresses and private key
if [[ ! $FACTORY_CONTRACT =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    echo "Error: FACTORY_CONTRACT is not a valid Ethereum address"
    echo "Current value: $FACTORY_CONTRACT"
    exit 1
fi

if [[ ! $PRIVATE_KEY =~ ^[a-fA-F0-9]{64}$ ]]; then
    echo "Error: PRIVATE_KEY is not a valid 64-character hex string"
    echo "Current value: $PRIVATE_KEY"
    echo "Note: Do not include the '0x' prefix"
    exit 1
fi

echo "Creating user portfolio..."
echo "Factory contract: $FACTORY_CONTRACT"
echo "Using RPC: $BASE_SEPOLIA_RPC_URL"
echo "Private key: ${PRIVATE_KEY:0:8}...${PRIVATE_KEY: -8}"
echo ""

# Execute the cast send command
echo "Executing cast send..."
cast send "$FACTORY_CONTRACT" \
  "createUserPortfolio()" \
  --rpc-url "$BASE_SEPOLIA_RPC_URL" --private-key "$PRIVATE_KEY"
