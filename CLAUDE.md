# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**注意**: 本项目使用 [bd (beads)](https://github.com/steveyegge/beads) 进行 issue 追踪，请使用 `bd` 命令而非 markdown TODO，完整流程请参见 AGENTS.md。

## 项目概述

多语言开发环境 Docker 镜像 (Ubuntu 24.04 LTS)，镜像大小约 1.85GB。专为被企业策略禁用 WSL 的 Windows 用户设计。

**技术栈**: Zulu JDK 21 headless | Node.js 24 + Bun | Python 3.12 + uv/pipx | Maven + Gradle

**常用工具**: git, gh, jq, ripgrep, fd, fzf, tmux, lazygit, helix, bat, eza, delta, btop, starship, zoxide, bd, mihomo, ping, ip, ss, dig, nc, socat, ssh, curl, wget 等

## 常用命令

```bash
docker build -t buntoolbox .              # 构建镜像 (本地，较慢)
./scripts/test-image.sh                   # 从 Docker Hub 拉取并测试
./scripts/test-image.sh <image>           # 测试指定镜像
./scripts/check-versions.sh               # 检查工具版本更新
./scripts/check-versions.sh -v            # 详细模式，显示所有可用下载变体
```

## 架构

**Dockerfile 层顺序** (稳定→易变): 系统 → JDK → Python → uv/pipx → Maven → gh → Node/Bun → Gradle → TUI → 配置

**层优化策略**: 稳定的 apt 包放第一层，TUI 工具放最后。用户更新时只拉取变化的层。

**版本管理**: Dockerfile 顶部 ARG 声明 (`NODE_MAJOR`, `GRADLE_VERSION`, `*_VERSION`)

**CI/CD**: `.github/workflows/docker.yml` → Docker Hub (secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`)

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
- **`apt-get clean` 不省空间** — 在 `rm -rf /var/lib/apt/lists/*` 后已无残留
- **JDK jmods/man 可删** — 仅用于 jlink，容器不需要
- **测试 bd 用 `bd --help`** — `bd --version` 无数据库时返回非零
- **测试 mihomo 用 `-v` 和 `-h`** — 不支持 `--version` / `--help`
- **网络/开发工具新增** — 镜像已预装 iputils-ping、iproute2(含 ip/ss)、dnsutils(dig/nslookup/host)、netcat-openbsd(nc)、traceroute、socat、openssh-client(ssh/scp/sftp)、file、lsof、psmisc(killall/fuser/pstree)、bc；telnet 为可选，仅兼容性测试用

### 测试脚本架构（scripts/test-image.sh）

测试使用 `check()` 函数，签名: `check <name> <version_cmd> <usage_cmd> <expected> <test_desc>`
- 参数说明：
  - `<name>`: 工具名称
  - `<version_cmd>`: 版本检查命令（如 `git --version`）
  - `<usage_cmd>`: 功能测试命令（如 `git status`）
  - `<expected>`: 预期输出或结果（如版本号、功能性返回值等）
  - `<test_desc>`: 测试描述（简要说明测试目的）
- 版本检查: `timeout 5` 秒
- 功能测试: `timeout 10` 秒
- 输出格式: 表格 (Tool | Version | Test | Result)

测试策略:
- 先做"存在性"检查（版本输出），再做"功能性"检查（loopback/可预期目标）
- ping：使用 `127.0.0.1`；某些环境缺 CAP_NET_RAW 时功能测试可能失败
- 网络功能性测试失败不直接判定镜像失败

### Windows 行尾（CRLF/LF）
- 推荐：`git config --global core.autocrlf input`、`git config --global core.safecrlf true`
- `.gitattributes` 建议：
```
* text eol=lf
*.bat text eol=crlf
### 基本用法示例（Windows/Dev Containers）

- 规范化索引：`git add --renormalize .` 后 `git status` 确认

## 用法

详见 [README.md](README.md) 中的 Windows/Dev Containers 用法示例。

## 已优化

- JDK 11+17+21 → 仅 21 headless (节省 ~610MB)
- 删除 jmods/man、`/root/.launchpadlib`
- pipx 通过 uv 安装 (避免 Python 3.12 distutils 问题)
- GitHub API 缓存 (5分钟) 避免速率限制
- Ubuntu 基础镜像仅 78MB (92 个包，无 curl/wget/git/python/vim/ping/ssh)
