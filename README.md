# Claude Code Skills

A collection of custom skills for [Claude Code](https://claude.com/claude-code).

## Installation

Symlink the `commands/` folder to your Claude Code commands directory:

```bash
ln -s /path/to/cc-skills/commands ~/.claude/commands
```

This gives you all skills at once, and `git pull` automatically updates them.

## Requirements

### codex-review
- [OpenAI Codex CLI](https://github.com/openai/codex) installed and configured

### benchmark-consumer-resolver
- `gh` CLI authenticated (`gh auth login`)
- `~/.dogrc` with Datadog credentials:
  ```
  apikey = your_api_key
  appkey = your_app_key
  ```

## Available Skills

### codex-review

Run OpenAI Codex CLI review against a base branch, verify findings, and summarize results.

**Usage:** `/codex-review` or `/codex-review main`

Runs `codex review --base <branch>`, then manually verifies each finding by examining code and tracing data flow. Produces a structured summary with severity levels (Critical, High, Medium, Low, False Positive).

### benchmark-consumer-resolver

Measure how a PR affected GraphQL resolver latency and errors in production.

**Usage:** `/benchmark-consumer-resolver --pr <number> [--resolver <name>[,<name>...]] [--window <hours>]`

**Examples:**
- Single resolver: `/benchmark-consumer-resolver --pr 27416 --resolver performancehistory`
- Multiple resolvers: `/benchmark-consumer-resolver --pr 27416 --resolver performancehistory,portfolio`
- Auto-detect: `/benchmark-consumer-resolver --pr 27416`

Queries Datadog for resolver metrics (avg, p50, p90, p99, request count, error count) before and after a PR merge. Outputs a comparison table per resolver showing performance impact with a verdict line. When multiple resolvers are analyzed, includes a summary table.
