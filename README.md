# Buntoolbox

> **Bun** + **Ubuntu** + **Toolbox** = 全能开发环境 Docker 镜像

**Ideal for Windows users with WSL disabled by enterprise policy** - provides a complete Linux development environment via Docker.

## 包含组件

- **运行时**: Bun, Node.js 24, Python 3.12
- **JDK**: Azul Zulu 21 headless
- **基础镜像**: Ubuntu 24.04 LTS
- **常用工具**: git, gh, jq, ripgrep, fd, fzf, tmux, lazygit, helix, bat, eza, delta, btop, starship, zoxide, bd, mihomo 等

## 使用方式

### Basic Usage

```bash
docker pull cuipengfei/buntoolbox:latest
docker run -it cuipengfei/buntoolbox
```

### Windows (WSL Disabled) - Project Development

```powershell
# Mount your project folder into the container
docker run -it -v ${PWD}:/workspace -w /workspace cuipengfei/buntoolbox:latest

# With Git credentials sharing
docker run -it -v ${PWD}:/workspace -w /workspace `
  -v ${HOME}/.ssh:/root/.ssh:ro `
  -v ${HOME}/.gitconfig:/root/.gitconfig:ro `
  cuipengfei/buntoolbox:latest
```

### VS Code Dev Containers (Recommended)

1. Install the "Dev Containers" extension in VS Code
2. Clone this repo or copy `.devcontainer/devcontainer.json` to your project
3. Open your project in VS Code
4. Command Palette → "Dev Containers: Reopen in Container"

### Persistent Development Environment

```powershell
# Create a named container that persists between sessions
docker create --name mydev -it -v ${PWD}:/workspace -w /workspace cuipengfei/buntoolbox:latest
docker start -ai mydev

# Later, reconnect to same container with all your state preserved
docker start -ai mydev
```

## 命名由来

| 组合 | 含义 |
|------|------|
| Bun | 现代 JS 运行时 |
| (U)buntu | 稳定的 Linux 基底 |
| Toolbox | 多语言工具箱 |

## Documentation

- [REVIEW.md](REVIEW.md) - Detailed assessment for WSL replacement and tool recommendations
- [CLAUDE.md](CLAUDE.md) - AI agent instructions and project overview
- [AGENTS.md](AGENTS.md) - Issue tracking with bd (beads)

---

*一个镜像，无限可能。*
