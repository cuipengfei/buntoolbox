# PROJECT KNOWLEDGE BASE

**Generated:** 2026-05-10
**Commit:** 01cd5b9
**Branch:** master

## OVERVIEW
Buntoolbox 是一个多语言开发环境 Docker 镜像（基于 Ubuntu 26.04 LTS），专为受企业安全策略限制 WSL 的 Windows 用户而设计。当前发布三个 sibling variants：`cuipengfei/buntoolbox:latest` 是 terminal/TUI/dev image；`cuipengfei/buntoolbox:i3` 是基于 LinuxServer Webtop i3 的 browser desktop image；`cuipengfei/buntoolbox:kde` 是基于 LinuxServer Webtop KDE 的 browser desktop image。
**核心技术栈**: Azul Zulu JDK 25 headless, Node.js 24 + Bun, Python 3.14 + uv/pipx, Maven, Gradle, OpenVSCode Server, ttyd, Dockerfile 编排与 Bash 基础设施脚本；`i3` / `kde` variants 额外包含 Webtop/Selkies/browser GUI stack。

## STRUCTURE
```
buntoolbox/
├── .github/          # 包含 Copilot 指导及 CI/CD 工作流
├── docker/           # 共享 layer scripts/env snippets 与 webtop root-first patch
├── scripts/          # 用于版本检查与自动化测试镜像的 bash 工具箱
├── Dockerfile        # latest 分层构建入口
├── docker/webtop/Dockerfile # i3/kde browser desktop 共享分层构建入口
└── README.md         # 面向用户的使用文档与接入指南
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| 工具版本更新 | `docker/layers/*.env`, `scripts/` | 修改共享版本 snippet 后，必须先运行 `check-versions.sh` 与 `check-wsl-versions.sh`；`latest`、`i3` 与 `kde` 共用这些版本来源。 |
| CI 镜像构建 | `.github/workflows/` | Push to master / v* tag / workflow_dispatch 触发构建。push to master 只构建+推送 `latest`；release tag (v*) 构建并推送全部三个 variant (`latest`/`i3`/`kde`)，三个 job 并行；`workflow_dispatch` 可手动触发任意 variant。无 PR 触发。 |
| 验证构建结果 | `scripts/test-image.sh`| CI 完成后验证镜像。`latest` 跑 common checks；`i3` / `kde` 跑 common checks + shared webtop/root-first runtime checks + desktop-specific checks。 |
| 本地开发环境 | `scripts/check-wsl-versions.sh` | 检查并保证本地 WSL 工具与上游版本一致。 |
| Issue 追踪 | bd (beads) 命令行工具 | `bd ready`, `bd create`, `bd close`。不要用 Markdown TODO 列表。 |

## CONVENTIONS
- **交流语言**: 与用户交流主要用**中文**，代码与命令用英文。
- **Bash 脚本**: 全局变量 `UPPER_SNAKE_CASE`，函数 `snake_case`。所有脚本首部添加 `set -e` 并提供用法注释。
- **Dockerfile 构建分层**: 按**更新频率**排序（稳定的系统基础与运行时在前，频繁更新的高层工具与配置在后）。
- **清理与缓存**: `apt-get` 等清理操作必须与安装命令放在同一 `RUN` 指令中完成。
- **版本声明**: 工具版本以 `docker/layers/*.env` 作为共享来源，`Dockerfile` 与 `docker/webtop/Dockerfile` 在 point-of-use COPY/RUN 边界读取，避免 variants 漂移。

## ANTI-PATTERNS (THIS PROJECT)
- ❌ **Markdown TODOs**: 禁用 Markdown 格式的任务列表，必须使用 `bd` 命令进行任务管理追踪。
- ❌ **删除关键底层目录**: 绝不允许删除 `/root/.local/share/uv` 或 `/usr/include/node` (分别影响 pipx 与原生模块编译)。
- ❌ **未经确认自动 Commit**: 等待用户明确指令后方可 `git commit && git push`。
- ❌ **覆盖 pip 安装**: 禁止使用 `pip install --upgrade pip` (PEP 668 限制，易破坏外部依赖记录)。
- ❌ **本地构建镜像**: 禁止在本地执行耗时、消耗流量的 `docker build`。让 GitHub Actions 去做。

## UNIQUE STYLES
- **TUI 优先环境**: 环境深度集成诸多现代终端工具（zellij, lazygit, helix, eza, delta, btop, procs），鼓励全程键盘操作。
- **双 Shell 支持**: 默认 bash，预装 zsh + oh-my-zsh + zsh-autosuggestions，用户可随时 `zsh` 切换。starship/zoxide/direnv/aliases 在两种 shell 中均已配置。
- **全平台 VS Code 接入**: 预置 `openvscode-start.sh`，默认映射 3000 端口提供无验证、浏览器内的完整 VS Code 体验。
- **浏览器终端接入**: 预置 `ttyd-start.sh`，默认映射 7681 端口提供轻量 web 终端，支持自定义 shell 和 Zellij。
- **浏览器桌面接入**: `cuipengfei/buntoolbox:i3` / `cuipengfei/buntoolbox:kde` 预置 Webtop browser desktop。Webtop HTTP/HTTPS 为 3200/3201；3000 保留给 `openvscode-start`；正常交互 root-first，`HOME=/root`。
- **KDE GPU 接入边界**: Windows + Docker Desktop + WSL2 下，KDE flavor 的可操作、已实测 GPU 路径是 WSLg/Mesa D3D12 的 GUI app OpenGL：`--device /dev/dxg`、只读挂载完整 `/usr/lib/wsl`、`LD_LIBRARY_PATH=/usr/lib/wsl/lib`、`GALLIUM_DRIVER=d3d12`、`LIBVA_DRIVER_NAME=d3d12`，并在 Webtop 场景设置 `DISABLE_DRI3=true`。验证优先看 `glxinfo -B` / `eglinfo` / `glxgears -info` 的 `D3D12 (...)`、`Microsoft Corporation`、`Accelerated: yes`。不要把 `btop`、`nvidia-smi`、`--gpus all` 或 GPU 出现在系统监控里当作 KDE/KWin compositor GPU 证据；KWin compositor、Webtop/Selkies stream encoding、GUI app OpenGL 是三层不同问题。LinuxServer/Webtop 官方文档承诺的是 `/dev/dri`/NVIDIA 路径，不承诺 WSLg `/dev/dxg`；Webtop/WSL2 中按 KWin 仍使用软件 compositor 设计。若完全没有 WSL2 backend，则不要按 KDE GPU 可用设计。
- **Selkies VAAPI 实验边界**: 当前 LinuxServer Webtop 的 Selkies 服务是 `--mode=websockets` / Pixelflux 路径，`SELKIES_ENCODER` 不接受 `vah264enc` / `nvh264enc` 这类 GStreamer element 名；可接受值是 Webtop encoder 名如 `x264enc`、`x264enc-striped`、`jpeg`。VAAPI knob 是 `SELKIES_DRI_NODE` / `DRI_NODE`，例如 `SELKIES_DRI_NODE=/dev/dri/renderD128`，并配合 `SELKIES_USE_CPU=false`。本机 PoC：`vainfo --display drm --device /dev/dri/renderD128` 可报告 D3D12 H.264 EncSlice，但 FFmpeg `h264_vaapi` 产出 0-byte stream，GStreamer VAAPI encode 不可靠；因此不要把 KDE image 默认切到 VAAPI stream encoding，除非端到端 browser session 证明稳定、非空码流、无画质回退。
- **bd 任务认领**: 用 `bd update <id> --claim`（原子写入 assignee + status=in_progress + started_at），优于手动 `--status in_progress`。**绝不**用 `bd edit`（开 $EDITOR，agent 无法交互），改字段一律 `bd update <id> --description/--title/--notes/--acceptance`。

## COMMANDS
```bash
# 检查云端及本地所需更新
./scripts/check-versions.sh
./scripts/check-wsl-versions.sh

# 测试由 GitHub Actions 刚编译推送到 Docker Hub 的镜像
./scripts/test-image.sh
./scripts/test-image.sh --variant i3 --image cuipengfei/buntoolbox:i3
./scripts/test-image.sh --variant kde --image cuipengfei/buntoolbox:kde

# bd 任务认领与流转（v1.0.2 起推荐用法）
bd update buntoolbox-xxx --claim --json          # 原子认领
bd comments add buntoolbox-xxx "进展说明"          # 评论用 positional，不是 -m
bd close buntoolbox-xxx --reason "Done" --json

# 解析 bd JSON 输出时，必须 2>/dev/null 抛掉 .beads 权限警告
bd show buntoolbox-xxx --json 2>/dev/null | jq .
```

## BD WORKFLOW: Main ↔ Sub-Agent (MECE 5 切片)

主代理与子代理造 bd issue 沟通时的最低线约定。完整调研记录见 bd issue `vn7 / dh2 / iuw / 1ms / s0l`。

### 1. Handoff（主代理建 issue）
- Issue body 五段模板：`# Task / # Scope / # Acceptance / # Constraints / # Executor notes`。
- 长内容一律 `bd create "..." --body-file=/tmp/x.md`；**不要** inline `-d`（backtick / `!` / 引号会炒 shell）。
- 需提示执行参数时用 `metadata.execution_*`：`agent_type / suggested_model / reasoning_effort / mode / parallel_group`；没依据不填。
- `-p 0..4` 反映真实紧急度；issue_type 默认 `task`。

### 2. 子代理执行契约
1. `bd show <id> --json 2>/dev/null` 先读，不靠记忆。
2. `bd update <id> --claim --json` 原子认领。
3. **永不** `bd edit`（开 $EDITOR，agent 无法交互）。
4. Acceptance 逐字当合同读。
5. 不越界（不改 issue 未要求的文件）。

### 3. 结果回写
- **默认单条结构化评论**：`## Result / ## Evidence (表格) / ## Verification / ## Limits / ## Next action`。
- 多评论**仅**用于：partial 中转 / 外部 blocker / 修正之前评论。
- 每条 claim 挂证据（命令+输出 / `path:line` / URL / hash）；未验证部分明说。
- `--reason` ≤120 字符；长报告进评论，不进 reason。

### 4. 失败 / 部分完成恢复
- crash → 主代理加 `FAILED:` 评论，然后 `bd reopen --reason "..."`（已关）或 `bd update --status open --assignee ""`（未关）。
- 僵尸 claim → `bd stale --days 1 --status in_progress --json` 找出重置。
- **不要** `bd close` 失败任务（会从 `bd ready` 隐藏）；保持 open + 失败评论。
- `bd doctor`：先 `--dry-run` 或 `--fix -i`；**不要** `--fix --yes`（参考 issue #1062 历史损坏）。
- 同一 issue 上 retry；scope 变了才开新 issue。

### 5. 并行 / 依赖
- **硬阻塞** → `bd dep add <child> <parent>`（真不能并行才用）。
- **关联** → `bd dep relate <a> <b>`（see also，不阻塞）。
- **层级** → `bd create --parent <epic-id>`；hierarchy ≠ 自动阻塞。
- 子代理选活唯一入口是 `bd ready`，**不用** `bd list`。
- `metadata.execution_parallel_group` 只是 orchestrator 提示，**不**是阻塞机制。
- 多 agent 冲突解决 / merge 用 `bd merge-slot acquire/release` 串行化。
- 只读 worker 加 `--readonly`；禁 auto-sync 加 `--sandbox`。

## WORKFLOW: 新增工具 / 版本升级（标准流程）

当需要在镜像里新增工具，或升级已有工具版本时，统一按以下顺序执行：

1. **先在本机（WSL）安装并验证**
   - 先在当前开发机安装目标工具（优先官方推荐安装方式，避免不必要源码编译）。
   - 验证核心命令可用、版本可读、基本功能正常。

2. **确认来源与安装策略**
   - 确认工具来源（apt / 官方 release / 其他官方渠道）。
   - 如需版本锁定，在 `Dockerfile` 顶部 `ARG` 统一声明版本。

3. **落地到 Dockerfile**
   - 按构建分层原则放置到合适层（稳定层在前，高频更新层在后）。
   - 版本号优先落在 `docker/layers/*.env` 共享 snippet；安装逻辑优先落在 `docker/layers/*.sh` 共享脚本，供 `Dockerfile` 和 `docker/webtop/Dockerfile` 复用。
   - 如果新增工具只适用于某个 variant，必须在 Dockerfile、README 和测试里明确写出 variant 边界；默认假设工具应同时出现在 `latest`、`i3` 与 `kde`。
   - 安装与清理放在同一 `RUN` 中，避免镜像层膨胀。
   - 如需 shell 自动加载，在最终配置区写入对应 profile/bashrc 初始化，并确认 root-first Webtop variants 中 `HOME=/root` 的配置路径一致。

4. **同步更新脚本（必须）**
   - `scripts/check-versions.sh`：支持新工具/新版本对齐检查。
   - `scripts/check-wsl-versions.sh`：支持本机环境同源检查。
   - `scripts/test-image.sh` / `scripts/lib/test-common-tools.sh`：新增或更新 common tool 验证项，使 `latest`、`i3` 与 `kde` 默认都覆盖该工具。
   - 如果工具只属于 Webtop runtime，则优先放入 `scripts/lib/test-webtop-runtime.sh`；如果只属于某个 desktop，则放入 `scripts/lib/test-i3-runtime.sh` 或 `scripts/lib/test-kde-runtime.sh`，并说明为什么不属于 common checks。

5. **同步更新文档与元信息（必须）**
   - `README.md`（用户可见工具清单）
   - `image-release.txt`（镜像内元信息）
   - `AGENTS.md`（流程/约定变化时）
   - 如果影响 browser desktop / 端口 / root-first 行为，还要更新 `docs/container-access-design.md` 和相关 OpenSpec evidence/design 文档。

6. **执行验证**
   - 脚本语法：`bash -n scripts/*.sh`（至少覆盖改动脚本）。
   - 版本检查：`./scripts/check-versions.sh`、`./scripts/check-wsl-versions.sh`。
   - 镜像验证：`./scripts/test-image.sh --variant latest --image cuipengfei/buntoolbox:latest`、`./scripts/test-image.sh --variant i3 --image cuipengfei/buntoolbox:i3` 和 `./scripts/test-image.sh --variant kde --image cuipengfei/buntoolbox:kde`。
   - 说明：若远端 `latest` / `i3` / `kde` 尚未由 CI 重建，`test-image.sh` 可能出现预期版本差异，属正常现象；push to master 只发布 `latest`，tag v* 才发布全部三个，再跑 post-push image tests。

7. **提交与推送**
   - `git add` 相关文件 → `git commit` → `git push`。
   - 提交信息遵循 conventional commits 格式（`feat:` / `fix:` / `chore:` 等）。

8. **CI 收口**
   - `gh run watch` 监视 GitHub Actions 构建进度。
   - CI 先测试 `buntoolbox:ci-latest-test` 再发布 `latest`；tag v* 时额外测试 `buntoolbox:ci-i3-test` 和 `buntoolbox:ci-kde-test` 再发布 `i3` 与 `kde`。
   - 构建完成后执行 `./scripts/test-image.sh --variant latest --image cuipengfei/buntoolbox:latest` 验证 latest；tag v* 发布后额外执行 `--variant i3` 和 `--variant kde` 验证。

## NOTES
- **Node.js 对齐**: Dockerfile 通过 `NODE_VERSION` ARG 锁定精确版本（如 `24.15.0`），安装方式为官方 tarball。
- **WSL 目录约定**: 本地二进制安装优先放到 `~/.local/bin`，避开 nvm/sdkman 初始化带来的额外复杂度。
- **会话关闭协议**: 宣称完成工作前：`git status` → `git add` → `git commit -m "<msg> (bd-xxx)"` → `git push`。提交信息**末尾带括号 issue ID**，方便 `bd doctor` / `bd orphans` 追溯；不存在 `bd sync` 命令，Dolt 同步靠 `bd hooks install`（一次性）或手动 `bd dolt commit`。

@RTK.md
