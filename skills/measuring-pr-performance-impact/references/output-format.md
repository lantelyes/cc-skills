# Output Format

Tables only. No verbose analysis. Bold changes >20%.

```markdown
# Performance Impact: PR #27416

**PR Title:** <title>
**Merged:** <timestamp>
**Window:** <hours_before>h before / <hours_after>h after merge

## performancehistory

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| avg | 543ms | 253ms | **-53%** |
| p50 | 338ms | 289ms | -14% |
| p90 | 812ms | 520ms | **-36%** |
| p99 | 990ms | 596ms | **-40%** |
| requests | 135K | 82K | |
| errors | 0 | 0 | |

## portfolio

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| avg | 80ms | 236ms | +194% |
| p50 | 140ms | 148ms | +6% |
| p90 | 160ms | 155ms | -3% |
| p99 | 527ms | 442ms | -16% |
| requests | 101K | 88K | |
| errors | 0 | 0 | |

## Summary

| Resolver | Avg | p99 | Verdict |
|----------|-----|-----|---------|
| performancehistory | **-53%** | **-40%** | Improved |
| portfolio | +194% | -16% | Mixed |

[Dashboard](https://app.datadoghq.com/dashboard/52w-7p4-q8a)
```
