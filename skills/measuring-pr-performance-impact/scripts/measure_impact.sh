#!/bin/bash
# Usage: ./measure_impact.sh <resolver[,resolver2,...]> <merged_epoch> [window_hours]
# Outputs formatted markdown with separate table per resolver
set -e

RESOLVERS="${1:?Usage: measure_impact.sh <resolver[,resolver2,...]> <merged_epoch> [window_hours]}"
MERGED_EPOCH="${2:?Missing merged_epoch}"
WINDOW_HOURS="${3:-24}"
WINDOW_SECS=$((WINDOW_HOURS * 3600))

# Load credentials
DOGRC="$HOME/.dogrc"
if [[ ! -f "$DOGRC" ]]; then
  echo "Error: Datadog credentials not found in $DOGRC" >&2
  exit 1
fi
DD_apikey=$(grep '^apikey' "$DOGRC" | sed 's/apikey *= *//')
DD_appkey=$(grep '^appkey' "$DOGRC" | sed 's/appkey *= *//')

# Calculate time windows
BEFORE_START=$((MERGED_EPOCH - WINDOW_SECS))
BEFORE_END=$MERGED_EPOCH
AFTER_START=$MERGED_EPOCH
AFTER_END=$((MERGED_EPOCH + WINDOW_SECS))
NOW=$(date +%s)
if [[ $AFTER_END -gt $NOW ]]; then AFTER_END=$NOW; fi

# Query function
query_metric() {
  local resolver=$1 metric=$2 from=$3 to=$4
  local query
  case "$metric" in
    avg|p50|p90|p99)
      query="${metric}:ct.consumer.graphql.latency.ms.distribution{resolver:${resolver}} by {query}"
      ;;
    count)
      query="sum:ct.consumer.graphql.latency.ms.distribution{resolver:${resolver}}.as_count()"
      ;;
    errors)
      query="sum:ct.consumer.graphql.error.count{resolver:${resolver}}.as_count()"
      ;;
  esac
  curl -s "https://api.datadoghq.com/api/v1/query" \
    -H "DD-API-KEY: ${DD_apikey}" \
    -H "DD-APPLICATION-KEY: ${DD_appkey}" \
    -G \
    --data-urlencode "query=${query}" \
    --data-urlencode "from=${from}" \
    --data-urlencode "to=${to}" | \
    jq '((.series // [])[0].pointlist // []) | map(.[1] // 0) | if length > 0 then add / length else 0 end'
}

# Process each resolver
IFS=',' read -ra RESOLVER_ARRAY <<< "$RESOLVERS"

# Query all metrics for all resolvers (parallel)
for resolver in "${RESOLVER_ARRAY[@]}"; do
  for metric in avg p50 p90 p99; do
    query_metric "$resolver" "$metric" "$BEFORE_START" "$BEFORE_END" > "/tmp/${resolver}_before_${metric}" &
    query_metric "$resolver" "$metric" "$AFTER_START" "$AFTER_END" > "/tmp/${resolver}_after_${metric}" &
  done
done
wait

# Read results helper
read_val() { cat "/tmp/${1}_${2}_${3}" 2>/dev/null || echo "0"; }

# Calculate actual after hours
ACTUAL_AFTER_SECS=$((AFTER_END - AFTER_START))
ACTUAL_AFTER_HOURS=$((ACTUAL_AFTER_SECS / 3600))

# Warn if after window < 24h
if [[ $ACTUAL_AFTER_HOURS -lt 24 ]]; then
  echo "Warning: Only ${ACTUAL_AFTER_HOURS}h of post-merge data available (< 24h may not be representative)" >&2
fi

# Format milliseconds
fmt_ms() {
  local val=$1
  if (( $(echo "$val < 1" | bc -l) )); then
    printf "%.2fms" "$val"
  elif (( $(echo "$val < 10" | bc -l) )); then
    printf "%.1fms" "$val"
  else
    printf "%.0fms" "$val"
  fi
}

# Calculate percent change and format with bold if >10%
calc_change() {
  local before=$1 after=$2
  if (( $(echo "$before == 0" | bc -l) )); then
    echo "N/A"
    return
  fi
  local pct=$(echo "scale=1; (($after - $before) / $before) * 100" | bc -l)
  local sign=""
  if (( $(echo "$pct > 0" | bc -l) )); then sign="+"; fi
  local abs_pct=$(echo "$pct" | tr -d '-')
  if (( $(echo "$abs_pct > 10" | bc -l) )); then
    printf "**%s%.0f%%**" "$sign" "$pct"
  else
    printf "%s%.0f%%" "$sign" "$pct"
  fi
}

# Output markdown
echo "**Window:** ${WINDOW_HOURS}h before / ${ACTUAL_AFTER_HOURS}h after merge"
echo ""

# Store summary data
declare -a SUMMARY_RESOLVERS
declare -a SUMMARY_AVG
declare -a SUMMARY_P99

# Output table for each resolver
for resolver in "${RESOLVER_ARRAY[@]}"; do
  before_avg=$(read_val "$resolver" before avg)
  after_avg=$(read_val "$resolver" after avg)
  before_p50=$(read_val "$resolver" before p50)
  after_p50=$(read_val "$resolver" after p50)
  before_p90=$(read_val "$resolver" before p90)
  after_p90=$(read_val "$resolver" after p90)
  before_p99=$(read_val "$resolver" before p99)
  after_p99=$(read_val "$resolver" after p99)

  # Warn if no data
  if [[ "$before_avg" == "0" && "$before_p99" == "0" ]]; then
    echo "Warning: No data found for resolver '$resolver'" >&2
    continue
  fi

  echo "## $resolver"
  echo ""
  echo "| Metric | Before | After | Change |"
  echo "|--------|--------|-------|--------|"
  echo "| avg | $(fmt_ms $before_avg) | $(fmt_ms $after_avg) | $(calc_change $before_avg $after_avg) |"
  echo "| p50 | $(fmt_ms $before_p50) | $(fmt_ms $after_p50) | $(calc_change $before_p50 $after_p50) |"
  echo "| p90 | $(fmt_ms $before_p90) | $(fmt_ms $after_p90) | $(calc_change $before_p90 $after_p90) |"
  echo "| p99 | $(fmt_ms $before_p99) | $(fmt_ms $after_p99) | $(calc_change $before_p99 $after_p99) |"
  echo ""

  # Store for summary
  SUMMARY_RESOLVERS+=("$resolver")
  SUMMARY_AVG+=("$(calc_change $before_avg $after_avg)")
  SUMMARY_P99+=("$(calc_change $before_p99 $after_p99)")
done

# Output summary table
echo "## Summary"
echo ""
echo "| Resolver | Avg | p99 |"
echo "|----------|-----|-----|"
for i in "${!SUMMARY_RESOLVERS[@]}"; do
  echo "| ${SUMMARY_RESOLVERS[$i]} | ${SUMMARY_AVG[$i]} | ${SUMMARY_P99[$i]} |"
done
echo ""
echo "[Dashboard](https://app.datadoghq.com/dashboard/52w-7p4-q8a)"

# Cleanup
for resolver in "${RESOLVER_ARRAY[@]}"; do
  rm -f /tmp/${resolver}_before_* /tmp/${resolver}_after_*
done
