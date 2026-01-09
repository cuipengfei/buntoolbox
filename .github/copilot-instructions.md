# GitHub Copilot Instructions for Buntoolbox

## 语言偏好 / Language Preference

**请主要使用中文与用户交流。** Copilot 应该使用中文进行对话、解释和文档编写，除非用户明确要求使用其他语言。

## 项目概述

**Buntoolbox** 是一个多语言开发环境 Docker 镜像 (基于 Ubuntu 24.04 LTS)，镜像大小约 1.79GB。

**主要特性:**
- **运行时**: Bun, Node.js 24, Python 3.14
- **JDK**: Azul Zulu 25 headless
- **基础镜像**: Ubuntu 24.04 LTS
- **常用工具**: git, gh, jq, ripgrep, fd, fzf, tmux, lazygit, helix, bat, eza, delta, btop, starship, zoxide, bd, mihomo 等

## 技术栈

- **容器技术**: Docker
- **基础系统**: Ubuntu 24.04 LTS (Noble)
- **Java**: Azul Zulu JDK 25 headless
- **JavaScript/TypeScript**: Node.js 24, Bun
- **Python**: Python 3.14 + uv/pipx
- **构建工具**: Maven, Gradle
- **CI/CD**: GitHub Actions

## 常用命令

```bash
docker build -t buntoolbox .              # 构建镜像
./scripts/test-image.sh                   # 构建并测试 (42 项检查)
./scripts/test-image.sh <image>           # 仅测试已有镜像
./scripts/check-versions.sh               # 检查工具版本更新
./scripts/check-versions.sh -v            # 详细模式，显示所有可用下载变体
```

## 架构说明

**Dockerfile 层顺序** (按稳定性排序，稳定→易变):
1. 系统基础 + 必要工具
2. Azul Zulu JDK 25
3. Python 3.14 + uv/pipx
4. Maven
5. GitHub CLI
6. Node.js + Bun
7. Gradle
8. TUI 工具
9. 最终配置

**版本管理**: 所有版本号在 Dockerfile 顶部通过 ARG 声明

## 项目结构

```
buntoolbox/
├── .github/
│   ├── copilot-instructions.md  # Copilot 指令文件
│   └── workflows/               # GitHub Actions 工作流
├── scripts/
│   ├── check-versions.sh        # 检查工具版本更新
│   └── test-image.sh            # 测试镜像脚本
├── Dockerfile                   # Docker 镜像定义
├── README.md                    # 用户文档
├── CLAUDE.md                    # Claude AI 指导
└── AGENTS.md                    # AI Agent 指导
```

## 开发指南

### 修改 Dockerfile 时的注意事项

- **安装前先创建目标目录** — `mkdir -p /path` 在 tar 解压前，否则构建失败
- **不要删除 `/root/.local/share/uv`** — pipx 依赖此目录
- **清理必须在同一 RUN 指令中** — Docker 层增量，后续删除无效
- **JDK jmods/man 可删** — 仅用于 jlink，容器不需要

### 不要删除的组件

| 组件 | 大小 | 原因 |
|------|-----:|------|
| `/usr/include/node` | 67MB | native 模块编译 |
| cmake + ninja | 37MB | C/C++ 编译 |
| vim + helix | 249MB | 保留两个编辑器 |
| lto-dump, fonts, locale | ~70MB | 用户选择保留 |

### 测试命令说明

- **测试 bd 用 `bd --help`** — `bd --version` 无数据库时返回非零
- **测试 mihomo 用 `-v` 和 `-h`** — 不支持 `--version` / `--help`

## Issue 追踪

本项目使用 **bd (beads)** 进行 issue 追踪。请使用 `bd` 命令而不是 markdown TODO 列表。

### 常用命令

```bash
bd ready --json                    # 查看未阻塞的 issue
bd create "标题" -t bug|feature|task -p 0-4 --json  # 创建 issue
bd update <id> --status in_progress --json  # 更新状态
bd close <id> --reason "完成" --json  # 关闭 issue
```

## 重要规则

- ✅ 主要使用中文与用户交流
- ✅ 使用 bd 进行任务追踪
- ✅ 修改 Dockerfile 后运行 `./scripts/test-image.sh` 测试
- ✅ 更新工具版本前先运行 `./scripts/check-versions.sh`
- ❌ 不要创建 markdown TODO 列表
- ❌ 不要删除上述"不要删除"表格中的组件

---

**详细信息请参阅 [CLAUDE.md](../CLAUDE.md) 和 [AGENTS.md](../AGENTS.md)**
