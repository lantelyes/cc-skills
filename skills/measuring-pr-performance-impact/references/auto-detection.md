# Auto-Detection: Finding Affected Resolvers

When user doesn't specify resolvers, trace the dependency chain from changed files to GraphQL resolvers.

## Step 1: Get valid resolver names from Datadog

```bash
~/.claude/skills/measuring-pr-performance-impact/scripts/list_resolvers.sh
```

Returns list of all resolver names with recent data. **ONLY use names from this list.**

## Step 2: Trace dependency chain

Changed files often affect resolvers **indirectly** through intermediate layers:

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

## Step 3: Map schema files to resolver names

In this codebase, resolvers are defined in `schema.py` files, not separate folders. Look for:
- `@tracer.wrap(resource="resolver_<name>")` decorators
- Field names like `performance_history` → resolver is `performancehistory`
- The folder name often hints at resolvers: `app/graphql/portfolio/` → likely `portfolio` resolver

## Step 4: Cross-reference with Datadog

Only use resolver names that exist in the list from Step 1. Common resolvers:
- `portfolio` - Portfolio summary
- `performancehistory` - Performance history data
- `pricehistory` - Price history lookups

## Step 5: Confirm with user

Use the `AskUserQuestion` tool with multi-select:

```json
{
  "questions": [{
    "question": "Which resolvers do you want to measure?",
    "header": "Resolvers",
    "multiSelect": true,
    "options": [
      {"label": "performancehistory", "description": "Uses price history module"},
      {"label": "portfolio", "description": "Imports from app.core.performance"}
    ]
  }]
}
```

**IMPORTANT:**
- Each option MUST be a specific resolver name (e.g., `performancehistory`, `portfolio`)
- Do NOT add meta-options like "All resolvers", "All of the above", "None", etc.
- Max 4 options (most likely affected resolvers first)
