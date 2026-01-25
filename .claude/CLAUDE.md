# Yield Server - Claude Code Instructions

## Overview

This repository contains yield adapters for DefiLlama. Each adapter fetches APY and TVL data from DeFi protocols.

## Creating Yield Adapters

When asked to create a yield adapter, follow the skill at `.claude/skills/build-yield-adapter.md`.

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
| `.claude/skills/build-yield-adapter.md` | Full adapter creation workflow |
| `.claude/skills/fix-yield-adapter.md` | Debug and fix broken adapters |
| `.claude/skills/research-protocol.md` | Generic protocol research |
| `.claude/skills/research-liquid-staking.md` | Liquid staking specifics |
| `.claude/skills/research-lending.md` | Lending protocol specifics |
| `.claude/skills/research-dex.md` | DEX/AMM specifics |

## Common Patterns

See existing adapters for reference:
- **Liquid Staking**: `src/adaptors/lido/`, `src/adaptors/marinade/`
- **Lending**: `src/adaptors/aave-v3/`, `src/adaptors/compound-v3/`
- **DEX**: `src/adaptors/uniswap-v3/`, `src/adaptors/curve/`
- **Yield**: `src/adaptors/yearn-finance/`, `src/adaptors/beefy/`