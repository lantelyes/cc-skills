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

2. **Determine resolvers**

   **If user specified a resolver:** Validate it exists
   - Run `list_resolvers.sh` to get valid resolver names
   - Check if specified resolver exists (case-insensitive)
   - If not found: Use `AskUserQuestion` to suggest close matches (resolvers containing similar substrings)
   - Example: "Resolver 'pricehistry' not found. Did you mean one of these?"

   **If user did NOT specify a resolver:** Auto-detect
   - See [references/auto-detection.md](references/auto-detection.md)

3. **Measure impact** - MUST use script (supports comma-separated resolvers):
   ```bash
   ~/.claude/skills/measuring-pr-performance-impact/scripts/measure_impact.sh <resolver[,resolver2,...]> <merged_epoch> [window_hours]
   ```

   **Window parameter:**
   - Default: `12` (12 hours before and after merge)
   - Common values: `12` (12h), `24` (1 day), `168` (1 week)
   - If PR was recently merged, "after" window will be truncated to now

   Outputs pre-formatted output with Unicode box drawing and aligned columns.

4. **Display output** - Your response should be ONLY:

   a. One line with PR title and merge time
   b. The script output EXACTLY as-is (no code block needed - just paste it directly)

   **DO NOT ADD:**
   - "Key findings" or analysis
   - Your own summary or commentary
   - Reformatted tables
   - Any text after the script output

   The script output is self-explanatory and beautifully formatted. Let it speak for itself.

## Error handling
- PR not merged: "PR #X has not been merged yet"
- PR not found: "PR #X not found or no access"
- No data: "No metrics found for resolver X"
- Missing creds: "Datadog credentials not found in ~/.dogrc"
