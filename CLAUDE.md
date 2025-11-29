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
| JS/TS | Node.js 24 LTS, Bun |
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

层顺序优化：稳定层在前，易变层在后（用户更新时拉取更少数据）：

1. 系统基础 + 开发工具 (stable)
2. Azul Zulu JDK (stable)
3. Python + uv/uvx + pipx (stable)
4. Rust (stable)
5. Maven (stable)
6. GitHub CLI (stable)
7. Node.js + Bun (medium)
8. Go (frequently updated)
9. Gradle (frequently updated)
10. TUI 工具 (most frequently updated)
11. 最终配置 (tiny)

## 版本更新

版本号集中在 Dockerfile 顶部的 ARG 声明中。运行脚本检查最新版本：

```bash
./scripts/check-versions.sh
```

检查的工具：Go, Gradle, Node.js, lazygit, helix
