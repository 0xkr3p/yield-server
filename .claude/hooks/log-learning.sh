#!/bin/bash
# Log learnings to feedback entries
# Called by agents after completing work
#
# Usage: log-learning.sh <protocol> <agent> <status> <learning> [pattern_tags]
# Example: log-learning.sh "aave-v3" "fix-adapter" "success" "RAY format needs 1e27 division" "decimal-fix,lending"

PROTOCOL="${1:-}"
AGENT="${2:-}"
STATUS="${3:-}"
LEARNING="${4:-}"
PATTERN_TAGS="${5:-}"

if [ -z "$PROTOCOL" ] || [ -z "$AGENT" ] || [ -z "$LEARNING" ]; then
  echo "Usage: log-learning.sh <protocol> <agent> <status> <learning> [pattern_tags]"
  exit 1
fi

# Find repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

FEEDBACK_DIR="$REPO_ROOT/.claude/feedback/entries"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
FEEDBACK_FILE="${FEEDBACK_DIR}/${DATE}-${PROTOCOL}.json"

mkdir -p "$FEEDBACK_DIR"

# Convert pattern_tags to JSON array
if [ -n "$PATTERN_TAGS" ]; then
  TAGS_JSON=$(echo "$PATTERN_TAGS" | tr ',' '\n' | sed 's/^/"/;s/$/"/' | tr '\n' ',' | sed 's/,$//' | sed 's/^/[/;s/$/]/')
else
  TAGS_JSON="[]"
fi

# If feedback file exists, update it; otherwise create new
if [ -f "$FEEDBACK_FILE" ]; then
  # Update existing file with learnings
  TMP_FILE=$(mktemp)
  jq --arg learning "$LEARNING" \
     --arg status "$STATUS" \
     --arg agent "$AGENT" \
     --argjson tags "$TAGS_JSON" \
     '.learnings.root_cause = $learning |
      .learnings.pattern_tags = ($tags + .learnings.pattern_tags | unique) |
      .status = $status |
      .agent_or_skill = $agent' \
     "$FEEDBACK_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$FEEDBACK_FILE"
  echo "Updated learnings in: $FEEDBACK_FILE"
else
  # Create new feedback entry with learnings
  cat > "$FEEDBACK_FILE" << EOF
{
  "id": "${DATE}-${PROTOCOL}",
  "timestamp": "${TIMESTAMP}",
  "agent_or_skill": "${AGENT}",
  "protocol": "${PROTOCOL}",
  "chains": [],
  "category": null,
  "status": "${STATUS}",

  "metrics": {
    "test_passed": null,
    "validation_passed": null,
    "pool_count": null,
    "tvl_total": null,
    "tvl_variance_pct": null,
    "apy_min": null,
    "apy_max": null,
    "apy_avg": null
  },

  "error": null,

  "context": {
    "data_source_type": null,
    "reference_adapter": null,
    "iteration_count": 1,
    "duration_ms": null
  },

  "learnings": {
    "root_cause": "${LEARNING}",
    "fix_applied": null,
    "should_update_skill": false,
    "skill_update_suggestion": null,
    "pattern_tags": ${TAGS_JSON}
  }
}
EOF
  echo "Created feedback with learnings: $FEEDBACK_FILE"
fi
