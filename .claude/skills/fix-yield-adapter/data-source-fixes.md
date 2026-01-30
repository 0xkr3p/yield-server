# Data Source Fixes

Guide for fixing broken data sources (APIs, subgraphs, contracts).

## API Endpoint Changed

### Detection
```bash
# Test if API returns error
curl -sI "{api-url}" | head -5

# Check response format
curl -s "{api-url}" | head -100
```

### Fix Strategies

1. **Check protocol docs for new API URL**
2. **Search their GitHub for API changes**
3. **Check if they moved to a new domain**
4. **Check network tab on the application**

```bash
# Try common variations
curl -s "https://api.{protocol}.io/v2/pools"   # Try v2
curl -s "https://api.{protocol}.xyz/pools"     # Try different TLD
curl -s "https://api.{protocol}.finance/pools" # Try .finance
curl -s "https://{protocol}.com/api/v1/pools"  # Try under main domain
```

## Subgraph Moved to Decentralized Network

Old hosted subgraphs (api.thegraph.com) are being deprecated.

### Detection
```bash
# Test subgraph health
curl -s "{subgraph}" -d '{"query":"{_meta{block{number}}}"}' -H "Content-Type: application/json"
```

If returns error or "hosted service is deprecated", subgraph has moved.

### Fix: Update to New Endpoints

```javascript
// Old (deprecated)
const url = 'https://api.thegraph.com/subgraphs/name/org/subgraph';

// New options:

// 1. Decentralized network (requires API key)
const url = `https://gateway-arbitrum.network.thegraph.com/api/${process.env.GRAPH_API_KEY}/subgraphs/id/${subgraphId}`;

// 2. Goldsky (often free)
const url = 'https://api.goldsky.com/api/public/project_xxx/subgraphs/protocol/1.0.0/gn';

// 3. Satsuma
const url = 'https://{protocol}.subgraph.satsuma-prod.com/{key}/subgraphs/{name}';

// 4. Protocol's own hosted subgraph
const url = 'https://subgraph.{protocol}.com/subgraphs/name/{name}';
```

### Finding the New Subgraph URL

1. Check protocol documentation
2. Check protocol Discord/announcements
3. Search their GitHub for subgraph URLs
4. Check The Graph Network explorer: https://thegraph.com/explorer

## Contract Upgraded / Address Changed

### Detection
```bash
# Check if contract still exists
curl -s "https://api.etherscan.io/api?module=contract&action=getabi&address={address}"
```

If returns "Contract source code not verified" or contract is a proxy pointing elsewhere.

### Fix Strategies

1. **Check protocol announcements for new addresses**
2. **Look up new deployment in their docs/GitHub**
3. **Check if it's a proxy and get implementation**
4. **Update address constants in adapter**

```bash
# Check if contract is a proxy (look for implementation slot)
curl -s "https://api.etherscan.io/api?module=contract&action=getsourcecode&address={address}" | jq '.result[0].Implementation'
```

## Converting to On-Chain Data

When API/subgraph is unreliable, convert to on-chain calls.

### On-Chain SDK Patterns

```javascript
const sdk = require('@defillama/sdk');

// Single call
const result = await sdk.api.abi.call({
  target: contractAddress,
  abi: 'function totalSupply() view returns (uint256)',
  chain: chain,
});

// Multiple calls (same function, different targets)
const results = await sdk.api.abi.multiCall({
  calls: addresses.map(a => ({ target: a, params: [] })),
  abi: 'function balanceOf(address) view returns (uint256)',
  chain: chain,
});

// ERC20 helpers
const balance = await sdk.api.erc20.balanceOf({
  target: tokenAddress,
  owner: poolAddress,
  chain: chain,
});
```

### On-Chain APY Calculation

For lending protocols:
```javascript
// Compound-style: get supply rate per block
const supplyRatePerBlock = await sdk.api.abi.call({
  target: cTokenAddress,
  abi: 'function supplyRatePerSecond() view returns (uint256)',
  chain: chain,
});

// Convert to APY
const SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
const apy = (supplyRatePerBlock.output / 1e18) * SECONDS_PER_YEAR * 100;
```

For DEX:
```javascript
// Get reserves for TVL
const reserves = await sdk.api.abi.call({
  target: pairAddress,
  abi: 'function getReserves() view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestamp)',
  chain: chain,
});

// APY from fees requires volume data (usually from subgraph)
// If no volume data, may need to track events or use protocol API
```

## Reference: Similar Adapters by Data Source

When converting data sources, reference similar working adapters:

| Data Source | Example Adapters |
|-------------|------------------|
| On-chain (Aave-style) | `aave-v3`, `radiant-v2`, `seamless-protocol` |
| On-chain (Compound-style) | `compound-v3`, `venus-core-pool`, `moonwell` |
| On-chain (Uniswap-style) | `uniswap-v3`, `pancakeswap-v3` |
| Subgraph (DEX) | `curve`, `balancer-v2` |
| Subgraph (Lending) | `morpho-aave` |
| Protocol API | `yearn-finance`, `beefy` |

## Debugging Commands

```bash
# Check if API is up
curl -sI "{api-url}" | head -5

# Test subgraph health
curl -s "{subgraph}" -d '{"query":"{_meta{block{number}}}"}' -H "Content-Type: application/json"

# Get token price
curl -s "https://coins.llama.fi/prices/current/{chain}:{address}"

# Check contract exists
curl -s "https://api.etherscan.io/api?module=contract&action=getabi&address={addr}"

# View adapter output
cat src/adaptors/.test-adapter-output/{protocol-name}.json | jq '.'
```
