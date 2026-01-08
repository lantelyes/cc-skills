# Claude Code Skills

A collection of custom skills for [Claude Code](https://claude.com/claude-code).

## Installation

Copy or symlink any skill file into your Claude Code commands directory:

```bash
# Option 1: Copy a skill
cp codex-review.md ~/.claude/commands/

# Option 2: Symlink (for easy updates via git pull)
ln -s /path/to/cc-skills/codex-review.md ~/.claude/commands/
```

## Available Skills

### codex-review

Run OpenAI Codex CLI review against a base branch, verify findings, and summarize results.

**Usage:** `/codex-review` or `/codex-review main`

Runs `codex review --base <branch>`, then manually verifies each finding by examining code and tracing data flow. Produces a structured summary with severity levels (Critical, High, Medium, Low, False Positive).

### benchmark-consumer-resolver

Compare GraphQL resolver latency before/after a PR merge using Datadog metrics.

**Usage:** `/benchmark-consumer-resolver --pr <number> [--resolver <name>] [--window <hours>]`

Queries Datadog for resolver latency metrics (avg, p50, p99) before and after a PR merge. Auto-detects affected resolvers from changed files if not specified. Outputs a comparison table showing performance impact.
