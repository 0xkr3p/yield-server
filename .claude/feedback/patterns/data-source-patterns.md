# Data Source Migration Patterns

Patterns for migrating between data source types and handling data source failures.

## Migration Decision Tree

```
Is current data source working?
├── Yes → Keep using it
└── No → What type?
    ├── API (404/500/deprecated)
    │   ├── Find new API version
    │   ├── OR convert to subgraph
    │   └── OR convert to on-chain
    ├── Subgraph (hosted service deprecated)
    │   ├── Migrate to decentralized network
    │   ├── OR use Goldsky/Satsuma mirror
    │   └── OR convert to on-chain
    └── On-chain (RPC errors)
        ├── Update contract addresses
        ├── OR try different RPC endpoint
        └── OR batch requests differently
```

## API to On-Chain Migration

### Pattern: Replace REST API with Contract Calls

**When to use**: API is deprecated or unreliable

**Before (API)**:
```javascript
const response = await axios.get('https://api.protocol.com/v1/pools');
const pools = response.data.pools;
```

**After (On-chain)**:
```javascript
const pools = await sdk.api.abi.multiCall({
  abi: poolAbi.getAllPools,
  calls: [{ target: factoryAddress }],
  chain,
});
```

**SDK Patterns**:
```javascript
// Single call
const result = await sdk.api.abi.call({
  abi: 'function totalSupply() view returns (uint256)',
  target: tokenAddress,
  chain,
});

// Multiple calls (same function, different targets)
const results = await sdk.api.abi.multiCall({
  abi: 'function balanceOf(address) view returns (uint256)',
  calls: addresses.map(addr => ({ target: tokenAddress, params: [addr] })),
  chain,
});
```

---

## Subgraph Migration Patterns

### Pattern: Hosted to Decentralized Network

**Before (hosted - deprecated)**:
```javascript
const endpoint = 'https://api.thegraph.com/subgraphs/name/uniswap/uniswap-v3';
```

**After (decentralized)**:
```javascript
const endpoint = sdk.graph.modifyEndpoint('5zvR82QoaXYFyDEKLZ9t6v9adgnptxYpKpSbxtgVENFV');
```

### Pattern: Find Subgraph ID

1. Go to https://thegraph.com/explorer
2. Search for protocol name
3. Copy the deployment ID (the hash)
4. Use with `sdk.graph.modifyEndpoint()`

### Pattern: Alternative Providers

If The Graph decentralized network unavailable:

**Goldsky**:
```javascript
const endpoint = `https://api.goldsky.com/api/public/project_${projectId}/subgraphs/${name}/${version}/gn`;
```

**Satsuma**:
```javascript
const endpoint = `https://subgraph.satsuma-prod.com/${apiKey}/${org}/${name}/api`;
```

---

## Common Protocol-Specific Patterns

### Aave-Style Lending

**Data source priority**: On-chain PoolDataProvider > Subgraph > API

```javascript
// Get all reserves
const reserves = await sdk.api.abi.call({
  abi: 'function getReservesList() view returns (address[])',
  target: poolAddress,
  chain,
});

// Get reserve data for each
const reserveData = await sdk.api.abi.multiCall({
  abi: 'function getReserveData(address asset) view returns (tuple(...))',
  calls: reserves.map(r => ({ target: dataProviderAddress, params: [r] })),
  chain,
});
```

### Uniswap V3-Style DEX

**Data source priority**: Subgraph > On-chain events > API

```javascript
// Subgraph query for pools
const query = gql`{
  pools(first: 1000, orderBy: totalValueLockedUSD, orderDirection: desc) {
    id
    token0 { id symbol decimals }
    token1 { id symbol decimals }
    feeTier
    totalValueLockedUSD
    poolDayData(first: 7) {
      volumeUSD
      feesUSD
    }
  }
}`;
```

### Compound-Style Lending

**Data source priority**: On-chain Comptroller > API

```javascript
// Get all markets
const markets = await sdk.api.abi.call({
  abi: 'function getAllMarkets() view returns (address[])',
  target: comptrollerAddress,
  chain,
});

// Get supply/borrow rates per block
const supplyRates = await sdk.api.abi.multiCall({
  abi: 'function supplyRatePerBlock() view returns (uint256)',
  calls: markets.map(m => ({ target: m })),
  chain,
});
```

### Liquid Staking Tokens

**Data source priority**: On-chain exchange rate > API

```javascript
// Common exchange rate patterns
const exchangeRateFunctions = [
  'function getExchangeRate() view returns (uint256)',
  'function convertToAssets(uint256 shares) view returns (uint256)',
  'function tokensPerStEth() view returns (uint256)',
  'function getRate() view returns (uint256)',
];
```

---

## Stale Data Detection

### Subgraph Block Lag

```javascript
// Check subgraph sync status
const metaQuery = gql`{
  _meta { block { number } }
}`;

const currentBlock = await sdk.api.util.getLatestBlock(chain);
const subgraphBlock = meta._meta.block.number;
const lag = currentBlock - subgraphBlock;

if (lag > 3000) {
  console.warn(`Subgraph is ${lag} blocks behind`);
  // Consider fallback to on-chain
}
```

### API Freshness

```javascript
// Check timestamp in API response
const response = await axios.get(apiEndpoint);
const dataTimestamp = response.data.timestamp;
const age = Date.now() / 1000 - dataTimestamp;

if (age > 3600) { // More than 1 hour old
  console.warn(`API data is ${age/3600} hours old`);
}
```

---

## Fallback Chain Pattern

Implement multiple data sources with automatic fallback:

```javascript
async function getPoolData(chain) {
  // Try primary source
  try {
    return await getPrimaryData(chain);
  } catch (primaryError) {
    console.warn('Primary failed:', primaryError.message);
  }

  // Try secondary source
  try {
    return await getSecondaryData(chain);
  } catch (secondaryError) {
    console.warn('Secondary failed:', secondaryError.message);
  }

  // Try tertiary source
  return await getTertiaryData(chain);
}
```

---

## Pattern Tags for Feedback

When logging migrations, use these tags:
- `api-to-onchain` - Migrated from API to contract calls
- `hosted-to-decentralized` - Migrated The Graph subgraph
- `subgraph-to-onchain` - Migrated from subgraph to RPC
- `endpoint-update` - Simple URL change
- `fallback-added` - Added backup data source
