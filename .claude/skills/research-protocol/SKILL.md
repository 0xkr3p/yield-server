---
name: researching-protocols
description: Researches DeFi protocols for yield adapter development. Use as a general-purpose research skill when the protocol category is unknown or doesn't fit lending, DEX, or liquid staking patterns. Usage: /researching-protocols {protocol-slug}
---

# Research Protocol: $0

## Live Context

Protocol info: !`curl -s "https://api.llama.fi/protocol/$0" 2>/dev/null | jq '{name, slug, category, chains, url, github}' 2>/dev/null || echo "Fetch protocol info manually"`

TVL adapter preview: !`curl -s "https://raw.githubusercontent.com/DefiLlama/DefiLlama-Adapters/main/projects/$0/index.js" 2>/dev/null | head -30 || echo "No TVL adapter found"`

## Research Checklist

```
Research Progress:
- [ ] Phase 1: Review protocol info above
- [ ] Phase 2: Identify category and route to specialized skill
- [ ] Phase 3: Find data sources (subgraph/API/on-chain)
- [ ] Phase 4: Get contract addresses
- [ ] Phase 5: Understand APY calculation
- [ ] Phase 6: Find reference adapter
```

## Routing by Category

Based on the category from DefiLlama:

| Category | Route to Skill |
|----------|----------------|
| Lending, CDP | `.claude/skills/research-lending/SKILL.md` |
| Dexes, Liquidity Manager | `.claude/skills/research-dex/SKILL.md` |
| Liquid Staking | `.claude/skills/research-liquid-staking/SKILL.md` |
| Other | Continue with this skill |

## Research Phases

### Phase 1: Protocol Info Analysis

From the live context above, extract:
- **Category** → Determines adapter pattern
- **Chains** → Which chains to support
- **URL** → Protocol website for docs
- **GitHub** → Source for contracts/subgraph

### Phase 2: TVL Adapter Mining

The TVL adapter (if exists) often contains:
- Contract addresses
- Chain configurations
- RPC patterns

```bash
curl -s "https://raw.githubusercontent.com/DefiLlama/DefiLlama-Adapters/main/projects/$0/index.js"
```

### Phase 3: Data Source Discovery

**Priority order:**
1. On-chain (most reliable)
2. Subgraph (good for aggregated data)
3. API (last resort)

```bash
# Test subgraph
curl -s "https://api.thegraph.com/subgraphs/name/{org}/$0" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ _meta { block { number } } }"}'

# Test common API patterns
curl -s "https://api.$0.com/v1/pools" 2>/dev/null | head -50
```

### Phase 4: Contract Discovery

```bash
# Check for deployment files in GitHub
curl -s "https://raw.githubusercontent.com/{org}/$0/main/deployments.json" 2>/dev/null
curl -s "https://raw.githubusercontent.com/{org}/$0/main/addresses.json" 2>/dev/null

# Verify contract on Etherscan
curl -s "https://api.etherscan.io/api?module=contract&action=getabi&address={address}"
```

### Phase 5: APY Calculation Research

Look for:
- Fee structure (protocol docs)
- Interest rate models (lending)
- Trading fees (DEX)
- Staking rewards (liquid staking)

### Phase 6: Reference Adapter

```bash
# Find similar adapters
ls src/adaptors/ | head -30
cat src/adaptors/{similar}/index.js
```

## Output Format

```markdown
## Research Results: {Protocol Name}

### Basic Info
- Slug: {slug}
- Category: {category}
- Chains: {chains}
- Website: {url}

### Data Source Recommendation
- Primary: {on-chain | subgraph | api}
- Reason: {why}
- Fallback: {alternative}

### Contracts Found
| Chain | Name | Address |
|-------|------|---------|

### APY Calculation
- Method: {description}
- Formula: {formula}

### Tokens
- Underlying: {list}
- Receipt/LP: {if applicable}
- Rewards: {if applicable}

### Reference Adapter
- `src/adaptors/{name}/` - {why similar}

### Notes
- {edge cases, rate limits, etc.}
```

## Completion Checklist

- [ ] Category identified
- [ ] Data source found (on-chain/subgraph/API)
- [ ] Contract addresses per chain
- [ ] APY calculation method
- [ ] Token addresses
- [ ] Reference adapter identified
