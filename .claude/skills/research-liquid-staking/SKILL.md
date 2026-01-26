---
name: researching-liquid-staking
description: Researches liquid staking protocols for yield adapter development. Use when building adapters for LSTs like Lido, Rocket Pool, Marinade, Jito, or similar staking derivatives.
---

# Research Liquid Staking Protocol

Copy this checklist and track your progress:

```
Research Progress:
- [ ] Phase 1: DefiLlama Protocol Info
- [ ] Phase 2: Existing TVL Adapter
- [ ] Phase 3: Documentation Discovery
- [ ] Phase 4: Exchange Rate Pattern Detection
- [ ] Phase 5: Solana Stake Pool Structure (if Solana)
- [ ] Phase 6: APY Calculation Method
- [ ] Phase 7: Fee Structure Research
- [ ] Phase 8: Reference Adapters
- [ ] Phase 9: GitHub Research
```

## LST Fundamentals

Liquid staking protocols issue a receipt token representing staked assets. Yield accrues via:
1. **Rebasing** - Token balance increases (e.g., stETH)
2. **Exchange Rate** - Token value increases vs underlying (e.g., wstETH, rETH, mSOL)

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

**Verify category is "Liquid Staking"**

### Phase 2: Existing TVL Adapter

```bash
curl -s "https://raw.githubusercontent.com/DefiLlama/DefiLlama-Adapters/main/projects/{slug}/index.js"
```

**Look for:**
- Staking contract addresses
- Token contract addresses (receipt token)
- Chain configurations

### Phase 3: Documentation Discovery

**3a. Find Documentation via Sitemap:**
```bash
# Try common sitemap locations
curl -s "https://{protocol-domain}/sitemap.xml" | grep -oP '(?<=<loc>)[^<]+' | grep -i 'doc\|dev\|api\|contract\|address'

# Or parse sitemap index
curl -s "https://docs.{protocol}.com/sitemap.xml" | grep -oP '(?<=<loc>)[^<]+'
```

**3b. Key Documentation Pages to Find:**
- Contract addresses / deployments
- Exchange rate mechanism
- Fee structure
- Validator/operator info
- Integration guides

**3c. Common Documentation URLs:**
```bash
curl -s "https://docs.{protocol}.com/"
curl -s "https://{protocol}.gitbook.io/"
curl -s "https://docs.{protocol}.fi/"
curl -s "https://developers.{protocol}.fi/"
```

### Phase 4: Exchange Rate Pattern Detection

**For EVM Liquid Staking Tokens:**

| Pattern | Function | Example Protocols |
|---------|----------|-------------------|
| Rebasing | `balanceOf` changes over time | Lido stETH |
| Exchange Rate | `getExchangeRate()` | Rocket Pool rETH |
| Shares | `convertToAssets(shares)` | wstETH, ERC-4626 |
| Price Per Share | `pricePerShare()` | Some yield tokens |
| Get Rate | `getRate()` | Ankr, StakeWise |

**Common EVM Functions to Look For:**
```solidity
// Exchange rate functions
function getExchangeRate() external view returns (uint256);
function convertToAssets(uint256 shares) external view returns (uint256);
function pricePerShare() external view returns (uint256);
function getRate() external view returns (uint256);
function tokensPerStEth() external view returns (uint256);
function stEthPerToken() external view returns (uint256);

// Supply/balance functions
function totalSupply() external view returns (uint256);
function getTotalPooledEther() external view returns (uint256);
function totalAssets() external view returns (uint256);
```

**Fetch Contract ABI:**
```bash
# Ethereum
curl -s "https://api.etherscan.io/api?module=contract&action=getabi&address={token_address}" | jq -r '.result' | jq '.[] | select(.name | test("rate|exchange|convert|price|share"; "i"))'

# Other chains - adjust API endpoint
# Arbitrum: api.arbiscan.io
# Polygon: api.polygonscan.com
# Base: api.basescan.org
```

### Phase 5: Solana Stake Pool Structure

For Solana LSTs (e.g., mSOL, jitoSOL, bSOL):

**Account Data Layout:**
```
Offset 258: pool_token_supply (u64, 8 bytes) - Total LST supply
Offset 266: total_lamports (u64, 8 bytes) - Total staked SOL
```

**Calculate Exchange Rate:**
```javascript
exchangeRate = total_lamports / pool_token_supply
apy = ((currentRate / previousRate) ^ (365 / daysBetween) - 1) * 100
```

**Fetch Solana Stake Pool Data:**
```bash
curl -s https://api.mainnet-beta.solana.com -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "getAccountInfo",
    "params": ["{stake_pool_address}", {"encoding": "base64"}]
  }'
```

**Known Solana LST Addresses:**
| Protocol | Stake Pool | Token Mint |
|----------|------------|------------|
| Marinade | 8szGkuLTAux9XMgZ2vtY39jVSowEcpBfFfD8hXSEqdGC | mSoLzYCxHdYgdzU16g5QSh3i5K3z3KZK7ytfqcJm7So |
| Jito | Jito4APyf642JPZPx3hGc6WWJ8zPKtRbRs4P815Awbb | J1toso1uCk3RLmjorhTtrVwY9HJ7X8V9yYac6Y7kGCPn |
| BlazeStake | stk9ApL5HeVAwPLr3TLhDXdZS8ptVu7zp6ov8HFDuMi | bSo13r4TkiE4KumL71LsHTPpL2euBYLFx6h9HP3piy1 |

### Phase 6: APY Calculation Method

**Method 1: Exchange Rate Appreciation (Recommended)**
```javascript
// Fetch current and historical exchange rates
const currentRate = await getExchangeRate();
const historicalRate = await getExchangeRateAtBlock(blocksAgo);

// Calculate APY
const periodDays = 7; // Use 7-day average
const rateChange = currentRate / historicalRate;
const apy = (Math.pow(rateChange, 365 / periodDays) - 1) * 100;
```

**Method 2: From Protocol API (if available)**
```bash
# Check if protocol provides APY endpoint
curl -s "https://api.{protocol}.com/apy"
curl -s "https://{protocol}.com/api/v1/stats"
```

**Method 3: From Staking Rewards**
```javascript
// If protocol reports rewards directly
apy = (annualRewards / totalStaked) * 100;
```

### Phase 7: Fee Structure Research

**Common LST Fee Structures:**
- **Protocol Fee**: 5-10% of staking rewards (not of principal)
- **Operator Fee**: Additional cut for node operators
- **No fee on principal**: Fees only apply to yield

**Where to Find Fee Info:**
```bash
# Check contract for fee parameters
curl -s "https://api.etherscan.io/api?module=contract&action=getsourcecode&address={contract}" | jq -r '.result[0].SourceCode' | grep -i "fee"

# Documentation
curl -s "https://docs.{protocol}.com/sitemap.xml" | grep -oP '(?<=<loc>)[^<]+' | xargs -I {} sh -c 'curl -s "{}" | grep -i "fee"'
```

**Fee Impact on APY:**
```javascript
// Gross APY from chain staking rewards
const grossApy = chainStakingRate; // e.g., 4% for ETH

// Net APY after protocol fees
const protocolFee = 0.10; // 10% of rewards
const netApy = grossApy * (1 - protocolFee); // 3.6%
```

### Phase 8: Reference Adapters

**Study these existing LST adapters:**

```bash
# Lido (rebasing + wrapped)
cat src/adaptors/lido/index.js

# Rocket Pool (exchange rate)
cat src/adaptors/rocket-pool/index.js

# Marinade (Solana)
cat src/adaptors/marinade-finance/index.js

# Jito (Solana + MEV rewards)
cat src/adaptors/jito/index.js

# Ankr (multi-chain)
cat src/adaptors/ankr/index.js
```

### Phase 9: GitHub Research

```bash
# Check for SDK or rate calculation
curl -s "https://api.github.com/repos/{org}/{repo}/contents/" | jq '.[].name'

# Look for exchange rate implementation
curl -s "https://api.github.com/search/code?q=exchangeRate+repo:{org}/{repo}" | jq '.items[].path'

# Check contracts folder
curl -s "https://api.github.com/repos/{org}/{repo}/contents/contracts" | jq '.[].name'
```

## Output Format

```markdown
## Research Results: {Protocol Name} (Liquid Staking)

### Basic Info
- Slug: {slug}
- Chains: {chains}
- Website: {url}
- GitHub: {github}

### Token Mechanism
- Type: {Rebasing | Exchange Rate}
- Receipt Token: {symbol} ({address})
- Underlying: {symbol} ({address})

### Exchange Rate
- Function: {function name and signature}
- Contract: {address}
- Current Rate: {value}

### Contracts
| Chain | Contract | Address | Purpose |
|-------|----------|---------|---------|
| | | | Staking/Pool |
| | | | Token |

### APY Calculation
- Method: {Exchange rate appreciation | Protocol API | Calculated from rewards}
- Formula: {formula}
- Data Source: {on-chain | API endpoint}
- Historical Data: {How to get historical rates for APY calc}

### Fee Structure
- Protocol Fee: {X}% of rewards
- Operator Fee: {X}% (if applicable)
- Net APY Impact: Gross APY * {multiplier}

### Data Source Recommendation
- Primary: {on-chain | API}
- Reason: {why}

### Reference Adapter
- `src/adaptors/{name}/` - {similarity reason}

### Notes
- {Any special considerations}
- {Boost mechanisms if any}
- {Validator set info if relevant}
```

## Checklist

Before completing research:
- [ ] Token mechanism identified (rebasing vs exchange rate)
- [ ] Exchange rate function found
- [ ] Token addresses (receipt + underlying)
- [ ] Fee structure documented
- [ ] APY calculation method determined
- [ ] Historical rate source identified (for APY calc)
- [ ] Similar adapter identified
