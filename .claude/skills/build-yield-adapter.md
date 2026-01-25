# Skill: Build Yield Adapter

## Trigger
User asks to create/build a yield adapter for a protocol.

## Workflow

### Step 1: Validate Protocol

```bash
curl -s "https://api.llama.fi/protocol/{slug}" | jq '{name, slug, category, chains, url, github, module}'
```

**If empty/error:** Check `https://api.llama.fi/protocols` for correct slug.

**Save for later:** `category`, `chains`, `url`, `github`

### Step 2: Check No Existing Yield Adapter

```bash
ls src/adaptors/{protocol-name}/ 2>/dev/null && echo "EXISTS" || echo "NOT FOUND"
```

**If exists:** Ask user if they want to update it instead.

### Step 3: Research Protocol

Run the research skill based on category:

| Category | Research Skill |
|----------|----------------|
| Liquid Staking | `.claude/skills/research-liquid-staking.md` |
| Lending, CDP | `.claude/skills/research-lending.md` |
| DEX, AMM | `.claude/skills/research-dex.md` |
| All others | `.claude/skills/research-protocol.md` |

**Research must produce:**
- Data source (on-chain / subgraph / API)
- Contract addresses per chain
- APY calculation method
- Token addresses (underlying, receipt, rewards)
- Reference adapter to use as template

### Step 4: Find Reference Adapter

Based on research, identify a similar working adapter:

```bash
# List adapters in same category
ls src/adaptors/ | xargs -I {} sh -c 'head -5 src/adaptors/{}/index.js 2>/dev/null | grep -l "{pattern}"'

# Or check known good examples:
# Liquid Staking: lido, marinade-finance, jito, rocket-pool
# Lending: aave-v3, compound-v3, venus-core-pool
# DEX: uniswap-v3, curve, velodrome
# Yield: yearn-finance, beefy
```

Read the reference adapter to understand the pattern:
```bash
cat src/adaptors/{reference-adapter}/index.js
```

### Step 5: Create Adapter

```bash
mkdir -p src/adaptors/{protocol-name}
```

**Create `index.js` using this structure:**

```javascript
const utils = require('../utils');

const PROJECT_NAME = '{protocol-name}'; // Must match folder name exactly

const main = async () => {
  // 1. Fetch data using method from research
  //    - On-chain: use sdk.api.abi.call/multiCall
  //    - Subgraph: use graphql-request
  //    - API: use utils.getData()

  // 2. Get token prices if needed
  //    const prices = await utils.getPrices(addresses, chain);

  // 3. Build pool objects
  const pools = data.map(item => ({
    pool: `${item.address}-${chain}`.toLowerCase(), // Unique ID
    chain: utils.formatChain(chain),
    project: PROJECT_NAME,
    symbol: utils.formatSymbol(item.symbol),
    tvlUsd: item.tvl,
    apyBase: item.apy,                    // Base APY from fees/interest
    // apyReward: item.rewardApy,         // Only if rewards exist
    // rewardTokens: [item.rewardToken],  // Required if apyReward is set
    underlyingTokens: [item.tokenAddress],
  }));

  // 4. Filter invalid pools
  return pools.filter(p => utils.keepFinite(p));
};

module.exports = {
  timetravel: false,
  apy: main,
  url: '{protocol-url}',
};
```

**Key Rules:**
- `project` must exactly match folder name
- `pool` format: `${address}-${chain}`.toLowerCase()
- Always use `utils.formatChain()` and `utils.formatSymbol()`
- If `apyReward` is set, `rewardTokens` array is required
- Always filter with `utils.keepFinite()`

### Step 6: Test

```bash
cd src/adaptors && npm run test --adapter={protocol-name}
```

**Check output in `.test-adapter-output/{protocol-name}.json`:**
- Returns array with pools
- All required fields present
- APY values reasonable (typically 0-100%, max ~1000%)
- TVL roughly matches DefiLlama protocol TVL

### Step 7: Fix Issues

| Error | Fix |
|-------|-----|
| "pool is required" | Check pool ID format |
| "apyReward requires rewardTokens" | Add rewardTokens array or remove apyReward |
| APY is NaN/Infinity | Guard against division by zero |
| Empty array | Check API response, add console.log debugging |
| Timeout | Add retry logic or check RPC endpoint |
| "project doesn't match" | Ensure PROJECT_NAME matches folder name |

Re-run test after each fix until passing.

### Step 8: Summary

Report to user:
- Pools found: {count}
- TVL covered: ${total}
- APY range: {min}% - {max}%
- Any limitations or notes

---

## Learnings & Best Practices

### Reward Tokens from Merkl API

Many protocols distribute rewards via Merkl. Instead of hardcoding reward tokens, query them from the Merkl API helper:

**Option 1: Use the built-in helper function**
```javascript
const { addMerklRewardApy } = require('../merkl/merkl-additional-reward');

const main = async () => {
  let pools = await fetchBasePools(); // Your base pool logic

  // Augment with Merkl reward data (protocolId from merkl.xyz)
  pools = await addMerklRewardApy(pools, 'protocol-id', (pool) => pool.pool.split('-')[0]);

  return pools;
};
```

**Option 2: Query Merkl API directly**
```javascript
// Get opportunities for a specific protocol
const merklData = await utils.getData(
  `https://api.merkl.xyz/v4/opportunities?mainProtocolId=${protocolId}&status=LIVE&items=100`
);

// Extract reward tokens from response
const rewardTokens = merklData[0]?.rewardsRecord?.breakdowns.map(x => x.token.address) || [];
const apyReward = merklData[0]?.apr || 0;
```

**When to use:** If the protocol has Merkl integrations (check their UI for "Merkl rewards" badges or visit `app.merkl.xyz`).