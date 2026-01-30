# Error Reference: Test Error → Fix

Quick reference for common test errors and their fixes.

## Validation Errors

| Test Error | Likely Fix |
|------------|------------|
| `pool is required` | Check pool ID format, ensure lowercase: `pool: \`${address}-${chain}\`.toLowerCase()` |
| `chain is required` | Add `chain: utils.formatChain(chain)` |
| `tvlUsd should be number` | Fix TVL calculation, handle missing prices |
| `expects at least one number apy field` | Add apyBase, apyReward, or apy |
| `apyReward requires rewardTokens` | Add rewardTokens array or remove apyReward |
| `project field...doesn't match` | Ensure project === folder name exactly |
| `duplicate pool ids` | Make pool IDs unique (add index or pool type) |
| `ltv should be in range 0-1` | Ensure LTV is decimal (0.8 not 80) |
| Empty array returned | Data source issue, check API/subgraph |

## Data Source Errors

| Symptom | Check |
|---------|-------|
| 404 / Not Found | API URL changed |
| Empty response | API format changed, check response structure |
| Timeout | Rate limiting, add delays/retries |
| "Stale subgraph" | Subgraph behind, find new endpoint |
| Undefined prices | Token not in price API, check address format |
| NaN values | Division by zero, missing data |

## Code Fix Patterns

### "pool is required" / "chain is required"

```javascript
// Ensure correct format
pool: `${address}-${chain}`.toLowerCase()  // Must be lowercase!
chain: utils.formatChain(chain)            // Use the helper
```

### "apyReward requires rewardTokens"

```javascript
// Option 1: Add reward tokens
apyReward: rewardApy,
rewardTokens: ['0x...'],  // Required when apyReward is set

// Option 2: Remove if no rewards
// Simply don't include apyReward field
```

### "project doesn't match" / "folder name mismatch"

```javascript
const PROJECT_NAME = '{folder-name}';  // Must match folder exactly
// ...
project: PROJECT_NAME,
```

### APY is NaN / Infinity

```javascript
// Guard against division by zero
const apy = totalSupply > 0 ? (rewards / totalSupply) * 100 : 0;

// Use keepFinite to filter bad values
return pools.filter(p => utils.keepFinite(p));
```

### "Stale subgraph"

```javascript
// Old (deprecated)
const url = 'https://api.thegraph.com/subgraphs/name/org/subgraph';

// New (decentralized)
const url = 'https://gateway-arbitrum.network.thegraph.com/api/{api-key}/subgraphs/id/{subgraph-id}';

// Or use alternative providers
const url = 'https://api.goldsky.com/api/public/project_xxx/subgraphs/name/version/gn';
```

### Timeout / ETIMEDOUT

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

### "tvlUsd should be number"

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

### Duplicate pool IDs

```javascript
// Include distinguishing info in pool ID
pool: `${address}-${poolType}-${chain}`.toLowerCase()

// Or use index for multiple pools from same contract
pool: `${address}-${index}-${chain}`.toLowerCase()
```

### Token Decimals Wrong

```javascript
// Check token decimals
const decimals = await sdk.api.erc20.decimals(tokenAddress, chain);

// Use correct decimals
const balance = new BigNumber(rawBalance).div(10 ** decimals.output);
```

### Price Lookup Failing

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
