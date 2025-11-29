# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Note**: This project uses [bd (beads)](https://github.com/steveyegge/beads) for issue tracking. Use `bd` commands instead of markdown TODOs.

## Project Overview

Buntoolbox 是一个多语言开发环境 Docker 镜像，基于 Ubuntu 24.04 LTS (Noble)。通过 GitHub Actions 自动构建并推送到 Docker Hub。

## 技术栈

| 类别 | 组件 |
|:-----|:-----|
| 基础镜像 | Ubuntu 24.04 LTS (Noble) |
| JDK | Azul Zulu 11, 17, 21 (默认 21) |
| JS/TS | Node.js 24 LTS, Bun |
| Python | 3.12 + uv/uvx + pipx (uv 安装 pipx 避免 distutils 问题) |
| Go | 1.25.4 |
| Rust | rustup + rustfmt + clippy |
| 构建工具 | Maven, Gradle 9.2.1 |
| 开发工具 | git, gh, jq, ripgrep, fd, fzf, tmux, direnv |
| TUI 工具 | lazygit, helix, btop, bat, eza, delta, starship, zoxide |

## 常用命令

```bash
# 本地构建
docker build -t buntoolbox .

# 运行容器
docker run -it buntoolbox

# 挂载当前目录
docker run -it -v $(pwd):/workspace buntoolbox

# 检查工具版本更新
./scripts/check-versions.sh
```

## Dockerfile 层顺序

层顺序已优化：稳定层在前，易变层在后。更新 TUI 工具版本时，用户只需拉取最后几层。

```
稳定 ──────────────────────────────────────────────────────────► 易变
1.系统  2.JDK  3.Python  4.Rust  5.Maven  6.gh  7.Node  8.Go  9.Gradle  10.TUI  11.配置
```

## 版本管理

版本号集中在 Dockerfile 顶部 ARG 声明：
- `NODE_MAJOR` - Node.js 主版本
- `GO_VERSION` - Go 版本
- `GRADLE_VERSION` - Gradle 版本
- `LAZYGIT_VERSION` - lazygit 版本
- `HELIX_VERSION` - helix 版本

运行 `./scripts/check-versions.sh` 查询最新版本（需要 curl + jq）。

## CI/CD

GitHub Actions 自动构建（`.github/workflows/docker.yml`）：
- 触发：push 到 master/main，创建 tag，手动触发
- 平台：linux/amd64
- 缓存：`type=gha,mode=max`（稳定层缓存，重建时只构建变化的层）
- Secrets：`DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`
