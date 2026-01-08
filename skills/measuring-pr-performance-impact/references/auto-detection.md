# Auto-Detection: Finding Affected Resolvers

When user doesn't specify resolvers, use keyword matching to find likely candidates.

## Step 1: Get valid resolver names from Datadog (REQUIRED FIRST)

**YOU MUST run this script BEFORE any code analysis:**

```bash
~/.claude/skills/measuring-pr-performance-impact/scripts/list_resolvers.sh
```

This returns the ONLY valid resolver names that exist in Datadog metrics. Save this list - you'll match against it in Step 2.

**IMPORTANT:** Do NOT guess resolver names from code - they won't match Datadog metrics.

## Step 2: Extract keywords and match resolvers

Extract keywords from changed file paths:
1. Split paths on `/` and `_`
2. Remove common words: `app`, `models`, `core`, `tests`, `test`, `py`, `graphql`
3. Keep meaningful terms (e.g., `price`, `history`, `portfolio`, `performance`)

Match keywords against resolver list:
- A resolver is a candidate if it **contains** any keyword
- Example: keyword `history` matches `pricehistory`, `performancehistory`

**Examples:**

| Changed file | Keywords | Matching resolvers |
|--------------|----------|-------------------|
| `app/models/price_history.py` | `price`, `history` | `pricehistory`, `performancehistory` |
| `app/core/portfolio/metrics.py` | `portfolio`, `metrics` | `portfolio` |
| `app/graphql/account/schema.py` | `account`, `schema` | `account` |

## Step 3: Confirm with user

Use `AskUserQuestion` with multi-select to confirm:

```json
{
  "questions": [{
    "question": "Which resolvers do you want to measure?",
    "header": "Resolvers",
    "multiSelect": true,
    "options": [
      {"label": "performancehistory", "description": "Matches keywords: price, history"},
      {"label": "pricehistory", "description": "Matches keywords: price, history"}
    ]
  }]
}
```

**Rules:**
- Each option MUST be a specific resolver name from Step 1
- Do NOT add meta-options like "All resolvers" or "None"
- Max 4 options (most likely candidates first)
- Include which keywords matched in the description

## Optional: Import tracing for additional context

If keyword matching gives too many candidates, trace imports to narrow down:

```bash
# Find what imports the changed file
grep -r "from app\.models\.price_history\|import.*price_history" app/ --include="*.py" -l
```

This helps identify which parts of the codebase actually use the changed code.
