  
# Cross-Chain Token  (Ethereum Sepolia ↔ zkSync Sepolia) with CCIP

This project demonstrates deploying a simple custom ERC-20 token, a vault, and token pools on **Ethereum Sepolia** and **zkSync Sepolia**, then transferring tokens between them using [Chainlink CCIP](https://docs.chain.link/ccip).

It supports:
- Minting tokens on the source chain (Ethereum Sepolia)
- Depositing tokens as collateral into a vault
- Transferring tokens **both ways** between Ethereum Sepolia and zkSync Sepolia



## Requirements

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- GNU Make
- `.env` file with required variables
- RPC access to Ethereum Sepolia, zkSync Sepolia, and optionally Arbitrum Sepolia (if testing more routes)


##  Setup

### 1. Install dependencies
```bash
make install

```

### 2. Configure `foundry.toml`

Add your RPC endpoints:

```toml
[rpc_endpoints]
eth = "https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY"
arb = "https://arb-sepolia.g.alchemy.com/v2/YOUR_KEY"
zksync = "https://zksync-sepolia.g.alchemy.com/v2/YOUR_KEY"

```

### 3. Create `.env`

```bash
cp .env.example .env

```

### 4. Edit `.env`

```env
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
ZKSYNC_SEPOLIA_RPC_URL=https://zksync-sepolia.g.alchemy.com/v2/YOUR_KEY
```



##  Deployment

For convenience, this repository provides a helper script:
```bash
./bridgeToZksync.sh
```

Deploy token, vault, and pool on **Ethereum Sepolia**:

```bash
make deploy-sepolia

```

Deploy token and pool on **zkSync Sepolia**:

```bash
make deploy-zksync

```
Configure pool
```bash
make configure-sepolia-pool
make configure-zksync-pool
```



##  Deposit Collateral and Mint

On Ethereum Sepolia (source chain):

```bash
make deposit TOKEN_AMOUNT=10000
```

> The minted amount should match the collateral deposited to ensure correct liquidity for cross-chain transfers.



## Cross-Chain Transfers

Transfer from Ethereum Sepolia → zkSync Sepolia:

```bash
make transfer-sepolia-to-zksync 

```

Transfer from zkSync Sepolia → Ethereum Sepolia:

```bash
make transfer-zksync-to-sepolia

```



##  Testing

Run tests:

```bash
make test

```
 

## 📝 Notes

-   Ethereum Sepolia is the **source chain** with the vault holding collateral.
    
-   The same token contract exists on both chains, but actual liquidity comes from the vault and pools.
    

        

