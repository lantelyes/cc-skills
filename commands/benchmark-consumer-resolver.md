---
description: Measure how a PR affected GraphQL resolver latency in production.
allowed-tools: Bash, Read
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
- `--resolver <name>` (optional): Resolver name to benchmark (e.g., `performancehistory`)
- `--window <hours>` (optional, default: 24): Hours before/after merge to compare

If `--resolver` not specified, examine the PR's changed files and title to infer which resolver(s) are most likely affected.

## Workflow

### Step 1: Get PR Details

```bash
gh pr view <PR_NUMBER> --json mergedAt,files,title --repo coin-tracker/coin-tracker-server
```

Extract `mergedAt` timestamp. If not merged, report: "PR #X has not been merged yet"

### Step 2: Query All Metrics in Parallel

Run this single bash block to fetch all metrics in parallel:

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

# Query all metrics in parallel
curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=avg:ct.consumer.graphql.latency.ms.distribution{resolver:RESOLVER} by {query}" \
  --data-urlencode "from=$BEFORE_START" --data-urlencode "to=$BEFORE_END" > /tmp/before_avg.json &

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=avg:ct.consumer.graphql.latency.ms.distribution{resolver:RESOLVER} by {query}" \
  --data-urlencode "from=$AFTER_START" --data-urlencode "to=$AFTER_END" > /tmp/after_avg.json &

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=p99:ct.consumer.graphql.latency.ms.distribution{resolver:RESOLVER} by {query}" \
  --data-urlencode "from=$BEFORE_START" --data-urlencode "to=$BEFORE_END" > /tmp/before_p99.json &

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=p99:ct.consumer.graphql.latency.ms.distribution{resolver:RESOLVER} by {query}" \
  --data-urlencode "from=$AFTER_START" --data-urlencode "to=$AFTER_END" > /tmp/after_p99.json &

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=p50:ct.consumer.graphql.latency.ms.distribution{resolver:RESOLVER} by {query}" \
  --data-urlencode "from=$BEFORE_START" --data-urlencode "to=$BEFORE_END" > /tmp/before_p50.json &

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=p50:ct.consumer.graphql.latency.ms.distribution{resolver:RESOLVER} by {query}" \
  --data-urlencode "from=$AFTER_START" --data-urlencode "to=$AFTER_END" > /tmp/after_p50.json &

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=p90:ct.consumer.graphql.latency.ms.distribution{resolver:RESOLVER} by {query}" \
  --data-urlencode "from=$BEFORE_START" --data-urlencode "to=$BEFORE_END" > /tmp/before_p90.json &

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=p90:ct.consumer.graphql.latency.ms.distribution{resolver:RESOLVER} by {query}" \
  --data-urlencode "from=$AFTER_START" --data-urlencode "to=$AFTER_END" > /tmp/after_p90.json &

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=sum:ct.consumer.graphql.latency.ms.distribution{resolver:RESOLVER} by {query}.as_count()" \
  --data-urlencode "from=$BEFORE_START" --data-urlencode "to=$BEFORE_END" > /tmp/before_count.json &

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=sum:ct.consumer.graphql.latency.ms.distribution{resolver:RESOLVER} by {query}.as_count()" \
  --data-urlencode "from=$AFTER_START" --data-urlencode "to=$AFTER_END" > /tmp/after_count.json &

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=sum:ct.consumer.graphql.error.count{resolver:RESOLVER}.as_count()" \
  --data-urlencode "from=$BEFORE_START" --data-urlencode "to=$BEFORE_END" > /tmp/before_errors.json &

curl -s "https://api.datadoghq.com/api/v1/query" \
  -H "DD-API-KEY: ${DD_apikey}" -H "DD-APPLICATION-KEY: ${DD_appkey}" -G \
  --data-urlencode "query=sum:ct.consumer.graphql.error.count{resolver:RESOLVER}.as_count()" \
  --data-urlencode "from=$AFTER_START" --data-urlencode "to=$AFTER_END" > /tmp/after_errors.json &

wait
echo "All queries complete"
```

### Step 3: Parse and Display Results

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

def fmt_ms(v): return f"{v:.1f}ms" if v else "N/A"
def fmt_count(v): return f"{v/1e6:.2f}M" if v >= 1e6 else f"{v/1e3:.1f}K" if v >= 1e3 else str(int(v))
def fmt_impact(b, a):
    if not b or not a or b == 0: return "N/A", 0
    pct = ((a - b) / b) * 100
    color = "\033[32m" if pct < 0 else "\033[33m" if pct > 10 else ""
    reset = "\033[0m" if color else ""
    sign = "" if pct < 0 else "+"
    return f"{color}{sign}{pct:.1f}%{reset}", pct

before_avg = parse_metric('/tmp/before_avg.json')
after_avg = parse_metric('/tmp/after_avg.json')
before_p50 = parse_metric('/tmp/before_p50.json')
after_p50 = parse_metric('/tmp/after_p50.json')
before_p90 = parse_metric('/tmp/before_p90.json')
after_p90 = parse_metric('/tmp/after_p90.json')
before_p99 = parse_metric('/tmp/before_p99.json')
after_p99 = parse_metric('/tmp/after_p99.json')
before_count = parse_count('/tmp/before_count.json')
after_count = parse_count('/tmp/after_count.json')
before_errors = parse_count('/tmp/before_errors.json')
after_errors = parse_count('/tmp/after_errors.json')

avg_impact, avg_pct = fmt_impact(before_avg, after_avg)
p50_impact, p50_pct = fmt_impact(before_p50, after_p50)
p90_impact, p90_pct = fmt_impact(before_p90, after_p90)
p99_impact, p99_pct = fmt_impact(before_p99, after_p99)
err_impact, err_pct = fmt_impact(before_errors, after_errors) if before_errors else ("N/A", 0)

# Generate verdict
improvements = []
regressions = []
if avg_pct < -5: improvements.append(f"avg by {abs(avg_pct):.0f}%")
elif avg_pct > 10: regressions.append(f"avg by {avg_pct:.0f}%")
if p99_pct < -5: improvements.append(f"p99 by {abs(p99_pct):.0f}%")
elif p99_pct > 10: regressions.append(f"p99 by {p99_pct:.0f}%")
if err_pct < -10: improvements.append(f"errors by {abs(err_pct):.0f}%")
elif err_pct > 10: regressions.append(f"errors by {err_pct:.0f}%")

if improvements and not regressions:
    verdict = f"\033[32mPR improved {', '.join(improvements)}\033[0m"
elif regressions and not improvements:
    verdict = f"\033[33mPR regressed {', '.join(regressions)} - investigate\033[0m"
elif improvements and regressions:
    verdict = f"Mixed: improved {', '.join(improvements)}, regressed {', '.join(regressions)}"
else:
    verdict = "No significant change detected"

print(f"""
{'=' * 60}
Performance Impact: PR #<NUMBER>
Resolver: <RESOLVER>
{'=' * 60}

PR Title: <TITLE>
Merged:   <MERGED_AT>
Window:   <WINDOW>h pre-merge / <ACTUAL_AFTER>h post-merge

+-------------------+-----------+-----------+-----------+
| Metric            | Pre-PR    | Post-PR   | Impact    |
+-------------------+-----------+-----------+-----------+
| avg latency       | {fmt_ms(before_avg):>9} | {fmt_ms(after_avg):>9} | {avg_impact:>9} |
| p50 latency       | {fmt_ms(before_p50):>9} | {fmt_ms(after_p50):>9} | {p50_impact:>9} |
| p90 latency       | {fmt_ms(before_p90):>9} | {fmt_ms(after_p90):>9} | {p90_impact:>9} |
| p99 latency       | {fmt_ms(before_p99):>9} | {fmt_ms(after_p99):>9} | {p99_impact:>9} |
| request count     | {fmt_count(before_count):>9} | {fmt_count(after_count):>9} | {'':>9} |
| error count       | {fmt_count(before_errors):>9} | {fmt_count(after_errors):>9} | {err_impact:>9} |
+-------------------+-----------+-----------+-----------+

Verdict: {verdict}

Dashboard: https://app.datadoghq.com/dashboard/52w-7p4-q8a
""")
```

## Reading the Results

- **Green (-X%)**: PR improved latency or reduced errors
- **Yellow (+X%)**: PR may have regressed latency or increased errors - investigate
- Request counts vary due to time window differences (pre-merge window is full, post-merge may be partial)

## Error Handling

- PR not merged: "PR #X has not been merged yet"
- No metrics data: "No metrics data found for resolver X in the specified time window"
- Missing credentials: "Datadog credentials not found in ~/.dogrc"
