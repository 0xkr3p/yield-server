---
name: fixing-yield-adapters
description: Debugs and repairs broken yield adapters. Use when the user asks to fix, debug, or repair a yield adapter, or when an adapter is failing tests.
---

# Fix Yield Adapter

## Quick Reference Files

- [Error Reference](./error-reference.md) - Error → Fix mappings
- [Data Source Fixes](./data-source-fixes.md) - API/subgraph migration patterns
- [Validation Guide](./validation-guide.md) - UI comparison procedures

## Progress Checklist

```
Fix Progress:
- [ ] Step 1: Run tests to identify the problem
- [ ] Step 2: Check if protocol is deprecated
- [ ] Step 3: Read the adapter code
- [ ] Step 4: Diagnose and fix by error type
- [ ] Step 5: Test iteratively
- [ ] Step 6: Validate against protocol UI
- [ ] Step 7: Decide patch vs refactor
```

## CRITICAL: Pool ID Preservation

**NEVER modify the `pool` field value when fixing an existing adapter.**

The `pool` field is the unique identifier in the database. Changing it will:
- Create a new database entry
- Lose ALL historical data for that pool
- Require manual database merging to recover

**Before ANY fix:**
1. Note the EXACT current pool ID format from the existing code
2. Preserve that format exactly, even if it doesn't match current conventions
3. Add a comment explaining why the format is preserved if it differs from standard

## Workflow

### Step 1: Run Tests

```bash
cd src/adaptors && npm run test --adapter={protocol-name}
```

Check output:
```bash
cat src/adaptors/.test-adapter-output/{protocol-name}.json
```

**Common failure modes:**
- Empty array returned (no pools)
- Test failures (validation errors)
- Runtime exceptions (API/RPC errors)
- Timeout (hanging requests)

### Step 2: Check if Protocol is Deprecated

**CRITICAL**: Before debugging, verify the protocol hasn't shut down.

```bash
# Get protocol info
curl -s "https://api.llama.fi/protocol/{slug}" | jq '{
  name: .name,
  url: .url,
  twitter: .twitter,
  currentTvl: .currentChainTvls
}'

# Check website status
curl -sI "{protocol-url}" | head -5

# Check for deprecation indicators
curl -s "{protocol-url}" | grep -i -E "deprecat|sunset|migrat|shutdown|discontinue"
```

**Signs of deprecation:**
- TVL dropped to $0 or near-zero
- Website shows deprecation banner
- Twitter announces shutdown
- Domain expired or redirects

**If deprecated:** Report findings and recommend removal rather than fixing.

### Step 3: Read the Adapter Code

```bash
cat src/adaptors/{protocol-name}/index.js
```

**Understand:**
- Data source (API, subgraph, on-chain)
- How pools are constructed
- APY calculation method
- Which chains are supported

### Step 4: Diagnose and Fix

See [error-reference.md](./error-reference.md) for detailed error → fix mappings.

**Quick diagnosis:**

| Error | Check |
|-------|-------|
| Empty array | Test data source directly |
| Validation error | Check field format |
| NaN/Infinity | Check division operations |
| Timeout | Add retry logic |

**Test data sources:**
```bash
# Test API
curl -s "{api-endpoint}" | head -100

# Test subgraph
curl -s "{subgraph-url}" -H "Content-Type: application/json" \
  -d '{"query": "{ _meta { block { number } } }"}'

# Check contract
curl -s "https://api.etherscan.io/api?module=contract&action=getabi&address={address}"
```

If data source is broken, see [data-source-fixes.md](./data-source-fixes.md).

### Step 5: Test Iteratively

```bash
cd src/adaptors && npm run test --adapter={protocol-name}
```

Add debug logging if needed:
```javascript
console.log('Raw data:', JSON.stringify(data, null, 2).slice(0, 500));
console.log('Pools before filter:', pools.length);
```

### Step 6: Validate Against Protocol UI

**CRITICAL: Passing tests does not mean the fix is correct.**

See [validation-guide.md](./validation-guide.md) for detailed validation procedures.

**Quick validation:**
```bash
# Compare TVL
ADAPTER_TVL=$(cat src/adaptors/.test-adapter-output/{protocol}.json | jq '[.[].tvlUsd] | add')
PROTOCOL_TVL=$(curl -s "https://api.llama.fi/protocol/{slug}" | jq '.currentChainTvls | add')
echo "Adapter: $ADAPTER_TVL, Protocol: $PROTOCOL_TVL"
```

**Acceptable variance:**
- TVL: ±10%
- APY: ±0.5% (base), ±1% (rewards)

### Step 7: Decide Patch vs Refactor

**Patch when:**
- Single endpoint/address change
- Minor data format change
- Adding missing field

**Refactor when:**
- Data source completely changed (API → subgraph)
- Protocol architecture changed significantly
- Multiple fundamental issues
- Code is unmaintainable

**Refactor approach:**
1. Find working adapter in same category as reference
2. Research protocol using research skill
3. Rewrite using research output
4. Test thoroughly

## After Fixing

1. Run tests to confirm fix
2. Validate output matches protocol UI
3. Remove any debug logging
4. Report summary of changes made

## Use validate-adapter Agent

After fixing, run the validate-adapter agent to ensure accuracy:

```
@validate-adapter {protocol-name}
```

This performs comprehensive validation against the protocol UI.
