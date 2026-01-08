# Output Format

## CRITICAL: Separate Tables Per Resolver

**DO NOT put all resolvers in one combined table.**

Each resolver MUST have its own `## heading` and its own table.

### WRONG (do not do this):

```markdown
| Resolver | Metric | Before | After | Change |
|----------|--------|--------|-------|--------|
| pricehistoryusd | avg | 63ms | 55ms | -13% |
| pricehistoryusd | p50 | 58ms | 51ms | -11% |
| portfolio | avg | 77ms | 72ms | -6% |
```

### CORRECT (do this):

```markdown
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
```

## Full Template

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

## Rules
- Bold changes >10%
- NO verbose analysis or commentary
- Just tables and summary
