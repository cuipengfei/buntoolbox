# GitHub Copilot Instructions for Buntoolbox

## Project Overview

Buntoolbox 是一个全能开发环境 Docker 镜像，基于 Ubuntu，集成多种运行时和开发工具。

**Key Features:**
- 多 JDK 版本支持 (Azul Zulu 11, 17, 21)
- 现代 JS 运行时 (Bun, Node.js)
- Python 开发环境
- 常用开发工具集

## Tech Stack

- **Base Image**: Ubuntu
- **JDK**: Azul Zulu (11, 17, 21)
- **JS Runtime**: Bun, Node.js
- **Python**: Latest stable

## Build Commands

```bash
# Build image
docker build -t buntoolbox .

# Run container
docker run -it buntoolbox
```

## Issue Tracking with bd

**CRITICAL**: This project uses **bd** for ALL task tracking. Do NOT create markdown TODO lists.

### Essential Commands

```bash
# Find work
bd ready --json                    # Unblocked issues

# Create and manage
bd create "Title" -t bug|feature|task -p 0-4 --json
bd update <id> --status in_progress --json
bd close <id> --reason "Done" --json

# Search
bd list --status open --priority 1 --json
bd show <id> --json
```

### Workflow

1. **Check ready work**: `bd ready --json`
2. **Claim task**: `bd update <id> --status in_progress`
3. **Work on it**: Implement, test, document
4. **Discover new work?** `bd create "Found bug" -p 1 --deps discovered-from:<parent-id> --json`
5. **Complete**: `bd close <id> --reason "Done" --json`

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

## Project Structure

```
buntoolbox/
├── Dockerfile           # Main build file
├── .beads/
│   └── issues.jsonl     # Git-synced issue storage
├── CLAUDE.md            # Claude Code instructions
├── AGENTS.md            # AI agent workflow guide
└── README.md            # User documentation
```

## Important Rules

- Use bd for ALL task tracking
- Always use `--json` flag for programmatic use
- Do NOT create markdown TODO lists
- Commit `.beads/issues.jsonl` with code changes

---

**For detailed workflows, see [AGENTS.md](../AGENTS.md)**
