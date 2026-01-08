# Output Format

The `measure_impact.sh` script outputs formatted markdown directly.

Just print the script output - no additional formatting needed.

## Example Output

```markdown
**Window:** 24h before / 14h after merge

## pricehistoryusd

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| avg | 63ms | 55ms | **-13%** |
| p50 | 58ms | 51ms | **-11%** |
| p90 | 111ms | 107ms | -4% |
| p99 | 108ms | 76ms | **-30%** |

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
| portfolio | -6% | **-16%** |

[Dashboard](https://app.datadoghq.com/dashboard/52w-7p4-q8a)
```
