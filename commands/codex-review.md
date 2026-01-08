---
description: Run OpenAI Codex CLI review against a base branch, verify findings, and summarize results
allowed-tools: Read, Glob, Grep, Bash(git:*), Bash(codex:*)
argument-hint: [base-branch]
---

# Codex Review

Review current branch against a base branch using OpenAI Codex CLI, verify each finding, and summarize.

## Context

- **Current branch:** !`git branch --show-current`
- **Default branch:** !`git rev-parse --abbrev-ref origin/HEAD 2>/dev/null`

If default branch shows "origin/main" or "origin/master", use the part after "origin/".

## Run Review

```bash
codex review --base ${ARGUMENTS:-<default-branch-from-above>}
```

## Verify Each Finding

For each finding from Codex:
1. Read the relevant code
2. Trace data flow to check if the issue is reachable
3. Check for existing safeguards (validation, types, etc.)
4. Assign severity: **Critical**, **High**, **Medium**, **Low**, or **False Positive**

## Output Format

```markdown
# Codex Review: <current-branch> → <base-branch>

| # | Finding | File | Severity | Verdict |
|---|---------|------|----------|---------|
| 1 | Brief title | path:lines | **Critical** | Valid |
| 2 | Brief title | path:lines | **High** | Valid |
| 3 | Brief title | path:lines | Medium | False Positive |
| 4 | Brief title | path:lines | Low | False Positive |

### Finding 1: <title>
**Codex:** <what codex reported>
**Analysis:** <your verification>
**Action:** <recommendation>

### Finding 2: ...

---

**Verdict:** Safe to merge / X blocking issues require attention
```

Use **bold** for Critical and High severity levels.

## Severity Guide

- **Critical**: Security vulnerability, data loss risk
- **High**: Correctness bug affecting users
- **Medium**: Edge case bug, performance issue
- **Low**: Code smell, minor issue
- **False Positive**: Not actually a problem
