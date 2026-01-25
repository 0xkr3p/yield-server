# Skill: Research Protocol

## Purpose
Gather all information needed to build a yield adapter through systematic research of protocol resources.

## Input
- Protocol slug (e.g., "aave-v3", "uniswap-v3")
- Or protocol details from DefiLlama API

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

**Extract and save:**
- `category` → Determines adapter pattern
- `chains` → Which chains to support
- `url` → Protocol website (for Phase 3)
- `github` → GitHub org/repos (for Phase 4)
- `module` → TVL adapter path (has contract addresses!)

### Phase 2: Existing TVL Adapter (Gold Mine!)

```bash
# Get the TVL adapter - often contains contract addresses
curl -s "https://raw.githubusercontent.com/DefiLlama/DefiLlama-Adapters/main/projects/{slug}/index.js"
```

**Look for:**
- Contract addresses
- Chain configurations  
- RPC call patterns
- Helper imports (may indicate data source)

### Phase 3: Protocol Website & Documentation

**3a. Documentation Locations to Check:**

Try fetching documentation directly:
```bash
# Common documentation URLs
curl -s "https://docs.{protocol}.com/" 
curl -s "https://{protocol}.gitbook.io/"
curl -s "https://docs.{protocol}.finance/"
curl -s "https://{protocol}.readme.io/"
curl -s "{protocol-url}/docs"
```

**3b. What to Search For in Documentation:**
- "contract" or "address" → Deployment addresses
- "API" → REST API endpoints  
- "subgraph" or "graph" → GraphQL endpoints
- "integration" or "SDK" → Developer tools
- "fee" or "rates" → Fee structure for APY calculation
- "architecture" → How the protocol works

**3c. Developer/Integration Resources:**
- Developer portals often at: `developers.{protocol}.com` or `{protocol}.com/developers`
- API documentation with endpoints and auth requirements
- Rate limits and usage guidelines

### Phase 4: Protocol GitHub Research

If `github` field exists from Phase 1:

```bash
# Get repo contents listing
curl -s "https://api.github.com/repos/{org}/{repo}/contents/" | jq '.[].name'

# Check README for addresses and architecture
curl -s "https://raw.githubusercontent.com/{org}/{repo}/main/README.md"
```

**4a. Look for deployment/address files:**
```bash
# Common locations for contract addresses
curl -s "https://raw.githubusercontent.com/{org}/{repo}/main/deployments.json"
curl -s "https://raw.githubusercontent.com/{org}/{repo}/main/addresses.json"
curl -s "https://api.github.com/repos/{org}/{repo}/contents/deployments" | jq '.[].name'
curl -s "https://api.github.com/repos/{org}/{repo}/contents/contracts" | jq '.[].name'
```

**4b. Look for subgraph:**
```bash
# Check for subgraph directory
curl -s "https://api.github.com/repos/{org}/{repo}/contents/subgraph" | jq '.[].name'
curl -s "https://raw.githubusercontent.com/{org}/{repo}/main/subgraph/subgraph.yaml"

# Or search for subgraph.yaml
curl -s "https://api.github.com/search/code?q=subgraph.yaml+repo:{org}/{repo}"
```

**4c. Look for SDK/API client:**
```bash
# Check package.json for hints
curl -s "https://raw.githubusercontent.com/{org}/{repo}/main/package.json" | jq '.dependencies'

# Look for SDK or API folders
curl -s "https://api.github.com/repos/{org}/{repo}/contents/sdk" | jq '.[].name'
curl -s "https://api.github.com/repos/{org}/{repo}/contents/api" | jq '.[].name'
```

### Phase 5: Subgraph Discovery

```bash
# Try common subgraph naming patterns on The Graph
curl -s "https://api.thegraph.com/subgraphs/name/{org}/{protocol}" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ _meta { block { number } } }"}'

# Try with chain suffix
curl -s "https://api.thegraph.com/subgraphs/name/{org}/{protocol}-{chain}" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ _meta { block { number } } }"}'

# Check Graph Explorer
# Use browser if needed: https://thegraph.com/explorer?search={protocol}
```

**If subgraph found, explore schema:**
```graphql
{
  __schema {
    types {
      name
      fields { name }
    }
  }
}
```

### Phase 6: Contract Verification (EVM Chains)

For each contract address found:

```bash
# Etherscan API (works for most EVM chains with different base URLs)
curl -s "https://api.etherscan.io/api?module=contract&action=getabi&address={address}"

# Get contract source to understand functions
curl -s "https://api.etherscan.io/api?module=contract&action=getsourcecode&address={address}"
```

**Explorer API endpoints:**
| Chain | API Base |
|-------|----------|
| Ethereum | api.etherscan.io |
| Polygon | api.polygonscan.com |
| Arbitrum | api.arbiscan.io |
| Optimism | api-optimistic.etherscan.io |
| BSC | api.bscscan.com |
| Avalanche | api.snowtrace.io |
| Base | api.basescan.org |

### Phase 7: Solana Account Data

For Solana protocols:

```bash
# Get account info
curl -s https://api.mainnet-beta.solana.com -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "getAccountInfo",
    "params": ["{address}", {"encoding": "jsonParsed"}]
  }'
```

**Check account owner to identify program type:**
- `TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA` → Token account
- `SPoo1Ku8WFXoNDMHPsrGSTSG1Y47rzgn41SLUNakuHy` → Stake Pool
- Custom → Protocol-specific program

### Phase 8: API Endpoint Discovery

If protocol has an API (found in docs or GitHub):

```bash
# Test common API patterns
curl -s "https://api.{protocol}.com/v1/pools"
curl -s "https://api.{protocol}.io/stats"
curl -s "https://{protocol}.com/api/yields"
curl -s "https://api.{protocol}.finance/apy"
```

### Phase 9: Price Data

```bash
# Get token prices for TVL calculation
curl -s "https://coins.llama.fi/prices/current/{chain}:{address},{chain}:{address2}"
```

### Phase 10: Reference Similar Adapters

Look at adapters in the same category for patterns:

```bash
# List adapters
ls src/adaptors/ | head -50

# Find similar by examining a known one in same category
cat src/adaptors/{similar-protocol}/index.js
```

## Output Format

After research, compile findings:

```markdown
## Research Results: {Protocol Name}

### Basic Info
- Slug: {slug}
- Category: {category}
- Chains: {chains}
- Website: {url}
- GitHub: {github}

### Data Source Recommendation
- Primary: {on-chain | subgraph | api}
- Reason: {why this source}
- Fallback: {alternative if primary fails}

### Contracts Found
| Chain | Name | Address | Verified | Source |
|-------|------|---------|----------|--------|
| | | | | (docs/github/explorer) |

### Subgraph
- Available: Yes/No
- Endpoint: {url}
- Status: {synced/behind/error}
- Key Entities: {pools, markets, vaults, etc.}

### API Endpoints
| Endpoint | Method | Purpose | Auth Required |
|----------|--------|---------|---------------|
| | | | |

### Key Functions (On-Chain)
| Contract | Function | Returns | Purpose |
|----------|----------|---------|---------|
| | | | |

### APY Calculation
- Method: {description}
- Formula: {formula}
- Data needed: {what to fetch}

### Fee Structure
- Protocol fee: {x%}
- Other fees: {details}

### Tokens
- Underlying: {symbols and addresses}
- Receipt/LP: {if applicable}
- Rewards: {if applicable}

### Reference Adapters
Similar adapters to use as template:
- src/adaptors/{name}/ - {why similar}

### Notes & Considerations
- {any issues, edge cases, or special considerations}
- {rate limits, auth requirements}
- {missing information that needs manual research}
```

## Research Checklist

Before completing research, ensure you have:
- [ ] Protocol category identified
- [ ] All supported chains listed
- [ ] At least one data source (on-chain/subgraph/API)
- [ ] Contract addresses for each chain
- [ ] Method to calculate APY
- [ ] Fee structure understood
- [ ] Token addresses (underlying, receipt, rewards)
- [ ] Similar adapter identified for reference

## Output Format

After research, compile findings:

```markdown
## Research Results: {Protocol Name}

### Basic Info
- Slug: {slug}
- Category: {category}
- Chains: {chains}
- Website: {url}

### Data Source Recommendation
Primary: {on-chain | subgraph | api}
Reason: {why this source}

### Contracts Found
| Chain | Name | Address | Verified |
|-------|------|---------|----------|

### Subgraph
- Available: Yes/No
- Endpoint: {url}
- Status: {synced/behind/error}

### API Endpoints
- {endpoint}: {description}

### Key Functions/Data Points
- {function}: {what it returns}

### APY Calculation
Method: {description}
Formula: {formula}

### Reference Adapters
Similar adapters to use as template:
- src/adaptors/{name}/ - {why similar}

### Notes
- {any issues or special considerations}
```

## Fallback: Browser Research

If HTTP research is insufficient (rare), invoke Claude in Chrome:

```
mcp__claude_in_chrome__navigate({url: "{protocol-docs-url}"})
```

Only use browser for:
- JavaScript-rendered documentation
- Complex interactive docs
- When HTTP endpoints return nothing useful