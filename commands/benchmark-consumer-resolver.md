---
description: Measure how a PR affected GraphQL resolver latency in production.
allowed-tools: Read, Bash(*)
argument-hint: --pr <number> [--resolver <name>] [--window <hours>]
---

# Measure PR Performance Impact

Measure how a PR affected GraphQL resolver latency and errors in production.

## Configuration

- **Dashboard**: https://app.datadoghq.com/dashboard/52w-7p4-q8a
- **Credentials**: `~/.dogrc`
- **Latency metric**: `ct.consumer.graphql.latency.ms.distribution`
- **Error metric**: `ct.consumer.graphql.error.count`

## Parameters

Parse from `$ARGUMENTS`:
- `--pr <number>` (required): PR number to analyze
- `--resolver <name>[,<name>...]` (optional): Resolver name(s) to benchmark, comma-separated (e.g., `performancehistory,portfolio`)
- `--window <hours>` (optional, default: 24): Hours before/after merge to compare

If `--resolver` not specified, auto-detect from PR files (see Auto-Detect section below).

## Auto-Detect Resolvers

When `--resolver` not specified, **search the codebase** to find which resolvers use the changed files:

### Step 1: Convert changed files to module names
For each changed file in the PR, convert path to Python import pattern:
`app/core/foo/bar.py` → search pattern `app.core.foo` or `from app.core.foo`

### Step 2: Find GraphQL resolvers that import those modules
```bash
# For each changed module, find which GraphQL files import it
grep -r "<module_pattern>" app/graphql/ --include="*.py" -l
```

### Step 3: Map GraphQL files to resolver names
- Resolver files are in `app/graphql/<feature>/<resolver_name>/`
- The Datadog resolver name is the folder/file name in **lowercase, no underscores**
- Example: `app/graphql/portfolio/performance_history/resolver.py` → `performancehistory`

### Step 4: Confirm with user
Before querying, confirm: "Based on the changed files, I found these resolvers may be affected: [list]. Should I benchmark all of them, or specify which ones?"

### Fallback
If no GraphQL imports found, the change may be in shared utilities. Ask user to specify resolver(s) manually.

## Resolver Name Discovery

Before querying metrics, fetch the list of valid resolver names from Datadog:

```bash
DD_apikey=$(grep '^apikey' ~/.dogrc | sed 's/apikey *= *//')
DD_appkey=$(grep '^appkey' ~/.dogrc | sed 's/appkey *= *//')
curl -s "https://api.datadoghq.com/api/v1/tags/hosts" \
  -H "DD-API-KEY: ${DD_apikey}" \
  -H "DD-APPLICATION-KEY: ${DD_appkey}" \
  -G --data-urlencode "filter=resolver"
```

Or query the metric itself for tag values:
```bash
curl -s "https://api.datadoghq.com/api/v2/metrics/ct.consumer.graphql.latency.ms.distribution/tags" \
  -H "DD-API-KEY: ${DD_apikey}" \
  -H "DD-APPLICATION-KEY: ${DD_appkey}"
```

Use ONLY resolver names that appear in Datadog. Do NOT guess or transform names.

## Workflow

### Step 1: Get PR Details

```bash
gh pr view <PR_NUMBER> --json mergedAt,files,title --repo coin-tracker/coin-tracker-server
```

Extract `mergedAt` timestamp. If not merged, report: "PR #X has not been merged yet"

### Step 2: Determine Resolvers

Parse `--resolver` argument. If comma-separated, split into list.
If not specified, auto-detect from PR files (may return multiple).

### Step 3: Query Metrics for Each Resolver

For each resolver in the list, run queries in parallel using resolver-specific temp files (`/tmp/${RESOLVER}_before_avg.json`, etc.):

```bash
# Load credentials
DD_apikey=$(grep '^apikey' ~/.dogrc | sed 's/apikey *= *//')
DD_appkey=$(grep '^appkey' ~/.dogrc | sed 's/appkey *= *//')

# Calculate timestamps (replace MERGED_EPOCH and WINDOW_HOURS)
BEFORE_START=$((MERGED_EPOCH - WINDOW_HOURS * 3600))
BEFORE_END=$MERGED_EPOCH
AFTER_START=$MERGED_EPOCH
AFTER_END=$((MERGED_EPOCH + WINDOW_HOURS * 3600))
NOW=$(date +%s)
[[ $AFTER_END -gt $NOW ]] && AFTER_END=$NOW

# For each RESOLVER, query all metrics in parallel
curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=avg:ct.consumer.graphql.latency.ms.distribution{resolver:RESOLVER} by {query}" \
  --data-urlencode "from=$BEFORE_START" --data-urlencode "to=$BEFORE_END" > /tmp/${RESOLVER}_before_avg.json &

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=avg:ct.consumer.graphql.latency.ms.distribution{resolver:RESOLVER} by {query}" \
  --data-urlencode "from=$AFTER_START" --data-urlencode "to=$AFTER_END" > /tmp/${RESOLVER}_after_avg.json &

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=p99:ct.consumer.graphql.latency.ms.distribution{resolver:RESOLVER} by {query}" \
  --data-urlencode "from=$BEFORE_START" --data-urlencode "to=$BEFORE_END" > /tmp/${RESOLVER}_before_p99.json &

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=p99:ct.consumer.graphql.latency.ms.distribution{resolver:RESOLVER} by {query}" \
  --data-urlencode "from=$AFTER_START" --data-urlencode "to=$AFTER_END" > /tmp/${RESOLVER}_after_p99.json &

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=p50:ct.consumer.graphql.latency.ms.distribution{resolver:RESOLVER} by {query}" \
  --data-urlencode "from=$BEFORE_START" --data-urlencode "to=$BEFORE_END" > /tmp/${RESOLVER}_before_p50.json &

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=p50:ct.consumer.graphql.latency.ms.distribution{resolver:RESOLVER} by {query}" \
  --data-urlencode "from=$AFTER_START" --data-urlencode "to=$AFTER_END" > /tmp/${RESOLVER}_after_p50.json &

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=p90:ct.consumer.graphql.latency.ms.distribution{resolver:RESOLVER} by {query}" \
  --data-urlencode "from=$BEFORE_START" --data-urlencode "to=$BEFORE_END" > /tmp/${RESOLVER}_before_p90.json &

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=p90:ct.consumer.graphql.latency.ms.distribution{resolver:RESOLVER} by {query}" \
  --data-urlencode "from=$AFTER_START" --data-urlencode "to=$AFTER_END" > /tmp/${RESOLVER}_after_p90.json &

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=sum:ct.consumer.graphql.latency.ms.distribution{resolver:RESOLVER} by {query}.as_count()" \
  --data-urlencode "from=$BEFORE_START" --data-urlencode "to=$BEFORE_END" > /tmp/${RESOLVER}_before_count.json &

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=sum:ct.consumer.graphql.latency.ms.distribution{resolver:RESOLVER} by {query}.as_count()" \
  --data-urlencode "from=$AFTER_START" --data-urlencode "to=$AFTER_END" > /tmp/${RESOLVER}_after_count.json &

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=sum:ct.consumer.graphql.error.count{resolver:RESOLVER}.as_count()" \
  --data-urlencode "from=$BEFORE_START" --data-urlencode "to=$BEFORE_END" > /tmp/${RESOLVER}_before_errors.json &

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=sum:ct.consumer.graphql.error.count{resolver:RESOLVER}.as_count()" \
  --data-urlencode "from=$AFTER_START" --data-urlencode "to=$AFTER_END" > /tmp/${RESOLVER}_after_errors.json &

wait
echo "Queries complete for ${RESOLVER}"
```

### Step 4: Parse and Display Results

For each resolver, parse its temp files and display a table with the resolver name as header.

**Output format (MUST follow exactly):**

```
============================================================
Performance Impact: PR #27416
PR Title: perf: Optimize price history lookup with VALUES join
Merged: 2026-01-07T19:28:46Z
Window: 24h pre-merge / 24h post-merge
============================================================

## performancehistory

+-------------------+-----------+-----------+-----------+
| Metric            | Pre-PR    | Post-PR   | Impact    |
+-------------------+-----------+-----------+-----------+
| avg latency       |  555.2ms  |  407.1ms  |   -26.7%  |
| p50 latency       |  338.0ms  |  289.0ms  |   -14.5%  |
| p90 latency       |  812.0ms  |  520.0ms  |   -36.0%  |
| p99 latency       |  990.0ms  |  596.0ms  |   -39.8%  |
| request count     |    1.2M   |    1.1M   |           |
| error count       |      0    |      0    |      N/A  |
+-------------------+-----------+-----------+-----------+
Verdict: PR improved avg by 27%, p99 by 40%

## portfolio

+-------------------+-----------+-----------+-----------+
| Metric            | Pre-PR    | Post-PR   | Impact    |
+-------------------+-----------+-----------+-----------+
| avg latency       |  164.3ms  |  151.1ms  |    -8.1%  |
| p50 latency       |  120.0ms  |  115.0ms  |    -4.2%  |
| p90 latency       |  280.0ms  |  260.0ms  |    -7.1%  |
| p99 latency       |  450.0ms  |  420.0ms  |    -6.7%  |
| request count     |  800.0K   |  750.0K   |           |
| error count       |      0    |      0    |      N/A  |
+-------------------+-----------+-----------+-----------+
Verdict: No significant change

============================================================
Summary (only if multiple resolvers)
============================================================
| Resolver           | Avg Impact | p99 Impact | Verdict     |
|--------------------|------------|------------|-------------|
| performancehistory |    -26.7%  |    -39.8%  | Improved    |
| portfolio          |     -8.1%  |     -6.7%  | No change   |

Dashboard: https://app.datadoghq.com/dashboard/52w-7p4-q8a
```

**IMPORTANT:** Each resolver MUST have its own complete table with ALL 6 metric rows (avg, p50, p90, p99, request count, error count). Do NOT condense into a summary-only format.

**Python parsing reference:**

```python
import json

def parse_metric(filepath):
    with open(filepath) as f:
        data = json.load(f)
    if not data.get('series'):
        return None
    total_sum, total_count = 0, 0
    for series in data['series']:
        points = [p[1] for p in series['pointlist'] if p[1] is not None]
        total_sum += sum(points)
        total_count += len(points)
    return total_sum / total_count if total_count else None

def parse_count(filepath):
    with open(filepath) as f:
        data = json.load(f)
    if not data.get('series'):
        return 0
    return sum(sum(p[1] for p in s['pointlist'] if p[1]) for s in data['series'])

def get_resolver_metrics(resolver):
    return {
        'before_avg': parse_metric(f'/tmp/{resolver}_before_avg.json'),
        'after_avg': parse_metric(f'/tmp/{resolver}_after_avg.json'),
        'before_p50': parse_metric(f'/tmp/{resolver}_before_p50.json'),
        'after_p50': parse_metric(f'/tmp/{resolver}_after_p50.json'),
        'before_p90': parse_metric(f'/tmp/{resolver}_before_p90.json'),
        'after_p90': parse_metric(f'/tmp/{resolver}_after_p90.json'),
        'before_p99': parse_metric(f'/tmp/{resolver}_before_p99.json'),
        'after_p99': parse_metric(f'/tmp/{resolver}_after_p99.json'),
        'before_count': parse_count(f'/tmp/{resolver}_before_count.json'),
        'after_count': parse_count(f'/tmp/{resolver}_after_count.json'),
        'before_errors': parse_count(f'/tmp/{resolver}_before_errors.json'),
        'after_errors': parse_count(f'/tmp/{resolver}_after_errors.json'),
    }

# For each resolver, get metrics and print table with resolver header
for resolver in resolvers:
    metrics = get_resolver_metrics(resolver)
    print(f"\n## {resolver}\n")
    # Print table and verdict...
```

## Reading the Results

- **Green (-X%)**: PR improved latency or reduced errors
- **Yellow (+X%)**: PR may have regressed latency or increased errors - investigate
- Request counts vary due to time window differences (pre-merge window is full, post-merge may be partial)

## Error Handling

- PR not merged: "PR #X has not been merged yet"
- No metrics data: "No metrics data found for resolver X in the specified time window"
- Missing credentials: "Datadog credentials not found in ~/.dogrc"
