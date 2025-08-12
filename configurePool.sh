#!/bin/bash

# Define constants 
AMOUNT=100000

DEFAULT_ZKSYNC_LOCAL_KEY="0x7726827caac94a7f9e1b160f7ea819f172f7b6f9d2a97f992c38edeab82d4110"
DEFAULT_ZKSYNC_ADDRESS="0x36615Cf349d7F6344891B1e7CA7C72883F5dc049"

ZKSYNC_REGISTRY_MODULE_OWNER_CUSTOM="0x3139687Ee9938422F57933C3CDB3E21EE43c4d0F"
ZKSYNC_TOKEN_ADMIN_REGISTRY="0xc7777f12258014866c677Bdb679D0b007405b7DF"
ZKSYNC_ROUTER="0xA1fdA8aa9A8C4b945C45aD30647b01f07D7A0B16"
ZKSYNC_RNM_PROXY_ADDRESS="0x3DA20FD3D8a8f8c1f1A5fD03648147143608C467"
ZKSYNC_SEPOLIA_CHAIN_SELECTOR="6898391096552792247"
ZKSYNC_LINK_ADDRESS="0x23A1aFD896c8c8876AF46aDc38521f4432658d1e"

SEPOLIA_REGISTRY_MODULE_OWNER_CUSTOM="0x62e731218d0D47305aba2BE3751E7EE9E5520790"
SEPOLIA_TOKEN_ADMIN_REGISTRY="0x95F29FEE11c5C55d26cCcf1DB6772DE953B37B82"
SEPOLIA_ROUTER="0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59"
SEPOLIA_RNM_PROXY_ADDRESS="0xba3f6251de62dED61Ff98590cB2fDf6871FbB991"
SEPOLIA_CHAIN_SELECTOR="16015286601757825753"
SEPOLIA_LINK_ADDRESS="0x779877A7B0D9E8603169DdbD7836e478b4624789"

source .env
# forge build --zksync
# echo "Configuring the pool on ZKsync..."
# cast send ${ZKSYNC_POOL_ADDRESS}  --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myDevKey "applyChainUpdates(uint64, bool, bytes, bytes, (bool,uint128,uint128), (bool,uint128,uint128)[])"  "[(${SEPOLIA_CHAIN_SELECTOR}, true ,[$(cast abi-encode "f(address)" ${SEPOLIA_POOL_ADDRESS})],$(cast abi-encode "f(address)" ${SEPOLIA_TOKEN_ADDRESS}),(false,0,0),(false,0,0))]"

# cast send ${ZKSYNC_POOL_ADDRESS} \
#   --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} \
#   --account myDevKey \
#   "applyChainUpdates((uint64,bool,bytes,bytes,(bool,uint128,uint128),(bool,uint128,uint128))[])" \
#   "[(${SEPOLIA_CHAIN_SELECTOR},true,$(cast abi-encode "f(address)" ${SEPOLIA_POOL_ADDRESS}),$(cast abi-encode "f(address)" ${SEPOLIA_TOKEN_ADDRESS}),(false,0,0),(false,0,0))]"

# cast send ${ZKSYNC_POOL_ADDRESS}  --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myDevKey
#  "applyChainUpdates(
#  uint64,
#  bool,
#  bytes,
#  bytes,
#  (bool,uint128,uint128),
#  (bool,uint128,uint128)
#  )[])"  "[(${SEPOLIA_CHAIN_SELEC

# echo "Sepolia balance before bridging: $SEPOLIA_BALANCE_BEFORE"


SEPOLIA_TOKEN_ADDRESS=0x95a57e2fe227ad0926e340E5fACAd77845Dab971

echo "Bridging the funds using the script to ZKsync..."
SEPOLIA_BALANCE_BEFORE=$(cast balance $(cast wallet address --account myDevKey) --erc20 ${SEPOLIA_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL})
echo "Sepolia balance before bridging: $SEPOLIA_BALANCE_BEFORE"

forge script ./script/BridgeToken.s.sol:BridgeTokensScript --rpc-url ${SEPOLIA_RPC_URL} --account myDevKey --broadcast --sig "run(address,uint64,address,uint256,address,address)" $(cast wallet address --account myDevKey) ${ZKSYNC_SEPOLIA_CHAIN_SELECTOR} ${SEPOLIA_TOKEN_ADDRESS} 55555 ${SEPOLIA_LINK_ADDRESS} ${SEPOLIA_ROUTER}
echo "Funds bridged to ZKsync"
SEPOLIA_BALANCE_AFTER=$(cast balance $(cast wallet address --account myDevKey) --erc20 ${SEPOLIA_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL})
echo "Sepolia balance after bridging: $SEPOLIA_BALANCE_AFTER"

