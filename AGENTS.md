# AGENTS.md - AI Agent Instructions

> 给在此仓库工作的 AI 编程 agent 的指南。

## 项目概述

**Buntoolbox** 是一个多语言开发环境 Docker 镜像（Ubuntu 24.04 LTS，约 2GB）。

**技术栈**: Dockerfile + Bash 脚本 | 无应用代码，纯基础设施项目

**语言偏好**: 与用户交流用**中文**，代码/命令用英文

---

## Build / Test / Lint 命令

### 核心命令

```bash
# 检查工具版本更新（更新前必须运行）
./scripts/check-versions.sh
./scripts/check-versions.sh -v    # 显示 Linux x86_64 资产选项

# 测试镜像（从 Docker Hub 拉取并测试，42 项检查）
./scripts/test-image.sh
./scripts/test-image.sh --no-pull              # 离线测试（已有镜像）
./scripts/test-image.sh cuipengfei/buntoolbox:v1.0.0  # 指定镜像

# WSL 本地环境版本检查
./scripts/check-wsl-versions.sh
```

### 单项快速验证

```bash
docker run --rm cuipengfei/buntoolbox:latest java -version
docker run --rm cuipengfei/buntoolbox:latest bun --version
```

### 本地构建（不推荐，慢）

```bash
docker build -t buntoolbox .
```

---

## 代码风格指南

### Bash 脚本规范

```bash
#!/bin/bash
# 文件描述（必须）
# Usage: ./scripts/xxx.sh [options]

set -e  # 出错即停

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# 参数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose) VERBOSE=true; shift ;;
        *) shift ;;
    esac
done

# 函数命名: snake_case
get_current_version() {
    grep "^ARG ${1}=" "$DOCKERFILE" | cut -d'=' -f2
}
```

**命名约定**: 变量 `UPPER_SNAKE_CASE`（全局）/ `lower_snake_case`（局部）| 函数 `snake_case` | 文件 `kebab-case.sh`

**错误处理**: `set -e` 出错即停 | 可选命令用 `|| true` | 检查依赖用 `command -v`

### Dockerfile 规范

```dockerfile
# 版本声明在顶部
ARG TOOL_VERSION=1.0.0

# 层按更新频率排序（稳定→易变）
# 清理必须在同一 RUN 指令中
RUN apt-get update && apt-get install -y pkg \
    && rm -rf /var/lib/apt/lists/*

# 安装前先创建目标目录
RUN mkdir -p /opt/tool \
    && tar -xzf tool.tar.gz -C /opt/tool
```

---

## Issue 追踪 (bd/beads)

**重要**: 使用 `bd` 命令，不要用 markdown TODO 列表。

```bash
bd ready --json                              # 查看待办
bd create "标题" -t bug -p 1 --json          # 创建 issue
bd update bd-42 --status in_progress --json  # 认领
bd close bd-42 --reason "Done" --json        # 完成
```

**类型**: `bug` | `feature` | `task` | `chore` | **优先级**: `0`(紧急) → `4`(backlog)

## 版本更新流程

1. `./scripts/check-versions.sh` 检查更新
2. 修改 `Dockerfile` 顶部 ARG 值
3. 同步更新: `image-release.txt`, `scripts/*.sh`, `CLAUDE.md`, `README.md`
4. `git commit && git push`
5. `gh run watch` 等待 CI 完成
6. `./scripts/test-image.sh` 验证

## 重要约束

### 必须做

- ✅ 修改后运行 `./scripts/test-image.sh` 验证
- ✅ 更新版本前运行 `./scripts/check-versions.sh`
- ✅ 使用 bd 追踪任务
- ✅ 安装前 `mkdir -p` 创建目标目录
- ✅ 清理操作与安装在同一 RUN 指令

### 禁止做

- ❌ 本地构建镜像（用 CI）
- ❌ 删除 `/root/.local/share/uv`（pipx 依赖）
- ❌ 删除 `/usr/include/node`（native 编译需要）
- ❌ 创建 markdown TODO 列表
- ❌ 未经确认自动 git commit

### 测试特殊命令

| 工具 | 正确测试方式 | 原因 |
|------|-------------|------|
| bd | `bd --help` | `--version` 无数据库时返回非零 |
| mihomo | `mihomo -v` | 不支持 `--version` |
| jdtls | 检查 jar 文件名 | 无 `--version` 命令 |

## 文件同步清单

添加/更新工具时必须同步: `Dockerfile`, `image-release.txt`, `scripts/*.sh`, `CLAUDE.md`, `README.md`

## 参考

- [CLAUDE.md](CLAUDE.md) - 详细项目说明
- [README.md](README.md) - 用户文档
- [.github/copilot-instructions.md](.github/copilot-instructions.md) - Copilot 规则
