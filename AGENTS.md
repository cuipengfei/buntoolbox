# PROJECT KNOWLEDGE BASE

**Generated:** 2026-02-22
**Commit:** 774af7e
**Branch:** master

## OVERVIEW
Buntoolbox 是一个多语言开发环境 Docker 镜像（基于 Ubuntu 24.04 LTS，约 2GB大小），专为受企业安全策略限制 WSL 的 Windows 用户而设计。
**核心技术栈**: Azul Zulu JDK 25 headless, Node.js 24 + Bun, Python 3.14 + uv/pipx, Maven, Gradle, Dockerfile 编排与 Bash 基础设施脚本。

## STRUCTURE
```
buntoolbox/
├── .github/          # 包含 Copilot 指导及 CI/CD 工作流
├── scripts/          # 用于版本检查与自动化测试镜像的 bash 工具箱
├── Dockerfile        # 分层构建的容器镜像核心定义
└── README.md         # 面向用户的使用文档与接入指南
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| 工具版本更新 | `Dockerfile`, `scripts/` | 修改 `Dockerfile` ARG 前，必须先运行 `check-versions.sh` 与 `check-wsl-versions.sh` 确保双端同步。 |
| CI 镜像构建 | `.github/workflows/` | Push / PR / v* tag 触发构建。非 PR 才向 Docker Hub 推送。 |
| 验证构建结果 | `scripts/test-image.sh`| CI 完成后，对镜像进行 42 项以上针对运行时与工具的自动化检查。 |
| 本地开发环境 | `scripts/check-wsl-versions.sh` | 检查并保证本地 WSL 工具与上游版本一致。 |
| Issue 追踪 | bd (beads) 命令行工具 | `bd ready`, `bd create`, `bd close`。不要用 Markdown TODO 列表。 |

## CONVENTIONS
- **交流语言**: 与用户交流主要用**中文**，代码与命令用英文。
- **Bash 脚本**: 全局变量 `UPPER_SNAKE_CASE`，函数 `snake_case`。所有脚本首部添加 `set -e` 并提供用法注释。
- **Dockerfile 构建分层**: 按**更新频率**排序（稳定的系统基础与运行时在前，频繁更新的高层工具与配置在后）。
- **清理与缓存**: `apt-get` 等清理操作必须与安装命令放在同一 `RUN` 指令中完成。
- **版本声明**: 所有组件的版本号在 `Dockerfile` 顶部通过 `ARG` 唯一声明，其他脚本从此处动态读取。

## ANTI-PATTERNS (THIS PROJECT)
- ❌ **Markdown TODOs**: 禁用 Markdown 格式的任务列表，必须使用 `bd` 命令进行任务管理追踪。
- ❌ **删除关键底层目录**: 绝不允许删除 `/root/.local/share/uv` 或 `/usr/include/node` (分别影响 pipx 与原生模块编译)。
- ❌ **未经确认自动 Commit**: 等待用户明确指令后方可 `git commit && git push`。
- ❌ **覆盖 pip 安装**: 禁止使用 `pip install --upgrade pip` (PEP 668 限制，易破坏外部依赖记录)。
- ❌ **本地构建镜像**: 禁止在本地执行耗时、消耗流量的 `docker build`。让 GitHub Actions 去做。

## UNIQUE STYLES
- **TUI 优先环境**: 环境深度集成诸多现代终端工具（zellij, lazygit, helix, eza, delta, btop, procs），鼓励全程键盘操作。
- **全平台 VS Code 接入**: 预置 `openvscode-start.sh`，默认映射 3000 端口提供无验证、浏览器内的完整 VS Code 体验。
- **特定工具检测绕过**: `bd` 没有数据库时 `--version` 会异常退出（请用 `--help`），`mihomo` 无版检参数（请用 `-v`），`jdtls` 依靠 jar 文件名而非命令。

## COMMANDS
```bash
# 检查云端及本地所需更新
./scripts/check-versions.sh
./scripts/check-wsl-versions.sh

# 测试由 GitHub Actions 刚编译推送到 Docker Hub 的镜像
./scripts/test-image.sh

# bd 任务认领与流转
bd update bd-42 --status in_progress --json
bd close bd-42 --reason "Done" --json
```

## NOTES
- **jdtls 安装约定**: 版本含有时间戳 (`1.56.0-202601291528`)。完整解压在 `~/.local/share/jdtls`，依靠 `~/jdtls` 的软连接暴露环境。
- **Node.js 对齐**: 仅比较主干版本号（如 24）。
- **WSL 目录约定**: 本地二进制安装优先放到 `~/.local/bin`，避开 nvm/sdkman 初始化带来的额外复杂度。
- **会话关闭协议**: 宣称完成工作前：`git status` -> `git add` -> `bd sync` -> `git commit` -> `bd sync` -> `git push`。
