#!/bin/bash

# Check if required environment variables are set
if [ -z "$FACTORY_CONTRACT" ]; then
    echo "Error: FACTORY_CONTRACT environment variable is not set"
    echo "Please set it to your factory contract address"
    echo "Example: export FACTORY_CONTRACT=0x1234567890123456789012345678901234567890"
    exit 1
fi

if [ -z "$USER_ADDR" ]; then
    echo "Error: USER_ADDR environment variable is not set"
    echo "Please set it to the user address you want to query"
    echo "Example: export USER_ADDR=0xabcdefabcdefabcdefabcdefabcdefabcdefabcd"
    exit 1
fi

if [ -z "$BASE_SEPOLIA_RPC_URL" ]; then
    echo "Error: BASE_SEPOLIA_RPC_URL environment variable is not set"
    echo "Please set it to your Base Sepolia RPC URL"
    echo "Example: export BASE_SEPOLIA_RPC_URL=https://sepolia.base.org"
    exit 1
fi

# Validate addresses
if [[ ! $FACTORY_CONTRACT =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    echo "Error: FACTORY_CONTRACT is not a valid Ethereum address"
    echo "Current value: $FACTORY_CONTRACT"
    exit 1
fi

if [[ ! $USER_ADDR =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    echo "Error: USER_ADDR is not a valid Ethereum address"
    echo "Current value: $USER_ADDR"
    exit 1
fi

echo "Calling factory contract: $FACTORY_CONTRACT"
echo "For user address: $USER_ADDR"
echo "Using RPC: $BASE_SEPOLIA_RPC_URL"
echo ""

# Execute the cast call with proper error handling
echo "Executing cast call..."
cast call "$FACTORY_CONTRACT" \
  "getUserPortfolio(address)(address)" "$USER_ADDR" \
  --rpc-url "$BASE_SEPOLIA_RPC_URL"