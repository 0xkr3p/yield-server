# Error Patterns Library

Common errors encountered during yield adapter development with standard fixes.

## Validation Errors

### ERR-VAL-001: Pool ID Required
**Error**: `pool is required` or `pool cannot be empty`
**Cause**: Missing or malformed pool identifier
**Fix**: Ensure pool ID is formatted as `${address}-${chain}`.toLowerCase()
```javascript
// Wrong
pool: address

// Correct
pool: `${address}-${chain}`.toLowerCase()
```
**Affected**: build-adapter, fix-adapter

### ERR-VAL-002: Chain Required
**Error**: `chain is required`
**Cause**: Chain field missing or not formatted
**Fix**: Use `utils.formatChain(chain)` for proper formatting
```javascript
// Wrong
chain: 'ETHEREUM'

// Correct
chain: utils.formatChain('ethereum')
```
**Affected**: build-adapter

### ERR-VAL-003: Reward Tokens Missing
**Error**: `apyReward requires rewardTokens array`
**Cause**: Pool has `apyReward > 0` but no `rewardTokens`
**Fix**: Add rewardTokens array with token addresses
```javascript
// Wrong
{ apyReward: 5.5 }

// Correct
{
  apyReward: 5.5,
  rewardTokens: ['0x...']
}
```
**Affected**: build-adapter, fix-adapter

### ERR-VAL-004: Project Name Mismatch
**Error**: `project does not match folder name`
**Cause**: `project` field doesn't match adapter directory name
**Fix**: Ensure exact match (case-sensitive)
```javascript
// Folder: src/adaptors/aave-v3/
module.exports = {
  project: 'aave-v3' // Must match exactly
}
```
**Affected**: build-adapter

### ERR-VAL-005: Invalid APY Value
**Error**: `APY must be a finite number` or `NaN detected`
**Cause**: Division by zero or undefined values in APY calculation
**Fix**: Guard against zero division and use `utils.keepFinite()`
```javascript
// Wrong
const apy = fee / tvl * 365

// Correct
const apy = tvl > 0 ? (fee / tvl * 365) : 0
return pools.filter(utils.keepFinite)
```
**Affected**: build-adapter, fix-adapter

### ERR-VAL-006: Zero APY for Yield Protocol
**Error**: `apyBase = 0` for pools with TVL > $1000
**Cause**: Data source not returning APY, wrong field queried, or broken endpoint
**Symptoms**:
- Tests pass but APY shows 0%
- Protocol UI shows positive APY but adapter shows 0
- Share price calculation returns 0 change

**When apyBase = 0 is a BUG**:
| Protocol Type | Expected |
|---------------|----------|
| Lending (supply) | `apyBase > 0` |
| Liquid Staking | `apyBase > 0` |
| DEX/AMM | `apyBase > 0` OR `apyReward > 0` |
| Yield Aggregator | `apyBase > 0` |

**When apyBase = 0 is VALID**:
| Scenario | Required Alternative |
|----------|---------------------|
| Reward-only pool | `apyReward > 0` + `rewardTokens` |
| Borrow-only pool | `apyBaseBorrow > 0` |
| Treasury vault | Document in `poolMeta` |

**Fix Options**:
1. Check if data source returns APY in different field name
2. Verify APY is percentage not decimal (10 not 0.10)
3. Find alternative data source if current is broken
4. Calculate from on-chain rate/share price correctly

**Example Fix (Goldfinch)**:
```javascript
// Broken: subgraph indexer failing
const { seniorPools } = await request(BROKEN_SUBGRAPH, query);

// Fixed: migrate to working Goldsky endpoint
const SUBGRAPH_URL = 'https://api.goldsky.com/api/public/.../goldfinch-v2/.../gn';
const { seniorPools } = await request(SUBGRAPH_URL, query);
// Now returns estimatedApy = 0.1001 (10.01%)
```
**Affected**: build-adapter, fix-adapter

---

## Data Source Errors

### ERR-DS-001: API 404 Not Found
**Error**: `Request failed with status code 404`
**Cause**: API endpoint moved or deprecated
**Fix Options**:
1. Find new API endpoint in protocol docs
2. Convert to on-chain data source
3. Check for alternative API versions
**Affected**: fix-adapter, investigating-broken-data-sources

### ERR-DS-002: Subgraph Deprecated
**Error**: `Subgraph deployment not found` or hosted service error
**Cause**: The Graph hosted service migration
**Fix**: Update to decentralized network endpoint
```javascript
// Old (hosted)
https://api.thegraph.com/subgraphs/name/org/subgraph

// New (decentralized)
const endpoint = sdk.graph.modifyEndpoint('SUBGRAPH_ID')
```
**Affected**: fix-adapter, investigating-broken-data-sources

### ERR-DS-003: RPC Timeout
**Error**: `ECONNRESET` or `timeout of xxxms exceeded`
**Cause**: RPC endpoint overloaded or rate limited
**Fix Options**:
1. Add retry logic with exponential backoff
2. Use `sdk.api.abi.multiCall` for batching
3. Reduce concurrent requests
**Affected**: fix-adapter

### ERR-DS-004: Empty Response
**Error**: Empty array `[]` or `No pools found`
**Cause**: API structure changed or filter too restrictive
**Fix**:
1. Check API response format
2. Verify filter conditions
3. Check if protocol has active pools
**Affected**: fix-adapter, build-adapter

### ERR-DS-005: Price Lookup Failed
**Error**: `undefined price` or `Price not found for token`
**Cause**: Token not indexed by DefiLlama price API
**Fix Options**:
1. Use `utils.getData()` to check for price
2. Fall back to on-chain oracle
3. Use LP token price calculation
```javascript
// Check price availability
const priceKey = `${chain}:${tokenAddress}`
const priceData = await utils.getData(`https://coins.llama.fi/prices/current/${priceKey}`)
if (!priceData.coins[priceKey]) {
  // Handle missing price
}
```
**Affected**: build-adapter, fix-adapter

---

## Calculation Errors

### ERR-CALC-001: Blocks Per Year Mismatch
**Error**: APY values 100x too high or too low
**Cause**: Wrong blocks-per-year constant for chain
**Fix**: Use correct constant per chain
```javascript
const BLOCKS_PER_YEAR = {
  ethereum: 2628000,
  polygon: 15768000,
  bsc: 10512000,
  arbitrum: 2628000,
  avalanche: 31536000,
}
```
**Affected**: build-adapter

### ERR-CALC-002: RAY Format Confusion
**Error**: APY values ~10^25 too high
**Cause**: Aave RAY format (10^27) not converted
**Fix**: Divide by `1e27` for Aave-style protocols
```javascript
// Aave-style rate
const apyBase = (liquidityRate / 1e27) * 100
```
**Affected**: build-adapter (lending)

### ERR-CALC-003: Percentage vs Decimal
**Error**: APY values 100x off
**Cause**: Mixing percentage (5%) with decimal (0.05)
**Fix**: Standardize to percentage for output
```javascript
// Output should be percentage
return {
  apyBase: 5.5,  // 5.5%, not 0.055
  apyReward: 2.0 // 2.0%, not 0.02
}
```
**Affected**: build-adapter, fix-adapter

---

## Pattern Detection Rules

When 3+ occurrences of an error pattern are logged:
1. Add to this document if not present
2. Update affected skills with prevention guidance
3. Consider adding automated check to verify hook

## Linking Feedback

When logging feedback for a known pattern, use the pattern ID:
```json
{
  "learnings": {
    "pattern_tags": ["ERR-VAL-003", "reward-tokens"]
  }
}
```
