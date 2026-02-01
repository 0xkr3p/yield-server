#!/bin/bash
# Feedback capture hook for adapter tests
# Captures metrics from test output and saves/updates feedback entries
# Works when running from root or src/adaptors directory

# Determine the repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Get adapter name from argument or find most recent
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
  # No output directory found
  exit 0
fi

# Find adapter name if not provided
if [ -z "$ADAPTER" ]; then
  ADAPTER=$(ls -t "$OUTPUT_DIR"/*.json 2>/dev/null | head -1 | xargs -I {} basename {} .json)
fi

if [ -z "$ADAPTER" ]; then
  exit 0
fi

OUTPUT_FILE="$OUTPUT_DIR/${ADAPTER}.json"
FEEDBACK_DIR="$REPO_ROOT/.claude/feedback/entries"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
FEEDBACK_FILE="${FEEDBACK_DIR}/${DATE}-${ADAPTER}.json"

# Ensure feedback directory exists
mkdir -p "$FEEDBACK_DIR"

# Skip if no output file
if [ ! -f "$OUTPUT_FILE" ]; then
  exit 0
fi

# Skip if file is older than 5 minutes (not from recent test run)
if [ "$(uname)" = "Darwin" ]; then
  FILE_AGE=$(( $(date +%s) - $(stat -f %m "$OUTPUT_FILE") ))
else
  FILE_AGE=$(( $(date +%s) - $(stat -c %Y "$OUTPUT_FILE") ))
fi

if [ "$FILE_AGE" -gt 300 ]; then
  exit 0
fi

# Extract metrics
POOL_COUNT=$(jq 'length' "$OUTPUT_FILE" 2>/dev/null || echo "0")
TOTAL_TVL=$(jq '[.[].tvlUsd // 0] | add' "$OUTPUT_FILE" 2>/dev/null || echo "0")
APY_MIN=$(jq '[.[].apyBase // 0, .[].apyReward // 0] | min' "$OUTPUT_FILE" 2>/dev/null || echo "0")
APY_MAX=$(jq '[.[].apyBase // 0, .[].apyReward // 0] | max' "$OUTPUT_FILE" 2>/dev/null || echo "0")
APY_AVG=$(jq '([.[].apyBase // 0] | add) / length' "$OUTPUT_FILE" 2>/dev/null || echo "0")
CHAINS=$(jq '[.[].chain] | unique' "$OUTPUT_FILE" 2>/dev/null || echo "[]")

# Check for errors
HIGH_APY=$(jq '[.[] | select((.apyBase // 0) > 1000 or (.apyReward // 0) > 1000)] | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")
MISSING_REWARDS=$(jq '[.[] | select((.apyReward // 0) > 0 and ((.rewardTokens | length) == 0 or .rewardTokens == null))] | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")
ZERO_TVL=$(jq '[.[] | select(.tvlUsd == 0 or .tvlUsd == null)] | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")

# Determine status and error type
STATUS="success"
ERROR_TYPE="null"
ERROR_MSG="null"

if [ "$POOL_COUNT" -eq 0 ]; then
  STATUS="failed"
  ERROR_TYPE="\"validation\""
  ERROR_MSG="\"No pools returned\""
elif [ "$MISSING_REWARDS" -gt 0 ]; then
  STATUS="failed"
  ERROR_TYPE="\"validation\""
  ERROR_MSG="\"${MISSING_REWARDS} pools missing rewardTokens\""
elif [ "$HIGH_APY" -gt 0 ]; then
  STATUS="partial"
  ERROR_TYPE="\"calculation\""
  ERROR_MSG="\"${HIGH_APY} pools with suspicious APY\""
elif [ "$ZERO_TVL" -gt 5 ]; then
  STATUS="partial"
  ERROR_TYPE="\"data_source\""
  ERROR_MSG="\"${ZERO_TVL} pools with zero TVL\""
fi

# Build error object
if [ "$ERROR_TYPE" = "null" ]; then
  ERROR_OBJ="null"
else
  ERROR_OBJ="{\"type\": ${ERROR_TYPE}, \"message\": ${ERROR_MSG}, \"stack\": null}"
fi

# If feedback file exists, update metrics; otherwise create new
if [ -f "$FEEDBACK_FILE" ]; then
  # Update existing file with metrics (preserve learnings)
  TMP_FILE=$(mktemp)
  jq --arg status "$STATUS" \
     --argjson pool_count "$POOL_COUNT" \
     --argjson tvl_total "${TOTAL_TVL:-0}" \
     --argjson apy_min "${APY_MIN:-0}" \
     --argjson apy_max "${APY_MAX:-0}" \
     --argjson apy_avg "${APY_AVG:-0}" \
     --argjson chains "$CHAINS" \
     --argjson error "$ERROR_OBJ" \
     --argjson test_passed "$([ "$STATUS" != "failed" ] && echo "true" || echo "false")" \
     '.status = $status |
      .chains = $chains |
      .metrics.test_passed = $test_passed |
      .metrics.pool_count = $pool_count |
      .metrics.tvl_total = $tvl_total |
      .metrics.apy_min = $apy_min |
      .metrics.apy_max = $apy_max |
      .metrics.apy_avg = $apy_avg |
      .error = $error' \
     "$FEEDBACK_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$FEEDBACK_FILE"
  echo "Updated metrics in: $FEEDBACK_FILE"
else
  # Create new feedback entry
  cat > "$FEEDBACK_FILE" << EOF
{
  "id": "${DATE}-${ADAPTER}",
  "timestamp": "${TIMESTAMP}",
  "agent_or_skill": "test-adapter",
  "protocol": "${ADAPTER}",
  "chains": ${CHAINS},
  "category": null,
  "status": "${STATUS}",

  "metrics": {
    "test_passed": $([ "$STATUS" != "failed" ] && echo "true" || echo "false"),
    "validation_passed": null,
    "pool_count": ${POOL_COUNT},
    "tvl_total": ${TOTAL_TVL:-0},
    "tvl_variance_pct": null,
    "apy_min": ${APY_MIN:-0},
    "apy_max": ${APY_MAX:-0},
    "apy_avg": ${APY_AVG:-0}
  },

  "error": ${ERROR_OBJ},

  "context": {
    "data_source_type": null,
    "reference_adapter": null,
    "iteration_count": 1,
    "duration_ms": null
  },

  "learnings": {
    "root_cause": null,
    "fix_applied": null,
    "should_update_skill": false,
    "skill_update_suggestion": null,
    "pattern_tags": []
  }
}
EOF
  echo "Created feedback: $FEEDBACK_FILE"
fi
