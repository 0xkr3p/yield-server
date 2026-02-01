# Feedback Entry Schema

This document defines the structured format for capturing feedback from agent and skill executions.

## Entry Format

Each feedback entry is a JSON file stored in `.claude/feedback/entries/` with the naming convention:
`YYYY-MM-DD-{protocol}.json`

## Schema Definition

```json
{
  "id": "string - unique identifier (date-protocol)",
  "timestamp": "string - ISO 8601 datetime",
  "agent_or_skill": "string - name of agent or skill used",
  "protocol": "string - protocol slug",
  "chains": ["array of chain names"],
  "category": "string - protocol category (lending, dex, liquid-staking, etc.)",
  "status": "string - success | partial | failed | abandoned",

  "metrics": {
    "test_passed": "boolean",
    "validation_passed": "boolean",
    "pool_count": "number",
    "tvl_total": "number - USD value",
    "tvl_variance_pct": "number - variance from DefiLlama",
    "apy_min": "number",
    "apy_max": "number",
    "apy_avg": "number"
  },

  "error": {
    "type": "string - validation | data_source | timeout | deprecation | runtime | null",
    "message": "string - error message if applicable",
    "stack": "string - stack trace if applicable"
  },

  "context": {
    "data_source_type": "string - on-chain | subgraph | api | mixed",
    "reference_adapter": "string - adapter used as template",
    "iteration_count": "number - fix attempts",
    "duration_ms": "number - execution time"
  },

  "learnings": {
    "root_cause": "string - what caused the issue (if failed)",
    "fix_applied": "string - what was done to resolve",
    "should_update_skill": "boolean",
    "skill_update_suggestion": "string - proposed change to skill",
    "pattern_tags": ["array of pattern identifiers"]
  }
}
```

## Required Fields

At minimum, every entry must have:
- `id`
- `timestamp`
- `agent_or_skill`
- `protocol`
- `status`

## Example Entry

```json
{
  "id": "2026-02-01-aave-v3",
  "timestamp": "2026-02-01T14:30:00Z",
  "agent_or_skill": "build-adapter",
  "protocol": "aave-v3",
  "chains": ["ethereum", "polygon", "arbitrum", "optimism", "base"],
  "category": "lending",
  "status": "success",

  "metrics": {
    "test_passed": true,
    "validation_passed": true,
    "pool_count": 156,
    "tvl_total": 12500000000,
    "tvl_variance_pct": 2.1,
    "apy_min": 0.5,
    "apy_max": 45.2,
    "apy_avg": 8.3
  },

  "error": null,

  "context": {
    "data_source_type": "on-chain",
    "reference_adapter": "aave-v2",
    "iteration_count": 1,
    "duration_ms": 45000
  },

  "learnings": {
    "root_cause": null,
    "fix_applied": null,
    "should_update_skill": false,
    "skill_update_suggestion": null,
    "pattern_tags": ["lending", "multi-chain", "aave-fork"]
  }
}
```

## Pattern Tags Reference

Use consistent tags for categorization:

### Error Categories
- `validation-error` - Test validation failures
- `data-source-error` - API/subgraph/RPC failures
- `timeout-error` - Request timeouts
- `deprecation` - Protocol deprecated

### Fix Categories
- `endpoint-update` - Changed API/subgraph URL
- `decimal-fix` - Fixed decimal handling
- `formula-fix` - Fixed APY calculation
- `contract-update` - Updated contract addresses
- `migration` - Migrated data source type

### Protocol Categories
- `lending`, `dex`, `liquid-staking`, `yield`, `cdp`
- `aave-fork`, `compound-fork`, `uniswap-fork`, `curve-fork`
- `multi-chain`, `single-chain`

## Quick Log Format

For rapid manual logging, use this shorthand:

```
Log: {agent/skill} | {protocol} | {status} | {learning}
```

Example:
```
Log: fix-adapter | silo-v2 | success | learned: isolated markets need separate pool IDs
```

These can be expanded to full entries during weekly review.
