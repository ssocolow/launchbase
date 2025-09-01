cast send $USER_CONTRACT \
  "setPortfolioAllocation(address[],uint16[],uint8[],address[])" \
  "[$USDC_ADDRESS,0x4200000000000000000000000000000000000006]" \
  "[6000,4000]" \
  "[6,18]" \
  "[$USDC_PRICE_FEED,$WETH_PRICE_FEED]" \
  --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
