# Output Format

**IMPORTANT:**
- Each resolver gets its OWN separate table with a `## resolver_name` heading
- End with a Summary table
- NO verbose analysis, commentary, or conclusions - JUST tables

Bold changes >10%.

```markdown
# Performance Impact: PR #27416

**Title:** <title>
**Merged:** <timestamp>
**Window:** 24h before / 14h after

## pricehistoryusd

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| avg | 63ms | 55ms | **-13%** |
| p50 | 58ms | 51ms | **-11%** |
| p90 | 111ms | 107ms | -4% |
| p99 | 108ms | 76ms | **-30%** |

## performancehistory

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| avg | 378ms | 409ms | +8% |
| p50 | 4ms | 5ms | +32% |
| p90 | 736ms | 551ms | **-25%** |
| p99 | 818ms | 598ms | **-27%** |

## portfolio

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| avg | 77ms | 72ms | -6% |
| p50 | 141ms | 148ms | +5% |
| p90 | 161ms | 154ms | -4% |
| p99 | 527ms | 440ms | **-16%** |

## Summary

| Resolver | Avg | p99 |
|----------|-----|-----|
| pricehistoryusd | **-13%** | **-30%** |
| performancehistory | +8% | **-27%** |
| portfolio | -6% | **-16%** |

[Dashboard](https://app.datadoghq.com/dashboard/52w-7p4-q8a)
```
