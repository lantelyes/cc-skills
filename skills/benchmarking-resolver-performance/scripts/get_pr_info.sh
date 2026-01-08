#!/bin/bash
# Usage: ./get_pr_info.sh <pr_number>
# Returns: JSON with title, mergedAt, mergedAtEpoch, files
set -e
PR_NUMBER="${1:?Usage: get_pr_info.sh <pr_number>}"

# Get PR data
PR_JSON=$(gh pr view "$PR_NUMBER" --json mergedAt,files,title --repo coin-tracker/coin-tracker-server)

# Extract mergedAt and convert to epoch
MERGED_AT=$(echo "$PR_JSON" | jq -r '.mergedAt')
if [[ "$MERGED_AT" == "null" || -z "$MERGED_AT" ]]; then
  echo "$PR_JSON"
  exit 0
fi

# Convert ISO 8601 to epoch (macOS)
MERGED_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$MERGED_AT" +%s 2>/dev/null || date -d "$MERGED_AT" +%s)

# Add epoch to JSON
echo "$PR_JSON" | jq --arg epoch "$MERGED_EPOCH" '. + {mergedAtEpoch: ($epoch | tonumber)}'
