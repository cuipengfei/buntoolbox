# Buntoolbox Project Overview

## Purpose
Multi-language development environment Docker image (Ubuntu 24.04 LTS, ~1.8GB). Designed for Windows users with WSL disabled by enterprise policy.

## Tech Stack
- **Base**: Ubuntu 24.04 LTS
- **Java**: Azul Zulu JDK 21 headless
- **JavaScript**: Node.js 24 + Bun
- **Python**: Python 3.12 + uv/pipx
- **Build**: Maven + Gradle
- **CI/CD**: GitHub Actions → Docker Hub

## Key Tools Included
git, gh, jq, ripgrep, fd, fzf, tmux, lazygit, helix, bat, eza, delta, btop, starship, zoxide, procs, bd, mihomo

## Project Structure
```
buntoolbox/
├── Dockerfile           # Main image definition
├── scripts/
│   ├── test-image.sh    # Test image (68 checks)
│   └── check-versions.sh # Check tool version updates
├── .github/workflows/   # GitHub Actions CI/CD
├── .devcontainer/       # VS Code Dev Container config
├── CLAUDE.md            # AI agent instructions
├── AGENTS.md            # Issue tracking with bd (beads)
└── README.md            # User documentation
```

## Dockerfile Architecture
Layer order (stable → volatile): System → JDK → Python → uv/pipx → Maven → gh → Node/Bun → Gradle → TUI → Config

Version management: ARG declarations at top of Dockerfile
