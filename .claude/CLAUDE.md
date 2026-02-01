# Yield Server - Claude Code Instructions

## Overview

This repository contains yield adapters for DefiLlama. Each adapter fetches APY and TVL data from DeFi protocols.

## Creating Yield Adapters

When asked to create a yield adapter, follow the skill at `.claude/skills/build-yield-adapter/SKILL.md`.

## Fixing Yield Adapters
When asked to fix a yield adapter, follow the skill at `.claude/skills/fix-yield-adapter/SKILL.md`

### Quick Command Reference

```bash
# Research a protocol
claude "Research protocol {name} for yield adapter"

# Build an adapter
claude "Create yield adapter for {protocol-slug}"

# Fix a broken adapter
claude "Fix yield adapter for {protocol-name}"

# Test an adapter
cd src/adaptors && npm run test --adapter={protocol-name}
```

## Key Principles

### Data Source Priority
1. **On-chain** (contract calls via RPC) - most reliable
2. **Subgraph** (The Graph) - good for historical/aggregated data
3. **API** - last resort, may be less reliable

### Research Without Browser
Most research can be done via direct HTTP requests:

| Data | Source |
|------|--------|
| Protocol info | `https://api.llama.fi/protocol/{slug}` |
| TVL adapter code | `https://raw.githubusercontent.com/DefiLlama/DefiLlama-Adapters/main/projects/{name}/index.js` |
| Subgraph discovery | `https://api.thegraph.com/subgraphs/name/{org}/{name}` |
| Token prices | `https://coins.llama.fi/prices/current/{chain}:{address}` |
| EVM contract ABI | `https://api.etherscan.io/api?module=contract&action=getabi&address={addr}` |
| Solana account | Solana RPC `getAccountInfo` |

### When to Use Browser (Claude in Chrome)
Only invoke browser automation when:
- Documentation requires JavaScript rendering
- Need to inspect network requests on a live site
- Login-protected resources
- Complex multi-step navigation

## Project Structure

```
src/adaptors/
├── {protocol-name}/
│   ├── index.js          # Main adapter (required)
│   ├── abi.js            # Contract ABIs (if needed)
│   └── config.js         # Multi-chain config (if needed)
├── utils.js              # Shared utilities
└── test.js               # Test runner
```

## Adapter Requirements

### Required Fields
- `pool`: Unique ID `${address}-${chain}`.toLowerCase()
- `chain`: Use `utils.formatChain()`
- `project`: Must match folder name
- `symbol`: Use `utils.formatSymbol()`
- `tvlUsd`: Total Value Locked in USD

### APY Fields (at least one required)
- `apyBase`: Base APY from fees/interest
- `apyReward`: Reward APY (requires `rewardTokens`)
- `apy`: Total APY (only if breakdown unknown)

### Module Exports
```javascript
module.exports = {
  timetravel: false,
  apy: main,
  url: 'https://...' // optional
};
```

## Testing

```bash
cd src/adaptors
npm run test --adapter={protocol-name}
```

Output saved to `.test-adapter-output/{protocol-name}.json`

## Skills Reference

| Skill | Purpose |
|-------|---------|
| `building-yield-adapters` | Full adapter creation workflow |
| `fixing-yield-adapters` | Debug and fix broken adapters |
| `investigating-broken-data-sources` | Fix broken APIs, subgraphs, contracts |
| `researching-protocols` | Generic protocol research |
| `researching-liquid-staking` | Liquid staking specifics |
| `researching-lending-protocols` | Lending protocol specifics |
| `researching-dex-protocols` | DEX/AMM specifics |

## Skill Improvement

Log skill outcomes to `.claude/skills/SKILL-LOG.md` for weekly review:

```
# Quick log entry
"Log: building-yield-adapters | silo-v2 | success | learned: need to handle isolated markets differently"
```

Weekly, review the log with Claude to identify patterns and improve skills.

## Common Patterns

See existing adapters for reference:
- **Liquid Staking**: `src/adaptors/lido/`, `src/adaptors/marinade/`
- **Lending**: `src/adaptors/aave-v3/`, `src/adaptors/compound-v3/`
- **DEX**: `src/adaptors/uniswap-v3/`, `src/adaptors/curve/`
- **Yield**: `src/adaptors/yearn-finance/`, `src/adaptors/beefy/`

## Subagents

Custom subagents are available for specialized yield adapter workflows. These should be used proactively when the task matches their purpose.

### Available Subagents

| Subagent | Model | Purpose | When to Use |
|----------|-------|---------|-------------|
| `research-protocol` | sonnet | Gather technical details for adapter development | Before building new adapters, investigating unfamiliar protocols |
| `build-adapter` | opus | Create complete yield adapters from research | After research is complete, creating new adapters from scratch |
| `fix-adapter` | sonnet | Diagnose and repair broken adapters | When adapters fail tests or return incorrect data |
| `test-adapter` | haiku | Execute tests and generate quality reports | After building or fixing to verify correctness |
| `validate-adapter` | sonnet | Validate adapter output against protocol UI | **After any build/fix** to ensure data accuracy |
| `compare-adapters` | haiku | Compare two adapter outputs | When debugging or migrating adapters |
| `discover-adapters` | haiku | Find protocols missing yield adapters | When looking for new protocols to add coverage |

### Subagent Locations

All subagent definitions are in `.claude/agents/`:
- `.claude/agents/research-protocol.md`
- `.claude/agents/build-adapter.md`
- `.claude/agents/fix-adapter.md`
- `.claude/agents/test-adapter.md`
- `.claude/agents/validate-adapter.md` (NEW)
- `.claude/agents/compare-adapters.md` (NEW)
- `.claude/agents/discover-adapters.md`

### Workflow Chains

**New Adapter Pipeline:**
```
research-protocol → build-adapter → test-adapter → validate-adapter
                                                   ↓
                                            (fix-adapter if validation fails)
```

**Fix Existing Adapter:**
```
fix-adapter → test-adapter → validate-adapter
           ↓
    (if deprecated: report and recommend removal)
    (if needs refactor: research-protocol → build-adapter)
```

**Discovery Pipeline:**
```
discover-adapters → user selects protocols → research-protocol (parallel)
```

**IMPORTANT:** Always run `validate-adapter` after `test-adapter` - passing tests only verify format, not data accuracy.

### Cost Optimization

- **haiku**: Fast/cheap tasks (testing, discovery)
- **sonnet**: Reasoning tasks (research, debugging)
- **opus**: Critical code generation (building adapters)

## Feedback System

A structured feedback system captures outcomes from agent and skill executions to enable continuous improvement.

### Feedback Directory Structure

```
.claude/feedback/
├── schema.md                    # Feedback entry format
├── entries/                     # JSON feedback per execution
├── patterns/                    # Known patterns library
│   ├── error-patterns.md        # Common errors → fixes
│   └── data-source-patterns.md  # Migration patterns
├── weekly/                      # Weekly summaries
└── REVIEW-WORKFLOW.md           # Review process
```

### Quick Feedback Logging

After any significant work, log the outcome:

```
Log: {agent/skill} | {protocol} | {success/partial/failed} | {learning}
```

Example:
```
Log: build-adapter | morpho-blue | success | isolated markets need separate pool IDs
```

### Automated Feedback Capture

Feedback is automatically captured via hooks after:
- Adapter tests (pool count, TVL, APY metrics)
- Validation runs (variance data)

Feedback entries are saved to `.claude/feedback/entries/YYYY-MM-DD-{protocol}.json`

### Weekly Review

Run weekly to identify patterns and improve skills:

```bash
claude "Run weekly feedback review"
```

See `.claude/feedback/REVIEW-WORKFLOW.md` for the full process.

### Pattern Library

Before debugging, check known patterns:
- `.claude/feedback/patterns/error-patterns.md` - Common errors with fixes
- `.claude/feedback/patterns/data-source-patterns.md` - Migration patterns

## MCP Integration (Optional)

MCP (Model Context Protocol) servers can enhance data fetching accuracy. Configuration is in `.claude/mcp.json`.

### Available MCP Servers

| Server | Purpose | Priority |
|--------|---------|----------|
| `etherscan` | Fetch contract ABIs, verify contracts | High |
| `subgraph` | Query 15,000+ subgraphs with schema inspection | High |
| `github` | Access TVL adapters and reference code | Medium |
| `evm` | Multi-chain EVM interactions (30+ chains) | Medium |
| `solana` | Solana blockchain and SPL token queries | Low |

### Setup

1. Copy `.claude/mcp.json` to your Claude Code MCP configuration
2. Set required environment variables:
   - `ETHERSCAN_API_KEY` - Get from https://etherscan.io/apis
   - `GRAPH_API_KEY` - Get from https://thegraph.com/studio/apikeys/
   - `GITHUB_TOKEN` - Generate at https://github.com/settings/tokens

### Benefits

- **Etherscan MCP**: Replaces manual `curl` for ABI fetching
- **Subgraph MCP**: Automatic schema discovery, better error handling
- **GitHub MCP**: Structured access to TVL adapters

## Usage Guide

For comprehensive usage examples and scenarios, see `.claude/USAGE-GUIDE.md`.