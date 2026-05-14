## ADDED Requirements

说明：本文档正文使用中文；`ADDED Requirements`、`Requirement`、`Scenario`、`SHALL`、`MUST`、`WHEN`、`THEN` 是 OpenSpec 规范关键字，按校验器要求保留英文。

### Requirement: 以上游 Webtop KDE 作为规范基准

系统 SHALL 以上游 LinuxServer Webtop Ubuntu KDE 和 baseimage-selkies 的 runtime contract 作为 KDE browser desktop 的规范基准，并在实现前记录本次使用的 upstream source、image digest、关键 Dockerfile/env/service 文件和差异说明。

#### Scenario: 记录上游 KDE Dockerfile 证据
- **WHEN** 开始实现 KDE mimic 变更
- **THEN** evidence MUST 记录 `docker-webtop` 的 `ubuntu-kde` Dockerfile 来源、commit 或 digest、`FROM ghcr.io/linuxserver/baseimage-selkies:ubunturesolute`、`TITLE="Ubuntu KDE"`、`PIXELFLUX_WAYLAND=true`、KDE package list、`COPY /root /`、`EXPOSE 3001` 和 `VOLUME /config`

#### Scenario: 记录 baseimage-selkies 证据
- **WHEN** 开始实现 KDE mimic 变更
- **THEN** evidence MUST 记录 baseimage-selkies 的 s6 service surface，至少包括 `init-nginx`、`init-selkies-config`、`svc-nginx`、`svc-selkies`、`svc-de`、`svc-pulseaudio`、`svc-dbus`、`svc-xorg`、`svc-watchdog` 和 `/defaults/default.conf`

#### Scenario: 差异必须有理由
- **WHEN** buntoolbox 行为与上游 Webtop KDE 不一致
- **THEN** 每个差异 MUST 说明原因，并归类为 WSL 不适配、buntoolbox 既有合同、root-first 合同、安全/端口合同或暂不支持项

### Requirement: Browser delivery 必须走 Webtop/Selkies 链路

系统 SHALL 通过 Webtop/Selkies browser streaming 链路提供 KDE 桌面，而不是用 VNC/noVNC/xrdp/WSLg 冒充 Webtop KDE 成功。

#### Scenario: 启动链路包含 Webtop 基础服务
- **WHEN** KDE variant 容器启动
- **THEN** `/init` MUST 启动 s6，并启动或配置 nginx、Selkies websocket backend、DBus、PulseAudio、desktop session service 和必要的 display/runtime 目录

#### Scenario: 浏览器入口通过 nginx 暴露
- **WHEN** Windows 浏览器访问 buntoolbox KDE desktop
- **THEN** 请求 MUST 进入 Webtop nginx/frontend，并通过内部 websocket upstream 连接 Selkies backend

#### Scenario: 禁止替代链路冒充成功
- **WHEN** VNC/noVNC/xrdp/WSLg 能显示某个 KDE 或 Linux GUI 窗口
- **THEN** 该结果 MUST NOT 被记为本 capability 的 Webtop KDE mimic 成功，除非同时证明 nginx/Selkies/Webtop frontend 链路可用

### Requirement: KDE 会话必须 mimic 上游 Wayland/Plasma 启动链

系统 SHALL 默认采用上游 KDE Wayland 启动模型：`PIXELFLUX_WAYLAND=true`，`startwm_wayland.sh` 配置 KDE，`dbus-run-session` 启动 KWin Wayland/Xwayland 和 Plasma Shell。

#### Scenario: KDE Wayland marker 存在
- **WHEN** KDE desktop runtime 进入 ready 状态
- **THEN** process evidence MUST 显示 `kwin_wayland` 或等价 KWin Wayland marker、`Xwayland :1` 或等价 Xwayland marker、`plasmashell`、DBus session 和 KDE auth/desktop supporting process 中的关键项

#### Scenario: 上游 KDE tweaks 被保留或解释
- **WHEN** 实现处理 KDE startup scripts
- **THEN** MUST 保留或显式解释以下上游行为：禁用 KWin compositing、禁用 screen lock、设置 clipboard rule、创建 `$HOME/.XDG`、设置 `QT_QPA_PLATFORM=wayland`、`XDG_CURRENT_DESKTOP=KDE`、`XDG_SESSION_TYPE=wayland`、`KDE_SESSION_VERSION=6`、`DISPLAY=:1`

#### Scenario: Wayland fallback 不能静默改变目标
- **WHEN** CPU/WSL/Docker Desktop 环境导致 Wayland 不可用或 AVX2 检查失败
- **THEN** implementation MUST 记录 fallback 原因，并将 release verdict 标记为 blocker 或 non-mimic/degraded evidence；不得把 X11 fallback、WSLg 或任意非 Wayland path 当作 `ubuntu-kde` mimic release pass

### Requirement: buntoolbox 差异必须最小且可验证

系统 SHALL 只在明确必要处偏离上游 Webtop KDE，并为每个偏离提供测试或证据。

#### Scenario: root-first 合同
- **WHEN** buntoolbox KDE container 内交互 shell 或 GUI terminal 打开
- **THEN** `whoami` MUST 为 `root`，`HOME` MUST 为 `/root`，关键 Webtop/KDE/Selkies 支撑进程 MUST NOT 以 `abc` 作为正常 runtime user 运行；nginx worker 可以使用 `www-data` 或 nginx 默认服务用户，但 MUST NOT 使用 `abc`

#### Scenario: 端口合同
- **WHEN** buntoolbox KDE container 启动
- **THEN** Webtop HTTP MUST 默认监听并响应 `3200`，Webtop HTTPS MUST 默认监听 `3201` 且至少可 TLS 握手或返回 self-signed HTTPS 响应，Webtop MUST NOT 占用 `3000`，`openvscode-start` MUST 能在 `3000` 服务

#### Scenario: 内部 websocket 端口合同
- **WHEN** nginx 配置生成
- **THEN** `CUSTOM_WS_PORT` 或等价内部 websocket upstream MUST 被记录为内部端口，不应要求用户直接暴露；如果改变上游默认 `8082`，MUST 说明原因并更新测试

### Requirement: WSL / Windows browser 验收必须端到端

系统 SHALL 在当前 WSL + Docker Desktop + Windows browser 场景中定义并执行端到端验收，而不仅是容器内进程存在检查。

#### Scenario: WSL runbook 可复现启动
- **WHEN** 用户按文档在当前 WSL 启动 `buntoolbox:kde`
- **THEN** 文档 MUST 给出完整 `docker run` 或 compose 示例，包含端口映射、`--shm-size`、推荐 seccomp/IPC/设备选项、可选 GPU 参数和不适用项说明

#### Scenario: Windows 浏览器 minimal action
- **WHEN** Windows 浏览器打开 `http://localhost:3200/` 或 `https://localhost:3201/`
- **THEN** 用户 MUST 能看到 KDE Plasma desktop，打开 Konsole 或 Dolphin，执行一个最小交互动作，并在 `openspec/changes/mimic-webtop-kde-wsl/evidence.md` 记录页面 URL、时间戳、截图路径或等价 artifact、动作描述、对应 `ps`/`curl`/`ss`/`docker logs` 摘要

### Requirement: Evidence artifact 必须可审计

系统 SHALL 在 implementation 阶段把所有发布资格证据集中写入 `openspec/changes/mimic-webtop-kde-wsl/evidence.md`，并在 evidence 中给出最终 release verdict。

#### Scenario: Evidence 文件字段完整
- **WHEN** implementation 声称 KDE mimic 完成
- **THEN** `evidence.md` MUST 包含采集日期、upstream source URL、branch/commit 或 digest、baseimage-selkies source、image tag/digest、容器启动命令、WSL/Docker Desktop baseline、HTTP 3200 证据、HTTPS 3201 证据、websocket upstream 证据、KDE Wayland process evidence、root-first/no-abc evidence、Windows browser minimal action evidence、GPU optional evidence 或未测说明、已知偏差和 release verdict

#### Scenario: Evidence 缺失阻止完成
- **WHEN** `evidence.md` 缺失、release verdict 缺失，或 browser minimal action 只有人工描述没有 artifact/日志摘要
- **THEN** implementation MUST NOT 被标记为完成

#### Scenario: 停止后无异常残留
- **WHEN** KDE container 被停止和删除
- **THEN** WSL/Docker Desktop side MUST 不留下由本次 runbook 创建的异常长期进程、异常端口监听或未说明的 host-level mutation

### Requirement: GPU/WSL 能力必须分层表达

系统 SHALL 把 KWin compositor、GUI app OpenGL、Selkies stream encoding 三层能力分开验证和陈述，不能把任一层的成功当作全部 GPU 加速成功。

#### Scenario: 最小成功不依赖 GPU
- **WHEN** 没有可用 `/dev/dri`、NVIDIA runtime 或 WSLg `/dev/dxg` 映射
- **THEN** browser-accessible KDE desktop 仍 MUST 有 CPU/software path 的最小成功标准，除非上游 Wayland/KDE 本身无法启动并已记录 blocker

#### Scenario: 官方 GPU path 与 WSL path 分开
- **WHEN** 文档说明 GPU 选项
- **THEN** MUST 区分 LinuxServer 官方 `/dev/dri`/NVIDIA/`DRINODE`/`DRI_NODE` path、WSL Docker Desktop 可实验的 `/dev/dxg`/Mesa D3D12 GUI app OpenGL path，以及 Selkies encoding path

#### Scenario: 不夸大 VAAPI/NVENC
- **WHEN** 验证 GPU 或编码
- **THEN** MUST 用 `glxinfo -B`、`eglinfo`、Selkies logs、browser session 画面和非空 stream/recording 等证据分别支撑，不能用 `nvidia-smi`、`btop` 或设备存在本身作为 KDE Webtop GPU 成功证据

### Requirement: 发布和回归验证覆盖 KDE variant

系统 SHALL 将 KDE mimic 变更纳入 buntoolbox 的构建、测试、文档和发布闭环。

#### Scenario: 本地静态验证
- **WHEN** implementation 完成但尚未发布
- **THEN** MUST 通过 OpenSpec validate、脚本语法检查、Dockerfile/build args 静态检查、root-first guard fixture、KDE runtime test script review 和 README/runbook review

#### Scenario: CI 构建验证
- **WHEN** GitHub Actions 构建 KDE variant
- **THEN** CI MUST 构建 `buntoolbox:ci-kde-test` 或等价测试 tag，执行 common tool checks、webtop runtime checks 和 KDE-specific checks，再发布 `cuipengfei/buntoolbox:kde`

#### Scenario: 发布后 WSL 验收
- **WHEN** `cuipengfei/buntoolbox:kde` 发布完成
- **THEN** MUST 在当前 WSL 使用发布镜像运行 `scripts/test-image.sh --variant kde --image cuipengfei/buntoolbox:kde`，并完成 Windows browser minimal action 记录
