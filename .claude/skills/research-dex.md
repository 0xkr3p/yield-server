# Skill: Research DEX/AMM Protocol

## Purpose
Gather all information needed to build a yield adapter for DEX and AMM protocols.

## Input
- Protocol slug (e.g., "uniswap-v3", "curve", "velodrome")
- Chain(s) to support

## DEX Fundamentals

DEX yield comes from trading fees earned by liquidity providers:
- **APY** = (Volume 24h × Fee Rate × 365 / TVL) × 100

**Two Main AMM Types:**
| Type | Fee Tiers | Examples |
|------|-----------|----------|
| V2 (Constant Product) | Fixed (usually 0.3%) | Uniswap V2, SushiSwap, PancakeSwap |
| V3 (Concentrated Liquidity) | Multiple tiers | Uniswap V3, PancakeSwap V3, Aerodrome |

## Research Phases

### Phase 1: DefiLlama Protocol Info

```bash
curl -s "https://api.llama.fi/protocol/{slug}" | jq '{
  name,
  slug,
  category,
  chains,
  url,
  twitter,
  github,
  module
}'
```

**Verify category is "Dexes" or "Liquidity Manager"**

### Phase 2: Identify DEX Architecture

**Detection Questions:**
1. Is it V2-style (fixed fee) or V3-style (concentrated liquidity)?
2. Does it have a subgraph? (Most DEXes do)
3. Is there a factory contract?
4. What fee tiers exist?

**Check Factory Contract:**
```bash
# Look for common factory functions
curl -s "https://api.etherscan.io/api?module=contract&action=getabi&address={factory}" | jq -r '.result' | grep -i "createPool\|createPair\|allPairs\|feeTier"
```

### Phase 3: Documentation Discovery

**3a. Find Documentation via Sitemap:**
```bash
# Get sitemap and find relevant pages
curl -s "https://docs.{protocol}.com/sitemap.xml" 2>/dev/null | grep -oP '(?<=<loc>)[^<]+' | grep -iE 'contract|address|subgraph|api|fee|developer|integrate'

# Try alternative docs locations
curl -s "https://{protocol}.gitbook.io/sitemap.xml" 2>/dev/null | grep -oP '(?<=<loc>)[^<]+'
curl -s "https://docs.{protocol}.fi/sitemap.xml" 2>/dev/null | grep -oP '(?<=<loc>)[^<]+'
curl -s "https://docs.{protocol}.xyz/sitemap.xml" 2>/dev/null | grep -oP '(?<=<loc>)[^<]+'
```

**3b. Key Documentation Sections:**
- Subgraph endpoints
- Contract addresses (Factory, Router)
- Fee structure / fee switch
- API endpoints (if available)

### Phase 4: Existing TVL Adapter

```bash
curl -s "https://raw.githubusercontent.com/DefiLlama/DefiLlama-Adapters/main/projects/{slug}/index.js"
```

**Extract:**
- Factory addresses
- Subgraph URLs
- Chain configurations

### Phase 5: Subgraph Discovery (Primary Data Source)

**5a. Find Subgraph URL:**
```bash
# Check The Graph hosted service (legacy)
curl -s "https://api.thegraph.com/subgraphs/name/{org}/{protocol}" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ _meta { block { number } } }"}' 2>/dev/null

# Try with chain suffix
curl -s "https://api.thegraph.com/subgraphs/name/{org}/{protocol}-{chain}" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ _meta { block { number } } }"}' 2>/dev/null

# Check Graph Network (decentralized)
# Pattern: https://gateway.thegraph.com/api/{api-key}/subgraphs/id/{subgraph-id}

# Search protocol docs/github for subgraph URL
curl -s "https://raw.githubusercontent.com/{org}/{repo}/main/README.md" | grep -i "subgraph\|thegraph"
```

**5b. Explore Subgraph Schema:**
```bash
# Get schema types
curl -s "{subgraph_url}" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ __schema { types { name fields { name } } } }"}' | jq '.data.__schema.types[] | select(.name | test("Pool|Pair|Token|Day|Hour"; "i"))'
```

**5c. Common Subgraph Entities:**

**V2-style (pairs):**
```graphql
{
  pairs(first: 100, orderBy: reserveUSD, orderDirection: desc) {
    id
    token0 { symbol, id }
    token1 { symbol, id }
    reserveUSD        # TVL
    volumeUSD         # All-time volume
    # For daily volume, use pairDayDatas
  }
  pairDayDatas(first: 7, orderBy: date, orderDirection: desc, where: { pair: "{pair_id}" }) {
    date
    dailyVolumeUSD
    reserveUSD
  }
}
```

**V3-style (pools with fee tiers):**
```graphql
{
  pools(first: 100, orderBy: totalValueLockedUSD, orderDirection: desc) {
    id
    token0 { symbol, id }
    token1 { symbol, id }
    feeTier            # Fee in basis points (500 = 0.05%, 3000 = 0.3%, 10000 = 1%)
    totalValueLockedUSD
    volumeUSD
    # For daily volume, use poolDayDatas
  }
  poolDayDatas(first: 7, orderBy: date, orderDirection: desc, where: { pool: "{pool_id}" }) {
    date
    volumeUSD
    tvlUSD
    feesUSD
  }
}
```

### Phase 6: Fee Structure Research

**6a. Common Fee Tiers (V3-style):**
| Tier | Fee | Typical Use |
|------|-----|-------------|
| 100 | 0.01% | Stablecoin pairs |
| 500 | 0.05% | Stable pairs |
| 3000 | 0.3% | Most pairs |
| 10000 | 1% | Exotic pairs |

**6b. Fee Switch Status:**
Some protocols have a "fee switch" that diverts part of fees to protocol treasury:
```bash
# Check factory contract for fee switch
curl -s "https://api.etherscan.io/api?module=contract&action=getsourcecode&address={factory}" | jq -r '.result[0].SourceCode' | grep -i "feeToSetter\|protocolFee\|feeSwitch"

# Check docs
curl -s "https://docs.{protocol}.com/sitemap.xml" | grep -oP '(?<=<loc>)[^<]+' | xargs -I {} sh -c 'curl -s "{}" 2>/dev/null | grep -i "fee switch\|protocol fee"'
```

**6c. Calculate LP Fee Rate:**
```javascript
// V2-style (fixed fee, e.g., 0.3%)
const feeRate = 0.003;

// V3-style (from feeTier)
const feeRate = feeTier / 1000000; // feeTier is in hundredths of basis points
// Example: feeTier 3000 → 0.003 (0.3%)

// With protocol fee switch (if enabled)
// Typically 10-33% goes to protocol
const lpFeeRate = feeRate * (1 - protocolFeePercentage);
```

### Phase 7: APY Calculation

**Primary Formula:**
```javascript
// Using 24h volume from subgraph
const apy = (volume24h * feeRate * 365 / tvl) * 100;

// Or using 7-day average (more stable)
const avgDailyVolume = volume7d / 7;
const apy = (avgDailyVolume * feeRate * 365 / tvl) * 100;
```

**From Subgraph Data:**
```javascript
// If subgraph has feesUSD directly
const apy = (feesUSD24h * 365 / tvl) * 100;
```

**Handling Edge Cases:**
```javascript
// Filter out low liquidity pools
if (tvl < 10000) continue; // Skip pools under $10k

// Cap unrealistic APYs
const cappedApy = Math.min(apy, 1000); // Cap at 1000%

// Handle zero TVL
if (tvl === 0) continue;
```

### Phase 8: Reward Tokens (Liquidity Mining)

Many DEXes offer additional rewards:

```bash
# Check for gauge/farm contracts
curl -s "https://api.etherscan.io/api?module=contract&action=getabi&address={address}" | jq -r '.result' | grep -i "gauge\|farm\|reward\|stake"

# Look in subgraph for incentives
curl -s "{subgraph_url}" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ liquidityPositions(first: 1) { ... } gauges(first: 1) { ... } }"}'
```

**If rewards exist:**
```javascript
{
  apyBase: feeApy,           // From trading fees
  apyReward: rewardApy,      // From token emissions
  rewardTokens: ['0x...'],   // Reward token addresses
}
```

### Phase 9: ve-Tokenomics Research (Curve-style DEXes)

Many DEXes use vote-escrow models:
- **Velodrome/Aerodrome** (Optimism/Base)
- **Curve** (multi-chain)
- **Solidly forks**

```bash
# Check for voting/gauge system
curl -s "https://api.etherscan.io/api?module=contract&action=getabi&address={address}" | jq -r '.result' | grep -i "vote\|escrow\|gauge\|bribe"
```

**Boost Mechanics:**
```javascript
// veToken holders can boost LP rewards up to 2.5x
// Base APY shown should typically be the minimum (1x boost)
// Or note in pool metadata that boost is available
```

### Phase 10: On-Chain Data (Fallback)

If no subgraph available:

**V2 Factory:**
```javascript
// Get all pairs
const allPairsLength = await factory.allPairsLength();
const pairs = [];
for (let i = 0; i < allPairsLength; i++) {
  pairs.push(await factory.allPairs(i));
}

// Get pair data
const reserves = await pair.getReserves();
const token0 = await pair.token0();
const token1 = await pair.token1();
```

**V3 Factory:**
```javascript
// V3 pools are created per fee tier
const pool = await factory.getPool(token0, token1, feeTier);
const slot0 = await pool.slot0(); // Current price tick
const liquidity = await pool.liquidity();
```

### Phase 11: API Endpoints (Alternative)

Some DEXes provide APIs:
```bash
# Check for API
curl -s "https://api.{protocol}.com/pools"
curl -s "https://{protocol}.com/api/v1/pools"
curl -s "https://api.{protocol}.fi/pools"

# Specific examples
curl -s "https://api.curve.fi/api/getPools/all"
curl -s "https://yields.llama.fi/pools" | jq '.data[] | select(.project == "{protocol}")'
```

### Phase 12: Reference Adapters

**Study these existing DEX adapters:**

```bash
# Uniswap V3 (concentrated liquidity, multi-chain)
cat src/adaptors/uniswap-v3/index.js

# Uniswap V2 (constant product)
cat src/adaptors/uniswap-v2/index.js

# Curve (stable pools, gauge rewards)
cat src/adaptors/curve/index.js

# Velodrome (ve-tokenomics, Optimism)
cat src/adaptors/velodrome-v2/index.js

# Aerodrome (ve-tokenomics, Base)
cat src/adaptors/aerodrome/index.js

# PancakeSwap (multi-version, BSC)
cat src/adaptors/pancakeswap/index.js

# Camelot (Arbitrum native)
cat src/adaptors/camelot-v3/index.js
```

### Phase 13: GitHub Research

```bash
# Find subgraph in repo
curl -s "https://api.github.com/repos/{org}/{repo}/contents/" | jq '.[].name' | grep -i subgraph

# Get subgraph schema
curl -s "https://raw.githubusercontent.com/{org}/{subgraph-repo}/main/schema.graphql"

# Check for SDK with pool data
curl -s "https://api.github.com/repos/{org}/{repo}/contents/packages" | jq '.[].name'
```

## Output Format

```markdown
## Research Results: {Protocol Name} (DEX)

### Basic Info
- Slug: {slug}
- Type: {V2 Constant Product | V3 Concentrated Liquidity | Stable Pool | Hybrid}
- Chains: {chains}
- Website: {url}
- GitHub: {github}

### Protocol Architecture
- Factory: {address per chain}
- Router: {address per chain}
- Fee Tiers: {list of fee tiers}
- ve-Tokenomics: {Yes/No}

### Fee Structure
- LP Fee Tiers: {0.01%, 0.05%, 0.3%, 1%}
- Protocol Fee Switch: {Enabled/Disabled}
- Protocol Fee: {X}% of swap fees (if enabled)

### Subgraph
- Available: Yes/No
- Endpoint: {url}
- Status: {synced/behind/error}
- Key Entities: {pools/pairs, dayDatas, tokens}

**Sample Query:**
```graphql
{
  pools(first: 10, orderBy: totalValueLockedUSD, orderDirection: desc) {
    id
    feeTier
    totalValueLockedUSD
    volumeUSD
  }
}
```

### APY Calculation
- Method: `(volume24h * feeRate * 365 / tvl) * 100`
- Volume Source: {subgraph poolDayData | API}
- Fee Rate Source: {feeTier field | fixed}

### Volume Data
- 24h Volume: {from poolDayData or pairDayData}
- 7d Volume: {sum of 7 dailyVolumeUSD}
- Recommendation: Use 7-day average for stability

### Reward Tokens (if applicable)
- Emission Token: {symbol} ({address})
- Gauge System: {Yes/No}
- Boost Available: {Yes/No, max boost}

### Contracts Per Chain
| Chain | Factory | Router | Subgraph |
|-------|---------|--------|----------|
| | | | |

### Data Source Recommendation
- Primary: {Subgraph}
- Reason: {Has volume, TVL, fee data}
- Fallback: {On-chain via factory}

### Reference Adapter
- `src/adaptors/{name}/` - {similarity reason}

### Notes
- {Minimum TVL filter recommendation}
- {Any special pool types (stable, weighted, etc.)}
- {Rate limits or pagination needed}
```

## Checklist

Before completing research:
- [ ] DEX type identified (V2 vs V3 vs stable)
- [ ] Subgraph discovered and tested
- [ ] Fee tiers documented
- [ ] Protocol fee switch status known
- [ ] APY calculation formula confirmed
- [ ] Volume data source identified
- [ ] Reward tokens identified (if any)
- [ ] Multi-chain config gathered
- [ ] Similar adapter identified
- [ ] Sample subgraph query working
