## Why

当前 `buntoolbox:latest` 是 terminal/TUI/dev image，不能为了 GUI/i3 试验而改变既有默认入口、端口语义和用户体验。前序 spike 已验证 i3/browser desktop 方向可用，因此需要新增一个独立的 `buntoolbox:i3` 变体，让用户能选择 GUI desktop，同时保持 `latest` 完全不变。

## What Changes

- 新增独立镜像变体 `buntoolbox:i3`，基于 canonical LinuxServer image `lscr.io/linuxserver/webtop:ubuntu-i3`。
- 保留 `buntoolbox:latest` 的既有行为：根 `Dockerfile` 默认构建 terminal/TUI image，默认命令、默认端口、默认 `test-image.sh` 行为和 README 主路径不被 GUI 变体改变。
- 在 i3 变体中复用 webtop 的 `/init`、s6、Xvfb、i3、Selkies/browser GUI stack，但通过 root-first patch 不采用 LinuxServer `abc` user model 作为正常交互体验。
- 将 webtop browser GUI HTTP 默认端口移到 `3200`，HTTPS 默认端口移到 `3201`；`3000` 保留给 `openvscode-start` / openvscode-server 使用。
- 抽取 buntoolbox common toolchain 安装逻辑，使 `latest` 与 `i3` 共享工具版本和安装脚本，避免复制两份完整 Dockerfile。
- 保持现有 Docker layer/cache 粒度：共享逻辑不得合并为一个巨大 install-all 层，升级高频工具不得导致 JDK、Python、Node 等早期重层重建。
- 抽取共享测试逻辑，让 `latest` 与 `i3` 共用 common tool checks；`i3` 只增加 root-first、webtop port、GUI process 等 variant-specific checks。
- 增加 root-first guard，对 webtop runtime surface 做 broad deny-pattern scan；如果 upstream webtop 升级后重新引入未审查的 `abc` runtime 行为，构建必须 fail closed。
- 更新 GitHub Actions，使默认分支和 release tag 继续发布 `latest`，并新增发布 `i3` / `i3-*` tag；PR 中 build/test 但不 push。
- 更新 README 和 image metadata，说明 `latest` 与 `i3` 的用途、端口、root-first 行为、desktop runtime 注意项和安全边界。

## Capabilities

### New Capabilities

- `docker-image-variants`: 定义 buntoolbox 多镜像变体的构建、运行、测试和发布行为，覆盖 `latest` 与 `i3` 的边界、共享 toolchain、root-first webtop patch、端口策略、CI tag 策略和验收要求。

### Modified Capabilities

- 无。

## Impact

- 影响 Docker 构建结构：根 `Dockerfile` 需要逐步迁移到共享 layer scripts，但 `buntoolbox:latest` 行为必须保持兼容。
- 新增 `Dockerfile.i3` 或等价 i3 构建入口；后续 KDE 扩展已将 Webtop GUI variants 收敛到 shared `docker/webtop/Dockerfile`，并保留 webtop root-first patch、preflight/guard 脚本和 i3 variant runtime 配置。
- 影响脚本：`scripts/check-versions.sh`、`scripts/check-wsl-versions.sh`、`scripts/test-image.sh` 需要读取新的共享版本来源，并复用 common checks。
- 影响 CI：`.github/workflows/docker.yml` 需要增加 i3 build/tag/push 路径；后续 KDE 扩展还新增 kde build/tag/push 路径，但不能让 GUI variants 发布 `latest`。
- 影响文档：`README.md`、`image-release.txt` 或 variant-specific metadata 需要说明 `latest`、`i3`、`kde` 等 image 的选择、端口和安全注意项。
- 外部依赖：新增对 `lscr.io/linuxserver/webtop:ubuntu-i3` 的构建期依赖；实施阶段必须记录 digest、`build_version` 和 upstream revision，以便追踪 tag drift。
