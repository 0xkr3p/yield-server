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
