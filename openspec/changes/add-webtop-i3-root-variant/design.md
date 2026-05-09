## Context

当前 `buntoolbox:latest` 是基于 `ubuntu:26.04` 的 terminal/TUI/dev image，根 `Dockerfile` 暴露 `22` 和 `7681`，默认 `CMD ["/bin/bash"]`。README 中 `openvscode-start` 的默认端口语义是 `3000`，`ttyd-start` 的默认端口语义是 `7681`。

前序 webtop/i3 调研和本地验证显示，`linuxserver/webtop:ubuntu-i3` / `lscr.io/linuxserver/webtop:ubuntu-i3` 的核心价值在于已经封装了 browser desktop GUI stack：`/init`、s6、Xvfb、i3、Selkies、nginx/frontend 等。该 image 的 upstream `ubuntu-i3` Dockerfile 基于 `ghcr.io/linuxserver/baseimage-selkies:ubunturesolute`，并安装 i3/chromium/stterm/sway 等 GUI 组件。

同时，webtop runtime 脚本大量围绕 LinuxServer `abc` user model 设计：常见模式包括 `s6-setuidgid abc`、`chown abc:abc`、`pgrep -u abc`、`usermod abc`、`lsiown abc:abc`。buntoolbox 的目标体验是 root-first，因此 `buntoolbox:i3` 需要复用 webtop GUI stack，但不能把 `abc` 作为正常交互用户模型。

本 change 的设计边界是：新增 sibling image，而不是让 `i3` 继承 `buntoolbox:latest`，也不是让 `latest` 继承 GUI 组件。

## Goals / Non-Goals

**Goals:**

- 保持 `buntoolbox:latest` 的现有行为、默认入口、默认端口语义、默认测试入口和用户文档主路径不变。
- 新增 `buntoolbox:i3`，基于 `lscr.io/linuxserver/webtop:ubuntu-i3`，复用 webtop browser GUI stack。
- 在 `buntoolbox:i3` 中实现 root-first 正常交互体验：GUI desktop、terminal、toolchain、shell config 都应面向 root 和 `/root`。
- 将 webtop GUI HTTP 默认端口改为 `3200`，HTTPS 默认端口改为 `3201`，并保留 `3000` 给 `openvscode-start` 使用。
- 抽取 buntoolbox common toolchain install layers，供 `latest` 与 `i3` 复用，避免复制两份完整 Dockerfile。
- 抽取 common test checks，供 `latest` 与 `i3` 复用；`i3` 只增加 variant-specific runtime checks。
- 保持接近现有 Dockerfile 的 layer/cache 粒度，避免一个高频工具变更导致早期重层重建。
- 用 broad guard 防止 upstream webtop 升级后重新引入未审查的 `abc` runtime 行为。

**Non-Goals:**

- 不把 GUI/i3 组件加入 `buntoolbox:latest`。
- 不把 `buntoolbox:i3` 设计为从 `buntoolbox:latest` 派生。
- 不删除 webtop base 中的 `abc` account 作为第一目标；允许它为 upstream compatibility 存在，但正常 runtime path 不得使用它。
- 不让 openvscode-server 随 i3 image 默认自动启动；已决事项是 webtop 不占用 `3000`，`openvscode-start` 手动启动并服务 `3000` 是验收路径。
- 不把所有工具安装合并成一个大 install-all 层。
- 不在本地执行耗时 Docker build；正式镜像验证以 CI 或用户明确批准的构建为准。

## Decisions

### Decision: `latest` 与 `i3` 是 sibling images

`buntoolbox:latest` 继续从 `ubuntu:26.04` 构建；`buntoolbox:i3` 从 `lscr.io/linuxserver/webtop:ubuntu-i3` 构建。二者共享 buntoolbox toolchain payload，但不互相作为 base。

替代方案：

- 从 `buntoolbox:latest` 派生 `i3`：拒绝，因为用户明确要求基于已验证的 webtop i3 base。
- 让 `latest` 加入 GUI 组件：拒绝，因为会改变 `latest` 的大小、端口和运行语义。
- 单 Dockerfile multi-target：暂不选，因为会重构当前 `latest` 构建路径，增加不必要风险。

### Decision: 复用 webtop GUI stack，但 patch 掉正常 `abc` runtime path

Webtop GUI build entry 保留 webtop `/init` 与 s6 service topology，但在构建阶段应用 root-first patch。最初 i3 方案使用 `Dockerfile.i3`；后续 KDE 扩展已收敛为 shared `docker/webtop/Dockerfile`，通过 build args 区分 i3/kde。Patch 目标不是删除 `abc` account，而是禁止正常 GUI/runtime 路径使用 `abc`。

Patch 语义包括：

```text
s6-setuidgid abc -> root-first execution
chown abc:abc -> root:root
chown root:abc -> root:root
pgrep -u abc -> root equivalent
id/usermod/groupmod/lsiown/crontab 对 abc 的 runtime mutation -> 禁用或 root-first 替代
HOME/config generation -> /root-oriented defaults
```

替代方案：

- 接受 `abc` model：拒绝，因为不符合 buntoolbox root-first 用户体验。
- 删除 `abc` account：暂不选，因为 upstream baseimage 脚本可能引用该 account；直接删除会扩大破坏面。
- 自建 Xvfb/i3/Selkies stack：暂不选，因为会丢失 webtop 已验证 GUI stack 的维护收益。

### Decision: Guard 使用 broad deny-pattern scan，不使用已知文件 allowlist

Root-first patch 之前和之后都必须检查 webtop runtime surface。Guard 不只检查当前已知文件，而是扫描目录面：

```text
/etc/s6-overlay
/etc/services.d
/etc/cont-init.d
/etc/cont-finish.d
/custom-services.d
/defaults
/usr/local/bin
相关 webtop wrappers
```

Post-patch fatal patterns 包括但不限于：`s6-setuidgid abc`、`su abc`、`runuser -u abc`、`gosu abc`、`chown abc:`、`chown :abc`、`chown root:abc`、`pgrep -u abc`、`pkill -u abc`、`id -u abc`、`id -G abc`、`usermod .* abc`、`groupmod .* abc`、`lsiown abc:`、`crontab -u abc`、`setpriv .* abc`。

`/etc/passwd` 中仍存在 `abc` 不是 fatal。文档或注释中出现 `abc` 不是 fatal。Runtime shell 中出现 user/process/ownership 语义的 `abc` 是 fatal。

### Decision: 端口采用 buntoolbox-first policy

`3000` 保留给 `openvscode-start` / openvscode-server。Webtop GUI HTTP 从默认 `3000` 改到 `3200`，HTTPS 从默认 `3001` 改到 `3201`。`CUSTOM_WS_PORT` 必须在实现设计中显式决定：保持 upstream 默认时，需要说明它是内部端口还是需要 expose/test；迁移时，需要说明新端口和验证方式。

### Decision: Shared payload 使用细粒度 layer scripts

为了避免双份 Dockerfile 漂移，同时保留 cache 行为，新增共享构建资产，例如：

```text
docker/layers/
  01-apt-base-packages.sh
  02-jdk.env
  02-jdk.sh
  03-python.sh
  04-maven.env
  04-maven.sh
  ...
  10-beads.env
  10-beads.sh
  11-root-shell-config.sh
  12-image-release.sh
docker/webtop/
  root-first.patch
  root-first-guard.sh
  root-first-preflight.sh
```

每个当前 Dockerfile 的重层或高频层应保留近似独立的 `COPY + RUN` 粒度。版本源从 Dockerfile ARG 迁移到细粒度 env/snippet 后，版本检查和测试脚本必须同步读取新的单点来源。

### Decision: 测试抽取 common checks，再叠加 i3 variant checks

默认 `scripts/test-image.sh` 行为保持兼容，继续默认测试 `cuipengfei/buntoolbox:latest`。测试实现可以拆成：

```text
scripts/test-image.sh
scripts/lib/test-common-tools.sh
scripts/lib/test-i3-runtime.sh
```

`latest` 与 `i3` 共享 common tool checks。`i3` 额外验证 root-first、webtop 3200、3000 未被 webtop 占用、openvscode-start 可用、关键 GUI 进程不以 `abc` 运行。

### Decision: CI 使用独立 build/tag path

`.github/workflows/docker.yml` 保留 latest build/tag/push 逻辑，并新增 i3 build/tag/push 逻辑。PR 中 build/test 但不 push；master push 发布 `latest` 与 `i3`；release tag 发布 `X.Y.Z`、`X.Y`、`i3-X.Y.Z`、`i3-X.Y`。

## Risks / Trade-offs

- [Risk] Root-first patch 漏掉 upstream 新增 `abc` runtime path。→ Mitigation: post-patch broad deny-pattern scan；发现 fatal pattern 直接 fail build。
- [Risk] 共享 layer 抽取改变 `latest` 行为。→ Mitigation: 先迁移 `latest` 到共享层并保持默认测试兼容；验收要求 `latest` 默认构建、默认命令、默认端口和默认测试路径不变。
- [Risk] 共享脚本损害 Docker cache。→ Mitigation: 不使用大 install-all；高频工具保持独立 layer；版本 env/snippet 按 layer 贴近使用点复制。
- [Risk] Xvfb/i3/Selkies/dbus/pulseaudio 以 root 运行存在副作用。→ Mitigation: i3 variant-specific test 必须检查关键进程、browser endpoint 和 interactive root-first 行为；失败时修 patch，不退回正常 `abc` workflow。
- [Risk] 端口语义混淆。→ Mitigation: `CUSTOM_PORT=3200`，`CUSTOM_HTTPS_PORT=3201`；测试必须证明 webtop 不监听 `3000` 且 `openvscode-start` 可在 `3000` 服务。
- [Risk] Upstream tag drift。→ Mitigation: Gate 0 evidence 必须记录 canonical image digest、`build_version` 和 upstream revision；如果选择 digest pin 或 alias，必须记录理由。

## Migration Plan

1. 先实现 OpenSpec artifacts 和 Gate 0 evidence 采集任务，不直接动 Docker build 逻辑。
2. 抽取共享 layer scripts/env snippets，并让现有 `Dockerfile` 使用它们；验证 `latest` 默认行为和测试入口保持兼容。
3. 新增 `Dockerfile.i3` 或等价 Webtop build entry；后续采用 shared `docker/webtop/Dockerfile`，从 `lscr.io/linuxserver/webtop:ubuntu-i3` 开始，加入 root-first preflight/patch/guard，再复用共享 toolchain layers。
4. 重构测试脚本，抽取 common tool checks，增加 i3 runtime checks。
5. 更新 GitHub Actions，增加 i3 build/tag/push 路径。
6. 更新 README 和 image metadata。
7. 通过 OpenSpec validate、shell syntax check、test-image common/i3 paths 和 CI 收口。

## Rollback Strategy

- 如果 shared layer 抽取导致 `latest` 行为漂移，回退共享层迁移，保留原 `Dockerfile` 路径，先只保留 proposal/design 记录。
- 如果 root-first patch 在 upstream webtop 上失败，guard 应 fail build；不要发布 `i3` tag。
- 如果 i3 CI 失败，必须保证 latest build/tag/push 路径仍可独立通过。
- 删除 i3 variant 的回退范围应限于 Webtop build entry、`docker/webtop/`、i3-specific CI tag/path 和 i3 docs，不影响 `latest`；如果 shared `docker/webtop/Dockerfile` 同时服务 KDE，回退时必须避免误删 KDE 仍需的共享入口。

## Resolved Decisions / Remaining Questions

- 已决：`CUSTOM_WS_PORT` 保持 upstream 内部默认，不新增 Docker `EXPOSE`；外部验收覆盖 webtop `3200`/`3201` 与 openvscode `3000`。
- 已决：`buntoolbox:i3` 不默认自动启动 openvscode-server；`openvscode-start` 手动启动并服务 `3000` 是验收路径。
- 剩余问题：是否 pin `lscr.io/linuxserver/webtop:ubuntu-i3` digest？默认可以跟随 tag，但必须记录 manifest digest、build_version/revision 证据；如果 upstream drift 频繁破坏 root-first patch，应考虑 pin digest。
