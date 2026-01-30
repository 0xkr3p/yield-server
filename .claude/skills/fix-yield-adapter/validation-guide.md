# UI Validation Guide

**CRITICAL: Passing tests does not mean the fix is correct.** Tests only validate data format, not accuracy. You must verify the actual values match what the protocol displays.

## Step-by-Step Validation

### 1. Get Protocol UI URL

Use the DefiLlama API to find the protocol URL:
```bash
curl -s "https://api.llama.fi/protocol/{slug}" | jq -r '.url'
```

Common pool/vault pages:
- `/pools`, `/vaults`, `/earn`, `/markets`, `/stake`, `/farms`

### 2. View Adapter Output

```bash
cat src/adaptors/.test-adapter-output/{protocol-name}.json | jq '.[] | {pool, symbol, tvlUsd, apyBase, apyReward, apy}'
```

### 3. Compare Values

For each major pool, verify against the protocol UI:

| Field | Acceptable Variance | Red Flags |
|-------|---------------------|-----------|
| `tvlUsd` | ±10% of UI value | Off by 10x, 100x, or orders of magnitude |
| `apyBase` | ±0.5% absolute | Completely different (e.g., 5% vs 50%) |
| `apyReward` | ±1% absolute | Missing when UI shows rewards, or vice versa |
| `symbol` | Must match pool asset(s) | Wrong token names |

## Common Validation Failures

### TVL Wrong by Orders of Magnitude

**Cause:** Token decimals issue

```javascript
// Wrong: using raw balance without decimals
tvlUsd: rawBalance * price

// Correct: account for decimals
tvlUsd: (rawBalance / 10 ** decimals) * price
```

**Debug:**
1. Log the raw balance value
2. Check token decimals (18 for most ERC20, 6 for USDC/USDT, 8 for WBTC)
3. Verify price lookup is returning correct value

### APY 100x Too High or Too Low

**Cause:** Percentage vs decimal confusion or time period mismatch

```javascript
// If source gives daily rate, convert to annual
const apyBase = dailyRate * 365;

// If source gives decimal, convert to percentage
const apyBase = decimalApy * 100;

// If source gives per-second rate
const SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
const apyBase = ratePerSecond * SECONDS_PER_YEAR * 100;
```

### APY Shows 0% but UI Shows Rewards

**Causes:**
- Reward token address may be wrong
- Reward calculation may be missing
- Rewards are in a separate field

**Debug:**
1. Check if protocol has reward program active
2. Find reward token contract address
3. Verify reward emission rate calculation

### Pool Count Doesn't Match

**Causes:**
- Some pools may be filtered out (check filter logic)
- Multi-chain pools may be missing (check chain config)
- New pools added to protocol
- Deprecated pools still in adapter

## Spot-Check Specific Pools

Pick 2-3 pools of different sizes and verify:

1. **A large pool** (highest TVL) - ensures main calculation is correct
2. **A small pool** - ensures edge cases work
3. **A pool with rewards** (if applicable) - ensures reward APY works

### Example Verification

```
Protocol UI shows:
  USDC Pool: TVL $5.2M, APY 4.5% (base) + 2.1% (rewards)

Adapter output should be approximately:
  tvlUsd: 5200000 (±520000 = ±10%)
  apyBase: 4.5 (±0.5)
  apyReward: 2.1 (±0.5)
  rewardTokens: ['0x...'] (must be present if apyReward > 0)
```

## If Values Don't Match

**Do not ship a fix that passes tests but has wrong values.** Instead:

1. Re-examine the data source (API response, contract calls)
2. Check the calculation logic
3. Add debug logging to trace where values diverge
4. Compare raw data from source to what protocol UI displays
5. The protocol UI is the source of truth - match it

### Common Sources of Mismatch

| Source | Description |
|--------|-------------|
| Protocol API returns different data than UI uses | Check if there's a v2 API or different endpoint |
| Calculation formula differs from protocol's method | Read protocol docs for exact formula |
| Stale/cached data in API vs live UI | Check data timestamps |
| Different pool definitions | UI may exclude certain pools or include test pools |
| Multi-token pools | Symbol or TVL may be calculated differently |

## Quick Validation Commands

```bash
# Compare adapter TVL to DefiLlama protocol TVL
ADAPTER_TVL=$(cat src/adaptors/.test-adapter-output/{protocol}.json | jq '[.[].tvlUsd] | add')
PROTOCOL_TVL=$(curl -s "https://api.llama.fi/protocol/{slug}" | jq '.currentChainTvls | add')
echo "Adapter: $ADAPTER_TVL, Protocol: $PROTOCOL_TVL"

# Find pools with suspicious APY
cat src/adaptors/.test-adapter-output/{protocol}.json | jq '.[] | select(.apyBase > 100 or .apyReward > 100) | {symbol, apyBase, apyReward}'

# Find pools with zero TVL
cat src/adaptors/.test-adapter-output/{protocol}.json | jq '.[] | select(.tvlUsd == 0 or .tvlUsd == null) | {pool, symbol}'

# Check for missing rewardTokens
cat src/adaptors/.test-adapter-output/{protocol}.json | jq '.[] | select(.apyReward > 0 and (.rewardTokens | length) == 0)'
```
