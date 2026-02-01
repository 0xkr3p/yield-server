# Yield Adapter Development Usage Guide

This guide covers how to use the agents, skills, and workflows for yield adapter development.

## Quick Start

### Create a New Adapter

```bash
# 1. Research the protocol
claude "Research protocol {protocol-slug} for yield adapter"

# 2. Build the adapter
claude "Create yield adapter for {protocol-slug}"

# 3. Test it
cd src/adaptors && npm run test --adapter={protocol-name}

# 4. Validate against UI
claude "Validate adapter {protocol-name} against protocol UI"
```

### Fix a Broken Adapter

```bash
# 1. Run the fixer
claude "Fix yield adapter for {protocol-name}"

# 2. Test the fix
cd src/adaptors && npm run test --adapter={protocol-name}

# 3. Validate
claude "Validate adapter {protocol-name} against protocol UI"
```

---

## Workflow Chains

### New Adapter Pipeline

```
research-protocol → build-adapter → test-adapter → validate-adapter
                                                   ↓
                                          (fix-adapter if fails)
```

**When to use**: Creating adapters for protocols not yet covered.

### Fix Existing Adapter

```
fix-adapter → test-adapter → validate-adapter
     ↓
(if deprecated: report and recommend removal)
(if needs refactor: research-protocol → build-adapter)
```

**When to use**: Adapter tests are failing or data is incorrect.

### Discovery Pipeline

```
discover-adapters → user selects → research-protocol (parallel)
```

**When to use**: Looking for high-value protocols to add.

---

## Agents Reference

| Agent | Model | Command | Use When |
|-------|-------|---------|----------|
| `research-protocol` | sonnet | `claude "Research protocol {slug}"` | Before building, need protocol details |
| `build-adapter` | opus | `claude "Create adapter for {slug}"` | Ready to build from research |
| `fix-adapter` | sonnet | `claude "Fix adapter {name}"` | Tests failing or data wrong |
| `test-adapter` | haiku | `npm run test --adapter={name}` | After any code change |
| `validate-adapter` | sonnet | `claude "Validate adapter {name}"` | After tests pass (uses Playwright) |
| `compare-adapters` | haiku | `claude "Compare {a} and {b}"` | Debugging or learning |
| `discover-adapters` | haiku | `claude "Discover missing adapters"` | Finding new work |

### Model Selection Rationale

- **haiku**: Fast, cheap tasks (testing, discovery, comparison)
- **sonnet**: Reasoning-heavy tasks (research, debugging, validation)
- **opus**: Complex code generation (building new adapters)

---

## Skills Reference

### Research Skills

| Skill | Command | Specialization |
|-------|---------|----------------|
| `research-protocol` | `claude "Research protocol {slug}"` | Generic, routes by category |
| `research-lending` | `claude "Research lending protocol {slug}"` | Aave/Compound patterns |
| `research-liquid-staking` | `claude "Research LST {slug}"` | Exchange rates, rebasing |
| `research-dex` | `claude "Research DEX {slug}"` | Subgraph queries, fee calculation |

### Action Skills

| Skill | Command | Purpose |
|-------|---------|---------|
| `build-yield-adapter` | `claude "Create adapter for {slug}"` | Full adapter creation |
| `fix-yield-adapter` | `claude "Fix adapter {name}"` | Diagnose and repair |
| `investigating-broken-data-sources` | `claude "Investigate data source for {name}"` | API/subgraph debugging |

---

## Independent Skill Usage

Skills can be used independently for specific tasks:

### Research Only (No Building)

```bash
# Get protocol architecture details
claude "Research lending protocol morpho-blue, output research only"

# Find data sources for a protocol
claude "Research subgraph and API options for uniswap-v3"

# Understand APY calculation
claude "Research how to calculate APY for liquid staking protocol jito"
```

### Targeted Fixing

```bash
# Fix specific data source issue
claude "The subgraph for {protocol} is deprecated, migrate to decentralized"

# Fix calculation issue
claude "APY values for {protocol} are 100x too high, fix the calculation"

# Fix validation error
claude "Fix rewardTokens validation error for {protocol}"
```

### Analysis Tasks

```bash
# Compare approaches
claude "Compare how aave-v3 and compound-v3 calculate supply APY"

# Understand existing adapter
claude "Explain how the curve adapter handles gauge rewards"

# Find reference implementation
claude "Find a reference adapter for Balancer-style weighted pools"
```

---

## Common Scenarios

### Scenario 1: Protocol Has Active TVL Adapter

```bash
# Research will find contracts from TVL adapter
claude "Research protocol {slug} for yield adapter"
# → Finds contract addresses from DefiLlama-Adapters
# → Identifies data source (likely on-chain)
# → Suggests reference adapter

claude "Create yield adapter for {slug}"
```

### Scenario 2: Protocol Has Subgraph

```bash
# Research will discover subgraph
claude "Research DEX protocol {slug}"
# → Finds subgraph endpoint
# → Provides query templates
# → Shows fee tier handling

claude "Create yield adapter for {slug} using subgraph"
```

### Scenario 3: Protocol Has Only API

```bash
# Research identifies API as only option
claude "Research protocol {slug}"
# → Notes API dependency
# → Warns about reliability concerns
# → Suggests on-chain fallback if possible

claude "Create yield adapter for {slug}, prioritize on-chain data"
```

### Scenario 4: Adapter Stopped Working

```bash
# Run fixer to diagnose
claude "Fix yield adapter for {name}"
# → Runs test to identify error
# → Checks for deprecation
# → Attempts fix
# → Re-tests

# If deprecated
# → Reports deprecation status
# → Recommends removal or alternative
```

### Scenario 5: Data Doesn't Match UI

```bash
# Validate identifies mismatch
claude "Validate adapter {name} against protocol UI"
# → Compares TVL (should be within 10%)
# → Compares APY (should be within 0.5%)
# → Reports discrepancies

# Fix identified issues
claude "Fix adapter {name}, TVL is 50% too low"
```

---

## Feedback Loop

### Quick Log Entry

After any significant work, log the outcome:

```
Log: {agent/skill} | {protocol} | {success/partial/failed} | {learning}
```

Examples:
```
Log: build-adapter | morpho-blue | success | isolated markets need separate pool IDs
Log: fix-adapter | curve | partial | gauge rewards still not working on arbitrum
Log: research-protocol | pendle | failed | couldn't find PT/YT split documentation
```

### Weekly Review

```bash
claude "Run weekly feedback review"
```

Reviews:
- Failed/partial executions
- Common error patterns
- Skill improvement opportunities

---

## Testing Commands

```bash
# Run adapter test
cd src/adaptors && npm run test --adapter={name}

# View test output
cat src/adaptors/.test-adapter-output/{name}.json | jq '.'

# Check pool count
cat src/adaptors/.test-adapter-output/{name}.json | jq 'length'

# Check total TVL
cat src/adaptors/.test-adapter-output/{name}.json | jq '[.[].tvlUsd] | add'

# Find suspicious pools
cat src/adaptors/.test-adapter-output/{name}.json | jq '.[] | select(.apyBase > 100)'

# Check chains covered
cat src/adaptors/.test-adapter-output/{name}.json | jq '[.[].chain] | unique'
```

---

## Data Source Priority

When building or fixing adapters, prefer data sources in this order:

1. **On-chain** (most reliable)
   - Contract calls via `sdk.api.abi`
   - Direct exchange rate queries
   - Pool state from contracts

2. **Subgraph** (good for aggregated data)
   - Historical volumes and fees
   - Pool listings and metadata
   - Token relationships

3. **API** (last resort)
   - May become unavailable
   - May have rate limits
   - Data freshness varies

---

## Troubleshooting

### Tests Return Empty Array

1. Check if protocol has active pools
2. Verify contract addresses are correct
3. Check for API/subgraph outage
4. Verify chain is supported

### APY Values Seem Wrong

1. Check blocks-per-year constant for chain
2. Verify RAY format conversion (Aave: divide by 1e27)
3. Check percentage vs decimal confusion
4. Compare with protocol UI

### Validation Fails

1. Check TVL calculation (include all pool types)
2. Verify reward tokens are included
3. Check for stale subgraph data
4. Compare symbols with UI

### Hook Errors

1. Check `.claude/hooks/verify-adapter-output.sh` exists
2. Verify file is executable (`chmod +x`)
3. Check jq is installed
4. Review hook output for specific errors

---

## MCP Integration (Optional)

If MCP servers are configured (`.claude/mcp.json`):

### Playwright MCP (Recommended)
```bash
# Install: claude mcp add playwright -- npx @playwright/mcp@latest

# Used by validate-adapter agent to:
# - Navigate to protocol UIs
# - Render JavaScript content
# - Extract TVL/APY values from live pages
# - Take screenshots for verification
```

The validate-adapter agent uses Playwright to compare adapter output against actual protocol UI values. This handles JavaScript-rendered pages that WebFetch cannot access.

### Subgraph MCP
```bash
# Query any indexed subgraph
# Automatic schema discovery
# Natural language queries
```

### Etherscan MCP
```bash
# Fetch contract ABI (replaces curl to etherscan)
# Automatic when researching EVM protocols
```

### GitHub MCP
```bash
# Fetch TVL adapter code
# Search for reference implementations
```

See `.claude/mcp.json` for configuration details.

---

## Quick Reference Cheat Sheet

### Agents
```bash
claude "Research protocol {slug}"              # Gather protocol details
claude "Create yield adapter for {slug}"       # Build new adapter
claude "Fix yield adapter for {name}"          # Debug broken adapter
claude "Validate adapter {name}"               # Compare to UI (Playwright)
claude "Compare adapters {a} and {b}"          # Diff two adapters
claude "Discover missing adapters"             # Find protocols to add
```

### Testing
```bash
npm run test --adapter={name}                  # Run adapter test
cat .test-adapter-output/{name}.json | jq '.'  # View output
```

### Feedback
```bash
.claude/hooks/log-learning.sh "{protocol}" "{agent}" "{status}" "{learning}" "{tags}"
claude "Run weekly feedback review"            # Review patterns
```

### Hooks (auto-run via Claude)
```bash
.claude/hooks/capture-feedback.sh              # Capture test metrics
.claude/hooks/verify-adapter-output.sh         # Validate output
```

### MCP Setup
```bash
claude mcp add playwright -- npx @playwright/mcp@latest
# Set env: GRAPH_API_KEY, ETHERSCAN_API_KEY
```
