# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**注意**: 本项目使用 [bd (beads)](https://github.com/steveyegge/beads) 进行 issue 追踪，请使用 `bd` 命令而非 markdown TODO。

## 项目概述

多语言开发环境 Docker 镜像 (Ubuntu 24.04 LTS)，约 1.79GB。专为被企业策略禁用 WSL 的 Windows 用户设计。

**技术栈**: Zulu JDK 21 headless | Node.js 24 + Bun | Python 3.12 + uv/pipx | Maven + Gradle

## 常用命令

```bash
docker build -t buntoolbox .              # 构建镜像
./scripts/test-image.sh                   # 构建并测试 (42 项检查)
./scripts/test-image.sh <image>           # 仅测试已有镜像
./scripts/check-versions.sh               # 检查工具版本更新
./scripts/check-versions.sh -v            # 详细模式，显示所有可用下载变体
```

## 架构

**Dockerfile 层顺序** (稳定→易变): 系统 → JDK → Python → uv/pipx → Maven → gh → Node/Bun → Gradle → TUI → 配置

**版本管理**: Dockerfile 顶部 ARG 声明 (`NODE_MAJOR`, `GRADLE_VERSION`, `*_VERSION`)

**CI/CD**: `.github/workflows/docker.yml` → Docker Hub (secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`)

## 不要删除

| 组件 | 大小 | 原因 |
|------|-----:|------|
| `/usr/include/node` | 67MB | native 模块编译 |
| cmake + ninja | 37MB | C/C++ 编译 |
| vim + helix | 249MB | 保留两个编辑器 |
| lto-dump, fonts, locale | ~70MB | 用户选择保留 |

## 注意事项

- **安装前先创建目标目录** — `mkdir -p /path` 在 tar 解压前，否则构建失败
- **不要删除 `/root/.local/share/uv`** — pipx 依赖此目录
- **清理必须在同一 RUN 指令中** — Docker 层增量，后续删除无效
- **JDK jmods/man 可删** — 仅用于 jlink，容器不需要
- **测试 bd 用 `bd --help`** — `bd --version` 无数据库时返回非零
- **测试 mihomo 用 `-v` 和 `-h`** — 不支持 `--version` / `--help`

## WSL 替代方案用法

```powershell
# 基本用法，挂载项目目录
docker run -it -v ${PWD}:/workspace -w /workspace cuipengfei/buntoolbox:latest

# 带 Git 凭证共享
docker run -it -v ${PWD}:/workspace -w /workspace `
  -v ${HOME}/.ssh:/root/.ssh:ro `
  -v ${HOME}/.gitconfig:/root/.gitconfig:ro `
  cuipengfei/buntoolbox:latest

# 持久化命名容器
docker create --name mydev -it -v ${PWD}:/workspace -w /workspace cuipengfei/buntoolbox:latest
docker start -ai mydev
```

## Dev Containers

VS Code 用户: 已提供 `.devcontainer/devcontainer.json`。使用命令面板 "Dev Containers: Reopen in Container"。

## 已优化

- JDK 11+17+21 → 仅 21 headless (节省 ~610MB)
- 删除 jmods/man、`/root/.launchpadlib`
- pipx 通过 uv 安装 (避免 Python 3.12 distutils 问题)
- GitHub API 缓存 (5分钟) 避免速率限制
