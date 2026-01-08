#!/bin/bash
# Usage: ./benchmark.sh <resolver> <merged_epoch> [window_hours]
# Queries all metrics before/after merge, outputs JSON with results
set -e

RESOLVER="${1:?Usage: benchmark.sh <resolver> <merged_epoch> [window_hours]}"
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
  local metric=$1 from=$2 to=$3
  local query
  case "$metric" in
    avg|p50|p90|p99)
      query="${metric}:ct.consumer.graphql.latency.ms.distribution{resolver:${RESOLVER}} by {query}"
      ;;
    count)
      query="sum:ct.consumer.graphql.latency.ms.distribution{resolver:${RESOLVER}}.as_count()"
      ;;
    errors)
      query="sum:ct.consumer.graphql.error.count{resolver:${RESOLVER}}.as_count()"
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

# Query all metrics (parallel)
for metric in avg p50 p90 p99 count errors; do
  query_metric "$metric" "$BEFORE_START" "$BEFORE_END" > "/tmp/${RESOLVER}_before_${metric}" &
  query_metric "$metric" "$AFTER_START" "$AFTER_END" > "/tmp/${RESOLVER}_after_${metric}" &
done
wait

# Read results
read_val() { cat "/tmp/${RESOLVER}_${1}_${2}" 2>/dev/null || echo "0"; }

# Output JSON for Claude to format
cat << EOF
{
  "resolver": "$RESOLVER",
  "before": {
    "avg": $(read_val before avg),
    "p50": $(read_val before p50),
    "p90": $(read_val before p90),
    "p99": $(read_val before p99),
    "count": $(read_val before count),
    "errors": $(read_val before errors)
  },
  "after": {
    "avg": $(read_val after avg),
    "p50": $(read_val after p50),
    "p90": $(read_val after p90),
    "p99": $(read_val after p99),
    "count": $(read_val after count),
    "errors": $(read_val after errors)
  }
}
EOF

# Cleanup
rm -f /tmp/${RESOLVER}_before_* /tmp/${RESOLVER}_after_*
