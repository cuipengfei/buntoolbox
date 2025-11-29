# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Note**: This project uses [bd (beads)](https://github.com/steveyegge/beads)
for issue tracking. Use `bd` commands instead of markdown TODOs.
See AGENTS.md for workflow details.

## Project Overview

Buntoolbox 是一个全能开发环境 Docker 镜像，基于 Ubuntu 22.04，支持多语言开发。
镜像通过 GitHub Actions 自动构建并推送到 Docker Hub（支持 amd64/arm64）。

## 技术栈

| 类别 | 组件 |
|:---|:---|
| 基础镜像 | Ubuntu 22.04 LTS |
| JDK | Azul Zulu 11, 17, 21 (默认 21) |
| JS/TS | Node.js 22 LTS, Bun |
| Python | 3.12 + uv/uvx + pipx |
| Go | 1.25.4 |
| Rust | rustup + rustfmt + clippy |
| 构建工具 | Maven, Gradle 9.2.1 |
| 开发工具 | git, gh, jq, ripgrep, fd, fzf, tmux, direnv |
| TUI 工具 | lazygit, helix, btop, bat, eza, delta |
| Shell 增强 | starship (prompt), zoxide (smart cd) |

## 构建命令

```bash
# 本地构建（测试用）
docker build -t buntoolbox .

# 运行容器
docker run -it buntoolbox

# 挂载当前目录
docker run -it -v $(pwd):/workspace buntoolbox
```

## CI/CD

GitHub Actions 自动构建，需要设置以下 secrets：
- `DOCKERHUB_USERNAME` - Docker Hub 用户名
- `DOCKERHUB_TOKEN` - Docker Hub 访问令牌

触发条件：push 到 master/main，创建 tag，或手动触发。

## Dockerfile 结构

按顺序安装（每个 section 独立的 RUN 层）：
1. 系统基础 + 开发工具
2. Azul Zulu JDK (多版本)
3. Maven + Gradle
4. Node.js + Bun
5. Python + uv/uvx + pipx
6. Go
7. Rust
8. GitHub CLI
9. TUI 工具 (lazygit, helix, starship, zoxide, bat, eza, btop, delta)
10. 最终配置 (shell hooks, aliases, git lfs)

## 版本更新

Dockerfile 中使用 ARG 定义版本号，便于更新：
- `GRADLE_VERSION` - Gradle 版本
- `NODE_MAJOR` - Node.js 主版本
- `GO_VERSION` - Go 版本
- `LAZYGIT_VERSION` - lazygit 版本
- `HELIX_VERSION` - helix 版本
