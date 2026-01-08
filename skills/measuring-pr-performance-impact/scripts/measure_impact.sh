#!/bin/bash
# Usage: ./measure_impact.sh <resolver[,resolver2,...]> <merged_epoch> [window_hours]
# Outputs formatted table with latency metrics per resolver
set -e

RESOLVERS="${1:?Usage: measure_impact.sh <resolver[,resolver2,...]> <merged_epoch> [window_hours]}"
MERGED_EPOCH="${2:?Missing merged_epoch}"
WINDOW_HOURS="${3:-24}"
WINDOW_SECS=$((WINDOW_HOURS * 3600))

# Load credentials (env vars take priority, fallback to ~/.dogrc)
if [[ -n "$DD_API_KEY" && -n "$DD_APP_KEY" ]]; then
  DD_apikey="$DD_API_KEY"
  DD_appkey="$DD_APP_KEY"
elif [[ -f "$HOME/.dogrc" ]]; then
  DD_apikey=$(grep '^apikey' "$HOME/.dogrc" | sed 's/apikey *= *//')
  DD_appkey=$(grep '^appkey' "$HOME/.dogrc" | sed 's/appkey *= *//')
else
  echo "Error: Datadog credentials not found. Set DD_API_KEY/DD_APP_KEY env vars or create ~/.dogrc" >&2
  exit 1
fi

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
      # No 'by {query}' - aggregate across all queries using this resolver
      query="${metric}:ct.consumer.graphql.latency.ms.distribution{resolver:${resolver}}"
      ;;
    count)
      query="sum:ct.consumer.graphql.latency.ms.distribution{resolver:${resolver}}.as_count()"
      ;;
    errors)
      query="sum:ct.consumer.graphql.error.count{resolver:${resolver}}.as_count()"
      ;;
  esac
  # Use sum for counts, average for latency metrics
  local agg="add / length"
  if [[ "$metric" == "count" || "$metric" == "errors" ]]; then
    agg="add"
  fi
  curl -s "https://api.datadoghq.com/api/v1/query" \
    -H "DD-API-KEY: ${DD_apikey}" \
    -H "DD-APPLICATION-KEY: ${DD_appkey}" \
    -G \
    --data-urlencode "query=${query}" \
    --data-urlencode "from=${from}" \
    --data-urlencode "to=${to}" | \
    jq "((.series // [])[0].pointlist // []) | map(.[1] // 0) | if length > 0 then ${agg} else 0 end"
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

# Calculate actual after hours
ACTUAL_AFTER_SECS=$((AFTER_END - AFTER_START))
ACTUAL_AFTER_HOURS=$((ACTUAL_AFTER_SECS / 3600))

# Warn if after window < 24h
if [[ $ACTUAL_AFTER_HOURS -lt 24 ]]; then
  echo "Warning: Only ${ACTUAL_AFTER_HOURS}h of post-merge data available (< 24h may not be representative)" >&2
fi

# Format milliseconds (converts to seconds if >= 1000ms)
fmt_ms() {
  local val=$1
  if (( $(echo "$val >= 1000" | bc -l) )); then
    printf "%.1fs" "$(echo "scale=2; $val / 1000" | bc -l)"
  elif (( $(echo "$val < 1" | bc -l) )); then
    printf "%.2fms" "$val"
  elif (( $(echo "$val < 10" | bc -l) )); then
    printf "%.1fms" "$val"
  else
    printf "%.0fms" "$val"
  fi
}

# Format counts with K/M suffixes
fmt_count() {
  local val=$1
  if (( $(echo "$val >= 1000000" | bc -l) )); then
    printf "%.1fM" "$(echo "scale=2; $val / 1000000" | bc -l)"
  elif (( $(echo "$val >= 1000" | bc -l) )); then
    printf "%.1fK" "$(echo "scale=2; $val / 1000" | bc -l)"
  else
    printf "%.0f" "$val"
  fi
}

# Format percentage
fmt_pct() {
  printf "%.2f%%" "$1"
}

# Calculate percent change (raw number)
calc_change_raw() {
  local before=$1 after=$2
  if (( $(echo "$before == 0" | bc -l) )); then
    echo "0"
    return
  fi
  echo "scale=4; (($after - $before) / $before) * 100" | bc -l
}

# Format change with arrow (returns fixed 9-char display width string)
fmt_change() {
  local pct=$1
  local abs_pct=$(echo "$pct" | tr -d '-')
  local arrow="↓"
  if (( $(echo "$pct > 0" | bc -l) )); then
    arrow="↑"
  fi
  # Handle zero case - just show 0%
  if (( $(echo "$abs_pct < 0.5" | bc -l) )); then
    printf "%9s" "0%"
  else
    # Arrow is 1 display char but 3 bytes, so we need to pad manually
    local num=$(printf "%.0f%%" "$abs_pct")
    local display_len=$((1 + 1 + ${#num}))  # arrow + space + number
    local padding=$((9 - display_len))
    printf "%*s%s %s" "$padding" "" "$arrow" "$num"
  fi
}

# Print a data row (change column uses pre-padded string)
print_row() {
  local metric=$1 before=$2 after=$3 change=$4
  printf "║ %-10s │ %8s │ %8s │ %s ║\n" "$metric" "$before" "$after" "$change"
}

# Print row separator
print_sep() {
  echo "╟────────────┼──────────┼──────────┼───────────╢"
}

# Output markdown
echo "**Window:** ${WINDOW_HOURS}h before / ${ACTUAL_AFTER_HOURS}h after merge"
echo ""

# Output for each resolver
for resolver in "${RESOLVER_ARRAY[@]}"; do
  before_avg=$(read_val "$resolver" before avg)
  after_avg=$(read_val "$resolver" after avg)
  before_p50=$(read_val "$resolver" before p50)
  after_p50=$(read_val "$resolver" after p50)
  before_p90=$(read_val "$resolver" before p90)
  after_p90=$(read_val "$resolver" after p90)
  before_p99=$(read_val "$resolver" before p99)
  after_p99=$(read_val "$resolver" after p99)
  before_count=$(read_val "$resolver" before count)
  after_count=$(read_val "$resolver" after count)
  before_errors=$(read_val "$resolver" before errors)
  after_errors=$(read_val "$resolver" after errors)

  # Warn if no data
  if [[ "$before_avg" == "0" && "$before_p99" == "0" ]]; then
    echo "Warning: No data found for resolver '$resolver'" >&2
    continue
  fi

  # Calculate changes
  chg_avg=$(calc_change_raw $before_avg $after_avg)
  chg_p50=$(calc_change_raw $before_p50 $after_p50)
  chg_p90=$(calc_change_raw $before_p90 $after_p90)
  chg_p99=$(calc_change_raw $before_p99 $after_p99)

  # Calculate error rate
  if (( $(echo "$before_count > 0" | bc -l) )); then
    before_err_rate=$(echo "scale=4; ($before_errors / $before_count) * 100" | bc -l)
  else
    before_err_rate="0"
  fi
  if (( $(echo "$after_count > 0" | bc -l) )); then
    after_err_rate=$(echo "scale=4; ($after_errors / $after_count) * 100" | bc -l)
  else
    after_err_rate="0"
  fi
  chg_err_rate=$(calc_change_raw $before_err_rate $after_err_rate)
  chg_count=$(calc_change_raw $before_count $after_count)

  # Resolver name in uppercase
  resolver_upper=$(echo "$resolver" | tr '[:lower:]' '[:upper:]')

  # Table header
  echo "╔══════════════════════════════════════════════╗"
  printf "║ %-44s ║\n" "$resolver_upper"
  echo "╠════════════╤══════════╤══════════╤═══════════╣"
  printf "║ %-10s │ %8s │ %8s │ %9s ║\n" "Metric" "Before" "After" "Change"
  echo "╠════════════╪══════════╪══════════╪═══════════╣"

  # Data rows
  print_row "Average" "$(fmt_ms $before_avg)" "$(fmt_ms $after_avg)" "$(fmt_change $chg_avg)"
  print_sep
  print_row "P50" "$(fmt_ms $before_p50)" "$(fmt_ms $after_p50)" "$(fmt_change $chg_p50)"
  print_sep
  print_row "P90" "$(fmt_ms $before_p90)" "$(fmt_ms $after_p90)" "$(fmt_change $chg_p90)"
  print_sep
  print_row "P99" "$(fmt_ms $before_p99)" "$(fmt_ms $after_p99)" "$(fmt_change $chg_p99)"
  print_sep
  print_row "Requests" "$(fmt_count $before_count)" "$(fmt_count $after_count)" "$(fmt_change $chg_count)"
  print_sep
  print_row "Error Rate" "$(fmt_pct $before_err_rate)" "$(fmt_pct $after_err_rate)" "$(fmt_change $chg_err_rate)"

  # Table footer
  echo "╚════════════╧══════════╧══════════╧═══════════╝"
  echo ""
done

echo "[Dashboard](https://app.datadoghq.com/dashboard/52w-7p4-q8a)"

# Cleanup
for resolver in "${RESOLVER_ARRAY[@]}"; do
  rm -f /tmp/${resolver}_before_* /tmp/${resolver}_after_*
done
