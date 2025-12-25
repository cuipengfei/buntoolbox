# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**注意**: 本项目使用 [bd (beads)](https://github.com/steveyegge/beads) 进行 issue 追踪，请使用 `bd` 命令而非 markdown TODO，完整流程请参见 AGENTS.md。

## 项目概述

多语言开发环境 Docker 镜像 (Ubuntu 24.04 LTS)，镜像约 2.0GB。专为被企业策略禁用 WSL 的 Windows 用户设计。

**技术栈**: Zulu JDK 21 headless | Node.js 24 + Bun | Python 3.12 + pip/uv/pipx | Maven + Gradle

**常用工具**: git, gh, jq, ripgrep, fd, fzf, tmux, zellij, lazygit, helix, bat, eza, delta, btop, starship, zoxide, procs, bd, mihomo, openvscode-server 等（网络: ping, ip, ss, dig, nc, socat, ssh, sshd）

## 常用命令

```bash
docker build -t buntoolbox .              # 构建镜像 (本地，较慢)
./scripts/test-image.sh                   # 从 Docker Hub 拉取并测试
./scripts/test-image.sh <image>           # 测试指定镜像
./scripts/check-versions.sh               # 检查工具版本更新
./scripts/check-versions.sh -v            # 详细模式，显示所有可用下载变体
```

## 架构

**Dockerfile 层顺序** (按更新频率优化):
1. 系统基础 (apt packages) - 最稳定
2. JDK 21 - 稳定
3. Python 3.12 + pip - 稳定
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

**CI/CD**: `.github/workflows/docker.yml` → Docker Hub (secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`)

## 添加/更新工具时必须同步更新

| 文件 | 更新内容 |
|------|----------|
| `Dockerfile` | ARG 版本声明 + 安装指令 |
| `image-release.txt` | 工具列表（嵌入镜像 /etc/image-release） |
| `scripts/check-versions.sh` | 版本检查 |
| `scripts/test-image.sh` | 功能测试 |
| `CLAUDE.md` | 常用工具列表 |
| `README.md` | 包含组件列表 |

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
- **频繁更新的工具放最后** — beads 已移到最后一层，减少层重建影响
- **pip 不要升级** — 使用 apt 安装的 pip 即可，尝试升级会因 PEP 668 和缺少 RECORD 文件失败

### 镜像大小组成（2047 MB）

| 组件类型 | 大小 | 占比 | 主要内容 |
|---------|-----:|-----:|----------|
| 系统基础 + Ubuntu | 704 MB | 34.4% | apt packages, build-essential, 网络工具 |
| 语言运行时 | 583 MB | 28.5% | JDK 21 (227MB), Node.js (196MB), Bun (104MB), Python |
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

### Windows 行尾（CRLF/LF）

推荐配置：`git config --global core.autocrlf input` + `core.safecrlf true`

规范化：`git add --renormalize .` 后 `git status` 确认

## 用法

详见 [README.md](README.md)。
