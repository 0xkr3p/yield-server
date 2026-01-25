# Skill: Fix Yield Adapter

## Trigger
User asks to fix/debug/repair a broken yield adapter, or an adapter is failing tests.

## Workflow

### Step 1: Identify the Problem

**Run the test to see current errors:**
```bash
cd src/adaptors && npm run test --adapter={protocol-name}
```

**Check test output file:**
```bash
cat src/adaptors/.test-adapter-output/{protocol-name}.json
```

**Common failure modes:**
- Empty array returned (no pools)
- Test failures (validation errors)
- Runtime exceptions (API/RPC errors)
- Timeout (hanging requests)

### Step 2: Read the Adapter Code

```bash
cat src/adaptors/{protocol-name}/index.js
```

**Understand:**
- Data source (API, subgraph, on-chain)
- How pools are constructed
- APY calculation method
- Which chains are supported

### Step 3: Diagnose by Error Type

#### Error: Empty Array / No Pools

**Possible causes:**
1. API endpoint changed or down
2. Subgraph deprecated or moved
3. Contract address changed
4. Filter logic too aggressive

**Debugging:**
```bash
# Test API directly
curl -s "{api-endpoint}" | head -100

# Test subgraph
curl -s "{subgraph-url}" -H "Content-Type: application/json" \
  -d '{"query": "{ _meta { block { number } } }"}'

# Check if contract still exists
curl -s "https://api.etherscan.io/api?module=contract&action=getabi&address={address}"
```

#### Error: "pool is required" / "chain is required"

**Fix:** Ensure pool ID format is correct:
```javascript
pool: `${address}-${chain}`.toLowerCase()  // Must be lowercase!
chain: utils.formatChain(chain)            // Use the helper
```

#### Error: "apyReward requires rewardTokens"

**Fix:** Either add rewardTokens or remove apyReward:
```javascript
// Option 1: Add reward tokens
apyReward: rewardApy,
rewardTokens: ['0x...'],  // Required when apyReward is set

// Option 2: Remove reward APY if no rewards
// Simply don't include apyReward field
```

#### Error: "project doesn't match" / "folder name mismatch"

**Fix:** Ensure project field matches folder name exactly:
```javascript
const PROJECT_NAME = '{folder-name}';  // Must match folder
// ...
project: PROJECT_NAME,
```

#### Error: APY is NaN / Infinity

**Causes:** Division by zero, missing data

**Fix:**
```javascript
// Guard against division by zero
const apy = totalSupply > 0 ? (rewards / totalSupply) * 100 : 0;

// Use keepFinite to filter bad values
return pools.filter(p => utils.keepFinite(p));
```

#### Error: "Stale subgraph"

**Cause:** Subgraph is behind the chain head

**Fixes:**
1. Check if subgraph has moved to new provider
2. Use a different subgraph endpoint
3. Switch to on-chain data source

#### Error: Timeout / ETIMEDOUT

**Causes:** Slow API, rate limiting, RPC issues

**Fixes:**
```javascript
// Add retry logic
const data = await utils.getData(url).catch(async () => {
  await new Promise(r => setTimeout(r, 1000));
  return utils.getData(url);
});

// Use batching for many RPC calls
const results = await sdk.api.abi.multiCall({
  calls: addresses.map(a => ({ target: a, params: [] })),
  abi: ABI,
  chain: chain,
});
```

#### Error: "tvlUsd should be number"

**Fix:** Ensure TVL is calculated correctly:
```javascript
// Get prices for tokens
const prices = await utils.getPrices(tokenAddresses, chain);

// Calculate TVL
const tvlUsd = Number(balance) / 1e18 * prices[tokenAddress].price;

// Guard against undefined prices
const tvlUsd = prices[tokenAddress]?.price
  ? Number(balance) / 1e18 * prices[tokenAddress].price
  : 0;
```

#### Error: Duplicate pool IDs

**Fix:** Ensure unique pool identifiers:
```javascript
// Include distinguishing info in pool ID
pool: `${address}-${poolType}-${chain}`.toLowerCase()

// Or use index for multiple pools from same contract
pool: `${address}-${index}-${chain}`.toLowerCase()
```

### Step 4: Common Fix Patterns

#### API Endpoint Changed

1. Check protocol docs for new API URL
2. Search their GitHub for API changes
3. Check if they moved to a new domain

```bash
# Find new API
curl -s "https://api.{protocol}.io/v2/pools"   # Try v2
curl -s "https://api.{protocol}.xyz/pools"     # Try different TLD
```

#### Subgraph Moved to Decentralized Network

Old hosted subgraphs are being deprecated. Update to new endpoints:

```javascript
// Old (deprecated)
const url = 'https://api.thegraph.com/subgraphs/name/org/subgraph';

// New (decentralized)
const url = 'https://gateway-arbitrum.network.thegraph.com/api/{api-key}/subgraphs/id/{subgraph-id}';

// Or use alternative providers
const url = 'https://api.goldsky.com/api/public/project_xxx/subgraphs/name/version/gn';
```

#### Contract Upgraded / Address Changed

1. Check protocol announcements for new addresses
2. Look up new deployment in their docs/GitHub
3. Update address constants

#### Token Decimals Wrong

```javascript
// Check token decimals
const decimals = await sdk.api.erc20.decimals(tokenAddress, chain);

// Use correct decimals
const balance = new BigNumber(rawBalance).div(10 ** decimals.output);
```

#### Price Lookup Failing

```javascript
// Format address correctly for price API
const priceKey = `${chain}:${address.toLowerCase()}`;
const prices = await utils.getPrices([address], chain);

// Handle missing prices
const price = prices.pricesByAddress[address.toLowerCase()] || 0;
if (price === 0) {
  console.log(`Warning: No price for ${address}`);
}
```

### Step 5: Add Debug Logging

Temporarily add logging to understand data flow:

```javascript
const main = async () => {
  const data = await fetchData();
  console.log('Raw data:', JSON.stringify(data, null, 2).slice(0, 500));

  const pools = data.map(item => {
    console.log('Processing:', item.address, item.symbol);
    return {
      pool: `${item.address}-${chain}`.toLowerCase(),
      // ...
    };
  });

  console.log('Pools before filter:', pools.length);
  const filtered = pools.filter(p => utils.keepFinite(p));
  console.log('Pools after filter:', filtered.length);

  return filtered;
};
```

### Step 6: Test Iteratively

```bash
# Run test after each change
cd src/adaptors && npm run test --adapter={protocol-name}

# Use fast mode for quick iteration (skips validation)
cd src/adaptors && npm run test --adapter={protocol-name} --fast
```

### Step 7: Validate Fix

After tests pass, verify data quality:

1. **Pool count reasonable?** Compare to protocol UI
2. **TVL matches DefiLlama?** Check `https://defillama.com/protocol/{slug}`
3. **APY values sane?** Typically 0-100%, max ~1000%
4. **All chains included?** Check protocol operates on all expected chains

### Step 8: Consider Refactor vs Patch

**Patch when:**
- Single endpoint/address change
- Minor data format change
- Adding missing field

**Refactor when:**
- Data source completely changed (API → subgraph)
- Protocol architecture changed significantly
- Multiple fundamental issues
- Code is unmaintainable

**Refactor approach:**
1. Find a working adapter in same category as reference
2. Rewrite using research skill to gather fresh data
3. Test thoroughly

---

## Quick Reference: Test Error → Fix

| Test Error | Likely Fix |
|------------|------------|
| `pool is required` | Check pool ID format, ensure lowercase |
| `chain is required` | Add `chain: utils.formatChain(chain)` |
| `tvlUsd should be number` | Fix TVL calculation, handle missing prices |
| `expects at least one number apy field` | Add apyBase, apyReward, or apy |
| `apyReward requires rewardTokens` | Add rewardTokens array |
| `project field...doesn't match` | Ensure project === folder name |
| `duplicate pool ids` | Make pool IDs unique |
| `ltv should be in range 0-1` | Ensure LTV is decimal (0.8 not 80) |
| Empty array returned | Data source issue, check API/subgraph |

## Quick Reference: Data Source Issues

| Symptom | Check |
|---------|-------|
| 404 / Not Found | API URL changed |
| Empty response | API format changed, check response structure |
| Timeout | Rate limiting, add delays/retries |
| "Stale subgraph" | Subgraph behind, find new endpoint |
| Undefined prices | Token not in price API, check address format |
| NaN values | Division by zero, missing data |

## Useful Debugging Commands

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

---

## Investigating Broken Data Sources

When an adapter fails due to external data source issues (API down, subgraph deprecated, etc.), follow this investigation workflow to find alternatives.

### Step 1: Identify Current Data Source

From the adapter code, determine what data source is being used:

| Pattern in Code | Data Source Type |
|-----------------|------------------|
| `utils.getData(url)` or `axios.get` | REST API |
| `request(url, query)` or `graphql-request` | Subgraph/GraphQL |
| `sdk.api.abi.call` or `multiCall` | On-chain RPC |

### Step 2: Verify the Data Source is Actually Down

```bash
# For APIs
curl -sI "{api-url}" | head -5
curl -s "{api-url}" | head -100

# For subgraphs
curl -s "{subgraph-url}" -H "Content-Type: application/json" \
  -d '{"query": "{ _meta { block { number } } }"}'

# Common error responses:
# - 404/410: Endpoint removed or moved
# - 500/502/503: Server error (may be temporary)
# - Empty response: API format changed
# - "deployment does not exist": Subgraph deprecated
```

### Step 3: Research the Protocol

```bash
# Get protocol info from DefiLlama
curl -s "https://api.llama.fi/protocol/{slug}" | jq '{name, url, twitter, github}'

# Check if protocol still has TVL (is it still active?)
curl -s "https://api.llama.fi/protocol/{slug}" | jq '.tvl | last'

# Get the TVL adapter for contract addresses
curl -s "https://raw.githubusercontent.com/DefiLlama/DefiLlama-Adapters/main/projects/{slug}/index.js"
```

### Step 4: Find Alternative Data Sources

#### 4a: Finding New API Endpoints

```bash
# Check protocol's GitHub for API references
curl -s "https://api.github.com/search/code?q=api+repo:{org}/{repo}" | jq '.items[].path'

# Common API URL patterns to try
curl -s "https://api.{protocol}.com/v1/pools"
curl -s "https://api.{protocol}.io/pools"
curl -s "https://api.{protocol}.xyz/stats"
curl -s "https://{protocol}.com/api/yields"
curl -s "https://api.{protocol}.finance/v2/vaults"

# Check for API docs
curl -s "https://docs.{protocol}.com/"
curl -s "https://api.{protocol}.com/docs"
```

#### 4b: Finding Migrated Subgraphs

The Graph hosted service is deprecated. Subgraphs migrate to:
1. **Decentralized Network** (graph-gateway)
2. **Alternative providers** (Goldsky, Satsuma, 0xGraph)

```bash
# Search The Graph's decentralized network
# Visit: https://thegraph.com/explorer?search={protocol}

# Common alternative subgraph providers
curl -s "https://api.goldsky.com/api/public/project_{id}/subgraphs/{name}/{version}/gn" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ _meta { block { number } } }"}'

curl -s "https://subgraph.satsuma-prod.com/{org}/{name}/api" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ _meta { block { number } } }"}'

# Check protocol's GitHub for subgraph references
curl -s "https://api.github.com/search/code?q=subgraph+repo:{org}/{repo}" | jq '.items[].path'

# Look for subgraph.yaml in their repos
curl -s "https://raw.githubusercontent.com/{org}/{repo}/main/subgraph/subgraph.yaml"
```

#### 4c: Finding On-Chain Data (Most Reliable Fallback)

If API/subgraph is gone, switch to on-chain:

```bash
# Get contract ABI from block explorer
curl -s "https://api.etherscan.io/api?module=contract&action=getabi&address={address}"

# Check for view functions that return pool data
# Common patterns:
# - getAllMarkets() / getAllPools() / getAllVaults()
# - getReserveData(address)
# - poolInfo(uint256)
# - getPoolData(address)
```

**On-chain data patterns by protocol type:**

| Protocol Type | Common Contract Functions |
|---------------|---------------------------|
| Lending (Aave-like) | `getReserveData`, `getAllReservesTokens`, `liquidityRate`, `variableBorrowRate` |
| Lending (Compound-like) | `getAllMarkets`, `supplyRatePerBlock`, `borrowRatePerBlock`, `totalSupply`, `totalBorrows` |
| DEX (Uniswap-like) | `slot0`, `liquidity`, `token0`, `token1`, factory's `allPairs` |
| Vaults (Yearn-like) | `pricePerShare`, `totalAssets`, `totalSupply`, `token` |
| Staking | `totalStaked`, `rewardRate`, `rewardPerToken`, `stakingToken` |

### Step 5: Implement the New Data Source

#### Converting API → On-Chain

```javascript
// Before (API)
const data = await utils.getData('https://api.protocol.com/pools');
const pools = data.pools.map(p => ({
  pool: p.address,
  tvlUsd: p.tvl,
  apyBase: p.apy,
}));

// After (On-chain)
const poolAddresses = (await sdk.api.abi.call({
  target: factoryAddress,
  abi: 'function getAllPools() view returns (address[])',
  chain,
})).output;

const [tvls, apys] = await Promise.all([
  sdk.api.abi.multiCall({
    calls: poolAddresses.map(p => ({ target: p })),
    abi: 'function totalValueLocked() view returns (uint256)',
    chain,
  }),
  sdk.api.abi.multiCall({
    calls: poolAddresses.map(p => ({ target: p })),
    abi: 'function currentApy() view returns (uint256)',
    chain,
  }),
]);

const pools = poolAddresses.map((address, i) => ({
  pool: `${address}-${chain}`.toLowerCase(),
  tvlUsd: tvls.output[i].output / 1e18 * price,
  apyBase: apys.output[i].output / 1e16, // Assuming 1e18 = 100%
}));
```

#### Converting Subgraph → On-Chain

```javascript
// Before (Subgraph)
const query = gql`{ pools { id tvlUSD apy } }`;
const data = await request(subgraphUrl, query);

// After (On-chain with events)
const poolCreatedEvents = await sdk.getEventLogs({
  chain,
  target: factoryAddress,
  eventAbi: 'event PoolCreated(address indexed pool, address token0, address token1)',
  fromBlock: deploymentBlock,
});

const poolAddresses = poolCreatedEvents.map(e => e.args.pool);
// Then fetch data from each pool contract...
```

#### Updating Subgraph URL (Hosted → Decentralized)

```javascript
// Before (deprecated hosted service)
const url = 'https://api.thegraph.com/subgraphs/name/org/subgraph-name';

// After (decentralized network - requires API key)
const url = `https://gateway-arbitrum.network.thegraph.com/api/${process.env.GRAPH_API_KEY}/subgraphs/id/${subgraphId}`;

// After (Goldsky - often free/public)
const url = 'https://api.goldsky.com/api/public/project_xxx/subgraphs/protocol-name/1.0.0/gn';

// After (Satsuma)
const url = 'https://subgraph.satsuma-prod.com/org/subgraph-name/api';
```

### Step 6: Calculate APY On-Chain

If the API/subgraph provided pre-calculated APY, you'll need to calculate it:

```javascript
// Lending APY (Compound-style)
const supplyRatePerBlock = await sdk.api.abi.call({
  target: cTokenAddress,
  abi: 'function supplyRatePerBlock() view returns (uint256)',
  chain,
});
const blocksPerYear = 2628000; // ~12 sec blocks
const apyBase = (Math.pow(1 + supplyRatePerBlock.output / 1e18, blocksPerYear) - 1) * 100;

// Lending APY (Aave-style, already annualized in RAY)
const reserveData = await sdk.api.abi.call({
  target: poolAddress,
  abi: 'function getReserveData(address) view returns (tuple(...))',
  params: [tokenAddress],
  chain,
});
const apyBase = reserveData.output.currentLiquidityRate / 1e25; // RAY = 1e27, want percentage

// Staking APY
const rewardRate = await sdk.api.abi.call({ target: stakingContract, abi: 'rewardRate', chain });
const totalStaked = await sdk.api.abi.call({ target: stakingContract, abi: 'totalSupply', chain });
const rewardPrice = prices[rewardToken];
const stakedPrice = prices[stakingToken];
const apyReward = (rewardRate.output / 1e18 * 365 * 24 * 3600 * rewardPrice) /
                  (totalStaked.output / 1e18 * stakedPrice) * 100;

// DEX Fee APY (from volume)
const dailyVolume = ...; // From events or external source
const poolTvl = ...;
const feeRate = 0.003; // 0.3%
const apyBase = (dailyVolume * feeRate * 365 / poolTvl) * 100;
```

### Step 7: Handle Missing Price Data

If tokens aren't in DefiLlama's price API:

```javascript
// Option 1: Use protocol's oracle
const price = await sdk.api.abi.call({
  target: protocolOracle,
  abi: 'function getAssetPrice(address) view returns (uint256)',
  params: [tokenAddress],
  chain,
});
const priceUsd = price.output / 1e8; // Assuming 8 decimals

// Option 2: Calculate from DEX pair
const reserves = await sdk.api.abi.call({
  target: pairAddress,
  abi: 'function getReserves() view returns (uint112, uint112, uint32)',
  chain,
});
const [reserve0, reserve1] = reserves.output;
const priceInToken1 = reserve1 / reserve0;
const priceUsd = priceInToken1 * knownToken1Price;

// Option 3: Use Chainlink
const price = await sdk.api.abi.call({
  target: chainlinkFeed,
  abi: 'function latestAnswer() view returns (int256)',
  chain,
});
const priceUsd = price.output / 1e8;

// Option 4: Hardcode for stablecoins (last resort)
const priceUsd = symbol.includes('USD') ? 1 : null;
```

### Decision Tree: Which Data Source to Use

```
Is the original data source still working?
├── Yes → Keep using it, just fix the code bug
└── No → What type was it?
    ├── API (404/500)
    │   ├── Check if URL changed → Update URL
    │   ├── Check for v2/new API → Migrate to new API
    │   └── No alternative API → Convert to on-chain
    ├── Subgraph (deprecated/stale)
    │   ├── Check decentralized network → Update URL + add API key
    │   ├── Check Goldsky/Satsuma → Update URL
    │   └── No alternative subgraph → Convert to on-chain
    └── On-chain (RPC errors)
        ├── Check if contract upgraded → Update addresses
        ├── Check if chain is supported → Add chain config
        └── RPC issues → Try different RPC endpoint
```

---

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
