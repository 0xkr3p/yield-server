---
name: building-yield-adapters
description: Creates yield adapters for DeFi protocols on DefiLlama. Use when the user asks to create, build, or add a new yield adapter for a protocol. Usage: /building-yield-adapters {protocol-slug}
---

# Build Yield Adapter: $0

## Live Context

Protocol info: !`curl -s "https://api.llama.fi/protocol/$0" 2>/dev/null | jq '{name, slug, category, chains, url}' 2>/dev/null || echo "Fetch protocol info manually"`

Existing adapter check: !`ls -la src/adaptors/$0/ 2>/dev/null && echo "ADAPTER EXISTS" || echo "No existing adapter"`

## Build Checklist

```
Build Progress:
- [ ] Step 1: Validate protocol exists on DefiLlama
- [ ] Step 2: Check no existing yield adapter
- [ ] Step 3: Research protocol (run appropriate research skill)
- [ ] Step 4: Find reference adapter
- [ ] Step 5: Create adapter files
- [ ] Step 6: Test adapter
- [ ] Step 7: Validate against protocol UI
- [ ] Step 8: Report summary to user
```

## Workflow

### Step 1: Validate Protocol

If live context above shows valid protocol info, proceed. If not:
```bash
curl -s "https://api.llama.fi/protocol/$0" | jq '{name, slug, category, chains}'
```

### Step 2: Check No Existing Adapter

If live context shows "ADAPTER EXISTS", ask user if they want to update instead.

### Step 3: Research Protocol

Run appropriate research skill based on category:

| Category | Skill |
|----------|-------|
| Lending, CDP | `/researching-lending-protocols $0` |
| Dexes, AMM | `/researching-dex-protocols $0` |
| Liquid Staking | `/researching-liquid-staking $0` |
| Other | `/researching-protocols $0` |

**Research must produce:**
- Data source (on-chain / subgraph / API)
- Contract addresses per chain
- APY calculation method
- Reference adapter

### Step 4: Create Adapter

```bash
mkdir -p src/adaptors/$0
```

**Template:**
```javascript
const utils = require('../utils');

const PROJECT_NAME = '$0'; // Must match folder name

const main = async () => {
  // 1. Fetch data (on-chain/subgraph/API)
  // 2. Get token prices if needed
  // 3. Build pool objects
  const pools = data.map(item => ({
    pool: `${item.address}-${chain}`.toLowerCase(),
    chain: utils.formatChain(chain),
    project: PROJECT_NAME,
    symbol: utils.formatSymbol(item.symbol),
    tvlUsd: item.tvl,
    apyBase: item.apy,
    // apyReward: item.rewardApy,      // If rewards
    // rewardTokens: [item.rewardToken], // Required if apyReward
    underlyingTokens: [item.tokenAddress],
  }));

  return pools.filter(p => utils.keepFinite(p));
};

module.exports = {
  timetravel: false,
  apy: main,
  url: '{protocol-url}',
};
```

**Key Rules:**
- `project` must match folder name exactly
- `pool` format: `${address}-${chain}`.toLowerCase()
- Always use `utils.formatChain()` and `utils.formatSymbol()`
- If `apyReward` set, `rewardTokens` required
- Always filter with `utils.keepFinite()`

### Step 5: Test

```bash
cd src/adaptors && npm run test --adapter=$0
```

Check output:
```bash
cat src/adaptors/.test-adapter-output/$0.json | jq 'length'
cat src/adaptors/.test-adapter-output/$0.json | jq '[.[].tvlUsd] | add'
```

### Step 6: Fix Issues

| Error | Fix |
|-------|-----|
| "pool is required" | Check pool ID format |
| "apyReward requires rewardTokens" | Add rewardTokens or remove apyReward |
| APY is NaN/Infinity | Guard division by zero |
| Empty array | Debug data source |

### Step 7: Validate Against UI

**CRITICAL:** Use validate-adapter agent:
```
@validate-adapter $0
```

Or manually compare output to protocol UI values.

### Step 8: Summary

Report to user:
- Pools found: {count}
- TVL covered: ${total}
- APY range: {min}% - {max}%
- Any notes

## Merkl Rewards Integration

Many protocols distribute token rewards via Merkl. For full integration details, see:

**`/add-merkl-rewards $0`**

### Quick Check

```bash
# Check if protocol has Merkl rewards
curl -s "https://api.merkl.xyz/v4/protocols" | jq '.[] | select(.name | test("$0"; "i"))'
```

### Integration Patterns

| Scenario | Approach |
|----------|----------|
| Protocol has `mainProtocolId` | Use `addMerklRewardApy()` helper |
| No `mainProtocolId` but vaults in Merkl | Custom query by vault address |
| No Merkl presence | Skip rewards integration |

See `/add-merkl-rewards` skill for complete implementation patterns and code examples.

## Reference Adapters

| Category | Examples |
|----------|----------|
| Liquid Staking | `lido`, `marinade-finance`, `jito` |
| Lending | `aave-v3`, `compound-v3`, `venus-core-pool` |
| DEX | `uniswap-v3`, `curve`, `velodrome-v2` |
| Yield | `yearn-finance`, `beefy` |
