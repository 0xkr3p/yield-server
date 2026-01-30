#!/bin/bash
# Verification hook for adapter test output
# Runs after adapter tests to check for common issues

# Get adapter name from the test command or argument
ADAPTER="${1:-}"

# If no adapter specified, try to extract from recent test output
if [ -z "$ADAPTER" ]; then
  # Find most recently modified output file
  ADAPTER=$(ls -t src/adaptors/.test-adapter-output/*.json 2>/dev/null | head -1 | xargs -I {} basename {} .json)
fi

if [ -z "$ADAPTER" ]; then
  echo "SKIP: No adapter specified and no recent output found"
  exit 0
fi

OUTPUT_FILE="src/adaptors/.test-adapter-output/${ADAPTER}.json"

# Check if output file exists
if [ ! -f "$OUTPUT_FILE" ]; then
  echo "ERROR: No output file found at $OUTPUT_FILE"
  exit 1
fi

echo "Verifying adapter: $ADAPTER"
echo "---"

# Check for empty array
POOL_COUNT=$(jq 'length' "$OUTPUT_FILE" 2>/dev/null)
if [ "$POOL_COUNT" = "null" ] || [ -z "$POOL_COUNT" ]; then
  echo "ERROR: Invalid JSON in output file"
  exit 1
fi

if [ "$POOL_COUNT" -eq 0 ]; then
  echo "WARNING: Adapter returned 0 pools"
  exit 1
fi

echo "Pool count: $POOL_COUNT"

# Check total TVL
TOTAL_TVL=$(jq '[.[].tvlUsd // 0] | add' "$OUTPUT_FILE" 2>/dev/null)
if [ "$TOTAL_TVL" = "null" ] || [ -z "$TOTAL_TVL" ]; then
  TOTAL_TVL=0
fi
echo "Total TVL: \$$(printf "%.2f" "$TOTAL_TVL")"

# Check for suspicious APY values (> 1000%)
HIGH_APY_COUNT=$(jq '[.[] | select((.apyBase // 0) > 1000 or (.apyReward // 0) > 1000)] | length' "$OUTPUT_FILE" 2>/dev/null)
if [ "$HIGH_APY_COUNT" -gt 0 ]; then
  echo "WARNING: $HIGH_APY_COUNT pools have APY > 1000%"
  jq '.[] | select((.apyBase // 0) > 1000 or (.apyReward // 0) > 1000) | {symbol, apyBase, apyReward}' "$OUTPUT_FILE"
fi

# Check for pools with zero TVL
ZERO_TVL_COUNT=$(jq '[.[] | select(.tvlUsd == 0 or .tvlUsd == null)] | length' "$OUTPUT_FILE" 2>/dev/null)
if [ "$ZERO_TVL_COUNT" -gt 0 ]; then
  echo "WARNING: $ZERO_TVL_COUNT pools have zero/null TVL"
fi

# Check for negative APY
NEG_APY_COUNT=$(jq '[.[] | select((.apyBase // 0) < 0 or (.apyReward // 0) < 0)] | length' "$OUTPUT_FILE" 2>/dev/null)
if [ "$NEG_APY_COUNT" -gt 0 ]; then
  echo "WARNING: $NEG_APY_COUNT pools have negative APY"
fi

# Check for missing rewardTokens when apyReward > 0
MISSING_REWARD_TOKENS=$(jq '[.[] | select((.apyReward // 0) > 0 and ((.rewardTokens | length) == 0 or .rewardTokens == null))] | length' "$OUTPUT_FILE" 2>/dev/null)
if [ "$MISSING_REWARD_TOKENS" -gt 0 ]; then
  echo "ERROR: $MISSING_REWARD_TOKENS pools have apyReward but no rewardTokens"
  exit 1
fi

# Check for NaN or Infinity values (they become null in JSON)
NAN_CHECK=$(jq '[.[] | select(.tvlUsd == null or .apyBase == null)] | length' "$OUTPUT_FILE" 2>/dev/null)
if [ "$NAN_CHECK" -gt 5 ]; then
  echo "WARNING: $NAN_CHECK pools have null values (possible NaN/Infinity)"
fi

# Summary
echo "---"
if [ "$HIGH_APY_COUNT" -gt 0 ] || [ "$ZERO_TVL_COUNT" -gt 5 ] || [ "$NEG_APY_COUNT" -gt 0 ]; then
  echo "REVIEW: Some issues found - please verify values match protocol UI"
else
  echo "PASS: Basic validation passed ($POOL_COUNT pools, \$$(printf "%.0f" "$TOTAL_TVL") TVL)"
fi
