#!/usr/bin/env bash
set -euo pipefail

# Usage: ./bootstrap_portfolio.sh <FACTORY_ADDRESS>
FACTORY_ADDRESS="${1:?Usage: ./bootstrap_portfolio.sh <FACTORY_ADDRESS>}"

# Required env vars
RPC_URL="${BASE_SEPOLIA_RPC_URL:?BASE_SEPOLIA_RPC_URL not set}"
PK="${PRIVATE_KEY:?PRIVATE_KEY not set}"
USDC_ADDRESS="${USDC_ADDRESS:?USDC_ADDRESS not set}"
USDC_PRICE_FEED="${USDC_PRICE_FEED:?USDC_PRICE_FEED not set}"
WETH_PRICE_FEED="${WETH_PRICE_FEED:?WETH_PRICE_FEED not set}"

# Assumed WETH on Base Sepolia (verify if needed)
WETH_ADDRESS="0x4200000000000000000000000000000000000006"

echo "RPC        : $RPC_URL"
echo "Factory    : $FACTORY_ADDRESS"
echo "USDC       : $USDC_ADDRESS"
echo "USDC Feed  : $USDC_PRICE_FEED"
echo "WETH Feed  : $WETH_PRICE_FEED"
echo "WETH       : $WETH_ADDRESS"

# Resolve user address from PK
USER_ADDR="$(cast wallet address --private-key "$PK")"
echo "User       : $USER_ADDR"

echo "== 1) Create user portfolio =="
cast send "$FACTORY_ADDRESS" "createUserPortfolio()" \
  --rpc-url "$RPC_URL" --private-key "$PK" | cat


echo "== 2) Fetch portfolio address =="
PORTFOLIO_ADDR="$(cast call "$FACTORY_ADDRESS" "getUserPortfolio(address)(address)" "$USER_ADDR" --rpc-url "$RPC_URL")"
echo "Portfolio  : $PORTFOLIO_ADDR"
if [ "$PORTFOLIO_ADDR" = "0x0000000000000000000000000000000000000000" ]; then
  echo "ERROR: Portfolio address is zero. Did createUserPortfolio revert or did you query with the same wallet?" >&2
  exit 1
fi


echo "== 3) Approve USDC (max allowance) =="
cast send "$USDC_ADDRESS" "approve(address,uint256)" \
  "$PORTFOLIO_ADDR" 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff \
  --rpc-url "$RPC_URL" --private-key "$PK" | cat

# Brief pause to avoid racing the deposit right after approval
echo "Pausing 1s before deposit..."
sleep 1


echo "== 4) Deposit 2 USDC =="
# 2 USDC with 6 decimals = 2_000_000
cast send "$PORTFOLIO_ADDR" "depositUsdc(uint256)" 2000000 \
  --rpc-url "$RPC_URL" --private-key "$PK" | cat


echo "USDC balance in portfolio:"
cast call "$USDC_ADDRESS" "balanceOf(address)(uint256)" "$PORTFOLIO_ADDR" --rpc-url "$RPC_URL" | cat


echo "== 5) Set portfolio allocation 60% USDC / 40% WETH =="
cast send "$PORTFOLIO_ADDR" \
  "setPortfolioAllocation(address[],uint16[],uint8[],address[])" \
  "[$USDC_ADDRESS,$WETH_ADDRESS]" \
  "[6000,4000]" \
  "[6,18]" \
  "[$USDC_PRICE_FEED,$WETH_PRICE_FEED]" \
  --rpc-url "$RPC_URL" --private-key "$PK" | cat


echo "Done. Portfolio: $PORTFOLIO_ADDR"