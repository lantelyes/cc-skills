#!/bin/bash
# Usage: ./benchmark.sh <resolver[,resolver2,...]> <merged_epoch> [window_hours]
# Queries all metrics before/after merge for each resolver, outputs JSON array
set -e

RESOLVERS="${1:?Usage: benchmark.sh <resolver[,resolver2,...]> <merged_epoch> [window_hours]}"
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
    jq '.series[0].pointlist | map(.[1]) | add / length // 0'
}

# Process each resolver
IFS=',' read -ra RESOLVER_ARRAY <<< "$RESOLVERS"

# Query all metrics for all resolvers (parallel)
for resolver in "${RESOLVER_ARRAY[@]}"; do
  for metric in avg p50 p90 p99 count errors; do
    query_metric "$resolver" "$metric" "$BEFORE_START" "$BEFORE_END" > "/tmp/${resolver}_before_${metric}" &
    query_metric "$resolver" "$metric" "$AFTER_START" "$AFTER_END" > "/tmp/${resolver}_after_${metric}" &
  done
done
wait

# Read results helper
read_val() { cat "/tmp/${1}_${2}_${3}" 2>/dev/null || echo "0"; }

# Calculate actual after hours (may be less if PR was recently merged)
ACTUAL_AFTER_SECS=$((AFTER_END - AFTER_START))
ACTUAL_AFTER_HOURS=$((ACTUAL_AFTER_SECS / 3600))

# Output JSON array
echo "["
first=true
for resolver in "${RESOLVER_ARRAY[@]}"; do
  if [ "$first" = true ]; then first=false; else echo ","; fi
  cat << EOF
  {
    "resolver": "$resolver",
    "window": {
      "hours_before": $WINDOW_HOURS,
      "hours_after": $ACTUAL_AFTER_HOURS
    },
    "before": {
      "avg": $(read_val "$resolver" before avg),
      "p50": $(read_val "$resolver" before p50),
      "p90": $(read_val "$resolver" before p90),
      "p99": $(read_val "$resolver" before p99),
      "count": $(read_val "$resolver" before count),
      "errors": $(read_val "$resolver" before errors)
    },
    "after": {
      "avg": $(read_val "$resolver" after avg),
      "p50": $(read_val "$resolver" after p50),
      "p90": $(read_val "$resolver" after p90),
      "p99": $(read_val "$resolver" after p99),
      "count": $(read_val "$resolver" after count),
      "errors": $(read_val "$resolver" after errors)
    }
  }
EOF
done
echo "]"

# Cleanup
for resolver in "${RESOLVER_ARRAY[@]}"; do
  rm -f /tmp/${resolver}_before_* /tmp/${resolver}_after_*
done
