# Output Format

Use markdown tables with **bold** for changes >10%.

## Single resolver

```markdown
# Performance Impact: PR #27416

**PR Title:** <title>
**Merged:** <timestamp>
**Window:** 24h pre-merge / 24h post-merge

## <resolver_name>

| Metric | Pre-PR | Post-PR | Impact |
|--------|--------|---------|--------|
| avg latency | 555.2ms | 407.1ms | **-26.7%** |
| p50 latency | 338.0ms | 289.0ms | -14.5% |
| p90 latency | 812.0ms | 520.0ms | **-36.0%** |
| p99 latency | 990.0ms | 596.0ms | **-39.8%** |
| request count | 1.2M | 1.1M | |
| error count | 0 | 0 | N/A |

**Verdict:** PR improved avg by 27%, p99 by 40%
```

## Multiple resolvers

Add summary table at end:

```markdown
## Summary

| Resolver | Avg Impact | p99 Impact | Verdict |
|----------|------------|------------|---------|
| performancehistory | **-26.7%** | **-39.8%** | Improved |
| portfolio | -8.1% | -6.7% | No change |

[Dashboard](https://app.datadoghq.com/dashboard/52w-7p4-q8a)
```
