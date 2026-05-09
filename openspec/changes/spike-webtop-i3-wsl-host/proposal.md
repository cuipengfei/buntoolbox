## Why

前序调研记录显示 `linuxserver/webtop:ubuntu-i3` 的目标链路不是 VNC/noVNC，也不是 WSLg，而是 `Xvfb -> i3 -> Selkies websocket -> nginx/frontend`；实施 Gate 0 必须重新记录 Dockerfile、image metadata 和关键启动文件证据后，才能把该链路作为本 spike 的已验证前提。在决定是否把 i3/browser desktop 方向纳入 buntoolbox 前，需要先在当前 WSL 中做一个可回退、低污染的 user-level 试运行。

## What Changes

- 新增一个 WSL host 侧的 spike/test-run 方案，用于尽量 mimic `linuxserver/webtop:ubuntu-i3` 的浏览器访问 i3 桌面体验。
- 方案目标链路为：`Xvfb :1` 启动 headless X display，`dbus-launch --exit-with-session /usr/bin/i3` 启动 i3，Selkies 以 websocket mode 提供 streaming backend，再通过 user-level frontend/proxy 暴露给 Windows browser。
- 所有 runtime 状态、日志、配置、Python venv 和 pid 文件必须放在 user-level 目录，例如 `~/.local/share/webtop-i3/`，不得污染真实 `$HOME`、系统 nginx、sudoers、Docker daemon 或 buntoolbox Dockerfile。
- 系统依赖安装若不可避免，必须被当作 host-level mutation 单独记录：安装前状态、安装命令、安装后验证、人工回退建议和“不自动删除用户已有包”的边界都必须写入 records。
- 所有安装、文件变更、配置变更、端口选择和环境变量设置都必须记录到文档或任务结果中，并记录对应的回退方式；不要求做大体积备份，但必须能知道如何手动撤回。
- 第一阶段只验证 i3 workflow 和 browser-delivered desktop 手感。最小成功标准是：Windows browser 能访问 localhost endpoint、看到 i3 session、启动 terminal 或指定轻量 X app、完成一个 i3 workspace/fullscreen 类最小动作、停止后没有 spike-owned 残留进程。
- HTTPS、Chromium、中文输入、GPU/NVENC parity、音频和 Wayland/labwc fallback 均为可选观察项，不属于最小成功标准。
- 本变更不直接修改 buntoolbox 镜像；它只是为后续是否采用 i3 提供实测依据。

## Capabilities

### New Capabilities
- `wsl-webtop-i3-spike`: 定义在当前 WSL 中以低污染、可回退方式运行 browser-accessible i3 desktop spike 的行为、边界、验收标准和记录要求。

### Modified Capabilities
- 无。

## Impact

- 影响当前 WSL 用户环境的候选安装包、用户级目录、启动/停止/status 脚本、端口监听和日志记录。
- 不应影响 buntoolbox Dockerfile、README、image-release.txt、CI、系统级 nginx、sudoers、Docker daemon、真实用户 `$HOME` 的 shell/agent 配置。
- 需要新增 OpenSpec artifacts 记录设计边界、任务步骤、回退记录要求和后续是否进入 buntoolbox adoption 的决策标准。
