---
name: measuring-pr-performance-impact
description: Measures GraphQL resolver latency changes before/after a PR merge using Datadog metrics. Use when analyzing PR performance impact, measuring latency changes, or comparing resolver performance before and after a code change.
---

# Measure PR Performance Impact

Compare GraphQL resolver latency before/after a PR merge.

## When to use
- "How did PR 27416 affect performance?"
- "Measure the performance impact of PR 27416"
- "Did this PR regress latency?"

## CRITICAL: Always Use Bundled Scripts

**YOU MUST use the bundled scripts for all operations.** Do NOT use gh CLI or curl commands directly.

Scripts are located at: `~/.claude/skills/measuring-pr-performance-impact/scripts/`

## Workflow

1. **Get PR info** - MUST use script:
   ```bash
   ~/.claude/skills/measuring-pr-performance-impact/scripts/get_pr_info.sh <pr_number>
   ```
   Returns JSON with `title`, `mergedAt`, `mergedAtEpoch`, `files`

2. **Determine resolvers** (if not specified by user)
   - See [Auto-Detection](#auto-detection) below

3. **Measure impact** - MUST use script (supports comma-separated resolvers):
   ```bash
   ~/.claude/skills/measuring-pr-performance-impact/scripts/measure_impact.sh <resolver[,resolver2,...]> <merged_epoch> [window_hours]
   ```
   Outputs JSON array with before/after metrics for each resolver.

4. **Format output** - See [references/output-format.md](references/output-format.md)

## Auto-Detection

When user doesn't specify resolvers, trace the dependency chain from changed files to GraphQL resolvers.

### Step 1: Get valid resolver names from Datadog
```bash
~/.claude/skills/measuring-pr-performance-impact/scripts/list_resolvers.sh
```
Returns list of all resolver names with recent data. **ONLY use names from this list.**

### Step 2: Trace dependency chain (IMPORTANT)

Changed files often affect resolvers **indirectly** through intermediate layers. You MUST trace the full chain:

```
Changed file (app/models/, app/core/)
    ↓ imported by
Intermediate modules (app/core/*, app/services/*)
    ↓ imported by
GraphQL schemas (app/graphql/*/schema.py)
    ↓ defines
Resolver names (lowercase, no underscores)
```

**Example for `app/models/price_history.py`:**
1. Find what imports price_history in app/core:
   ```bash
   grep -r "from app\.models\.price_history\|from app\.models import.*price_history\|import.*price_history" app/core/ --include="*.py" -l
   ```
2. For each result (e.g., `app/core/performance/`), find what GraphQL schemas import from it:
   ```bash
   grep -r "from app\.core\.performance\|import.*app\.core\.performance" app/graphql/ --include="*.py" -l
   ```
3. Look at those schema files for resolver definitions (look for `@tracer.wrap(resource="resolver_*")` or field names)

### Step 3: Map schema files to resolver names

In this codebase, resolvers are defined in `schema.py` files, not separate folders. Look for:
- `@tracer.wrap(resource="resolver_<name>")` decorators
- Field names like `performance_history` → resolver is `performancehistory`
- The folder name often hints at resolvers: `app/graphql/portfolio/` → likely `portfolio` resolver

### Step 4: Cross-reference with Datadog

Only use resolver names that exist in the list from Step 1. Common resolvers:
- `portfolio` - Portfolio summary
- `performancehistory` - Performance history data
- `pricehistory` - Price history lookups

### Step 5: Confirm with user
Before measuring, confirm: "Based on the changed files, these resolvers may be affected: [list]. Should I measure all of them?"

## Error handling
- PR not merged: "PR #X has not been merged yet"
- No data: "No metrics found for resolver X"
- Missing creds: "Datadog credentials not found in ~/.dogrc"
