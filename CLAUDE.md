# CLAUDE.md
 
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**注意**: 本项目使用 [bd (beads)](https://github.com/steveyegge/beads) 进行 issue 追踪，请使用 `bd` 命令而非 markdown TODO，完整流程请参见 AGENTS.md。

**交流语言**: 与用户交流请主要使用中文；代码与命令以英文为主（与 `.github/copilot-instructions.md` 保持一致）。

## 项目概述

多语言开发环境 Docker 镜像 (Ubuntu 24.04 LTS)，镜像约 2.0GB。专为被企业策略禁用 WSL 的 Windows 用户设计。

**技术栈**: Zulu JDK 25 headless | Node.js 24 + Bun | Python 3.14 + pip/uv/pipx | Maven + Gradle

**常用工具**: git, gh, jq, ripgrep, fd, fzf, tmux, zellij, lazygit, helix, bat, eza, delta, btop, starship, zoxide, procs, bd, mihomo, openvscode-server, claude, jdtls 等（网络: ping, ip, ss, dig, nc, socat, ssh, sshd）

## 常用命令

```bash
# 拉取与交互运行
docker pull cuipengfei/buntoolbox:latest
docker run -it cuipengfei/buntoolbox:latest

# 本地构建（不推荐，慢）
docker build -t buntoolbox .

# 镜像端到端测试（默认从 Docker Hub 拉取）
./scripts/test-image.sh
./scripts/test-image.sh cuipengfei/buntoolbox:latest      # 指定镜像
./scripts/test-image.sh --no-pull                         # 离线测试（镜像已存在）
DOCKER_BIN="/Docker/host/bin/docker.exe" ./scripts/test-image.sh -v  # 指定宿主 docker 可执行 + 详细输出

# 版本检查（用于更新 Dockerfile 顶部 ARG 值）
./scripts/check-versions.sh
./scripts/check-versions.sh -v                            # 显示 Linux x86_64 资产选项（便于选择）

# WSL 本地环境版本检查（保持 WSL 与 Docker 镜像同步）
./scripts/check-wsl-versions.sh

# 单项快速验证（最小化排障）
docker run --rm cuipengfei/buntoolbox:latest java -version
docker run --rm cuipengfei/buntoolbox:latest node --version
docker run --rm cuipengfei/buntoolbox:latest bun --version
docker run --rm cuipengfei/buntoolbox:latest python --version
docker run --rm cuipengfei/buntoolbox:latest gh --version
docker run --rm cuipengfei/buntoolbox:latest zellij --version
docker run --rm cuipengfei/buntoolbox:latest uv --version
docker run --rm cuipengfei/buntoolbox:latest claude --version

# OpenVSCode Server 快速启动（浏览器 VS Code，默认端口 3000，无认证）
docker run -d -p 3000:3000 cuipengfei/buntoolbox:latest openvscode-start
# 自定义端口
docker run -d -p 8080:8080 cuipengfei/buntoolbox:latest openvscode-start 8080
```

## 架构

**Dockerfile 层顺序** (按更新频率优化):
1. 系统基础 (apt packages) - 最稳定
2. JDK 25 - 稳定
3. Python 3.14 + pip - 稳定
4. Maven - 稳定
5. GitHub CLI - 稳定
6. Node.js - 稳定
7. 稳定 TUI 工具 (eza, delta, zoxide, helix, starship, procs, zellij, openvscode-server)
8. 中频更新工具 (Gradle, Bun, lazygit, mihomo) - 5次更新
9. 高频更新工具 (uv/pipx) - 9次更新
10. beads - 最频繁 (13次更新)
11. 最终配置

**TUI 工具层**: eza, delta, zoxide, helix, starship, procs, zellij, openvscode-server

**中频更新工具层**: Gradle, Bun, lazygit, mihomo (各5次版本更新)

**层优化策略**: 按版本变化频率排序，稳定工具在前，频繁更新工具在后，最小化层重建影响。uv 从第3层移到第9层，更新时影响的层数从6个减少到2个。

**版本管理**: Dockerfile 顶部 ARG 声明 (`NODE_MAJOR`, `GRADLE_VERSION`, `*_VERSION`)

**Claude Code 版本**: 使用 `ARG CLAUDE_VERSION` 固定版本，安装脚本支持 `bash -s -- <VERSION>` 传递版本号。版本检查使用官方 GCS bucket endpoint: `https://storage.googleapis.com/claude-code-dist-.../claude-code-releases/latest`

**CI/CD**: `.github/workflows/docker.yml` → Docker Hub (secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`)

### CI/CD 行为说明
- 触发条件：
  - push 到 master/main 分支、打 `v*` 标签、PR 到 master/main、或手动 `workflow_dispatch`
- 推送策略：
  - 非 PR 事件才会 push 到 Docker Hub；标签由 `docker/metadata-action` 生成（分支、PR、semver 主/次版本、默认分支时 `latest`）
- 构建平台与缓存：
  - 仅 `linux/amd64`；启用 GitHub Actions 缓存（`cache-from/to: gha`）

## 添加/更新工具时必须同步更新

| 文件 | 更新内容 |
|------|----------|
| `Dockerfile` | ARG 版本声明 + 安装指令 |
| `image-release.txt` | 工具列表（嵌入镜像 /etc/image-release） |
| `scripts/check-versions.sh` | 版本检查 |
| `scripts/check-wsl-versions.sh` | WSL 本地版本检查 |
| `scripts/test-image.sh` | 功能测试 |
| `CLAUDE.md` | 常用工具列表 |
| `README.md` | 包含组件列表 |

**版本更新完整流程**:
```bash
# 1. 检查可用更新
./scripts/check-versions.sh
./scripts/check-versions.sh -v    # 查看 Linux x86_64 资产选项

# 2. 更新 Dockerfile 顶部 ARG 值
# Node 使用 LTS 主版本，脚本以官方 index.json 的 LTS 条目为准

# 3. 提交并推送
git add Dockerfile && git commit -m "chore: update tool versions" && git push

# 4. 监控 GitHub Actions 构建（必须等待完成）
gh run list --limit 1
gh run watch <run_id>             # 实时监控，通常 3-6 分钟

# 5. 构建成功后验证镜像
./scripts/test-image.sh           # 会自动拉取最新镜像并测试
```

**重要**: push 后必须 watch GitHub Actions 构建完成，然后运行 test-image.sh 验证。不要跳过任何步骤。

## 不要删除

| 组件 | 大小 | 原因 |
|------|-----:|------|
| `/usr/include/node` | 67MB | native 模块编译 |
| cmake + ninja | 37MB | C/C++ 编译 |
| vim + helix | 249MB | 保留两个编辑器 |
| lto-dump, fonts, locale | ~70MB | 用户选择保留 |
| `/root/.local/share/uv` | - | pipx 依赖此目录 |

## 注意事项

- **不要本地构建镜像** — 太慢且消耗 VPN 流量，推送后由 GitHub Actions 构建
- **不要自动 git commit** — 等待用户明确指示后再提交
- **安装前先创建目标目录** — `mkdir -p /path` 在 tar 解压前，否则构建失败
- **清理必须在同一 RUN 指令中** — Docker 层增量，后续删除无效
- **JDK jmods/man 可删** — 仅用于 jlink，容器不需要
- **测试 bd 用 `bd --help`** — `bd --version` 无数据库时返回非零
- **测试 mihomo 用 `-v` 和 `-h`** — 不支持 `--version` / `--help`
- **测试 jdtls 用 jar 文件名** — 无 `--version` 命令，从 `plugins/org.eclipse.jdt.ls.core_*.jar` 提取版本
- **jdtls 版本格式** — `version-timestamp`（如 `1.54.0-202511261751`），Dockerfile ARG 包含完整格式
- **频繁更新的工具放最后** — beads 已移到最后一层，减少层重建影响
- **pip 不要升级** — 使用 apt 安装的 pip 即可，尝试升级会因 PEP 668 和缺少 RECORD 文件失败

### 会话关闭协议（Hooks 提示）
在宣称“完成”之前请执行：
```
[ ] 1. git status              (检查变更)
[ ] 2. git add <files>         (暂存改动)
[ ] 3. bd sync                 (同步 beads 变更)
[ ] 4. git commit -m "..."     (提交代码)
[ ] 5. bd sync                 (提交任何新增 beads 变更)
[ ] 6. git push                (推送到远程)
```

### 镜像大小组成（2047 MB）

| 组件类型 | 大小 | 占比 | 主要内容 |
|---------|-----:|-----:|----------|
| 系统基础 + Ubuntu | 704 MB | 34.4% | apt packages, build-essential, 网络工具 |
| 语言运行时 | 583 MB | 28.5% | JDK 25 (227MB), Node.js (196MB), Bun (104MB), Python |
| 编辑器/IDE | 440 MB | 21.5% | OpenVSCode (228MB), Helix (212MB) |
| 构建工具 | 186 MB | 9.1% | Gradle (150MB), Maven (37MB) |
| TUI/其他 | 134 MB | 6.5% | zellij, lazygit, mihomo, gh, starship, 等 |

**优化记录**: 已通过层优化节省 ~385 MB（APT cache 20MB, JDK jmods/man 50MB, uv cache 10MB, 临时文件 300MB, 文档 5MB）

**清理审计**: 99.6% 完成度，仅 1.5MB locale 文件未清理（系统依赖）

### Helper 脚本

- `scripts/openvscode-start.sh` — 快速启动 OpenVSCode Server，默认端口 3000，无认证
  - 用法: `openvscode-start [port]`
  - 安装到镜像: `/usr/local/bin/openvscode-start`

### 测试脚本（scripts/test-image.sh）

`check <name> <version_cmd> <usage_cmd> <expected> <test_desc>` — 版本检查 5s 超时，功能测试 10s
- 输出格式: 表格 (Tool | Version | Test | Result)
- 网络功能性测试失败不判定镜像失败（可能缺 CAP_NET_RAW）
- 常用选项: `-v/--verbose` 输出命令与原始结果；`--no-pull` 离线测试；环境变量 `DOCKER_BIN` 可指定宿主 docker 可执行

### Windows 行尾（CRLF/LF）

推荐配置：`git config --global core.autocrlf input` + `core.safecrlf true`

规范化：`git add --renormalize .` 后 `git status` 确认

## 用法

详见 [README.md](README.md)。
