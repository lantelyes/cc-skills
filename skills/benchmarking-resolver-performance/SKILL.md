---
name: benchmarking-resolver-performance
description: Measures GraphQL resolver latency changes before/after a PR merge using Datadog metrics. Use when analyzing PR performance impact, benchmarking resolvers, or comparing latency before and after a code change.
---

# Benchmark Resolver Performance

Compare GraphQL resolver latency before/after a PR merge.

## When to use
- "How did PR 27416 affect performance?"
- "Benchmark the performancehistory resolver for PR 27416"
- "Did this PR regress latency?"

## Workflow

1. **Get PR info**
   ```bash
   ./scripts/get_pr_info.sh <pr_number>
   ```
   Returns JSON with `title`, `mergedAt`, `mergedAtEpoch`, `files`

2. **Run benchmark**
   ```bash
   ./scripts/benchmark.sh <resolver> <merged_epoch> [window_hours]
   ```
   Queries all metrics, parses results, outputs JSON with before/after values.

3. **Format output** - See [references/output-format.md](references/output-format.md)

## Error handling
- PR not merged: "PR #X has not been merged yet"
- No data: "No metrics found for resolver X"
- Missing creds: "Datadog credentials not found in ~/.dogrc"
