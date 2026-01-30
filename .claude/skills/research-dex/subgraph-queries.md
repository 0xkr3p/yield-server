# DEX Subgraph Queries

Reference queries for researching DEX protocols via subgraphs.

## Finding Subgraph URL

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

## Exploring Subgraph Schema

```bash
# Get schema types
curl -s "{subgraph_url}" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ __schema { types { name fields { name } } } }"}' | jq '.data.__schema.types[] | select(.name | test("Pool|Pair|Token|Day|Hour"; "i"))'
```

## V2-style (Constant Product) Queries

### Get Top Pairs
```graphql
{
  pairs(first: 100, orderBy: reserveUSD, orderDirection: desc) {
    id
    token0 {
      symbol
      id
    }
    token1 {
      symbol
      id
    }
    reserveUSD        # TVL
    volumeUSD         # All-time volume
  }
}
```

### Get Daily Volume Data
```graphql
{
  pairDayDatas(
    first: 7
    orderBy: date
    orderDirection: desc
    where: { pair: "{pair_id}" }
  ) {
    date
    dailyVolumeUSD
    reserveUSD
  }
}
```

### Get All Pairs with Daily Data
```graphql
{
  pairs(first: 100, orderBy: reserveUSD, orderDirection: desc) {
    id
    token0 { symbol, id }
    token1 { symbol, id }
    reserveUSD
    pairDayDatas(first: 1, orderBy: date, orderDirection: desc) {
      dailyVolumeUSD
    }
  }
}
```

## V3-style (Concentrated Liquidity) Queries

### Get Top Pools
```graphql
{
  pools(first: 100, orderBy: totalValueLockedUSD, orderDirection: desc) {
    id
    token0 {
      symbol
      id
    }
    token1 {
      symbol
      id
    }
    feeTier            # Fee in basis points (500 = 0.05%, 3000 = 0.3%, 10000 = 1%)
    totalValueLockedUSD
    volumeUSD          # All-time volume
  }
}
```

### Get Daily Pool Data
```graphql
{
  poolDayDatas(
    first: 7
    orderBy: date
    orderDirection: desc
    where: { pool: "{pool_id}" }
  ) {
    date
    volumeUSD
    tvlUSD
    feesUSD
  }
}
```

### Get Pools with Fee Data
```graphql
{
  pools(first: 100, orderBy: totalValueLockedUSD, orderDirection: desc) {
    id
    token0 { symbol, id }
    token1 { symbol, id }
    feeTier
    totalValueLockedUSD
    poolDayDatas(first: 1, orderBy: date, orderDirection: desc) {
      volumeUSD
      feesUSD
    }
  }
}
```

## Curve-style (Stable Pool) Queries

```graphql
{
  pools(first: 100, orderBy: tvl, orderDirection: desc) {
    id
    name
    coins
    tvl
    virtualPrice
    dailyVolume
    baseApr
    rewardTokens {
      token { symbol, address }
      apy
    }
  }
}
```

## Velodrome/Aerodrome-style (ve-DEX) Queries

```graphql
{
  pairs(first: 100, orderBy: totalValueLockedUSD, orderDirection: desc) {
    id
    token0 { symbol, id }
    token1 { symbol, id }
    stable                # true for stable pairs
    totalValueLockedUSD
    volumeUSD
    gauge {
      id
      rewardRate
      totalSupply
    }
  }
}
```

## Common Entity Mappings

| V2 Entity | V3 Entity | Description |
|-----------|-----------|-------------|
| `pairs` | `pools` | Liquidity pools |
| `reserveUSD` | `totalValueLockedUSD` | TVL |
| `volumeUSD` | `volumeUSD` | Total volume |
| `pairDayDatas` | `poolDayDatas` | Daily snapshots |
| `dailyVolumeUSD` | `volumeUSD` | 24h volume |
| N/A | `feeTier` | Fee tier (V3 only) |
| N/A | `feesUSD` | Collected fees (V3) |

## Fee Tier Reference

| Fee Tier Value | Percentage | Typical Use |
|----------------|------------|-------------|
| 100 | 0.01% | Stablecoin pairs |
| 500 | 0.05% | Stable pairs |
| 3000 | 0.3% | Most pairs |
| 10000 | 1% | Exotic pairs |

## APY Calculation from Subgraph

### Using Volume
```javascript
// V2: fixed fee (usually 0.3%)
const feeRate = 0.003;
const apy = (dailyVolumeUSD * feeRate * 365 / reserveUSD) * 100;

// V3: variable fee from feeTier
const feeRate = feeTier / 1000000; // feeTier is in hundredths of bps
const apy = (dailyVolumeUSD * feeRate * 365 / totalValueLockedUSD) * 100;
```

### Using feesUSD (if available)
```javascript
// More accurate if subgraph tracks fees directly
const apy = (feesUSD24h * 365 / tvlUSD) * 100;
```

### 7-day Average (more stable)
```javascript
const avgDailyVolume = volume7d / 7;
const apy = (avgDailyVolume * feeRate * 365 / tvl) * 100;
```

## Testing Subgraph Query

```bash
# Test with curl
curl -s "{subgraph_url}" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ pools(first: 5, orderBy: totalValueLockedUSD, orderDirection: desc) { id totalValueLockedUSD } }"
  }' | jq '.'
```

## Alternative Subgraph Providers

If hosted service is deprecated:

```javascript
// Decentralized Graph Network
const url = `https://gateway.thegraph.com/api/${process.env.GRAPH_API_KEY}/subgraphs/id/${subgraphId}`;

// Goldsky
const url = 'https://api.goldsky.com/api/public/project_xxx/subgraphs/{protocol}/1.0.0/gn';

// Satsuma
const url = 'https://{protocol}.subgraph.satsuma-prod.com/{key}/subgraphs/{name}';

// Protocol-hosted
const url = 'https://subgraph.{protocol}.com/subgraphs/name/{name}';
```
