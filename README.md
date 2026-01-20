# Buntoolbox

> **Bun** + **Ubuntu** + **Toolbox** = 全能开发环境 Docker 镜像

**Ideal for Windows users with WSL disabled by enterprise policy** - provides a complete Linux development environment via Docker.

## 包含组件

- **运行时**: Bun, Node.js 24, Python 3.14 (pip/uv/pipx)
- **JDK**: Azul Zulu 25 headless
- **基础镜像**: Ubuntu 24.04 LTS
- **常用工具**: git, gh, jq, ripgrep, fd, fzf, tmux, zellij, lazygit, helix, bat, eza, delta, btop, starship, zoxide, bd, mihomo, sshd, openvscode-server, jdtls 等

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

### SSH Access (Remote Development)

```powershell
# Run container with SSH port exposed (default password: root)
docker run -d -p 2222:22 --name mydev-ssh cuipengfei/buntoolbox:latest /usr/sbin/sshd -D

# Connect via SSH
ssh -p 2222 root@localhost

# Or use with VS Code Remote-SSH extension
# Add to ~/.ssh/config:
#   Host docker-dev
#     HostName localhost
#     Port 2222
#     User root
```

### OpenVSCode Server (Browser-based VS Code)

```powershell
# Quick start (default port 3000, no authentication)
docker run -d -p 3000:3000 --name mydev-web cuipengfei/buntoolbox:latest openvscode-start

# Custom port
docker run -d -p 8080:8080 --name mydev-web cuipengfei/buntoolbox:latest openvscode-start 8080

# With connection token for security
docker run -d -p 3000:3000 --name mydev-web cuipengfei/buntoolbox:latest \
  openvscode-server --host 0.0.0.0 --port 3000 --connection-token mypassword

# Visit http://localhost:3000 in your browser
# Full VS Code experience in the browser, no installation needed!
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
