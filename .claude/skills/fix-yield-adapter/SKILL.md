---
name: fixing-yield-adapters
description: Debugs and repairs broken yield adapters. Use when the user asks to fix, debug, or repair a yield adapter, or when an adapter is failing tests.
---

# Fix Yield Adapter

Copy this checklist and track your progress:

```
Fix Progress:
- [ ] Step 1: Run tests to identify the problem
- [ ] Step 2: Get protocol info from DefiLlama API
- [ ] Step 3: Check if protocol is deprecated
- [ ] Step 4: Read the adapter code
- [ ] Step 5: Diagnose by error type
- [ ] Step 6: Apply common fix patterns
- [ ] Step 7: Add debug logging (if needed)
- [ ] Step 8: Test iteratively
- [ ] Step 9: Validate fix against protocol UI (TVL/APY must match what protocol displays)
- [ ] Step 10: Decide patch vs refactor
```

## Workflow

### Step 1: Run Tests to Confirm Adapter is Broken

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

### Step 2: Get Protocol Info from DefiLlama API

**Fetch protocol metadata including website and Twitter:**

```bash
curl -s "https://api.llama.fi/protocol/{protocol-slug}" | jq '{
  name: .name,
  url: .url,
  twitter: .twitter,
  currentTvl: .currentChainTvls,
  tvlHistory: (.tvl | last(3))
}'
```

**Extract:**
- `url` - Protocol website URL
- `twitter` - Twitter handle (if available)
- `currentChainTvls` - Current TVL per chain
- `tvl` - Recent TVL history

**If Twitter not in API response**, check the protocol website for social links:
```bash
# Look for Twitter links on the website
curl -s "{protocol-url}" | grep -oE "https://(twitter|x)\.com/[a-zA-Z0-9_]+" | head -1
```

### Step 3: Check if Protocol is Deprecated

**Before investing time in debugging, verify the protocol hasn't shut down.**

#### Check TVL for Signs of Death

From the API response in Step 2:
- TVL dropped to $0 or near-zero → likely deprecated
- TVL chart shows sudden cliff drop → possible shutdown
- No TVL updates for extended period → possibly abandoned

#### Check the Protocol Website

Visit the `url` from the API response and look for:
- Deprecation banners or shutdown notices
- "Migration" or "Sunset" announcements
- Redirects to a new protocol/version
- 404 errors or domain expired
- "Read-only" mode announcements

```bash
# Quick check if website is up
curl -sI "{protocol-url}" | head -5

# Check for deprecation indicators in page content
curl -s "{protocol-url}" | grep -i -E "deprecat|sunset|migrat|shutdown|discontinue|end of life|no longer|wind.?down"
```

#### Check Protocol Twitter/X

Using the `twitter` handle from Step 2 (or extracted from website), check for:
- Pinned tweet about shutdown or migration
- Recent announcements about discontinuing the protocol
- No activity for extended periods (6+ months)

**Twitter URL:** `https://twitter.com/{twitter-handle}` or `https://x.com/{twitter-handle}`

#### Decision: If Protocol is Deprecated

If the protocol is deprecated:
1. **Do not fix the adapter** - it will just break again
2. Report back to the user with findings
3. Suggest removing the adapter from the codebase
4. Consider if there's a successor protocol that needs an adapter instead

**Example response:**
> "The protocol appears to be deprecated. [Evidence: website shows 'Protocol sunset on X date' banner / Twitter announced shutdown / TVL dropped to $0 on DATE]. Recommend removing this adapter rather than fixing it."

---

### Step 4: Read the Adapter Code

```bash
cat src/adaptors/{protocol-name}/index.js
```

**Understand:**
- Data source (API, subgraph, on-chain)
- How pools are constructed
- APY calculation method
- Which chains are supported

### Step 5: Diagnose by Error Type

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

### Step 6: Common Fix Patterns

#### API Endpoint Changed

1. Check protocol docs for new API URL
2. Search their GitHub for API changes
3. Check if they moved to a new domain
4. Check network tab on the application

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

### Step 7: Add Debug Logging

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

### Step 8: Test Iteratively

```bash
# Run test after each change
cd src/adaptors && npm run test --adapter={protocol-name}

# Use fast mode for quick iteration (skips validation)
cd src/adaptors && npm run test --adapter={protocol-name} --fast
```

### Step 9: Validate Fix Against Protocol UI

**CRITICAL: Passing tests does not mean the fix is correct.** Tests only validate data format, not accuracy. You must verify the actual values match what the protocol displays.

#### 9a. Get the Protocol UI URL

Use the `url` from Step 2 to find the pools/vaults page:
- Common paths: `/pools`, `/vaults`, `/earn`, `/markets`, `/stake`, `/farms`
- Look for pages showing TVL and APY for each pool

#### 9b. Compare Adapter Output to Protocol UI

**View the adapter output:**
```bash
cat src/adaptors/.test-adapter-output/{protocol-name}.json | jq '.[] | {pool, symbol, tvlUsd, apyBase, apyReward, apy}'
```

**For each major pool, verify against the protocol UI:**

| Field | Acceptable Variance | Red Flags |
|-------|---------------------|-----------|
| `tvlUsd` | ±10% of UI value | Off by 10x, 100x, or orders of magnitude |
| `apyBase` | ±0.5% absolute | Completely different (e.g., 5% vs 50%) |
| `apyReward` | ±1% absolute | Missing when UI shows rewards, or vice versa |
| `symbol` | Must match pool asset(s) | Wrong token names |

#### 9c. Common Validation Failures

**TVL is wrong by orders of magnitude:**
- Check token decimals (18 vs 6 vs 8)
- Check if using raw balance vs formatted
- Check price lookup is working

```javascript
// Wrong: using raw balance without decimals
tvlUsd: rawBalance * price

// Correct: account for decimals
tvlUsd: (rawBalance / 10 ** decimals) * price
```

**APY is 100x too high or too low:**
- Check if APY is in percentage (5.0) vs decimal (0.05)
- Check time period (daily vs annual)

```javascript
// If source gives daily rate, convert to annual
const apyBase = dailyRate * 365;

// If source gives decimal, convert to percentage
const apyBase = decimalApy * 100;
```

**APY shows 0% but UI shows rewards:**
- Reward token address may be wrong
- Reward calculation may be missing
- Check if rewards are in a separate field

**Pool count doesn't match:**
- Some pools may be filtered out (check filter logic)
- Multi-chain pools may be missing (check chain config)
- New pools may have been added to protocol

#### 9d. Spot-Check Specific Pools

Pick 2-3 pools of different sizes and verify:

1. **A large pool** (highest TVL) - ensures main calculation is correct
2. **A small pool** - ensures edge cases work
3. **A pool with rewards** (if applicable) - ensures reward APY works

**Example verification:**
```
Protocol UI shows:
  USDC Pool: TVL $5.2M, APY 4.5% (base) + 2.1% (rewards)

Adapter output should be approximately:
  tvlUsd: 5200000 (±520000)
  apyBase: 4.5 (±0.5)
  apyReward: 2.1 (±0.5)
  rewardTokens: ['0x...'] (must be present if apyReward > 0)
```

#### 9e. If Values Don't Match

**Do not ship a fix that passes tests but has wrong values.** Instead:

1. Re-examine the data source (API response, contract calls)
2. Check the calculation logic
3. Add debug logging to trace where values diverge
4. Compare raw data from source to what protocol UI displays
5. The protocol UI is the source of truth - match it

**Common sources of mismatch:**
- Protocol API returns different data than UI uses
- Calculation formula differs from how protocol calculates
- Stale/cached data in API vs live UI
- Different pool definitions (e.g., including/excluding certain assets)

### Step 10: Consider Refactor vs Patch

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



## Investigating Broken Data Sources

If the data source itself is broken (API down, subgraph deprecated, contract changed), see [.claude/skills/investigating-broken-data-sources/SKILL.md](.claude/skills/investigating-broken-data-sources/SKILL.md) for a complete investigation workflow including:

- Finding alternative API endpoints
- Migrating from deprecated subgraphs
- Converting to on-chain data sources
- Calculating APY on-chain
- Handling missing price data

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
