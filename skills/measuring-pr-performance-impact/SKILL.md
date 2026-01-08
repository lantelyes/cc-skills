---
name: measuring-pr-performance-impact
description: Measures GraphQL resolver latency changes before/after a PR merge using Datadog metrics. Use when analyzing PR performance impact, measuring latency changes, or comparing resolver performance before and after a code change.
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

   Outputs JSON array with `window.hours_before` and `window.hours_after` for each resolver.

4. **Format output** - See [references/output-format.md](references/output-format.md)
   - **IMPORTANT:** Each resolver gets its own table with `## resolver_name` heading
   - Do NOT combine all resolvers into one table

## Error handling
- PR not merged: "PR #X has not been merged yet"
- PR not found: "PR #X not found or no access"
- No data: "No metrics found for resolver X"
- Missing creds: "Datadog credentials not found in ~/.dogrc"
