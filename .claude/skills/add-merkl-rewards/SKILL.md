---
name: add-merkl-rewards
description: Adds Merkl reward APY to yield adapters. Use when a protocol distributes token rewards via Merkl (common for incentive programs). Can be used standalone or referenced from build-yield-adapter.
---

# Add Merkl Rewards: $0

## Overview

Merkl (merkl.xyz) is a reward distribution platform used by many DeFi protocols to distribute token incentives. This skill helps integrate Merkl rewards into yield adapters.

## Live Context

Protocol in Merkl: !`curl -s "https://api.merkl.xyz/v4/protocols" 2>/dev/null | jq -r '.[] | select(.name | test("$0"; "i")) | "Found: \(.name) (ID: \(.id))"' 2>/dev/null || echo "Check manually"`

## Quick Check

```bash
# 1. Check if protocol has mainProtocolId in Merkl
curl -s "https://api.merkl.xyz/v4/protocols" | jq '.[] | select(.name | test("$0"; "i")) | {id, name}'

# 2. If not found by name, check by vault/pool address
curl -s "https://api.merkl.xyz/v4/opportunities?chainId=1&identifier=0xVAULT_ADDRESS" | jq '.[0] | {name, apr, mainProtocolId}'
```

## Integration Decision Tree

```
Does protocol have mainProtocolId in Merkl?
├── YES → Use Standard Integration (addMerklRewardApy helper)
└── NO → Check if vaults appear in opportunities by address
    ├── YES → Use Custom Integration (query by identifier)
    └── NO → No Merkl rewards available
```

## Standard Integration

Use when protocol has a `mainProtocolId` in Merkl's protocol list.

### Step 1: Find Protocol ID

```bash
curl -s "https://api.merkl.xyz/v4/protocols" | jq '.[] | select(.name | test("aave|compound|uniswap"; "i"))'
```

### Step 2: Add to Adapter

```javascript
const { addMerklRewardApy } = require('../merkl/merkl-additional-reward');

const main = async () => {
  // Fetch base pools first
  let pools = await fetchBasePools();

  // Add Merkl rewards
  // Args: pools, protocolId, addressGetter (extracts pool address from pool object)
  pools = await addMerklRewardApy(
    pools,
    'protocol-id',  // From Merkl API
    (pool) => pool.pool.split('-')[0]  // Extract address from pool ID
  );

  return pools;
};
```

### How It Works

The helper:
1. Fetches all LIVE opportunities for the protocol from Merkl API
2. Builds a map of `{chainId -> {poolAddress -> {apyReward, rewardTokens}}}`
3. Merges reward data into matching pools (by address)
4. Only adds rewards if pool doesn't already have `apyReward` or `rewardTokens`

## Custom Integration

Use when protocol doesn't have mainProtocolId but vaults appear in Merkl by address.

### Step 1: Verify Vaults Have Merkl Rewards

```bash
# Check specific vault address
curl -s "https://api.merkl.xyz/v4/opportunities?chainId=1&identifier=0x98C49e13bf99D7CAd8069faa2A370933EC9EcF17" | jq '.[0] | {name, apr, rewardsRecord}'
```

### Step 2: Add Custom Merkl Fetching

```javascript
const superagent = require('superagent');

// Chain ID mapping for Merkl API
const CHAIN_IDS = {
  ethereum: 1,
  base: 8453,
  arbitrum: 42161,
  optimism: 10,
  polygon: 137,
  sonic: 146,
  hyperliquid: 999,
  avalanche: 43114,
  bsc: 56,
};

// Fetch Merkl rewards for a specific vault
const getMerklRewards = async (vaultAddress, chainId) => {
  try {
    const response = await superagent.get(
      `https://api.merkl.xyz/v4/opportunities?chainId=${chainId}&identifier=${vaultAddress}`
    );
    const data = response.body;
    if (!data || data.length === 0) return null;

    const opportunity = data[0];
    if (!opportunity.apr || opportunity.apr <= 0) return null;

    const rewardTokens = opportunity.rewardsRecord?.breakdowns
      ?.map((b) => b.token?.address)
      .filter(Boolean) || [];

    return {
      apyReward: opportunity.apr,
      rewardTokens: [...new Set(rewardTokens)],
    };
  } catch (e) {
    return null; // Silently fail - rewards are optional
  }
};

// Batch fetch for multiple vaults
const getMerklRewardsForChain = async (vaultAddresses, chain) => {
  const chainId = CHAIN_IDS[chain];
  if (!chainId) return {};

  const rewards = {};
  const batchSize = 5; // Rate limit friendly

  for (let i = 0; i < vaultAddresses.length; i += batchSize) {
    const batch = vaultAddresses.slice(i, i + batchSize);
    const results = await Promise.all(
      batch.map((addr) => getMerklRewards(addr, chainId))
    );
    batch.forEach((addr, idx) => {
      if (results[idx]) {
        rewards[addr.toLowerCase()] = results[idx];
      }
    });
  }
  return rewards;
};
```

### Step 3: Use in Main Function

```javascript
const main = async () => {
  const pools = [];

  for (const chain of chains) {
    const vaults = await getVaultsForChain(chain);
    const vaultAddresses = vaults.map(v => v.address);

    // Fetch Merkl rewards in parallel with other data
    const [prices, merklRewards] = await Promise.all([
      utils.getPrices(assets, chain),
      getMerklRewardsForChain(vaultAddresses, chain),
    ]);

    for (const vault of vaults) {
      const poolData = {
        pool: `${vault.address}-${chain}`.toLowerCase(),
        chain: utils.formatChain(chain),
        // ... other fields
      };

      // Add Merkl rewards if available
      const rewards = merklRewards[vault.address.toLowerCase()];
      if (rewards && rewards.apyReward > 0) {
        poolData.apyReward = rewards.apyReward;
        poolData.rewardTokens = rewards.rewardTokens;
      }

      pools.push(poolData);
    }
  }

  return pools.filter(p => utils.keepFinite(p));
};
```

## Merkl API Reference

### Endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /v4/protocols` | List all registered protocols |
| `GET /v4/opportunities?mainProtocolId={id}` | Get opportunities by protocol |
| `GET /v4/opportunities?chainId={id}&identifier={addr}` | Get opportunity by vault address |
| `GET /v4/opportunities?chainId={id}&status=LIVE` | Get all live opportunities on chain |

### Chain IDs

From `src/adaptors/merkl/config.js`:

```javascript
{
  1: 'ethereum',
  137: 'polygon',
  10: 'optimism',
  42161: 'arbitrum',
  1101: 'polygon_zkevm',
  8453: 'base',
  60808: 'bob',
  146: 'sonic',
  43114: 'avax',
  80094: 'berachain',
  56: 'bsc',
  42220: 'celo',
  143: 'monad',
  999: 'hyperevm',  // Hyperliquid
}
```

### Response Structure

```json
{
  "name": "Deposit USDC on Protocol",
  "mainProtocolId": "protocol-id",  // null if not registered
  "apr": 0.511567920633326,         // Reward APR as decimal
  "identifier": "0xVaultAddress",
  "rewardsRecord": {
    "breakdowns": [
      {
        "token": {
          "address": "0xRewardToken",
          "symbol": "TOKEN",
          "decimals": 18
        },
        "amount": "123456789",
        "value": 100.50
      }
    ]
  }
}
```

## Examples

### Example 1: Protocol with mainProtocolId (Aave)

```javascript
const { addMerklRewardApy } = require('../merkl/merkl-additional-reward');

const main = async () => {
  let pools = await getAavePools();
  pools = await addMerklRewardApy(pools, 'aave', (p) => p.pool.split('-')[0]);
  return pools;
};
```

### Example 2: Protocol without mainProtocolId (Summer.fi)

See `src/adaptors/lazy-summer-protocol/index.js` for complete implementation.

### Example 3: Check if Protocol Has Merkl Rewards

```bash
# By protocol name
curl -s "https://api.merkl.xyz/v4/protocols" | jq '.[] | select(.name | test("morpho"; "i"))'

# By vault address on Ethereum
curl -s "https://api.merkl.xyz/v4/opportunities?chainId=1&identifier=0x..." | jq 'length'
```

## Troubleshooting

### No rewards showing up

1. Check vault is in Merkl: `curl "https://api.merkl.xyz/v4/opportunities?chainId={id}&identifier={addr}"`
2. Verify status is LIVE (not ENDED)
3. Check chain ID mapping is correct

### APR seems wrong

- Merkl returns APR as a decimal (0.05 = 5%)
- The helper and examples use it directly as `apyReward`
- Verify against Merkl UI: https://app.merkl.xyz

### Rate limiting

- Batch requests (5 at a time recommended)
- Add small delays between batches if needed
- Cache responses if calling frequently

## Related Skills

- `/build-yield-adapter` - Full adapter creation (references this skill)
- `/fix-yield-adapter` - May need to add missing rewards
- `/research-protocol` - Research may identify Merkl usage
