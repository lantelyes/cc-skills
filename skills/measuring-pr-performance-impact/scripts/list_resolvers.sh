#!/bin/bash
# Usage: ./list_resolvers.sh
# Returns: List of resolver names with recent Datadog data (one per line)
set -e

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
