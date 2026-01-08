---
description: Compare GraphQL resolver latency before/after a PR merge using Datadog metrics. Use for performance impact analysis.
allowed-tools: Bash, Read
argument-hint: --pr <number> [--resolver <name>] [--query <name>] [--window <hours>]
---

# Benchmark Consumer Resolver Performance

Compare GraphQL resolver latency metrics before and after a PR merge.

## Configuration

- **Dashboard ID**: `52w-7p4-q8a`
- **Dashboard URL**: https://app.datadoghq.com/dashboard/52w-7p4-q8a
- **Credentials**: `~/.dogrc`
- **Main metric**: `ct.consumer.graphql.latency.ms.distribution`
- **Trace pattern**: `trace.app.core.*.duration`

## Parameters

Parse from `$ARGUMENTS`:
- `--pr <number>` (required): PR number to analyze
- `--resolver <name>` (optional): Resolver name to benchmark (e.g., `performancehistory`)
- `--query <name>` (optional): GraphQL query name to filter (e.g., `getperformancehistory`)
- `--window <hours>` (optional, default: 24): Hours before/after merge to compare

## Workflow

### Step 1: Get PR Details

```bash
gh pr view <PR_NUMBER> --json mergedAt,files,title --repo coin-tracker/coin-tracker-server
```

Extract `mergedAt` timestamp. If not merged, report error.

### Step 2: Calculate Time Windows

- **Before period**: `(mergedAt - window hours)` to `mergedAt`
- **After period**: `mergedAt` to `(mergedAt + window hours)` or `now` if less time has passed

Convert to Unix timestamps for Datadog API.

### Step 3: Query Resolver Metrics

Use this pattern to query Datadog securely (credentials never exposed):

```bash
source <(grep -E '^(apikey|appkey)' ~/.dogrc | sed 's/ *= */=/g' | sed 's/^/DD_/') && \
curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" \
  -H "DD-APPLICATION-KEY: ${DD_appkey}" \
  -G \
  --data-urlencode "query=<AGGREGATION>:ct.consumer.graphql.latency.ms.distribution{resolver:<RESOLVER>} by {query}" \
  --data-urlencode "from=<FROM_TIMESTAMP>" \
  --data-urlencode "to=<TO_TIMESTAMP>"
```

Query for these aggregations: `avg`, `p99`, `p50`

Also get request count:
```bash
--data-urlencode "query=sum:ct.consumer.graphql.latency.ms.distribution{resolver:<RESOLVER>} by {query}.as_count()"
```

### Step 4: Query Sub-operation Breakdown

Find trace metrics for the resolver's code path:

```bash
source <(grep -E '^(apikey|appkey)' ~/.dogrc | sed 's/ *= */=/g' | sed 's/^/DD_/') && \
curl -s "https://api.datadoghq.com/api/v1/metrics?from=<FROM_7D_AGO>" \
  -H "DD-API-KEY: ${DD_apikey}" \
  -H "DD-APPLICATION-KEY: ${DD_appkey}" | \
python3 -c "import json,sys; print('\n'.join(m for m in json.load(sys.stdin).get('metrics',[]) if 'trace.' in m and 'duration' in m))" | \
grep -i "<RESOLVER_RELATED_PATTERN>"
```

Then query duration for each relevant trace metric before/after.

### Step 5: Parse Results

Parse JSON responses with Python:

```bash
cat /tmp/response.json | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data.get('series'):
    for series in data['series']:
        scope = series.get('scope', '')
        points = [p[1] for p in series['pointlist'] if p[1] is not None]
        if points:
            avg = sum(points) / len(points)
            print(f'{scope}: {avg:.2f}ms')
"
```

### Step 6: Format Output

Display results in this format:

```
=== PR #<NUMBER>: <RESOLVER> resolver ===
PR Title: <TITLE>
Merged: <MERGED_AT>
Window: <WINDOW> hours before/after

SUMMARY
+---------------------+---------+---------+---------+
| Metric              | Before  | After   | Change  |
+---------------------+---------+---------+---------+
| avg latency         | XXXms   | XXXms   | -XX%    |
| p99 latency         | XXXms   | XXXms   | -XX%    |
| p50 latency         | XXXms   | XXXms   | -XX%    |
| request count       | X.XXM   | X.XXM   | -       |
+---------------------+---------+---------+---------+

BREAKDOWN (sub-operations, sorted by impact)
+---------------------------------+---------+---------+---------+
| Operation                       | Before  | After   | Change  |
+---------------------------------+---------+---------+---------+
| <operation_name>                | XXXms   | XXXms   | -XX%    |
| ...                             | ...     | ...     | ...     |
+---------------------------------+---------+---------+---------+

Dashboard: https://app.datadoghq.com/dashboard/52w-7p4-q8a
```

Use indicators for significant changes:
- Improvement > 20%: show as positive
- Regression > 10%: show as warning

## Auto-detect Resolver

If `--resolver` not specified:
1. Look at PR changed files
2. Map file paths to likely resolvers:
   - `app/models/price_history.py` -> `performancehistory`, `pricehistory`
   - `app/core/performance/` -> `performancehistory`, `portfolio`
   - `app/graphql/portfolio/` -> `portfolio`, `performancehistory`
3. Query top resolvers by latency change and show most affected

## Common Resolvers

- `performancehistory` - Portfolio performance data
- `portfolio` - Portfolio queries
- `pricehistory` - Price history data
- `pricehistoryusd` - USD price history
- `filteredprices` - Filtered price queries

## Error Handling

- If PR not merged: "PR #X has not been merged yet"
- If no data in time window: "No metrics data found for resolver X in the specified time window"
- If credentials missing: "Datadog credentials not found in ~/.dogrc"
