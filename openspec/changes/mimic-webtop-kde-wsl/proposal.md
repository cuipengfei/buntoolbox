## Why

说明：本文档正文使用中文；`Why`、`What Changes`、`Capabilities`、`Impact` 等标题是 OpenSpec schema 识别用语，按工具约定保留英文。

当前 `buntoolbox:kde` 方向必须以 LinuxServer Webtop KDE 的真实链路为基准，而不是只“装一个 KDE”或用 VNC/WSLg 近似替代。用户要求的完成定义是：在当前 WSL / Docker Desktop 场景中启动 KDE 桌面，并能从 Windows 浏览器打开和操作这个 KDE desktop，体验和 LinuxServer `webtop:ubuntu-kde` 尽量一致；只有在 Webtop 做法明确不适合 WSL 或 buntoolbox 既有端口/root-first 约束时才做差异化。

## What Changes

- 建立一个完整的 KDE/Webtop mimic 变更方案，明确上游事实、架构边界、实现任务和验收标准。
- 以 `lscr.io/linuxserver/webtop:ubuntu-kde` / `ghcr.io/linuxserver/baseimage-selkies:ubunturesolute` 的 runtime contract 为基准：`/init`、s6 service graph、nginx、Selkies websocket backend、PulseAudio/DBus、Wayland/KWin/Xwayland、`startwm_wayland.sh`、`plasmashell`。
- 对 buntoolbox 的 Webtop variant 采用 sibling image 方式，复用现有 `docker/webtop/Dockerfile`、shared toolchain layers、root-first patch/guard、webtop runtime tests，并补齐 KDE-specific parity 和 WSL acceptance。
- 默认保持上游 KDE Wayland 语义：`TITLE="Ubuntu KDE"`、`PIXELFLUX_WAYLAND=true`、KWin Wayland + Xwayland、Plasma Shell、Konsole/Dolphin/Chromium 等 KDE desktop 包。
- 默认保持上游 browser delivery 语义：nginx 对外提供 Web Desktop GUI，Selkies backend 只作为内部 websocket upstream，不把 VNC/noVNC/xrdp/WSLg 当作成功替代。
- 明确 buntoolbox 必要差异：交互用户和 `$HOME` 改为 root-first `/root`；Webtop HTTP/HTTPS 改为 `3200`/`3201`，`3000` 保留给 `openvscode-start`；WSL GPU 只作为分层可选能力，不作为 KDE browser desktop 最小成功前置。
- 补齐验证闭环：source/provenance evidence、Dockerfile/build args、root-first guard、KDE Wayland process markers、nginx/Selkies endpoint、Windows browser minimal action、WSL/Docker Desktop runbook、README/metadata/CI/test-image 收口。
- 新增 `openspec/changes/mimic-webtop-kde-wsl/evidence.md` 作为 implementation evidence 落点，记录 upstream provenance、runtime logs、endpoint checks、Windows browser evidence 和 release verdict。
- 不进入实现；本 change 先生成中文 OpenSpec artifacts，后续 implementation 必须先经过 architect 和 critic 审阅。

## Capabilities

### New Capabilities

- `wsl-webtop-kde-mimic`: 定义 buntoolbox 在 WSL / Docker Desktop 环境中以 LinuxServer Webtop KDE 为基准提供 browser-accessible KDE desktop 的行为、差异边界、运行合同和验收标准。

### Modified Capabilities

- 无。

## Impact

- 影响 `docker/webtop/Dockerfile` 的 KDE build args / labels / env contract，以及 `docker/webtop/root-first-*` 对 Webtop KDE runtime surface 的适配和 guard。
- 影响 shared toolchain layer 在 KDE variant 中的复用、`image-release.txt` 的 variant metadata、README 和 WSL runbook 文档。
- 影响 `scripts/test-image.sh`、`scripts/lib/test-webtop-runtime.sh`、`scripts/lib/test-kde-runtime.sh`，并需要补齐 Windows browser / WSL acceptance 证据路径。
- 影响 GitHub Actions 对 `cuipengfei/buntoolbox:kde` 的构建、发布、post-push image test 和 provenance 记录。
- 不应改变 `buntoolbox:latest` 的 terminal/TUI 行为，不应改变 `buntoolbox:i3` 的既有通过路径，不应把 VNC/noVNC/WSLg 设计成 KDE mimic 的替代成功路径。
- 发布资格必须以 HTTPS `3201` 至少可访问或可握手为 release MUST；HTTP `3200` 可作为主要手动 browser minimal action 入口，但不能替代 HTTPS readiness。
- Wayland marker 不成立时，KDE variant 不得算 release pass；只能记录为 blocker 或 non-mimic/degraded evidence，除非另开变更重新定义目标。
