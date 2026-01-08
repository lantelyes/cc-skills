#!/bin/bash
# Usage: ./compare_prs.sh <resolver> <pr1,pr2,...> [window_hours]
# Compares multiple PRs and shows per-PR attribution + cumulative impact
set -e

RESOLVER="${1:?Usage: compare_prs.sh <resolver> <pr1,pr2,...> [window_hours]}"
PRS="${2:?Missing PR numbers (comma-separated)}"
WINDOW_HOURS="${3:-24}"
WINDOW_SECS=$((WINDOW_HOURS * 3600))
SCRIPT_DIR="$(dirname "$0")"

# Load credentials
DOGRC="$HOME/.dogrc"
if [[ ! -f "$DOGRC" ]]; then
  echo "Error: Datadog credentials not found in $DOGRC" >&2
  exit 1
fi
DD_apikey=$(grep '^apikey' "$DOGRC" | sed 's/apikey *= *//')
DD_appkey=$(grep '^appkey' "$DOGRC" | sed 's/appkey *= *//')

# Query function
query_metric() {
  local resolver=$1 metric=$2 from=$3 to=$4
  local query="${metric}:ct.consumer.graphql.latency.ms.distribution{resolver:${resolver}} by {query}"
  curl -s "https://api.datadoghq.com/api/v1/query" \
    -H "DD-API-KEY: ${DD_apikey}" \
    -H "DD-APPLICATION-KEY: ${DD_appkey}" \
    -G \
    --data-urlencode "query=${query}" \
    --data-urlencode "from=${from}" \
    --data-urlencode "to=${to}" | \
    jq '((.series // [])[0].pointlist // []) | map(.[1] // 0) | if length > 0 then add / length else 0 end'
}

# Format milliseconds
fmt_ms() {
  local val=$1
  # Handle empty/null values
  if [[ -z "$val" || "$val" == "null" ]]; then
    echo "N/A"
    return
  fi
  if (( $(echo "$val < 1" | bc -l 2>/dev/null || echo "0") )); then
    printf "%.2fms" "$val"
  elif (( $(echo "$val < 10" | bc -l 2>/dev/null || echo "0") )); then
    printf "%.1fms" "$val"
  else
    printf "%.0fms" "$val"
  fi
}

# Format percent change with bold if >10%
fmt_pct() {
  local pct=$1
  # Handle empty/null/N/A values
  if [[ -z "$pct" || "$pct" == "N/A" || "$pct" == "null" ]]; then
    echo "N/A"
    return
  fi
  local sign=""
  if (( $(echo "$pct > 0" | bc -l 2>/dev/null || echo "0") )); then sign="+"; fi
  local abs_pct=$(echo "$pct" | tr -d '-')
  if (( $(echo "$abs_pct > 10" | bc -l 2>/dev/null || echo "0") )); then
    printf "**%s%.0f%%**" "$sign" "$pct"
  else
    printf "%s%.0f%%" "$sign" "$pct"
  fi
}

# Get PR info for all PRs
IFS=',' read -ra PR_ARRAY <<< "$PRS"
declare -a PR_DATA  # "pr_number:epoch:title"

echo "Fetching PR info..." >&2
for pr in "${PR_ARRAY[@]}"; do
  info=$("$SCRIPT_DIR/get_pr_info.sh" "$pr" 2>&1) || {
    echo "Error: Failed to get info for PR #$pr" >&2
    exit 1
  }
  epoch=$(echo "$info" | jq -r '.mergedAtEpoch')
  title=$(echo "$info" | jq -r '.title' | cut -c1-50)
  PR_DATA+=("$pr:$epoch:$title")
done

# Sort by epoch
IFS=$'\n' SORTED=($(printf '%s\n' "${PR_DATA[@]}" | sort -t: -k2 -n))
unset IFS

# Detect overlaps (< 4h between merges)
OVERLAP_WARNINGS=()
for ((i=1; i<${#SORTED[@]}; i++)); do
  prev_epoch=$(echo "${SORTED[$((i-1))]}" | cut -d: -f2)
  curr_epoch=$(echo "${SORTED[$i]}" | cut -d: -f2)
  diff=$((curr_epoch - prev_epoch))
  if [[ $diff -lt 28800 ]]; then  # 8 hours
    prev_pr=$(echo "${SORTED[$((i-1))]}" | cut -d: -f1)
    curr_pr=$(echo "${SORTED[$i]}" | cut -d: -f1)
    hours=$((diff / 3600))
    OVERLAP_WARNINGS+=("PRs #$prev_pr and #$curr_pr merged within ${hours}h")
  fi
done

# Calculate baseline (before first PR)
FIRST_EPOCH=$(echo "${SORTED[0]}" | cut -d: -f2)
BASELINE_START=$((FIRST_EPOCH - WINDOW_SECS))
BASELINE_END=$FIRST_EPOCH

echo "Querying baseline metrics..." >&2
baseline_avg=$(query_metric "$RESOLVER" avg "$BASELINE_START" "$BASELINE_END")
baseline_p99=$(query_metric "$RESOLVER" p99 "$BASELINE_START" "$BASELINE_END")

if [[ "$baseline_avg" == "0" && "$baseline_p99" == "0" ]]; then
  echo "Error: No baseline data found for resolver '$RESOLVER'" >&2
  exit 1
fi

# Query each PR's "after" period
declare -a RESULTS  # "pr:avg:p99:change_avg"
NOW=$(date +%s)
prev_avg=$baseline_avg

echo "Querying metrics for each PR..." >&2
for ((i=0; i<${#SORTED[@]}; i++)); do
  pr=$(echo "${SORTED[$i]}" | cut -d: -f1)
  epoch=$(echo "${SORTED[$i]}" | cut -d: -f2)

  # After window: from this PR's merge to next PR's merge (or +window if last)
  if [[ $((i+1)) -lt ${#SORTED[@]} ]]; then
    next_epoch=$(echo "${SORTED[$((i+1))]}" | cut -d: -f2)
    after_end=$next_epoch
  else
    after_end=$((epoch + WINDOW_SECS))
    if [[ $after_end -gt $NOW ]]; then after_end=$NOW; fi
  fi

  after_avg=$(query_metric "$RESOLVER" avg "$epoch" "$after_end")
  after_p99=$(query_metric "$RESOLVER" p99 "$epoch" "$after_end")

  # Calculate change from previous state
  if (( $(echo "$prev_avg == 0" | bc -l) )); then
    change_avg="N/A"
  else
    change_avg=$(echo "scale=1; (($after_avg - $prev_avg) / $prev_avg) * 100" | bc -l 2>/dev/null || echo "0")
  fi

  RESULTS+=("$pr:$after_avg:$after_p99:$change_avg")
  prev_avg=$after_avg
done

# Calculate cumulative change (use last index explicitly for bash compatibility)
last_idx=$((${#RESULTS[@]} - 1))
if [[ $last_idx -ge 0 ]]; then
  final_avg=$(echo "${RESULTS[$last_idx]}" | cut -d: -f2)
  final_p99=$(echo "${RESULTS[$last_idx]}" | cut -d: -f3)
else
  final_avg=0
  final_p99=0
fi

# Validate values for bc
if [[ -z "$final_avg" || "$final_avg" == "null" ]]; then final_avg=0; fi
if [[ -z "$final_p99" || "$final_p99" == "null" ]]; then final_p99=0; fi
if [[ -z "$baseline_avg" || "$baseline_avg" == "null" ]]; then baseline_avg=0; fi

if (( $(echo "$baseline_avg == 0" | bc -l 2>/dev/null || echo "1") )); then
  cumulative_avg="N/A"
else
  cumulative_avg=$(echo "scale=1; (($final_avg - $baseline_avg) / $baseline_avg) * 100" | bc -l 2>/dev/null || echo "0")
fi

# Output markdown
echo "## Timeline: $RESOLVER"
echo ""
echo "| PR | avg | p99 | Change |"
echo "|----|-----|-----|--------|"
echo "| Baseline | $(fmt_ms $baseline_avg) | $(fmt_ms $baseline_p99) | - |"
for result in "${RESULTS[@]}"; do
  pr=$(echo "$result" | cut -d: -f1)
  avg=$(echo "$result" | cut -d: -f2)
  p99=$(echo "$result" | cut -d: -f3)
  change=$(echo "$result" | cut -d: -f4)
  echo "| #$pr | $(fmt_ms $avg) | $(fmt_ms $p99) | $(fmt_pct $change) |"
done
echo "| **Cumulative** | $(fmt_ms $final_avg) | $(fmt_ms $final_p99) | $(fmt_pct $cumulative_avg) |"
echo ""

# Output warnings
for warn in "${OVERLAP_WARNINGS[@]}"; do
  echo "> **Warning:** $warn - attribution may be unreliable"
done

if [[ ${#OVERLAP_WARNINGS[@]} -gt 0 ]]; then
  echo ""
fi

echo "[Dashboard](https://app.datadoghq.com/dashboard/52w-7p4-q8a)"
