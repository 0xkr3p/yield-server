#!/bin/bash
# Verification hook for adapter test output
# Runs after adapter tests to check for common issues
# Works when running from root or src/adaptors directory

# Determine the repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Get adapter name from the test command or argument
ADAPTER="${1:-}"

# Try to find the test output directory (works from root or src/adaptors)
# When running from root: output goes to ./.test-adapter-output/
# When running from src/adaptors: output goes to ./.test-adapter-output/
if [ -d "$REPO_ROOT/.test-adapter-output" ]; then
  OUTPUT_DIR="$REPO_ROOT/.test-adapter-output"
elif [ -d "$REPO_ROOT/src/adaptors/.test-adapter-output" ]; then
  OUTPUT_DIR="$REPO_ROOT/src/adaptors/.test-adapter-output"
elif [ -d ".test-adapter-output" ]; then
  OUTPUT_DIR=".test-adapter-output"
else
  echo "SKIP: No test output directory found"
  exit 0
fi

# If no adapter specified, try to find most recently modified output file
if [ -z "$ADAPTER" ]; then
  ADAPTER=$(ls -t "$OUTPUT_DIR"/*.json 2>/dev/null | head -1 | xargs -I {} basename {} .json)
fi

if [ -z "$ADAPTER" ]; then
  echo "SKIP: No adapter specified and no recent output found"
  exit 0
fi

OUTPUT_FILE="$OUTPUT_DIR/${ADAPTER}.json"

# Check if output file exists
if [ ! -f "$OUTPUT_FILE" ]; then
  echo "ERROR: No output file found at $OUTPUT_FILE"
  exit 1
fi

# Skip if file is older than 60 seconds (not from current test run)
if [ "$(uname)" = "Darwin" ]; then
  FILE_AGE=$(( $(date +%s) - $(stat -f %m "$OUTPUT_FILE") ))
else
  FILE_AGE=$(( $(date +%s) - $(stat -c %Y "$OUTPUT_FILE") ))
fi

# Skip if file is older than 5 minutes (not from recent test run)
if [ "$FILE_AGE" -gt 300 ]; then
  exit 0
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

# Check for apyBase = 0 without valid alternatives (potential bug)
# Valid cases: apyReward > 0, apyBaseBorrow > 0, or apy field exists
ZERO_APY_BUG_COUNT=$(jq '[.[] | select(
  (.apyBase == 0 or .apyBase == null) and
  (.apyReward == 0 or .apyReward == null) and
  (.apy == 0 or .apy == null) and
  (.apyBaseBorrow == 0 or .apyBaseBorrow == null) and
  (.tvlUsd > 1000)
)] | length' "$OUTPUT_FILE" 2>/dev/null)
if [ "$ZERO_APY_BUG_COUNT" -gt 0 ]; then
  echo "WARNING: $ZERO_APY_BUG_COUNT pools have APY = 0 with TVL > \$1000 (likely bug)"
  echo "  Pools with zero APY:"
  jq -r '[.[] | select(
    (.apyBase == 0 or .apyBase == null) and
    (.apyReward == 0 or .apyReward == null) and
    (.apy == 0 or .apy == null) and
    (.tvlUsd > 1000)
  )] | .[0:3] | .[] | "    - \(.symbol): TVL $\(.tvlUsd | floor)"' "$OUTPUT_FILE" 2>/dev/null
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
