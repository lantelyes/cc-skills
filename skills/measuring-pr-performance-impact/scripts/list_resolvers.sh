#!/bin/bash
# Usage: ./list_resolvers.sh
# Returns: List of resolver names with recent Datadog data (one per line)
set -e

DOGRC="$HOME/.dogrc"
if [[ ! -f "$DOGRC" ]]; then
  echo "Error: Datadog credentials not found in $DOGRC" >&2
  exit 1
fi
DD_apikey=$(grep '^apikey' "$DOGRC" | sed 's/apikey *= *//')
DD_appkey=$(grep '^appkey' "$DOGRC" | sed 's/appkey *= *//')

# Query last hour for all resolvers
FROM=$(($(date +%s) - 3600))
TO=$(date +%s)

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" \
  -H "DD-APPLICATION-KEY: ${DD_appkey}" \
  -G \
  --data-urlencode "query=avg:ct.consumer.graphql.latency.ms.distribution{*} by {resolver}" \
  --data-urlencode "from=${FROM}" \
  --data-urlencode "to=${TO}" | \
  jq -r '.series[].scope | split(",") | .[] | select(startswith("resolver:")) | sub("resolver:"; "")' | \
  sort -u
