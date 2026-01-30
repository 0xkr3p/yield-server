---
name: researching-dex-protocols
description: Researches DEX and AMM protocols for yield adapter development. Use when building adapters for decentralized exchanges, liquidity pools, or AMMs.
---

# Research DEX/AMM Protocol

## Quick Reference

- [Subgraph Queries](./subgraph-queries.md) - Query templates and examples

## DEX Fundamentals

**APY Formula:** `(Volume24h × FeeRate × 365 / TVL) × 100`

| AMM Type | Fee Tiers | Examples |
|----------|-----------|----------|
| V2 (Constant Product) | Fixed (0.3%) | Uniswap V2, SushiSwap |
| V3 (Concentrated Liquidity) | Multiple | Uniswap V3, PancakeSwap V3 |
| Stable | Low fixed | Curve |
| ve-DEX | Variable + rewards | Velodrome, Aerodrome |

## Research Checklist

```
Research Progress:
- [ ] Phase 1: DefiLlama Protocol Info
- [ ] Phase 2: Identify DEX Architecture
- [ ] Phase 3: Documentation Discovery
- [ ] Phase 4: Subgraph Discovery
- [ ] Phase 5: Fee Structure Research
- [ ] Phase 6: APY Calculation Method
- [ ] Phase 7: Reward Tokens (if any)
- [ ] Phase 8: Reference Adapters
```

## Research Phases

### Phase 1: DefiLlama Protocol Info

```bash
curl -s "https://api.llama.fi/protocol/{slug}" | jq '{
  name, slug, category, chains, url, twitter, github, module
}'
```

**Verify category is "Dexes" or "Liquidity Manager"**

### Phase 2: Identify DEX Architecture

| Question | V2 | V3 |
|----------|-----|-----|
| Fee tiers? | Single fixed | Multiple |
| Entity name | pairs | pools |
| Has tick data? | No | Yes |
| TVL field | reserveUSD | totalValueLockedUSD |

```bash
# Check factory for clues
curl -s "https://api.etherscan.io/api?module=contract&action=getabi&address={factory}" | \
  jq -r '.result' | grep -i "createPool\|createPair\|feeTier"
```

### Phase 3: Documentation Discovery

```bash
# Find docs via sitemap
curl -s "https://docs.{protocol}.com/sitemap.xml" 2>/dev/null | \
  grep -oP '(?<=<loc>)[^<]+' | grep -iE 'contract|subgraph|api|fee'
```

### Phase 4: Subgraph Discovery

See [subgraph-queries.md](./subgraph-queries.md) for detailed queries.

```bash
# Test subgraph
curl -s "https://api.thegraph.com/subgraphs/name/{org}/{protocol}" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ _meta { block { number } } }"}'
```

### Phase 5: Fee Structure

| Tier | Fee | Use Case |
|------|-----|----------|
| 100 | 0.01% | Stablecoins |
| 500 | 0.05% | Stable pairs |
| 3000 | 0.3% | Most pairs |
| 10000 | 1% | Exotic |

```javascript
// V2 fee rate
const feeRate = 0.003; // Fixed 0.3%

// V3 fee rate from tier
const feeRate = feeTier / 1000000;
```

### Phase 6: APY Calculation

```javascript
// Using 24h volume
const apy = (volume24h * feeRate * 365 / tvl) * 100;

// Using 7-day average (more stable)
const avgDailyVolume = volume7d / 7;
const apy = (avgDailyVolume * feeRate * 365 / tvl) * 100;

// If subgraph has feesUSD
const apy = (feesUSD24h * 365 / tvl) * 100;
```

### Phase 7: Reward Tokens

Check for liquidity mining programs:

```bash
# Look for gauge/farm contracts
curl -s "https://api.etherscan.io/api?module=contract&action=getabi&address={address}" | \
  jq -r '.result' | grep -i "gauge\|farm\|reward"
```

If rewards exist:
```javascript
{
  apyBase: feeApy,           // From trading fees
  apyReward: rewardApy,      // From token emissions
  rewardTokens: ['0x...'],   // Reward token addresses
}
```

### Phase 8: Reference Adapters

| DEX Type | Reference Adapters |
|----------|-------------------|
| V2 | `uniswap-v2`, `sushiswap` |
| V3 | `uniswap-v3`, `pancakeswap-v3` |
| Stable | `curve` |
| ve-DEX | `velodrome-v2`, `aerodrome` |

```bash
cat src/adaptors/{reference}/index.js
```

## Output Format

```markdown
## Research Results: {Protocol Name} (DEX)

### Basic Info
- Slug: {slug}
- Type: {V2 | V3 | Stable | ve-DEX}
- Chains: {chains}
- Website: {url}

### Protocol Architecture
- Factory: {address per chain}
- Fee Tiers: {list}
- ve-Tokenomics: {Yes/No}

### Subgraph
- Endpoint: {url}
- Status: {synced/behind}
- Key Entities: {pools/pairs}

### APY Calculation
- Method: `(volume24h * feeRate * 365 / tvl) * 100`
- Volume Source: {subgraph poolDayData}
- Fee Rate: {from feeTier or fixed}

### Contracts Per Chain
| Chain | Factory | Subgraph |
|-------|---------|----------|

### Reference Adapter
- `src/adaptors/{name}/` - {why similar}
```

## Completion Checklist

- [ ] DEX type identified (V2 vs V3 vs stable)
- [ ] Subgraph discovered and tested
- [ ] Fee tiers documented
- [ ] APY calculation formula confirmed
- [ ] Volume data source identified
- [ ] Reward tokens identified (if any)
- [ ] Multi-chain config gathered
- [ ] Similar adapter identified
