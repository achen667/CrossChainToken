include .env
#export $(shell sed 's/=.*//' .env)

.PHONY: all test clean deploy fund help install snapshot format anvil 

# =============================
# Variables
# =============================
AMOUNT ?= 1001
#Add your account here
ACCOUNT ?= myDevKey

# ZKSYNC_TOKEN_ADDRESS?=
# ZKSYNC_POOL_ADDRESS?=
SEPOLIA_TOKEN_ADDRESS?=0x61AD0D4448982c964286b129c85B1689D9Ff852d
# SEPOLIA_POOL_ADDRESS?=
# VAULT_ADDRESS?=

# =============================
# Constants
# =============================
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

# =============================
# Library Install
# =============================

install:
	forge install OpenZeppelin/openzeppelin-contracts
	forge install smartcontractkit/ccip@v2.17.0-ccip1.5.12
	forge install smartcontractkit/chainlink-local

# =============================
# Compile
# =============================

build:
	foundryup
	forge build

build-zksync:
	foundryup-zksync
	forge build --zksync

# =============================
# Deploy to ZKsync Sepolia
# =============================

deploy-zksync: build-zksync
	@echo "Deploying MyToken to ZKsync..."
	$(eval ZKSYNC_TOKEN_ADDRESS := $(shell forge create src/MyToken.sol:MyToken \
		--rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} \
		--account $(ACCOUNT) --legacy --zksync | awk '/Deployed to:/ {print $$3}'))
	@echo "ZKsync Token Address: $(ZKSYNC_TOKEN_ADDRESS)"

	@echo "Deploying MyTokenPool to ZKsync..."
	$(eval ZKSYNC_POOL_ADDRESS := $(shell forge create src/MyTokenPool.sol:MyTokenPool \
		--rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} \
		--account $(ACCOUNT) --legacy --zksync \
		--constructor-args $(ZKSYNC_TOKEN_ADDRESS) [] ${ZKSYNC_RNM_PROXY_ADDRESS} ${ZKSYNC_ROUTER} | awk '/Deployed to:/ {print $$3}'))
	@echo "ZKsync Pool Address: $(ZKSYNC_POOL_ADDRESS)"

	@echo "Granting pool mint/burn role..."
	cast send $(ZKSYNC_TOKEN_ADDRESS) "grantMintAndBurnRole(address)" $(ZKSYNC_POOL_ADDRESS) \
		--rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account $(ACCOUNT)

	@echo "Registering admin..."
	cast send ${ZKSYNC_REGISTRY_MODULE_OWNER_CUSTOM} "registerAdminViaOwner(address)" $(ZKSYNC_TOKEN_ADDRESS) \
		--rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account $(ACCOUNT)
	cast send ${ZKSYNC_TOKEN_ADMIN_REGISTRY} "acceptAdminRole(address)" $(ZKSYNC_TOKEN_ADDRESS) \
		--rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account $(ACCOUNT)
	cast send ${ZKSYNC_TOKEN_ADMIN_REGISTRY} "setPool(address,address)" $(ZKSYNC_TOKEN_ADDRESS) $(ZKSYNC_POOL_ADDRESS) \
		--rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account $(ACCOUNT)

# =============================
# Deploy to Sepolia
# =============================

deploy-sepolia: build
	@echo "Deploying Token + Pool on Sepolia..."
	$(eval OUTPUT := $(shell forge script ./script/Deployer.s.sol:TokenAndPoolDeployer \
		--rpc-url ${SEPOLIA_RPC_URL} --account $(ACCOUNT) --broadcast))
	$(eval SEPOLIA_TOKEN_ADDRESS := $(shell echo "$(OUTPUT)" | grep 'token: contract MyToken' | awk '{print $$4}'))
	$(eval SEPOLIA_POOL_ADDRESS := $(shell echo "$(OUTPUT)" | grep 'pool: contract MyTokenPool' | awk '{print $$4}'))
	@echo "Sepolia Token: $(SEPOLIA_TOKEN_ADDRESS)"
	@echo "Sepolia Pool: $(SEPOLIA_POOL_ADDRESS)"

	@echo "Deploying Vault..."
	$(eval VAULT_ADDRESS := $(shell forge script ./script/Deployer.s.sol:VaultDeployer \
		--rpc-url ${SEPOLIA_RPC_URL} --account $(ACCOUNT) --broadcast \
		--sig "run(address)" $(SEPOLIA_TOKEN_ADDRESS) | grep 'vault: contract Vault' | awk '{print $$NF}'))
	@echo "Vault Address: $(VAULT_ADDRESS)"

# =============================
# Configure Pools
# =============================

configure-sepolia-pool:
	forge script ./script/ConfigurePool.s.sol:ConfigurePoolScript \
		--rpc-url ${SEPOLIA_RPC_URL} --account $(ACCOUNT) --broadcast \
		--sig "run(address,uint64,address,address,bool,uint128,uint128,bool,uint128,uint128)" \
		$(SEPOLIA_POOL_ADDRESS) ${ZKSYNC_SEPOLIA_CHAIN_SELECTOR} ${ZKSYNC_POOL_ADDRESS} ${ZKSYNC_TOKEN_ADDRESS} \
		false 0 0 false 0 0

configure-zksync-pool:
	cast send $(ZKSYNC_POOL_ADDRESS) \
		"applyChainUpdates((uint64,bool,bytes,bytes,(bool,uint128,uint128),(bool,uint128,uint128))[])" \
		"[(${SEPOLIA_CHAIN_SELECTOR},true,$(shell cast abi-encode "f(address)" $(SEPOLIA_POOL_ADDRESS)),$(shell cast abi-encode "f(address)" $(SEPOLIA_TOKEN_ADDRESS)),(false,0,0),(false,0,0))]" \
		--rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account $(ACCOUNT)

# =============================
# Deposi fund 
# =============================

deposit:
	@echo "Depositing funds to the vault on Sepolia..."
	cast send ${VAULT_ADDRESS} --value ${AMOUNT} --rpc-url ${SEPOLIA_RPC_URL} --account ${ACCOUNT} "deposit()"


# =============================
# Bridge Tokens
# =============================

# Ethereum Sepolia to ZKsync Sepolia
bridge:
	@echo "Sepolia balance before:"
	cast balance $(shell cast wallet address --account $(ACCOUNT)) --erc20 $(SEPOLIA_TOKEN_ADDRESS) --rpc-url ${SEPOLIA_RPC_URL}

	forge script ./script/BridgeToken.s.sol:BridgeTokensScript -vvvv \
		--rpc-url ${SEPOLIA_RPC_URL} --account $(ACCOUNT) --broadcast \
		--sig "run(address,uint64,address,uint256,address,address)" \
		$(shell cast wallet address --account $(ACCOUNT)) ${ZKSYNC_SEPOLIA_CHAIN_SELECTOR} $(SEPOLIA_TOKEN_ADDRESS) ${AMOUNT} ${SEPOLIA_LINK_ADDRESS} ${SEPOLIA_ROUTER}

	@echo "Sepolia balance after:"
	cast balance $(shell cast wallet address --account $(ACCOUNT)) --erc20 $(SEPOLIA_TOKEN_ADDRESS) --rpc-url ${SEPOLIA_RPC_URL}

# ZKsync Sepolia to Ethereum Sepolia
# bridge-back:
# 	@echo "zkSync balance before:"
# 	cast balance $(shell cast wallet address --account $(ACCOUNT)) --erc20 $(ZKSYNC_TOKEN_ADDRESS) --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL}

# 	forge script ./script/BridgeToken.s.sol:BridgeTokensScript \
# 		--rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account $(ACCOUNT) --broadcast \
# 		--sig "run(address,uint64,address,uint256,address,address)" \
# 		$(shell cast wallet address --account $(ACCOUNT)) ${SEPOLIA_CHAIN_SELECTOR} $(ZKSYNC_TOKEN_ADDRESS) ${AMOUNT} ${ZKSYNC_LINK_ADDRESS} ${ZKSYNC_ROUTER}

# 	@echo "zkSync balance after:"
# 	cast balance $(shell cast wallet address --account $(ACCOUNT)) --erc20 $(ZKSYNC_TOKEN_ADDRESS) --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL}


# =============================
# Test
# =============================

test: 
	forge test 