# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a collection of Claude Code custom skills (slash commands). Each `.md` file at the repo root is a skill that can be installed into `~/.claude/commands/`.

## Skill File Format

Skills use markdown with YAML frontmatter:

```markdown
---
description: "Short description shown in skill picker"
allowed-tools: Bash, Read  # Optional: restrict which tools the skill can use
argument-hint: --flag <value>  # Optional: hint for arguments
---

# Skill Title

Instructions for Claude to follow when the skill is invoked.
$ARGUMENTS contains any arguments passed by the user.
```

## Adding New Skills

1. Create a new `.md` file at the repo root
2. Include YAML frontmatter with at least a `description`
3. Update README.md with the new skill under "Available Skills"
