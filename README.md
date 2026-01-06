# cc-skills

Sync [Claude Code](https://claude.com/claude-code) configuration across machines via git.

## Quick Start

```bash
git clone https://github.com/lantelyes/cc-skills.git ~/code/cc-skills
~/code/cc-skills/ccsync install
```

## Commands

| Command | Description |
|---------|-------------|
| `ccsync install` | Symlink repo files into `~/.claude/` and add ccsync to PATH |
| `ccsync update` | Pull from git and reinstall |
| `ccsync push [msg]` | Commit and push changes |
| `ccsync status` | Show git status and linked files |
| `ccsync add <path>` | Add a file from `~/.claude/` to the repo |

## How It Works

The repo structure mirrors `~/.claude/`. When you run `ccsync install`, each file/directory in the repo gets symlinked to the corresponding location in `~/.claude/`.

```
cc-skills/                    ~/.claude/
├── commands/                 ├── commands/
│   └── codex-review.md  -->  │   └── codex-review.md (symlink)
└── settings.json        -->  └── settings.json (symlink)
```

Only files you explicitly commit are synced. Machine-specific data (history, todos, debug logs) stays local.

## Syncing Across Machines

**After editing configs:**
```bash
ccsync push "Add new skill"
```

**On other machines:**
```bash
ccsync update
```

## Adding New Files

To add a file from your existing Claude Code config:

```bash
ccsync add commands/my-new-skill.md
ccsync push "Add my-new-skill"
```

## Skills

- **codex-review** - Run OpenAI Codex CLI review against a base branch, verify findings, and summarize results
