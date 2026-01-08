# Claude Code Skills

A collection of custom commands and skills for [Claude Code](https://claude.com/claude-code).

## Installation

### Commands (slash commands)

Symlink the `commands/` folder to your Claude Code commands directory:

```bash
ln -s /path/to/cc-skills/commands ~/.claude/commands
```

### Skills (auto-triggered)

Symlink the `skills/` folder to your Claude skills directory:

```bash
ln -s /path/to/cc-skills/skills ~/.claude/skills
```

This gives you all commands and skills at once, and `git pull` automatically updates them.

## Requirements

### codex-review
- [OpenAI Codex CLI](https://github.com/openai/codex) installed and configured

### benchmark-consumer-resolver / measuring-pr-performance-impact
- `gh` CLI authenticated (`gh auth login`)
- `~/.dogrc` with Datadog credentials:
  ```
  apikey = your_api_key
  appkey = your_app_key
  ```

## Available Commands

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

Queries Datadog for resolver metrics (avg, p50, p90, p99, request count, error rate) before and after a PR merge. Outputs a formatted Unicode table per resolver showing before/after comparison with change percentages.

## Available Skills

Skills are auto-triggered based on your request. They include bundled scripts for more reliable execution.

### measuring-pr-performance-impact

Measure how a PR affected GraphQL resolver latency using Datadog metrics.

**Triggers:** "measure PR 27416 performance", "how did PR 27416 affect performance?", "did this PR regress latency?"

**Features:**
- Unicode box-drawn tables with latency metrics (Average, P50, P90, P99)
- Request count and error rate tracking
- Change indicators (↓/↑ arrows with percentages)
- Auto-detects affected resolvers from changed files
- Configurable time window (default 24h)
