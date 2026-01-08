---
name: measuring-pr-performance-impact
description: Measures GraphQL resolver latency changes before/after PR merges. Supports single PR analysis and multi-PR comparison with per-PR attribution.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - AskUserQuestion
---

# Measure PR Performance Impact

Compare GraphQL resolver latency before/after a PR merge.

## When to use
- "How did PR 27416 affect performance?"
- "Measure the performance impact of PR 27416"
- "Did this PR regress latency?"
- "Compare the impact of PRs 27416, 27420, and 27425"
- "Which PR improved performance the most?"

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
   - See [references/auto-detection.md](references/auto-detection.md)

3. **Measure impact** - MUST use script (supports comma-separated resolvers):
   ```bash
   ~/.claude/skills/measuring-pr-performance-impact/scripts/measure_impact.sh <resolver[,resolver2,...]> <merged_epoch> [window_hours]
   ```

   **Window parameter:**
   - Default: `24` (24 hours before and after merge)
   - Common values: `24` (1 day), `168` (1 week), `72` (3 days)
   - If PR was recently merged, "after" window will be truncated to now

   Outputs formatted markdown with separate table per resolver.

4. **Print output** - The script outputs formatted markdown directly. Just print it.

## Error handling
- PR not merged: "PR #X has not been merged yet"
- PR not found: "PR #X not found or no access"
- No data: "No metrics found for resolver X"
- Missing creds: "Datadog credentials not found in ~/.dogrc"

## Comparing Multiple PRs

When analyzing cumulative impact of multiple PRs on a resolver:

```bash
~/.claude/skills/measuring-pr-performance-impact/scripts/compare_prs.sh <resolver> <pr1,pr2,pr3> [window_hours]
```

**Example:**
```bash
~/.claude/skills/measuring-pr-performance-impact/scripts/compare_prs.sh performancehistory 27416,27420,27425 24
```

**Output:** Timeline table showing baseline → each PR's individual contribution → cumulative change.

**Features:**
- PRs are automatically sorted chronologically
- Each PR's impact is measured relative to the previous state
- Overlap detection: Warns if PRs merged < 8h apart (attribution may be unreliable)
