cast send $USDC_ADDRESS "approve(address,uint256)" \
  $USER_CONTRACT \
  0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff \
  --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
