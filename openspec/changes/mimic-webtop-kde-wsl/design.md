## Context

说明：本文档正文使用中文；`Context`、`Goals / Non-Goals`、`Decisions`、`Risks / Trade-offs`、`Open Questions` 等标题是 OpenSpec schema 识别用语，按工具约定保留英文。

本 change 的目标是纯 WSL native：在当前 WSL 里直接运行 KDE desktop 和 browser streaming 服务，然后从 Windows 浏览器打开并操作 KDE。

Webtop KDE 的参考价值在于它定义了目标体验和服务关系：

```text
Windows browser
└─ Webtop/Selkies-style frontend
   └─ websocket/backend session
      └─ KDE desktop session
         ├─ KWin / display server compatibility layer
         ├─ Plasma Shell
         ├─ DBus / PulseAudio or PipeWire / desktop services
         └─ Konsole / Dolphin / Chromium 等 KDE apps
```

这个服务关系要在 WSL native 里复刻。不能通过 Docker、container、image、compose 或 Docker Desktop 获得；不能通过 WSLg 单应用窗口假装完成；不能把 VNC/noVNC/xrdp/RDP 作为 Webtop KDE 的等价替代。

本 change 的行为基线必须来自上游源码，而不是截图印象或 trial-and-error。当前已固定的 source inventory：

- Webtop KDE flavor：`/tmp/wsl-webtop-source-study/docker-webtop-ubuntu-kde`，branch `ubuntu-kde`，commit `45619c47324ef14a39485fa96269d5ed3ce4ce14`。
- Baseimage/Selkies runtime：`/tmp/wsl-webtop-source-study/docker-baseimage-selkies`，branch `master`，commit `93d956bfecbc511dbeb8dbece741ad361f2d9a6e`。
- Selkies LSIO backend/frontend contract：`/tmp/wsl-webtop-source-study/selkies-lsio`，branch `lsio`，commit `aae6a4de653bb95da0a6b820f885fb6b30a5e35c`。

需要复刻的是这些源码定义出的 runtime behavior。若实现阶段重新 clone 或更新这些 repo，必须先记录新的 branch/commit，并重新核对关键文件是否变更。

## Goals / Non-Goals

**Goals:**

- 当前 WSL native 环境能启动 KDE desktop session。
- Windows 浏览器能打开本机 URL，并看到完整 KDE Plasma desktop。
- 浏览器里的视觉和交互必须与 LinuxServer Webtop KDE exactly same；只有 WSL hard limit 才允许差异。
- 采用 Webtop/Selkies 风格 browser desktop：frontend + streaming backend + KDE session。
- KDE session 应包含 Plasma Shell、窗口管理、Konsole/Dolphin、剪贴板/输入/窗口交互等完整桌面能力。
- 识别并记录 WSL hard limits：systemd、Wayland/X11、GPU、audio、network forwarding、certificate/browser API 等。

**Non-Goals:**

- 不使用 Docker、container、image、compose 或 Docker Desktop。
- 不修改任何 buntoolbox 产品代码、Dockerfile、scripts、CI、README、image metadata、测试脚本或 release workflow。
- 不把 WSLg 单应用窗口当作 browser desktop。
- 不用 VNC/noVNC/xrdp/RDP 作为成功替代。
- 不接受“像 Webtop KDE”或“差不多能看到 KDE”；要求 exactly same，除非 WSL hard limit。
- 不把额外证据文件作为 DoD；DoD 是浏览器里真实打开并看到 KDE desktop。

## Decisions

### Decision: 实现对象是 WSL native host

所有实现动作都发生在当前 WSL native 环境中：安装 packages、配置服务、启动 KDE session、启动 browser streaming frontend/backend、设置端口和 Windows browser 访问路径。

禁止把任务转成构建或运行某个外部打包产物。仓库只承载 OpenSpec proposal，不是实现对象。

### Decision: Webtop KDE 是 exact behavior template，不是运行依赖

Webtop KDE 用来定义“应该长什么样、怎么交互、有哪些服务关系”。WSL native 方案应复刻它的 browser desktop 体验：浏览器连接 frontend，frontend 连接 streaming backend，backend 展示 KDE session。

如果某个上游机制无法在 WSL native 里原样使用，必须先判断是否为 WSL hard limit。只有 hard limit 才允许替换，并且替换后的体验仍必须满足 Webtop KDE 的 frontend/interaction 语义；不满足则不是完成。

WSL hard limit 必须是经过合理 native 配置尝试后仍存在的平台/runtime 限制；缺包、未配置、未尝试的配置、实现困难、时间不足或为了方便做的取舍，都不得归类为 WSL hard limit。

### Decision: Upstream source is the source of truth

“exactly same as Webtop KDE”必须落到上游源码事实，而不是主观观感。当前 KDE flavor 的 primary path 是：

```text
linuxserver/docker-webtop:ubuntu-kde
├─ Dockerfile
│  ├─ FROM ghcr.io/linuxserver/baseimage-selkies:ubunturesolute
│  ├─ ENV TITLE="Ubuntu KDE" PIXELFLUX_WAYLAND=true
│  ├─ install plasma-desktop / plasma-workspace / kwin-x11 / konsole / dolphin / wl-clipboard-rs-tools
│  └─ setcap -r /usr/bin/kwin_wayland
├─ root/defaults/startwm_wayland.sh
│  ├─ disable KWin compositing and screen autolock
│  ├─ create wl-clipboard KWin rule
│  ├─ export QT_QPA_PLATFORM=wayland, XDG_SESSION_TYPE=wayland, KDE_SESSION_VERSION=6, DISPLAY=:1
│  └─ dbus-run-session:
│     ├─ WAYLAND_DISPLAY=wayland-1 python3 /kwin-xwayland.py &
│     ├─ polkit-kde-authentication-agent-1 &
│     └─ WAYLAND_DISPLAY=wayland-0 plasmashell
└─ root/kwin-xwayland.py
   ├─ bind /tmp/.X11-unix/X1
   └─ exec kwin_wayland --no-lockscreen --xwayland --xwayland-display=:1 --xwayland-fd=<fd>
```

`baseimage-selkies` 的 primary path 是：

```text
init-selkies-config
├─ AVX2 check; unsupported CPU falls back from PIXELFLUX_WAYLAND
├─ XDG_RUNTIME_DIR=$HOME/.XDG
├─ DRI_NODE/renderD128 detection
└─ gamepad/input/env defaults

svc-xorg
└─ if PIXELFLUX_WAYLAND=true: sleep infinity

svc-selkies
└─ exec selkies --addr=localhost --mode=websockets

svc-de
└─ if PIXELFLUX_WAYLAND=true:
   ├─ wait $XDG_RUNTIME_DIR/${WAYLAND_DISPLAY:-wayland-1}
   └─ run /defaults/startwm_wayland.sh

nginx
├─ serve /usr/share/selkies/web/
└─ proxy /websocket to 127.0.0.1:${CUSTOM_WS_PORT:-8082}
```

WSL native implementation MUST mimic this graph first. If a node cannot be used unchanged, the deviation must identify the source node it replaces and why WSL requires the difference.

### Decision: Distribution-faithful reuse, not handwritten mimic

WSL native implementation MUST reuse upstream distribution artifacts or faithfully port their behavior before inventing local replacements. The target is not a visually similar KDE-in-browser demo; it is Webtop KDE distribution behavior reconstructed in WSL native as far as the platform permits.

MUST reuse-or-faithfully-port nodes include:

- Webtop KDE `root/defaults/startwm_wayland.sh`.
- Webtop KDE `root/kwin-xwayland.py`.
- Baseimage-selkies `init-selkies-config`.
- Baseimage-selkies `init-nginx`.
- Baseimage-selkies `default.conf`.
- Baseimage-selkies `svc-selkies`.
- Baseimage-selkies `svc-de`.
- Selkies frontend assets and websocket path construction.
- Selkies backend `MODE websockets` / settings / frame contract.

Implementation MUST NOT introduce handwritten proxy, handwritten launcher, handwritten frontend, arbitrary DISPLAY allocation, arbitrary env override, omitted upstream script behavior, or “looks-similar” replacement unless all of the following are true:

1. the exact upstream source node is named;
2. the native WSL attempt is recorded;
3. the failure is proven not to be a config gap;
4. the replacement is the smallest adapter that preserves Webtop/Selkies semantics;
5. critic/verifier sign-off accepts the deviation as WSL hard limit.

Known current WSL runtime anti-patterns that MUST NOT be carried forward as defaults:

- handwritten `/tmp/wsl-kde-webtop/lsio-proxy.py` instead of source-mapped `default.conf` semantics;
- handwritten/generated KDE launcher instead of faithful `startwm_wayland.sh` reuse/port;
- `DISPLAY=:20` and `/tmp/.X11-unix/X20` drift from upstream `DISPLAY=:1` / `X1` without hard-limit proof;
- omitted upstream script behavior such as clipboard KWin rule, autostart bridge, UDisks service handling, `applications.menu` handling, `kbuildsycoca6`, `dbus-run-session` shape, and exact env/export ordering;
- ad hoc Selkies/KDE env changes made for convenience rather than source-backed WSL necessity.

### Decision: Source-first failure triage

失败处理必须是 source-grounded，不允许继续随机试错。每个问题先分层，再回查对应源码，再做最小实验：

```text
Browser blank / white page
└─ check nginx/static frontend/dashboard asset path

Connection established, waiting for server mode
└─ check Selkies backend sends "MODE websockets" and frontend handles it

WebSocket disconnected / 502
└─ check nginx /websocket CWS replacement and backend CUSTOM_WS_PORT alignment

Black screen after connection
└─ check encoder/frame type/keyframe/capture pipeline/KDE compositor output

KDE flashes then exits
└─ check startwm_wayland.sh, kwin-xwayland.py, dbus-run-session, plasmashell logs

Fullscreen/canvas size wrong
└─ check Selkies frontend fullscreen, resize, CSS scaling, manual resolution paths
```

禁止的失败处理方式：随机安装包、随机改 env、随机换 X11/Wayland、随机启用/禁用 audio/gamepad/GPU、随机换 streaming backend、把 VNC/noVNC/xrdp/RDP/WSLg 单应用窗口当 fallback、在没有源码假设的情况下叠加 ad hoc hot fix。

### Decision: MECE concurrency with main-agent orchestration

proposal 和 tasks 必须支持最大化 subagent 并发，但并发必须是 MECE 且有明确 owner：

- `A upstream-source-mapper`：只读，提取 Webtop KDE/baseimage/Selkies exact behavior baseline。
- `B wsl-baseline-mapper`：只读，检查当前 WSL systemd、display、audio、network、GPU、ports、installed packages。
- `C kde-session-planner`：设计 WSL native KDE session launcher，对齐 `startwm_wayland.sh` 和 `kwin-xwayland.py`。
- `D selkies-frontend-planner`：设计 Selkies backend/frontend 和 upstream `default.conf` semantics 的忠实复用或最小 source-mapped adapter，对齐 `/websocket`、`MODE websockets`、encoder/frame/fullscreen contract。
- `E hard-limit-verifier`：审查每个差异是否真是 WSL hard limit，防止把未配置或没调通当限制。
- `F reviewer/critic`：只读复核 source grounding、scope guard、DoD、hard-limit 证明。
- `H implementation-executor`：不属于并行 discovery slice；是唯一允许执行 WSL host mutation 的 owner，负责 package install、service start/stop、port allocation、runtime files。

并发规则：A/B/C/D/E/F 是 mandatory read-only subagent slices，必须并行或尽可能并行执行；H 必须串行执行所有 WSL host mutation，避免多个 agent 同时改系统状态、抢端口、杀进程或覆盖 runtime files。main agent 负责 orchestration、冲突裁决、review 和最终 browser DoD 验收。若某个 mandatory slice 因工具错误、高负载或上下文问题失败，implementation 仍保持 gated；main-agent fallback 可辅助诊断，但不满足 MECE subagent requirement，除非用户显式放宽。

### Decision: Selkies/browser streaming 优先

为了达到 Webtop KDE exactly same，优先路线是 WSL native 安装并运行 Selkies 相关 backend/frontend，以及 upstream `default.conf` semantics 的忠实复用或最小 source-mapped WSL-local adapter。这是为了复刻 Webtop KDE browser desktop，而不是做近似替代。

只有当 Selkies 在 WSL native 中被 hard limit 阻断时，才允许评估替代 streaming backend；替代方案仍必须满足 Webtop/Selkies-style browser desktop 交互和完整 KDE Plasma desktop 呈现，否则不通过。替代方案不能改变“Windows browser 中完整 KDE desktop”的目标，也不能退化成 VNC/noVNC/xrdp/RDP 或 WSLg 单应用窗口。

Selkies contract 的关键判断点：frontend 的 WebSocket URL 按当前页面路径构造到 `/websocket`；backend 必须以 websockets 模式发送 `MODE websockets`；upstream `default.conf` semantics 或最小 source-mapped adapter 必须把 `/websocket` 转到 backend 的 `CUSTOM_WS_PORT`；frame type、encoder mode、keyframe gate、fullscreen/resize 都必须与 Selkies frontend/backend contract 一致。遇到空白、黑屏、断线、全屏不占满时，先查这些 contract，不直接改 KDE、手写 proxy 或换 backend。

### Decision: KDE session 必须是完整 desktop

成功不是启动一个 KDE app。成功必须是浏览器中出现完整 Plasma desktop：panel、launcher/window management、desktop shell、Konsole 或 Dolphin 可打开。

KDE session 可根据 WSL 能力选择 Wayland 或 X11 兼容路径，但差异必须被归因为 WSL hard limit；不能为了方便随意偏离 Webtop KDE。

### Decision: DoD 以 browser visual result 为准

Definition of Done：Windows 浏览器打开本机 URL，看到完整 KDE desktop，视觉和交互与 LinuxServer Webtop KDE exactly same，除非 WSL hard limit。

命令、日志、截图、证据文件可以用于调试和交接，但不是 DoD 的额外要求，也不能替代浏览器里的真实结果。

## Current Apply Evidence (2026-05-15)

本节记录本次 `$openspec-apply-change` apply 阶段已经完成的只读证据。它不是 DoD；DoD 仍然必须由 Windows browser 中真实可见、可交互的 KDE desktop 判定。

### Upstream source baseline

上游源码 inventory 已固定：

- Webtop KDE flavor：`/tmp/wsl-webtop-source-study/docker-webtop-ubuntu-kde`，branch `ubuntu-kde`，commit `45619c47324ef14a39485fa96269d5ed3ce4ce14`。
- Baseimage/Selkies runtime：`/tmp/wsl-webtop-source-study/docker-baseimage-selkies`，branch `master`，commit `93d956bfecbc511dbeb8dbece741ad361f2d9a6e`。
- Selkies LSIO backend/frontend：`/tmp/wsl-webtop-source-study/selkies-lsio`，branch `lsio`，commit `aae6a4de653bb95da0a6b820f885fb6b30a5e35c`。

Webtop KDE flavor facts：

- KDE flavor inherits `ghcr.io/linuxserver/baseimage-selkies:ubunturesolute` and sets `TITLE="Ubuntu KDE"` plus `PIXELFLUX_WAYLAND=true`。Source: `docker-webtop-ubuntu-kde/Dockerfile:1,10-12` @ `45619c47324ef14a39485fa96269d5ed3ce4ce14`。
- KDE flavor installs a complete KDE desktop surface, including `dolphin`, `konsole`, `kwin-x11`, `plasma-desktop`, `plasma-workspace`, `systemsettings`, and installs Rust `wl-clipboard-rs-tools`。Source: `docker-webtop-ubuntu-kde/Dockerfile:23-46` @ `45619c47324ef14a39485fa96269d5ed3ce4ce14`。
- KDE flavor removes capabilities from `/usr/bin/kwin_wayland` with `setcap -r`。Source: `docker-webtop-ubuntu-kde/Dockerfile:55-57` @ `45619c47324ef14a39485fa96269d5ed3ce4ce14`。
- X11 fallback `startwm.sh` only displays an unsupported-platform message; the KDE target path is therefore the Wayland script, not X11 fallback。Source: `docker-webtop-ubuntu-kde/root/defaults/startwm.sh:1-3` @ `45619c47324ef14a39485fa96269d5ed3ce4ce14`。
- Default `autostart` is a no-op (`exit 0`) unless user config supplies more behavior。Source: `docker-webtop-ubuntu-kde/root/defaults/autostart:1` @ `45619c47324ef14a39485fa96269d5ed3ce4ce14`。

KDE session startup facts：

- `startwm_wayland.sh` disables KWin compositing and screen autolock if corresponding config files do not exist。Source: `docker-webtop-ubuntu-kde/root/defaults/startwm_wayland.sh:4-10` @ `45619c47324ef14a39485fa96269d5ed3ce4ce14`。
- It creates a permissive KWin rule for `wl-(copy|paste)` windows so clipboard helper windows skip taskbar/switcher and receive high focus-stealing protection settings。Source: `docker-webtop-ubuntu-kde/root/defaults/startwm_wayland.sh:16-46` @ `45619c47324ef14a39485fa96269d5ed3ce4ce14`。
- It prepares `$HOME/.config/autostart`, `$HOME/.XDG`, `$HOME/.local/share`, sets `$HOME/.XDG` to mode `700`, creates `user-places.xbel`, and runs `kbuildsycoca6` after ensuring `applications.menu` exists。Source: `docker-webtop-ubuntu-kde/root/defaults/startwm_wayland.sh:48-73` @ `45619c47324ef14a39485fa96269d5ed3ce4ce14`。
- It exports `QT_QPA_PLATFORM=wayland`, `XDG_CURRENT_DESKTOP=KDE`, `XDG_SESSION_TYPE=wayland`, `KDE_SESSION_VERSION=6`, and `DISPLAY=:1`; it also ensures `/tmp/.X11-unix` exists with mode `1777`。Source: `docker-webtop-ubuntu-kde/root/defaults/startwm_wayland.sh:75-82` @ `45619c47324ef14a39485fa96269d5ed3ce4ce14`。
- It starts one DBus session containing `WAYLAND_DISPLAY=wayland-1 python3 /kwin-xwayland.py`, optional `polkit-kde-authentication-agent-1`, and foreground `WAYLAND_DISPLAY=wayland-0 plasmashell`; after `plasmashell` exits it kills KWin。Source: `docker-webtop-ubuntu-kde/root/defaults/startwm_wayland.sh:83-94` @ `45619c47324ef14a39485fa96269d5ed3ce4ce14`。
- `kwin-xwayland.py` maps `DISPLAY=:1` to `/tmp/.X11-unix/X1`, deletes an old socket if present, binds/listens on that Unix socket, marks the fd inheritable, and execs `kwin_wayland --no-lockscreen --xwayland --xwayland-display=:1 --xwayland-fd=<fd>`。Source: `docker-webtop-ubuntu-kde/root/kwin-xwayland.py:5-26` @ `45619c47324ef14a39485fa96269d5ed3ce4ce14`。

Baseimage runtime facts：

- `init-selkies-config` falls back from Wayland if CPU lacks AVX2 and is not aarch64, chooses Wayland config paths when `PIXELFLUX_WAYLAND=true`, disables second screen in that mode, and sets `XDG_RUNTIME_DIR=$HOME/.XDG`。Source: `docker-baseimage-selkies/root/etc/s6-overlay/s6-rc.d/init-selkies-config/run:3-18,40-45` @ `93d956bfecbc511dbeb8dbece741ad361f2d9a6e`。
- `init-selkies-config` detects `/dev/dri/renderD128` into `DRI_NODE`/`DRINODE` and gracefully disables gamepad UI/env when `/dev/input/js*` node creation fails。Source: `docker-baseimage-selkies/root/etc/s6-overlay/s6-rc.d/init-selkies-config/run:271-307` @ `93d956bfecbc511dbeb8dbece741ad361f2d9a6e`。
- `init-nginx` defaults `CUSTOM_PORT=3000`, `CUSTOM_HTTPS_PORT=3001`, `CUSTOM_WS_PORT=8082`, copies `/defaults/default.conf`, replaces ports/subfolder/download path, and copies `/usr/share/selkies/$DASHBOARD` to `/usr/share/selkies/web`。Source: `docker-baseimage-selkies/root/etc/s6-overlay/s6-rc.d/init-nginx/run:3-14,29-67` @ `93d956bfecbc511dbeb8dbece741ad361f2d9a6e`。
- nginx static route serves `/usr/share/selkies/web/`, and websocket route proxies `SUBFOLDERwebsocket` to `http://127.0.0.1:CWS` with Upgrade headers, HTTP/1.1, long timeouts, and buffering disabled。Source: `docker-baseimage-selkies/root/defaults/default.conf:6-10,26-40,64-68,84-98` @ `93d956bfecbc511dbeb8dbece741ad361f2d9a6e`。
- `svc-selkies` creates PulseAudio null sinks `output` and `input` and then execs `selkies --addr="localhost" --mode="websockets"`。Source: `docker-baseimage-selkies/root/etc/s6-overlay/s6-rc.d/svc-selkies/run:5-19,62-66` @ `93d956bfecbc511dbeb8dbece741ad361f2d9a6e`。
- `svc-de` in Wayland mode waits for `$XDG_RUNTIME_DIR/${WAYLAND_DISPLAY:-wayland-1}` before running `/defaults/startwm_wayland.sh`; `svc-xorg` sleeps forever in Wayland mode。Source: `docker-baseimage-selkies/root/etc/s6-overlay/s6-rc.d/svc-de/run:3-17`; `docker-baseimage-selkies/root/etc/s6-overlay/s6-rc.d/svc-xorg/run:3-6` @ `93d956bfecbc511dbeb8dbece741ad361f2d9a6e`。
- `svc-nginx` kills stale nginx worker/master processes before `nginx -g 'daemon off;'`; `svc-pulseaudio` runs `pulseaudio --exit-idle-time=-1`; `svc-dbus` runs system `dbus-daemon`; `svc-watchdog` only restarts autostart when `RESTART_APP=true`。Source: `docker-baseimage-selkies/root/etc/s6-overlay/s6-rc.d/svc-nginx/run:4-16`; `svc-pulseaudio/run:1-6`; `svc-dbus/run:3-12`; `svc-watchdog/run:3-38` @ `93d956bfecbc511dbeb8dbece741ad361f2d9a6e`。

Selkies backend/frontend contract facts：

- Settings precedence is CLI, then `SELKIES_*`, then legacy env such as `CUSTOM_WS_PORT`, then defaults。Source: `selkies-lsio/src/selkies/settings.py:10-18` @ `aae6a4de653bb95da0a6b820f885fb6b30a5e35c`。
- WebSockets mode defaults to `mode=websockets`; common settings cover audio, microphone, gamepad, clipboard, framerate, manual resolution, CSS scaling, and sidebar visibility; WebSockets-specific settings allow `encoder` values `x264enc`, `x264enc-striped`, `jpeg` and `port` default `8081` with legacy env `CUSTOM_WS_PORT`。Source: `selkies-lsio/src/selkies/settings.py:37-123` @ `aae6a4de653bb95da0a6b820f885fb6b30a5e35c`。
- Backend sends `MODE {self.mode}` immediately after a WebSocket connects, then sends `server_settings` built from settings definitions。Source: `selkies-lsio/src/selkies/selkies.py:1608-1658` @ `aae6a4de653bb95da0a6b820f885fb6b30a5e35c`。
- Backend handles `SETTINGS,{json}` by registering a display client, killing/superseding an old primary client when a new primary connects, applying client settings, and reconfiguring display/pipeline state。Source: `selkies-lsio/src/selkies/selkies.py:2083-2217` @ `aae6a4de653bb95da0a6b820f885fb6b30a5e35c`。
- Backend broadcasts primary `stream_resolution` to all clients and uses `reconfigure_displays` as the central place to create virtual desktop/capture pipelines for connected display clients。Source: `selkies-lsio/src/selkies/selkies.py:1269-1289,2860-3022` @ `aae6a4de653bb95da0a6b820f885fb6b30a5e35c`。
- Current `selkies-lsio` frontend constructs the WebSocket URL from current protocol/host/pathname and appends `websockets`; this differs from baseimage nginx template text `SUBFOLDERwebsocket`, so implementation MUST pin the actual frontend artifact and align proxy location to that artifact rather than assume a path name。Source: `selkies-lsio/addons/selkies-web-core/selkies-ws-core.js:2729-2737` @ `aae6a4de653bb95da0a6b820f885fb6b30a5e35c`; `docker-baseimage-selkies/root/defaults/default.conf:26-40` @ `93d956bfecbc511dbeb8dbece741ad361f2d9a6e`。
- Frontend on open displays `Connection established. Waiting for server mode...`, sends initial `SETTINGS` with resolution data, sends clipboard request `cr`, and starts metrics/backpressure loops。Source: `selkies-lsio/addons/selkies-web-core/selkies-ws-core.js:2793-2910` @ `aae6a4de653bb95da0a6b820f885fb6b30a5e35c`。
- Frontend binary frame contract includes H.264 key/delta handling, JPEG stripe handling, shared-mode keyframe gating, and canvas painting paths; black screen triage must inspect frame type/keyframe/pipeline state before changing KDE。Source: `selkies-lsio/addons/selkies-web-core/selkies-ws-core.js:2925-3065` @ `aae6a4de653bb95da0a6b820f885fb6b30a5e35c`。
- Dashboard sidebar renderability is driven by `ui_sidebar_show_*` server settings for video settings, screen settings, audio settings, stats, clipboard, files, apps, sharing, gamepads, fullscreen, gaming mode, trackpad, keyboard button, and soft buttons。Source: `selkies-lsio/addons/selkies-dashboard/src/components/Sidebar.jsx:599-612,2135-2211,2252-2283,2389-2407,2680-2726,3005-3021,3469-3580` @ `aae6a4de653bb95da0a6b820f885fb6b30a5e35c`。

### MECE fan-out results and main-agent review

A/B/C/D/E/F mandatory read-only subagent slices have all completed. No subagent performed WSL host mutation; host mutation remains reserved for the serial `H implementation-executor` after planning gates pass.

Main-agent synthesis from completed slices:

- A `bg_6c097fc2`：APPROVE。上游 inventory commits match；reuse matrix inputs cover `startwm_wayland.sh`, `kwin-xwayland.py`, `init-selkies-config`, `init-nginx`, `default.conf`, `svc-selkies`, `svc-de`, Selkies frontend assets, backend websocket contract；env baseline includes `DISPLAY=:1`, `/tmp/.X11-unix/X1`, `wayland-1/0`, `XDG_RUNTIME_DIR=$HOME/.XDG`, `CUSTOM_WS_PORT=8082`。
- B `bg_719cc102`：APPROVE。当前 WSL snapshot：Ubuntu 26.04，systemd running，agent shell has no `DISPLAY`/`WAYLAND_DISPLAY`，KDE packages installed，Selkies venv process on `0.0.0.0:8081`，proxy on `127.0.0.1:3200`，no KDE compositor currently running，`/dev/dri` absent，`/dev/dxg` present；config gaps include port bind, env injection, Selkies path alignment。
- C `bg_cf9a9278`：APPROVE KDE-session planning output, but REJECT overall gate until matrices/reviews complete。Default must be `DISPLAY=:1`/X1；use source-mapped `startwm_wayland.sh` + `kwin-xwayland.py`；use pid/pgid stop model；no `pkill -f`。
- D `bg_1d6283f2`：REJECT Selkies/frontend implementation-gate readiness until the exact served frontend artifact pins `/websocket` vs `/websockets`。Local proxy/wrapper is acceptable only as source-mapped minimal adapter；backend/proxy ports must be explicitly aligned。
- E `bg_c0843e76`：REJECT hard-limit readiness。No WSL hard limit is proven；every deviation needs tasks 7.1-7.6 proof before being accepted。
- F `bg_282f69ad`：REJECT overall implementation-gate readiness until reuse matrix, env/display drift matrix, omitted upstream checklist, hard-limit proof, serial mutation plan, architect/critic sign-off are completed。

Therefore implementation remains gated. The next valid step is artifact-backed execution preparation and review, not package install, service start/stop, process kill, port allocation, WSL host mutation, or DoD claim.

### Current WSL native baseline (read-only snapshot)

Snapshot command set was read-only (`/etc/os-release`, `uname`, `id`, env, `systemctl is-system-running`, `command -v`, `ls`, `ss`, `dpkg-query`, `ps`).

- Distro/kernel/user: Ubuntu `26.04 LTS`, kernel `6.6.114.1-microsoft-standard-WSL2`, user `cpf` uid/gid `1000`, groups include `sudo` and `docker`。
- systemd/package/sudo: `systemctl` exists and reports `running`; `apt` and `sudo` exist; `sudo -n true` returned `0`。
- runtime/session env: `XDG_RUNTIME_DIR=/run/user/1000`; `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus`; shell env had empty `DISPLAY` and `WAYLAND_DISPLAY` in the agent shell。
- runtime sockets: `/run/user/1000` exists mode `700` and contains `bus`; `/run/user/1000/wayland-1` existed; `/tmp/.X11-unix` exists world-writable and contains `X0` owned by `cpf`。
- installed commands: `kwin_wayland`, `plasmashell`, `konsole`, `dolphin`, `dbus-run-session`, `pactl`, `pipewire`, `pw-cli`, `Xwayland`, `nginx`, and `python3` exist; `selkies` was not on PATH in the agent shell, but a venv-backed `/tmp/selkies-lsio-venv/bin/python -m selkies` process was running。
- ports: `0.0.0.0:8081` was listened by the Selkies Python process; `127.0.0.1:3200` was listened by `/tmp/wsl-kde-webtop/lsio-proxy.py`。
- KDE packages: `plasma-desktop 4:6.6.4-0ubuntu1`, `plasma-workspace 4:6.6.4-0ubuntu2`, `kwin-x11 4:6.6.4-0ubuntu1`, `kwin-wayland 4:6.6.4-0ubuntu1`, `konsole 4:25.12.3-0ubuntu1`, `dolphin 4:25.12.3-0ubuntu1`, `dbus-user-session 1.16.2-2ubuntu4`, `pipewire 1.6.2-1ubuntu1`, and `nginx 1.28.3-2ubuntu1.1` were installed; `pulseaudio` query returned no version in this snapshot。
- GPU devices: `/dev/dri` did not exist; `/dev/dxg` existed. This is not stream-encoding success evidence and must be reported separately from KWin compositor, GUI app rendering, and browser stream encoding。
- Live process snapshot included `/tmp/selkies-lsio-venv/bin/python -m selkies`, `kwin_wayland --no-lockscreen --xwayland --xwayland-display=:20 --xwayland-fd=3`, `plasmashell`, `/usr/bin/Xwayland :20 ...`, and `/tmp/wsl-kde-webtop/lsio-proxy.py`。

Interpretation: current WSL has many required dependencies and a live experimental runtime, but this snapshot does not prove DoD. It also shows a deviation from upstream `DISPLAY=:1` / Xwayland `:1` to current live `:20`; that deviation is not yet a hard limit and must be justified or corrected before final success.

### Execution prep before host mutation

Runtime path/owner: planned WSL-local runtime root is `/tmp/wsl-kde-webtop`, owned by the serial `H implementation-executor`; OpenSpec artifacts remain in this change directory, and no buntoolbox product files are mutation targets.

Startup sequence: prepare init/env from `init-selkies-config` semantics → prepare frontend/proxy from served Selkies artifact and `default.conf` semantics → start Selkies backend with explicit backend/proxy port alignment → wait for Wayland socket → launch KDE via source-mapped `startwm_wayland.sh` and `kwin-xwayland.py` → supervise browser-desktop health.

Stop/restart/cleanup: track runtime PIDs/PGIDs under the runtime root, stop children by recorded process group, clean only owned sockets/locks/runtime files, and avoid `pkill -f`; restart must re-run env/proxy/backend/KDE sequence from a clean owned state.

Host mutation preflight list: before any mutation, list packages to install, runtime files to write, ports to bind, service/processes to start, env vars to inject, rollback/disable command for each item, and whether the mutation touches user-wide WSL state.

Source-first debug loop: each failure must name one layer, one upstream source node, one hypothesis, one minimal experiment, expected signal, actual signal, and rollback condition; do not stack ad hoc env/package/display/proxy changes.

Source-backed reuse matrix:

| Upstream node | Planned local handling | Gate status |
| --- | --- | --- |
| `startwm_wayland.sh` | Reuse or faithful source-mapped port for KDE session shape, env/export ordering, DBus session, KWin/plasmashell launch | Required before host mutation |
| `kwin-xwayland.py` | Reuse or faithful port for `/tmp/.X11-unix/X1`, fd inheritance, `kwin_wayland --xwayland-display=:1` | Required before host mutation |
| `init-selkies-config` | Port env/runtime-dir/device/gamepad/audio defaults relevant to WSL | Required before host mutation |
| `init-nginx` + `default.conf` | Reuse semantics for static frontend and WebSocket proxy; exact route depends on served artifact path proof | Blocked by D until `/websocket` vs `/websockets` is pinned |
| `svc-selkies` | Start backend in `--mode=websockets` with explicit addr/port/env alignment | Required before host mutation |
| `svc-de` | Wait for Wayland socket before KDE launch | Required before host mutation |
| Selkies frontend assets | Serve exact chosen artifact, then align proxy path to its WebSocket construction | Blocked by D until artifact proof |
| Selkies backend websocket contract | Preserve `MODE websockets`, settings, frame, fullscreen/resize behavior | Required before host mutation |

Minimal adapter proof checklist: any local proxy, wrapper, launcher, or frontend must name the upstream node replaced, quote the behavior preserved, prove native WSL direct reuse failed or needs adaptation, show the adapter is smaller than a replacement implementation, and receive reviewer sign-off before execution.

Env/display drift matrix:

| Item | Upstream expected | Local planned default | Deviation status |
| --- | --- | --- | --- |
| `DISPLAY` | `:1` | `:1` | `DISPLAY=:20` must be corrected, not kept as default |
| X socket | `/tmp/.X11-unix/X1` | `/tmp/.X11-unix/X1` | Any other socket needs hard-limit proof |
| `WAYLAND_DISPLAY` | `wayland-1` for KWin, `wayland-0` for `plasmashell` | Same | No approved drift |
| `XDG_RUNTIME_DIR` | `$HOME/.XDG` in Webtop baseline | Must be chosen explicitly and justified against WSL `/run/user/1000` snapshot | Pending review |
| `PIXELFLUX_WAYLAND` | `true` | Preserve Wayland-first semantics | No approved drift |
| `CUSTOM_WS_PORT` | `8082` in baseimage nginx init default | Must align backend and proxy explicitly; current WSL snapshot had backend `8081` | Pending D path/port proof |
| KDE/Qt env | `QT_QPA_PLATFORM=wayland`, `XDG_CURRENT_DESKTOP=KDE`, `XDG_SESSION_TYPE=wayland`, `KDE_SESSION_VERSION=6` | Same unless hard-limit proof exists | No approved drift |

`DISPLAY=:20` correction rule: any live or planned `:20` runtime must be reset to upstream `DISPLAY=:1`/`X1` before being treated as implementation baseline; if reset fails, tasks 7.2-7.6 must prove the failure is a WSL hard limit before any deviation is accepted.

Omitted upstream script checklist: before execution, compare planned local files against `startwm_wayland.sh`, `kwin-xwayland.py`, `init-selkies-config`, `init-nginx`, `default.conf`, `svc-selkies`, and `svc-de`; record each omitted behavior, reason, substitute node, rollback, and reviewer sign-off. Known must-check behaviors include clipboard KWin rule, autostart bridge, UDisks handling, `applications.menu`, `kbuildsycoca6`, `dbus-run-session` shape, exact env/export ordering, PulseAudio null sinks, nginx Upgrade headers/timeouts, and socket wait semantics.

### Current gate verdict

- Scope guard: satisfied for artifact work; no buntoolbox product code is required or allowed for this change.
- Upstream source baseline: sufficient for planning and source-first triage.
- MECE discovery: satisfied for planning by completed A/B/C/D/E/F mandatory read-only subagent slices; implementation remains gated by rejected D/E/F readiness checks and missing sign-offs.
- WSL hard limits: none are proven yet.
- Implementation gate: not passed. A serial mutation plan, architect sign-off on that plan, critic sign-off after revisions, and browser DoD verification are still required.
- Completion audit: objective is not achieved until Windows browser shows Webtop/Selkies-style KDE desktop, the desktop fills the browser, sidebar is present, WebSocket/session is stable, and Konsole or Dolphin launches interactively from KDE.

### H implementation-executor runtime evidence (2026-05-16)

本节记录 serial `H implementation-executor` 在当前 WSL host 上执行的最小 runtime mutation。它不修改 buntoolbox product files；runtime artifacts 均位于 `/tmp/wsl-kde-webtop`，旧实验目录已隔离保存。

Runtime owner and artifacts:

- Runtime root: `/tmp/wsl-kde-webtop`，owner/mode observed as `cpf:cpf 775`。
- Quarantined previous runtime: `/tmp/wsl-kde-webtop.quarantine-20260516-002952`。Quarantine reason: old runtime contained handwritten `lsio-proxy.py`, generated launchers, screenshots, logs, and previous experiment state; it was moved aside instead of deleted.
- Source-mapped runtime files:
  - `/tmp/wsl-kde-webtop/kwin-xwayland.py`: direct copy of Webtop KDE `root/kwin-xwayland.py` behavior, preserving `DISPLAY=:1` to `/tmp/.X11-unix/X1` and `kwin_wayland --no-lockscreen --xwayland --xwayland-display=:1 --xwayland-fd=<fd>`.
  - `/tmp/wsl-kde-webtop/startwm_wayland.sh`: source-mapped WSL port of Webtop KDE `root/defaults/startwm_wayland.sh`; preserves KWin compositing/autolock config, clipboard KWin rule, autostart bridge, `kbuildsycoca6`, `QT_QPA_PLATFORM=wayland`, `XDG_CURRENT_DESKTOP=KDE`, `XDG_SESSION_TYPE=wayland`, `KDE_SESSION_VERSION=6`, `DISPLAY=:1`, `dbus-run-session`, KWin on `WAYLAND_DISPLAY=wayland-1`, and `plasmashell` on `WAYLAND_DISPLAY=wayland-0`. WSL-native deviations are limited to using `/tmp/wsl-kde-webtop/kwin-xwayland.py` instead of container absolute `/kwin-xwayland.py`, writing logs under `/tmp/wsl-kde-webtop/logs`, and not deleting the host-level `/usr/share/dbus-1/system-services/org.freedesktop.UDisks2.service`.
  - `/tmp/wsl-kde-webtop/nginx.conf`: source-mapped minimal nginx adapter preserving baseimage `default.conf` static frontend alias semantics, WebSocket Upgrade headers, HTTP/1.1, 3600s timeouts, buffering disabled, and proxy to backend. The served frontend artifact was pinned to `/tmp/selkies-lsio-src/addons/selkies-dashboard/dist`; its compiled asset appends `websockets` to the current pathname, so this runtime uses `/websockets` instead of `/websocket`.
  - `/tmp/wsl-kde-webtop/start.sh`, `/tmp/wsl-kde-webtop/stop.sh`, `/tmp/wsl-kde-webtop/restart.sh`: WSL-local lifecycle wrappers that record PIDs under `/tmp/wsl-kde-webtop/pids` and avoid broad `pkill -f`.

Lifecycle commands:

```bash
# Start
/tmp/wsl-kde-webtop/start.sh

# Stop only this runtime's recorded PIDs and owned sockets
/tmp/wsl-kde-webtop/stop.sh

# Restart
/tmp/wsl-kde-webtop/restart.sh

# Browser URL
cat /tmp/wsl-kde-webtop/url.txt
# http://localhost:3200
```

Runtime cleanup / disable:

```bash
/tmp/wsl-kde-webtop/stop.sh
rm -rf /tmp/wsl-kde-webtop
# Optional: remove quarantined previous experiment only after user review
# rm -rf /tmp/wsl-kde-webtop.quarantine-20260516-002952
```

Optional package / host-state rollback notes:

- No package install was performed in this execution; KDE, nginx, Python, and the Selkies venv already existed.
- `/usr/bin/kwin_wayland` capability was aligned with Webtop KDE's Dockerfile behavior by running `sudo -n setcap -r /usr/bin/kwin_wayland`; before: `cap_sys_nice=ep`; after: no capability output. If the user wants to restore the previous host state, run `sudo setcap cap_sys_nice=ep /usr/bin/kwin_wayland`.
- `/tmp/.X11-unix` was observed as a WSLg tmpfs mounted read-only, which prevented `kwin-xwayland.py` from binding `/tmp/.X11-unix/X1` with `OSError: [Errno 30] Read-only file system`. A reversible platform mutation `sudo -n mount -o remount,rw /tmp/.X11-unix` made a write probe succeed and allowed `X1` to be created. This is not recorded as a WSL hard limit because the minimal remount fixed it. To restore the prior mount mode, run `sudo mount -o remount,ro /tmp/.X11-unix` after stopping this runtime.

Verified state from this execution:

- Old recorded PIDs `593720` (`/tmp/wsl-kde-webtop/lsio-proxy.py`) and `593780` (`python -m selkies`) were stopped explicitly; no broad `pkill -f` was used.
- Ports after old runtime stop: `3200`, `3201`, `8081`, and `8082` were free.
- New runtime listening ports: nginx on `127.0.0.1:3200`; Selkies backend on `0.0.0.0:8082`.
- WebSocket handshake through nginx: `ws://127.0.0.1:3200/websockets` returned first message `MODE websockets`.
- Windows localhost reachability: `powershell.exe -NoProfile -Command "(Invoke-WebRequest -UseBasicParsing http://localhost:3200/ -TimeoutSec 5).StatusCode"` returned `200`.
- KDE/session sockets after remount and restart: `/tmp/.X11-unix/X1`, `/tmp/wsl-kde-webtop/xdg-runtime/wayland-0`, and `/tmp/wsl-kde-webtop/xdg-runtime/wayland-1` existed.
- KWin command line preserved source baseline: `kwin_wayland --no-lockscreen --xwayland --xwayland-display=:1 --xwayland-fd=3`.
- Logs showed KWin accepted client connections on `wayland-0`; Plasma Shell logs progressed into KDE component loading. Logs also contained WSL/graphics warnings such as PipeWire and EGL/Zink messages; these are not hard-limit proof by themselves.

DoD status from this execution:

- Browser delivery plumbing is verified by curl, WebSocket handshake, process/port/socket evidence, and Windows `localhost:3200` HTTP reachability.
- Windows browser visual confirmation was not performed in this terminal-only execution, and the user did not confirm the browser view during the task. Therefore DoD tasks 8.1-8.6 remain unchecked. The next verification step is for the user to open `http://localhost:3200` in a Windows browser and confirm whether the full Webtop/Selkies-style KDE desktop, sidebar, browser fill, and Konsole/Dolphin interaction are visible.

### Menu/popup interaction debug evidence (2026-05-16)

User-observed symptom after the runtime above: on `http://localhost:3200`, KDE desktop right-click context menu appears then disappears immediately before items can be clicked; the KDE application launcher/start menu shows the same immediate-dismiss behavior.

Evidence collected before any behavioral fix:

- Runtime logs inspected under `/tmp/wsl-kde-webtop/logs`: `selkies.log`, `kwin-wayland.log`, `plasmashell.log`, `nginx-error.log`, and `nginx-access.log`.
- `selkies.log` showed `Starting Selkies in 'websockets' mode`, `[Wayland] Socket listening on: "wayland-1"`, `Wayland input injection initialized`, and Chrome client WebSocket connections through nginx. PulseAudio connection failures and non-browser WebSocket handshake warnings were present, but neither is proven to cause popup dismissal.
- `kwin-wayland.log` showed `Accepting client connections on sockets: QList("wayland-0")`, preserving the upstream KWin/Plasma Wayland split. The log also contained PipeWire/glamor warnings, which are not popup-focus proof by themselves.
- `plasmashell.log` contained KDE component warnings and repeated PipeWire errors but no direct popup/focus error tying Plasma popup dismissal to a KWin hard limit.
- `/tmp/wsl-kde-webtop/nginx.conf` serves `/tmp/selkies-lsio-src/addons/selkies-dashboard/dist/` and proxies `/websockets` to `127.0.0.1:8082`; this matches the currently served compiled dashboard artifact `dist/index.html`, which loads `assets/index-Bwt2RM1l.js` and whose frontend appends `websockets` to the current pathname.
- Live process environments for Selkies, KWin, and startwm showed `DISPLAY=:1`, `WAYLAND_DISPLAY=wayland-1`, `XDG_RUNTIME_DIR=/tmp/wsl-kde-webtop/xdg-runtime`, `QT_QPA_PLATFORM=wayland`, `XDG_SESSION_TYPE=wayland`, `XDG_CURRENT_DESKTOP=KDE`, `KDE_SESSION_VERSION=6`, `SELKIES_MODE=websockets`, `SELKIES_PORT=8082`, `SELKIES_ADDR=localhost`, and `PIXELFLUX_WAYLAND=true`.
- Source comparison against `docker-webtop-ubuntu-kde/root/defaults/startwm_wayland.sh` confirmed the current runtime keeps the upstream socket split: `WAYLAND_DISPLAY=wayland-1` for `kwin-xwayland.py` / `kwin_wayland`, and `WAYLAND_DISPLAY=wayland-0` for `plasmashell`.
- Selkies frontend input source (`addons/selkies-web-core/lib/input.js` and compiled `addons/selkies-dashboard/dist/assets/index-Bwt2RM1l.js`) shows the input overlay registers `mousedown` on `overlayInput`, `mouseup` on `window`, `contextmenu` suppression on the overlay, and touch handlers when `ontouchstart` exists. Ordinary mouse right-click sends button mask bit 2 (`button_mask=4`) on press and clears it on release. Touch long-press and trackpad two-finger tap also synthesize `button_mask=4` followed by release after 50ms.
- Selkies backend Wayland input source (`src/selkies/input_handler.py:1514-1593`) maps `button_mask` bit 2 to `inject_mouse_button(273, state)`, i.e. right-button press/release through the Wayland input bridge.

Current single hypothesis under test: the popup is opened correctly, but one user action causes duplicate or extra mouse/touch-derived button transitions through the frontend/Selkies input path, so KDE receives a second transition that immediately dismisses the popup. This hypothesis fits both the desktop right-click menu and launcher/start-menu dismissal, but it is not yet proven.

Minimal instrumentation applied to test the hypothesis:

- Backed up `/tmp/selkies-lsio-src/src/selkies/input_handler.py` to `/tmp/wsl-kde-webtop/input_handler.py.before-menu-debug`.
- Added one INFO log in the `msg_type in ["m", "m2"]` branch to record `type`, `x`, `y`, `button_mask`, previous `self.button_mask`, `scroll_magnitude`, `relative`, and `display_id` before calling `send_x11_mouse`.
- Restarted the owned runtime with `/tmp/wsl-kde-webtop/restart.sh`; `startup-status.log` showed `wayland-1 socket ready` and `started`. The runtime now waits for a browser refresh and one controlled right-click / launcher interaction to collect the event sequence.

No behavioral fix has been applied yet. DoD tasks 8.1-8.6 remain unchecked until the browser interaction is verified by user confirmation or direct browser interaction evidence.

### Distribution-faithful fix constraint for menu/popup bug (2026-05-16)

User constraint added after the diagnostic instrumentation above: the final fix for the disappearing KDE context menu / app launcher bug must not be a monkey patch; it must replicate / mimic LinuxServer Webtop KDE distribution and Selkies behavior. Treat the current `input_handler.py` logging as temporary diagnostics only, not as a valid final fix.

Verified instrumentation status:

- Current temporary source change is limited to `/tmp/selkies-lsio-src/src/selkies/input_handler.py:2142-2145`, adding one `logger_webrtc_input.info(...)` call in the `msg_type in ["m", "m2"]` branch.
- Backup path exists at `/tmp/wsl-kde-webtop/input_handler.py.before-menu-debug` and contains the original branch that calls `send_x11_mouse(...)` directly after parsing `x`, `y`, `button_mask`, and `scroll_magnitude`.
- The instrumentation does not alter the parsed values, relative/absolute mode calculation, `send_x11_mouse(...)` call arguments, or call order. It is diagnostic-only.
- Restore command when diagnostics are no longer needed: `cp /tmp/wsl-kde-webtop/input_handler.py.before-menu-debug /tmp/selkies-lsio-src/src/selkies/input_handler.py && /tmp/wsl-kde-webtop/restart.sh`.

Evidence after the instrumentation restart:

- `/tmp/wsl-kde-webtop/logs/selkies.log` contains a new Chrome/WebSocket client connection after restart, but no `Mouse message:` lines were present when inspected. Therefore no post-instrumentation right-click or launcher mouse sequence has been captured yet.
- Without a captured `Mouse message:` sequence or new user confirmation after refresh, the root cause is not proven. The next required evidence step remains: refresh `http://localhost:3200`, right-click once on the desktop, click launcher once, then inspect `selkies.log` for `Mouse message:` ordering.

Distribution drift evidence relevant to input/menu/focus:

- Upstream `init-selkies-config` attempts to create `/dev/input/js0` and companion gamepad/event nodes; if that fails, it writes `SELKIES_UI_SIDEBAR_SHOW_GAMEPADS=false`, `SELKIES_GAMEPAD_ENABLED=false`, `SELKIES_ENABLE_PLAYER2=false`, and `SELKIES_ENABLE_PLAYER3=false` into container environment. Source: `docker-baseimage-selkies/root/etc/s6-overlay/s6-rc.d/init-selkies-config/run:282-302` @ `93d956bfecbc511dbeb8dbece741ad361f2d9a6e`.
- Current WSL runtime has no `/dev/input/js0`, `/dev/input/js1`, or `/dev/input/event1000`, but Selkies process env leaves `SELKIES_GAMEPAD_ENABLED`, `SELKIES_UI_SIDEBAR_SHOW_GAMEPADS`, and `SELKIES_ENABLE_PLAYER2/3/4` unset; `selkies.log` shows four persistent virtual gamepad instances initialized with `/tmp/selkies_js{0-3}.sock` and `/tmp/selkies_event100{0-3}.sock`.
- This is a confirmed distribution-behavior drift. It is not yet proven to cause the popup dismissal, so it must not be presented as the root cause without the next interaction evidence. If a behavior-changing experiment is later justified, the source-faithful candidate is to mirror upstream's failed-gamepad-node branch via runtime env in `/tmp/wsl-kde-webtop/start.sh`, not to patch Selkies frontend/backend source.

Current no-monkey-patch rule for this bug:

- Allowed fix shape: source-faithful runtime config/startup/env/frontend selection change that maps to an upstream Webtop/baseimage/Selkies node and preserves distribution semantics.
- Disallowed fix shape: editing Selkies frontend JavaScript, backend Python input handling, CSS, or KDE code merely to suppress the symptom. Any temporary source instrumentation must be restored or explicitly carried only as diagnostics until evidence is captured.

### Source-faithful gamepad-env experiment for repeated menu clicks (2026-05-16)

Post-instrumentation evidence captured in `/tmp/wsl-kde-webtop/logs/selkies.log` before the experiment:

- Lines `222-237`: client resize changed the stream from `1916x1386` to `3840x1386`; Selkies restarted the Wayland capture pipeline and reported `Configuring Output: 3840x1386 @ 30.00 FPS`.
- Lines `265-270`: one left click and one right click near `x=1690 y=385`: left `button_mask=1 -> 0`, then right `button_mask=4 -> 0`.
- Lines `281-282`: one normal right click at `x=1159 y=538`: `button_mask=4 -> 0`.
- Lines `305-310`: the same-coordinate right-click sequence repeated three times at `x=898 y=653`: `button_mask=4 -> 0`, `button_mask=4 -> 0`, `button_mask=4 -> 0`.

Single hypothesis for this experiment: because the current WSL runtime lacks `/dev/input/js0`, `/dev/input/js1`, and `/dev/input/event1000`, but did not mirror upstream's failed-gamepad-node environment, Selkies kept gamepad/player controls and virtual gamepad setup enabled in a state where Webtop distribution would disable them. That distribution drift may contribute to repeated right-click/menu-dismiss input behavior. This is only a hypothesis; it is not claimed as proven root cause until user visual confirmation after the experiment.

Single source-faithful experiment applied:

- Edited only `/tmp/wsl-kde-webtop/start.sh` before Selkies startup.
- Added the same environment outcome as upstream `init-selkies-config` failed branch (`docker-baseimage-selkies/root/etc/s6-overlay/s6-rc.d/init-selkies-config/run:296-301` @ `93d956bfecbc511dbeb8dbece741ad361f2d9a6e`):
  - `SELKIES_UI_SIDEBAR_SHOW_GAMEPADS=false`
  - `SELKIES_GAMEPAD_ENABLED=false`
  - `SELKIES_ENABLE_PLAYER2=false`
  - `SELKIES_ENABLE_PLAYER3=false`
- Did not edit Selkies frontend/backend/input behavior; the temporary `input_handler.py` mouse logging remains diagnostic-only.

Verification after applying the experiment and running `/tmp/wsl-kde-webtop/restart.sh`:

- `/tmp/wsl-kde-webtop/logs/startup-status.log` showed `wayland-1 socket ready` and `started`.
- Live Selkies process env showed `SELKIES_UI_SIDEBAR_SHOW_GAMEPADS=false`, `SELKIES_GAMEPAD_ENABLED=false`, `SELKIES_ENABLE_PLAYER2=false`, `SELKIES_ENABLE_PLAYER3=false`, `CUSTOM_WS_PORT=8082`, `SELKIES_PORT=8082`, and `SELKIES_MODE=websockets`.
- Runtime processes were alive: nginx master using `/tmp/wsl-kde-webtop/nginx.conf`, Selkies `python -m selkies --addr=localhost --mode=websockets --port=8082`, KWin `kwin_wayland --no-lockscreen --xwayland --xwayland-display=:1 --xwayland-fd=3`, and `startwm_wayland.sh`.

Required user verification after this experiment: refresh `http://localhost:3200`, right-click once on the KDE desktop, and click the KDE app launcher once. Do not mark DoD 8.x complete until the user confirms the menu and launcher remain visible/clickable and the desktop remains acceptable.

### Post-gamepad-env result and right-click-only blocker (2026-05-16)

User verification after the source-faithful gamepad-env experiment: KDE app launcher is now OK, but right-click context menus still appear and immediately disappear. This confirms the gamepad-env experiment improved one interaction path but did not complete DoD because right-click remains broken.

Latest right-click evidence from `/tmp/wsl-kde-webtop/logs/selkies.log` after the gamepad-env experiment:

- Lines `975-976`: one right-click at `x=1735 y=466`, `button_mask=4 -> 0`.
- Lines `986-991`: same-coordinate right-click sequence repeated three times at `x=1760 y=469`: `button_mask=4 -> 0`, `button_mask=4 -> 0`, `button_mask=4 -> 0`.
- Lines `1002-1004`: a later left click at `x=1220 y=590`, `button_mask=1 -> 0`, followed by `Received STOP_VIDEO for 'primary'. Stopping stream.`
- The right-click events are absolute `type=m` messages, not relative `type=m2` trackpad/scroll messages. Earlier `m2` events in the log were scroll-wheel style messages (`button_mask=8`, `scroll_magnitude=1`) and are not the captured right-click sequence.

Runtime status checked during this pass:

- nginx remained alive and listening on `127.0.0.1:3200`.
- Selkies remained alive and listening on `0.0.0.0:8082`.
- KWin remained alive as `kwin_wayland --no-lockscreen --xwayland --xwayland-display=:1 --xwayland-fd=3`.
- `startwm_wayland.sh` remained alive.
- Current Selkies env still includes the source-faithful gamepad failed-branch values: `SELKIES_GAMEPAD_ENABLED=false` and `SELKIES_UI_SIDEBAR_SHOW_GAMEPADS=false`.

Source comparison for right-click/input path:

- Selkies input frontend maps ordinary `mousedown`/`mouseup` button events into `m,x,y,button_mask,0` and suppresses browser native `contextmenu` on the overlay. Source: `/tmp/selkies-lsio-src/addons/selkies-web-core/lib/input.js:1624-1717` and `2314-2318`.
- The frontend also registers `overlayInput.addEventListener('contextmenu', e => e.preventDefault())`. Source: `/tmp/selkies-lsio-src/addons/selkies-web-core/selkies-ws-core.js:1364-1372`.
- Trackpad mode is controlled by dashboard messages `touchinput:trackpad` / `touchinput:touch` and persisted client-side as `trackpadMode`. Source: `/tmp/selkies-lsio-src/addons/selkies-web-core/selkies-ws-core.js:1920-1938` and `3395-3403`.
- Current Selkies env leaves `SELKIES_UI_SIDEBAR_SHOW_TRACKPAD`, `SELKIES_UI_SIDEBAR_SHOW_GAMING_MODE`, `SELKIES_UI_SIDEBAR_SHOW_SOFT_BUTTONS`, and `SELKIES_UI_SIDEBAR_SHOW_KEYBOARD_BUTTON` unset, which matches Selkies defaults rather than a proven drift. The captured right-clicks are `type=m`, so there is no evidence that trackpad mode generated the right-click dismissal.

No additional behavior-changing experiment was applied in this pass. The reason is evidence discipline: after launcher improvement, the remaining right-click symptom is visible as repeated right-click input at the same coordinate, but the current runtime logs cannot distinguish whether those repeated events came from user repeated attempts, browser/frontend duplicate event delivery, native browser contextmenu interaction, or KDE popup focus dismissal after a normal press/release. No available distribution-faithful runtime config/env/startup change is directly supported by this evidence.

Investigated but rejected source-faithful experiment candidate:

- Switching nginx to an installed Webtop distribution frontend artifact would be source-faithful if such an artifact existed locally. Checked candidate paths `/usr/share/selkies/selkies-dashboard/index.html` and `/usr/share/selkies/web/index.html`; neither exists. The only available dashboard artifact remains `/tmp/selkies-lsio-src/addons/selkies-dashboard/dist/index.html`, currently served by `/tmp/wsl-kde-webtop/nginx.conf`.

Next evidence required before another experiment:

- User-side observation or browser devtools evidence for whether Chrome's native context menu appears, flickers, or is fully suppressed when right-clicking the Selkies canvas.
- If possible, one controlled right-click after clearing the log, with no repeated attempts, so `Mouse message:` can confirm whether a single physical right-click produces one or multiple `button_mask=4 -> 0` pairs.
- If devtools is acceptable, inspect whether the overlay receives duplicate `mousedown`/`mouseup`/`contextmenu` events for a single physical right-click. Without that evidence, editing Selkies JS/Python/CSS would be a monkey patch and remains disallowed.

### Source-faithful implementation gap closure pass for right-click path (2026-05-16)

User reframed the objective: this work is source-faithful implementation gap closure, not isolated “experiments.” Verified UI state entering this pass: the failed-gamepad-node env closure improved the KDE app launcher, but right-click menus still appear and immediately disappear.

Current-vs-upstream gap list for input/menu/focus-related distribution behavior:

| Area | Upstream source-backed behavior | Current runtime status before this pass | Gap verdict |
| --- | --- | --- | --- |
| Wayland display count | In `PIXELFLUX_WAYLAND=true`, `init-selkies-config` writes `SELKIES_SECOND_SCREEN=false` to container env. Source: `docker-baseimage-selkies/root/etc/s6-overlay/s6-rc.d/init-selkies-config/run:11-18` @ `93d956bfecbc511dbeb8dbece741ad361f2d9a6e`. | Live Selkies env had `SELKIES_SECOND_SCREEN=<unset>`, therefore Selkies defaulted to `second_screen=True` per `src/selkies/settings.py:113`. | Confirmed source-backed gap. |
| Failed gamepad node fallback | If `/dev/input/js0` cannot be created, upstream writes `SELKIES_UI_SIDEBAR_SHOW_GAMEPADS=false`, `SELKIES_GAMEPAD_ENABLED=false`, `SELKIES_ENABLE_PLAYER2=false`, `SELKIES_ENABLE_PLAYER3=false`. Source: `init-selkies-config/run:282-302`. | Already closed in `/tmp/wsl-kde-webtop/start.sh`; user confirmed launcher improved. | Closed; do not undo unless harmful evidence appears. |
| Selkies command shape | `svc-selkies` execs `selkies --addr="localhost" --mode="websockets"`. Source: `svc-selkies/run:62-66`. | Runtime command remains `/tmp/selkies-lsio-venv/bin/python -m selkies --addr=localhost --mode=websockets --port=8082`; port is explicit to align nginx `CUSTOM_WS_PORT=8082`. | Acceptable WSL-local adapter; not a right-click drift. |
| nginx proxy headers/route | `default.conf` preserves WebSocket Upgrade headers, HTTP/1.1, 3600s timeouts, buffering off, and proxies to `127.0.0.1:CWS`. Source: `default.conf:26-40`. | Runtime `nginx.conf` preserves these semantics and proxies `/websockets` to `127.0.0.1:8082` because current served dashboard artifact appends `websockets`. | Accepted source-mapped route adaptation. |
| KDE startup env/session | `startwm_wayland.sh` exports `QT_QPA_PLATFORM=wayland`, `XDG_CURRENT_DESKTOP=KDE`, `XDG_SESSION_TYPE=wayland`, `KDE_SESSION_VERSION=6`, `DISPLAY=:1`, starts KWin on `wayland-1`, Plasma on `wayland-0`, and runs `kbuildsycoca6`. Source: `docker-webtop-ubuntu-kde/root/defaults/startwm_wayland.sh:73-94`. | Runtime preserves these values and process shape. | No current right-click drift found. |
| Browser contextmenu/input routing | Selkies frontend maps ordinary right-click into `m,x,y,button_mask,0` and suppresses browser native contextmenu on overlay. Source: `/tmp/selkies-lsio-src/addons/selkies-web-core/lib/input.js:1624-1717,2314-2318`; `selkies-ws-core.js:1364-1372`. | Latest logs show right-clicks as normal absolute `type=m` `button_mask=4 -> 0`; no runtime evidence distinguishes browser duplicate events vs user repeated attempts vs KDE popup focus dismissal. | Needs user-side/devtools evidence before source changes; monkey patch remains disallowed. |
| Trackpad/relative mouse | Trackpad mode sends `touchinput:trackpad` and `SET_NATIVE_CURSOR_RENDERING,1`; right-click logs would differ if relative/pointer-lock path were involved. Source: `selkies-ws-core.js:1920-1938,3395-3403`. | Latest broken right-clicks are `type=m`, not `type=m2`. | No evidence of trackpad-mode root cause. |

Gap closure applied in this pass:

- Added `SELKIES_SECOND_SCREEN=false` to `/tmp/wsl-kde-webtop/start.sh`, before Selkies starts, with comment mapping it to `init-selkies-config` Wayland branch. This is a direct source-backed distribution behavior closure, not a Selkies/KDE source patch.
- Rollback for this closure: remove/comment the `SELKIES_SECOND_SCREEN=false` export in `/tmp/wsl-kde-webtop/start.sh` and rerun `/tmp/wsl-kde-webtop/restart.sh`.

Diagnostic instrumentation status:

- Restored `/tmp/selkies-lsio-src/src/selkies/input_handler.py` from `/tmp/wsl-kde-webtop/input_handler.py.before-menu-debug` so the temporary `Mouse message:` instrumentation is no longer present in Selkies source. Verified the `m/m2` branch again calls `send_x11_mouse(...)` directly. This prevents a patched Selkies source from being mistaken for an implementation fix.

Verification after restart:

- `/tmp/wsl-kde-webtop/logs/startup-status.log` showed `wayland-1 socket ready` and `started`.
- Live Selkies env showed `SELKIES_SECOND_SCREEN=false`, `SELKIES_GAMEPAD_ENABLED=false`, `SELKIES_UI_SIDEBAR_SHOW_GAMEPADS=false`, `SELKIES_ENABLE_PLAYER2=false`, `SELKIES_ENABLE_PLAYER3=false`, `CUSTOM_WS_PORT=8082`, `SELKIES_PORT=8082`, `SELKIES_MODE=websockets`, `DISPLAY=:1`, `WAYLAND_DISPLAY=wayland-1`, and `XDG_RUNTIME_DIR=/tmp/wsl-kde-webtop/xdg-runtime`.
- Runtime processes were alive: nginx, Selkies, KWin, and `startwm_wayland.sh`.
- Wayland/X sockets existed: `/tmp/wsl-kde-webtop/xdg-runtime/wayland-1`, `/tmp/wsl-kde-webtop/xdg-runtime/wayland-0`, and `/tmp/.X11-unix/X1`.
- Verification blocker: two checks of `ss -tlnp | grep -E '(:3200|:8082)'` showed nginx on `127.0.0.1:3200`, but did not show `8082` listening. `/tmp/wsl-kde-webtop/logs/selkies.log` stopped after `[Wayland] Socket listening on: "wayland-1"`. Therefore this pass cannot claim the restarted runtime is browser-test-ready until the missing `8082` listener is resolved or shown to become available later.

DoD status: still incomplete. The user must not be asked to validate right-click until the runtime WebSocket port is verified listening again. Do not mark tasks 8.x or hard-limit tasks 7.x complete.

### Backend listener restoration check after restart question (2026-05-16)

User asked whether the runtime had been turned off and on again. Factual status: `/tmp/wsl-kde-webtop/restart.sh` had already been run after adding `SELKIES_SECOND_SCREEN=false`; the previous pass initially reported a transient verification blocker where `8082` was not visible and `selkies.log` had only reached `[Wayland] Socket listening on: "wayland-1"`.

Current restoration diagnosis:

- Rechecking current state showed both required ports listening:
  - `0.0.0.0:8082` by Selkies Python process.
  - `127.0.0.1:3200` by nginx.
- Runtime PIDs were alive:
  - nginx master using `/tmp/wsl-kde-webtop/nginx.conf`.
  - Selkies `/tmp/selkies-lsio-venv/bin/python -m selkies --addr=localhost --mode=websockets --port=8082`.
  - KWin `kwin_wayland --no-lockscreen --xwayland --xwayland-display=:1 --xwayland-fd=3`.
  - `/tmp/wsl-kde-webtop/startwm_wayland.sh`.
- `/tmp/wsl-kde-webtop/logs/selkies.log` now contains `INFO:data_websocket:Data WebSocket Server listening on port 8082` at line `44`, followed by a WebSocket client connection and display reconfiguration/capture startup. Therefore the earlier `8082` blocker was not persistent at the time of this pass.
- Live Selkies env retained the source-faithful closures: `SELKIES_SECOND_SCREEN=false`, `SELKIES_GAMEPAD_ENABLED=false`, `SELKIES_UI_SIDEBAR_SHOW_GAMEPADS=false`, `SELKIES_ENABLE_PLAYER2=false`, `SELKIES_ENABLE_PLAYER3=false`, `CUSTOM_WS_PORT=8082`, `SELKIES_PORT=8082`, and `SELKIES_MODE=websockets`.
- Display sockets existed: `/tmp/wsl-kde-webtop/xdg-runtime/wayland-1`, `/tmp/wsl-kde-webtop/xdg-runtime/wayland-0`, and `/tmp/.X11-unix/X1`.
- A protocol-level handshake through nginx was verified with the Selkies virtualenv Python: connecting to `ws://127.0.0.1:3200/websockets` returned first message `MODE websockets`.

No runtime change was required in this pass. `SELKIES_SECOND_SCREEN=false` was not rolled back because current evidence shows backend listener and WebSocket handshake are restored while that source-faithful env remains active. The launcher-improving gamepad env closure was preserved.

Current status after restoration check: backend plumbing is ready for the next user visual test. The next manual check is to refresh `http://localhost:3200`, verify the KDE app launcher still works, and test one right-click menu. Do not mark DoD 8.x complete until the user confirms right-click and overall browser desktop behavior.

### Resize/output lifecycle investigation after latest right-click retest (2026-05-16)

User retested `http://localhost:3200`: right-click menus still disappear too quickly to click. App launcher was not restated in that message, but prior user confirmation after the gamepad failed-node env closure was that the launcher is OK.

Latest evidence inspected:

- Runtime ports initially showed both `0.0.0.0:8082` and `127.0.0.1:3200` listening before the resize gap closure attempt.
- Current Selkies env before the attempt had `SELKIES_SECOND_SCREEN=false`, `SELKIES_ENABLE_RESIZE=true`, no manual resolution env (`SELKIES_IS_MANUAL_RESOLUTION_MODE`, `SELKIES_MANUAL_WIDTH`, `SELKIES_MANUAL_HEIGHT` all unset), and the preserved gamepad failed-node closure values.
- `/tmp/wsl-kde-webtop/logs/selkies.log` showed repeated client lifecycle and output resize churn:
  - `Received resize request for primary: 3840x1386`, `1916x1386`, `1916x1820`, `1916x788`, then `3840x1386`.
  - Each resize caused `Wayland Resize: Updating primary ... and restarting pipeline`, `Stopping all streams`, `Capture loop stopped`, and `Configuring Output ...`.
  - Client disconnects caused `No display clients connected. Video pipelines remain stopped`, followed by a new client connection and display reconfiguration.
- `/tmp/wsl-kde-webtop/logs/plasmashell.log` contained repeated severe output/compositor symptoms at lines `317-319`, `527-529`, and `892-898`: `qt.qpa.wayland: There are no outputs - creating placeholder screen`, `kde.plasmashell: requesting unexisting screen available rect -1`, and `The Wayland connection broke. Did the Wayland compositor die?`.

Source-backed gap found:

- Selkies' own setting default for `enable_resize` is `False` (`/tmp/selkies-lsio-src/src/selkies/settings.py:170`), and its `ws_entrypoint` only wires `input_handler.on_resize` to `on_resize_handler` when `ENABLE_RESIZE` is true (`/tmp/selkies-lsio-src/src/selkies/selkies.py:3601-3609`).
- The current runtime had manually forced `SELKIES_ENABLE_RESIZE=true` in `/tmp/wsl-kde-webtop/start.sh`; this env is not emitted by the upstream `init-selkies-config` snippets inspected for Webtop KDE Wayland startup.
- Selkies/baseimage documentation states manual resolution mode can lock a fixed resolution and disable client UI resolution changes, but no such manual resolution env was set in the runtime.

Gap closure attempted and then rolled back:

- Attempted source-faithful closure: removed explicit `SELKIES_ENABLE_RESIZE=true` from `/tmp/wsl-kde-webtop/start.sh` to return to Selkies default resize-disabled behavior and stop browser-driven Wayland output churn.
- Restarted with `/tmp/wsl-kde-webtop/restart.sh`.
- Verification after this attempt failed: nginx listened on `127.0.0.1:3200`, processes and Wayland/X sockets existed, and `SELKIES_ENABLE_RESIZE=<unset>`, but `8082` did not appear in `ss -tlnp` and WebSocket handshake to `ws://127.0.0.1:3200/websockets` timed out. `selkies.log` stopped after `[Wayland] Socket listening on: "wayland-1"`.
- Because backend WebSocket did not verify, the resize closure was not left active. Restored `SELKIES_ENABLE_RESIZE=true` in `/tmp/wsl-kde-webtop/start.sh` and restarted.
- Verification after rollback still did not show `8082` within the allowed two status checks; `selkies.log` again stopped at `[Wayland] Socket listening on: "wayland-1"`. Runtime processes existed and `SELKIES_ENABLE_RESIZE=true`, `SELKIES_SECOND_SCREEN=false`, `SELKIES_GAMEPAD_ENABLED=false`, and `SELKIES_UI_SIDEBAR_SHOW_GAMEPADS=false` were present in the Selkies process env, but backend was not browser-test-ready at this checkpoint.

Current blocker:

- There is a source-backed resize/output lifecycle gap (`SELKIES_ENABLE_RESIZE=true` causes repeated Wayland output reconfiguration under changing browser sizes), and the latest Plasma logs support output lifecycle instability as relevant to popups/right-click menus.
- However, toggling that env exposed or coincided with a backend startup stall where Selkies does not progress beyond Wayland socket initialization to `Data WebSocket Server listening on port 8082` within the allowed verification window. Since the rollback also did not immediately restore `8082`, this appears to be a startup timing/stall issue requiring a focused backend-startup investigation before further UI testing.
- Do not ask the user to retest right-click until `8082` and `MODE websockets` are verified again. Do not mark DoD 8.x or hard-limit 7.x complete.

### Manual-resolution gap closure attempt after backend became available again (2026-05-16)

Main-agent verification after the previous stale blocker showed the backend was usable again: `ss -tlnp` showed Selkies listening on `0.0.0.0:8082`, nginx on `127.0.0.1:3200`, and `selkies.log` contained `Data WebSocket Server listening on port 8082`. This pass therefore resumed resize/output lifecycle gap analysis from a live backend state.

Current evidence rechecked:

- Live env before this attempt: `SELKIES_ENABLE_RESIZE=true`, `SELKIES_SECOND_SCREEN=false`, no manual resolution env (`SELKIES_IS_MANUAL_RESOLUTION_MODE`, `SELKIES_MANUAL_WIDTH`, `SELKIES_MANUAL_HEIGHT` unset), and the failed-gamepad-node closures still active.
- `selkies.log` continued to show browser-driven resize churn and client lifecycle churn: repeated `Received resize request for primary: 3840x1386`, `Wayland Resize: Updating primary ... and restarting pipeline`, `Cleaning up Data WS handler`, `No display clients connected`, and `Configuring Output ...`.
- `plasmashell.log` now included additional severe output/compositor lines beyond earlier evidence, including lines `1379-1383` and `1425-1427`: `There are no outputs - creating placeholder screen`, `requesting unexisting screen available rect -1`, and `The Wayland connection broke. Did the Wayland compositor die?`.

Source-backed implementation delta identified:

- LinuxServer baseimage-selkies documents manual resolution mode as a supported server-side configuration: if `SELKIES_MANUAL_WIDTH`, `SELKIES_MANUAL_HEIGHT`, or `SELKIES_IS_MANUAL_RESOLUTION_MODE` is set, resolution is locked and the client UI for changing resolution is disabled. Source: `/tmp/wsl-webtop-source-study/docker-baseimage-selkies/README.md:129-134`.
- Selkies settings activate manual mode when manual width/height are overridden. Source: `/tmp/selkies-lsio-src/src/selkies/settings.py:270-282`.
- Selkies server forces manual resolution from server config during settings application. Source: `/tmp/selkies-lsio-src/src/selkies/selkies.py:1410-1420`.
- Selkies resize handler ignores client resize when server manual mode is active. Source: `/tmp/selkies-lsio-src/src/selkies/selkies.py:3367-3374`.
- Selkies frontend recognizes server-forced manual mode and switches to manual resize handlers. Source: `/tmp/selkies-lsio-src/addons/selkies-web-core/selkies-ws-core.js:3466-3484`.

Runtime change attempted:

- Added `SELKIES_MANUAL_WIDTH=1920` and `SELKIES_MANUAL_HEIGHT=1080` to `/tmp/wsl-kde-webtop/start.sh` as a source-faithful manual-resolution closure. `1920x1080` maps to LinuxServer Webtop README's documented example for clamping resolution (`/tmp/wsl-webtop-source-study/docker-webtop/README.md:294-298`).
- Restarted with `/tmp/wsl-kde-webtop/restart.sh`.
- Verification showed the env was parsed correctly: `selkies.log` contained `A manual resolution setting was activated; locking to manual mode`, `Width override via SELKIES_MANUAL_WIDTH: 1920`, and `Height override via SELKIES_MANUAL_HEIGHT: 1080`.
- Verification failure: within two checks, only nginx on `127.0.0.1:3200` was visible; no `8082` listener appeared, WebSocket handshake timed out, and `selkies.log` stopped after `[Wayland] Socket listening on: "wayland-1"`.

Rollback:

- Removed `SELKIES_MANUAL_WIDTH=1920` and `SELKIES_MANUAL_HEIGHT=1080` from `/tmp/wsl-kde-webtop/start.sh` and restarted.
- Env returned to baseline (`SELKIES_ENABLE_RESIZE=true`, manual width/height unset, `SELKIES_SECOND_SCREEN=false`, gamepad closures preserved).
- However, within the allowed verification window after rollback, `8082` still did not appear and WebSocket handshake still timed out; `selkies.log` again stopped after `[Wayland] Socket listening on: "wayland-1"`.

Current status:

- The manual-resolution implementation delta is source-backed and targets the observed resize/output churn, but it was not left active because it did not pass backend readiness verification.
- The immediate blocker is again backend startup progress after restart: Selkies process exists but does not reach `Data WebSocket Server listening on port 8082` within the verification window. This must be diagnosed before another UI retest or another resize/output lifecycle closure.
- No Selkies/KDE source monkey patch was introduced. Diagnostic mouse instrumentation remains restored/absent.

### Gamepad and resize env semantics in LSIO WebSocket mode (2026-05-16)

Main-agent follow-up showed the backend became available again after the prior timing/stall report: `ss -tlnp` showed Selkies on `0.0.0.0:8082`, nginx on `127.0.0.1:3200`, and `selkies.log` contained `Data WebSocket Server listening on port 8082`.

Live runtime facts confirmed in this pass:

- Live Selkies process env contains the intended source-faithful env closures: `SELKIES_GAMEPAD_ENABLED=false`, `SELKIES_UI_SIDEBAR_SHOW_GAMEPADS=false`, `SELKIES_ENABLE_PLAYER2=false`, `SELKIES_ENABLE_PLAYER3=false`, `SELKIES_SECOND_SCREEN=false`, and `SELKIES_ENABLE_RESIZE=true`; manual resolution env remains unset.
- Despite `SELKIES_GAMEPAD_ENABLED=false`, `/tmp/wsl-kde-webtop/logs/selkies.log` still shows `Initializing 4 persistent gamepad instances...` and four `selkies_js{0-3}.sock` / `selkies_event100{0-3}.sock` gamepad instances.
- The same log confirms settings parsing did receive the env values: `gamepad_enabled: (False, False)`, `ui_sidebar_show_gamepads: (False, False)`, `enable_player2: (False, False)`, `enable_player3: (False, False)`, and `second_screen: (False, False)`. Therefore the gamepad env is not missing from the process or parser.
- The frontend/dashboard source uses `ui_sidebar_show_gamepads` and related server settings to hide UI affordances, and `second_screen=false` prevents secondary displays in the client. Source: `/tmp/selkies-lsio-src/addons/selkies-dashboard/src/components/Sidebar.jsx:599-612,636-639,2707-2718` and `/tmp/selkies-lsio-src/addons/selkies-web-core/selkies-ws-core.js:3443-3461`.

Source facts for gamepad backend initialization:

- Current runtime source `/tmp/selkies-lsio-src/src/selkies/input_handler.py:860` sets `self.num_gamepads = 4` unconditionally.
- `/tmp/selkies-lsio-src/src/selkies/input_handler.py:1122-1124` calls `await self._initialize_persistent_gamepads()` unconditionally during `connect()`.
- `/tmp/selkies-lsio-src/src/selkies/input_handler.py:1128-1158` creates all `self.num_gamepads` persistent sockets.
- Grep comparison showed the checked-out upstream LSIO mirror (`/tmp/wsl-webtop-source-study/selkies-lsio/src/selkies/input_handler.py`) and main Selkies mirror (`/tmp/wsl-webtop-source-study/selkies-main/src/selkies/input_handler.py`) contain the same unconditional `self.num_gamepads = 4` and `_initialize_persistent_gamepads()` call pattern. Thus this is not a local runtime integration drift.

Source facts for resize behavior:

- Current runtime source `/tmp/selkies-lsio-src/src/selkies/settings.py:170` declares `enable_resize` with default `False`, but WebSocket mode does not use that setting to wire resize behavior.
- `/tmp/selkies-lsio-src/src/selkies/selkies.py:26` has top-level `ENABLE_RESIZE = True`.
- `/tmp/selkies-lsio-src/src/selkies/selkies.py:3601-3608` wires `input_handler.on_resize` based on the top-level `ENABLE_RESIZE` global, not `settings.enable_resize`.
- Grep comparison showed the LSIO mirror and main Selkies mirror have the same WebSocket-mode `ENABLE_RESIZE = True` / `if ENABLE_RESIZE:` pattern. In contrast, `webrtc_mode.py` uses CLI args for `enable_resize`, but this runtime is explicitly running `--mode=websockets`, matching LinuxServer `svc-selkies/run`.
- `docker-baseimage-selkies/root/etc/s6-overlay/s6-rc.d/svc-selkies/run:62-66` starts `selkies --addr="localhost" --mode="websockets"` and does not pass a CLI flag that would change either backend gamepad socket initialization or WebSocket resize behavior.
- `docker-baseimage-selkies/root/etc/s6-overlay/s6-rc.d/init-selkies-config/run:282-302` only writes env for failed `/dev/input/js0` creation; it does not generate another config file or wrapper consumed by `InputHandler` to skip persistent socket initialization.

Conclusion:

- There is no further source-faithful runtime/startup/config gap available for gamepad backend socket initialization or WebSocket-mode resize wiring. Current behavior matches the checked-out LSIO/Selkies source path used by LinuxServer baseimage-selkies.
- The existing env closures are still source-faithful for the distribution UI/settings layer: they hide/disable gamepad and second-screen affordances sent to clients. They do not, by upstream code design, stop backend gamepad socket initialization or WebSocket-mode output resize handling.
- Changing backend gamepad initialization to respect `settings.gamepad_enabled`, or changing WebSocket-mode resize to respect `settings.enable_resize`, would require patching Selkies Python source. That is disallowed by the user's no-monkey-patch/source-faithful constraint and was not done.

Next non-monkey-patch diagnostic needed for right-click root cause:

- Capture browser-side event order for a single physical right-click (`mousedown`, `mouseup`, `contextmenu`, duplicate events) without editing Selkies source, or use existing browser DevTools/user observation to determine whether native Chrome/Windows contextmenu participates.
- Correlate a single controlled right-click with server-side logs only after deciding whether temporary diagnostic logging is acceptable again; if reintroduced, it must remain diagnostic-only and be restored afterward.
- Do not ask the user to retest as if a fix landed; no new lasting runtime change was applied in this pass.

### User-side right-click narrowing and focus/output evidence pass (2026-05-16)

New verified user-side evidence:

- Windows right-click works normally.
- Chrome right-click on pages other than `http://localhost:3200` works normally.
- Only KDE-in-Selkies at `http://localhost:3200` fails: the KDE right-click popup disappears very quickly and cannot be clicked.
- The KDE right-click popup disappears quickly both while the user holds the right mouse button and after the user releases it.

Implication: the failure is scoped to the Selkies canvas/input → KDE/Plasma popup/focus path. Because the popup disappears even while the right button is still held, the simple hypothesis “normal mouseup dismisses the menu” is insufficient.

Non-invasive runtime evidence collected:

- Ports remained available: Selkies on `0.0.0.0:8082`, nginx on `127.0.0.1:3200`.
- Process env for Selkies/KWin/startwm preserved the expected KDE/Wayland values: `QT_QPA_PLATFORM=wayland`, `XDG_SESSION_TYPE=wayland`, `KDE_SESSION_VERSION=6`, `WAYLAND_DISPLAY=wayland-1`, `DISPLAY=:1`, `XDG_RUNTIME_DIR=/tmp/wsl-kde-webtop/xdg-runtime`, `XDG_CURRENT_DESKTOP=KDE`.
- KWin log did not show direct popup/focus errors; it only repeated known WSL/Webtop warnings such as missing PipeWire/glamor support and unsupported host Wayland protocols.
- Selkies log around the latest area still showed client lifecycle/output churn near the right-click investigation window: Data WebSocket disconnects, `No display clients connected`, `Keyboard reset completed ... disconnect`, repeated `Received resize request for primary: 3840x1386`, `Wayland Resize: Updating primary ...`, and `Configuring Output ...`.
- Plasma log accumulated additional severe output/compositor lines beyond the previous evidence, including `qt.qpa.wayland: There are no outputs - creating placeholder screen`, `kde.plasmashell: requesting unexisting screen available rect -1`, and `The Wayland connection broke. Did the Wayland compositor die?` at lines `1593-1595` and `1641-1643`.

Source comparison for focus/popup/input path:

- Upstream Webtop KDE `startwm_wayland.sh` disables compositing/screen lock, applies only clipboard-specific KWin rules, sets KDE/Wayland env, starts `kwin-xwayland.py` with `WAYLAND_DISPLAY=wayland-1`, sleeps two seconds, then starts `plasmashell` with `WAYLAND_DISPLAY=wayland-0`. The WSL runtime mirrors this flow, with only WSL-safe adaptations: logging, not deleting host-level UDisks service, and not moving system `applications.menu` unless needed.
- The skipped UDisks deletion and system `applications.menu` move are not evidenced as popup/focus controls; launcher already improved after gamepad env closure, so they do not justify a right-click-focused runtime mutation.
- Selkies frontend suppresses browser native `contextmenu` on `overlayInput` and maps ordinary mouse events into `m,x,y,button_mask,0`; this is upstream behavior and was not patched.

Conclusion:

- No new source-faithful runtime/config gap was found that directly explains “right-click popup disappears even while held.” Random KWin/env tweaks would be non-source-faithful.
- The strongest remaining evidence points to one of two paths that cannot be distinguished from current logs without a targeted diagnostic:
  1. Browser/Selkies input path sends duplicate or unexpected right-button/focus events for one physical right-click.
  2. KDE/Plasma popup loses focus because the Selkies client/output lifecycle is changing under it (disconnect/resize/no-output churn), causing popup dismissal independent of mouseup.

Minimum next diagnostic, requiring user approval before proceeding:

- Preferred browser-side diagnostic: run a temporary DevTools console event logger on `http://localhost:3200` that records one physical right-click (`pointerdown`, `mousedown`, `mouseup`, `pointerup`, `contextmenu`, `blur`, `focus`, `visibilitychange`) on `#overlayInput` / document / window, then remove it. This does not patch Selkies source and directly tests whether a single held right-click causes duplicate or focus-loss events.
- Alternative server-side diagnostic: temporarily reintroduce diagnostic-only mouse/focus logging, ask for one controlled right-click, then restore the source immediately. This is more invasive and must not be treated as a fix.

No runtime change was applied in this pass. Do not ask for another free-form UI retest; ask only for the specific diagnostic evidence above. Do not mark DoD 8.x or hard-limit 7.x complete.

## Risks / Trade-offs

- [Risk] Selkies native 安装或运行在 WSL 中受依赖、权限、systemd、display server 限制。→ Mitigation: 先按 Selkies/Webtop 服务关系定位阻塞；只有确认 WSL hard limit 后才允许替换组件。
- [Risk] KDE Wayland path 在 WSL native 不稳定。→ Mitigation: 评估 X11/Xwayland 兼容路径，但必须保持 browser desktop 体验，并明确这是 WSL hard limit 差异。
- [Risk] 执行再次滑入 trial-and-error。→ Mitigation: 所有失败必须先回查 upstream source，写出单一 hypothesis 和最小实验；critic/reviewer 检查是否随机试错。
- [Risk] 多个 subagent 同时修改 WSL host 状态互相踩踏。→ Mitigation: discovery 并发、host mutation 串行；main agent 统一调度，单一 executor owns `/tmp/wsl-kde-webtop` runtime、ports 和 service lifecycle。
- [Risk] 误用 WSLg 单应用窗口或 VNC/noVNC/RDP 作为捷径。→ Mitigation: spec 明确禁止；critic 审阅专门检查。
- [Risk] scope 再次滑向 Docker/container/image 或 buntoolbox 产品化。→ Mitigation: tasks/spec 中设 scope guard，所有相关词只允许出现在禁止项里。
- [Risk] “exactly same” 与 WSL hard limit 冲突。→ Mitigation: 每个差异都必须回答：是否真是 WSL hard limit？如果不是，继续修正直到 exactly same。

## Migration Plan

1. Gate 0：确认 scope guard：pure WSL native；禁止 Docker/container/image/compose/Docker Desktop；禁止修改 buntoolbox 产品代码。
2. Gate 1：建立 upstream source inventory，并从源码提取 exact behavior baseline：KDE flavor、baseimage-selkies service graph、Selkies frontend/backend contract。
3. Gate 2：并行完成 MECE discovery：WSL baseline、KDE session planner、Selkies/frontend planner、hard-limit verifier。
4. Gate 3：main agent review 并整合各切片，明确唯一 WSL host executor 和串行 mutation plan。
5. Gate 4：在 WSL native 中安装或配置 KDE desktop、Selkies/browser streaming、frontend/proxy、display/audio/dbus 等必要组件。
6. Gate 5：启动 KDE session，通过 browser streaming 展示完整 desktop。
7. Gate 6：Windows 浏览器打开 URL，确认看到 KDE desktop 且与 Webtop KDE exactly same；若有差异，只能由 WSL hard limit 解释。

## Rollback Strategy

- 停止 WSL native 中新增的 KDE/session/streaming/frontend services。
- 删除或禁用本 change 创建的 WSL-local service files、launch scripts 或 config snippets。
- 不需要回滚 buntoolbox 产品代码，因为本 change 不允许修改它。
- OpenSpec amendment 阶段若产生 diff，必须只位于 `openspec/changes/mimic-webtop-kde-wsl/**`；implementation 阶段若产生 WSL host-local runtime artifacts，必须列出路径、owner、停止方式和删除方式。
- 如安装了 packages，提供可选卸载清单；但 package 卸载是否执行由用户决定，避免破坏 WSL 环境中其他用途。

## Open Questions

- 当前 WSL 是否启用 systemd？若未启用，服务管理需要使用 user-level launcher 或明确启用 systemd。
- Selkies native 安装在当前 WSL 是否可行？若不可行，阻塞点是否属于 WSL hard limit？
- Webtop KDE 的 exact frontend 是否可在 WSL native 中复用？如果不能，哪些 frontend 差异是 hard limit？
- KDE session 在当前 WSL 下应优先 Wayland 还是 X11 兼容路径，才能满足 Webtop KDE exact behavior template？

### Right-click popup blocker and plasmashell-wayland-1 experiment decision (2026-05-16)

本节记录右键弹出框 blocker 的当前状态，以及 plasmashell 到 wayland-1 架构实验的否决决定。两者均为已验证事实，不是推测。

#### Verified runtime facts entering this decision point

- Runtime readiness restored: nginx on `127.0.0.1:3200`, Selkies on `0.0.0.0:8082`, WebSocket handshake through nginx returned `MODE websockets`. Source: agent shell `ss -tlnp` and `ws://127.0.0.1:3200/websockets` first message.
- Current KWin geometry: `1378x909`, scale `1.25`, QPainter renderer, focusPolicy `ClickToFocus`. Confirmed via `qdbus org.kde.KWin /KWin supportInformation` output in prior pass.
- Plasma layout exists; xdg-desktop-portal ping returned a valid response. Confirmed via `plasmashell.log` component loading and portal query.
- Current topology remains source-faithful per upstream `startwm_wayland.sh:83-94` @ `45619c47324ef14a39485fa96269d5ed3ce4ce14`: `plasmashell` on `wayland-0`, `kwin_wayland` on `wayland-1`.
- Geometry A/B test under viewport `1378x910` / stream `1722x1136`: right-click popup appeared then disappeared before any item could be clicked. Page was initially black then normal, corresponding to Selkies `STOP_VIDEO`/`START_VIDEO`/capture restart in `selkies.log`.
- No-move right-click (held and released at the same position): popup still disappears. Captured input logs showed normal `button_mask=4 -> 0` single pair, no duplicate events, no `OUTSIDE_VIEWPORT` in that sample.
- DOM right-click path: browser DevTools confirmed `contextmenu.defaultPrevented=true` on `#overlayInput`; no duplicate `contextmenu` events observed from a single physical right-click. Source: user-side DevTools console evidence.
- WAYLAND_DEBUG diagnostics: both heavy global WAYLAND_DEBUG and plasmashell-only WAYLAND_DEBUG were applied as temporary diagnostics in prior passes, caused short-window readiness failures, and were restored. Neither is retained in the current runtime.

#### Decision: plasmashell to wayland-1 architecture experiment is NOT the next source-faithful action

The upstream `startwm_wayland.sh` (source: `docker-webtop-ubuntu-kde/root/defaults/startwm_wayland.sh:83-94` @ `45619c47324ef14a39485fa96269d5ed3ce4ce14`) defines the canonical Webtop KDE topology as:

```text
dbus-run-session:
  WAYLAND_DISPLAY=wayland-1 python3 /kwin-xwayland.py   (KWin on wayland-1)
  polkit-kde-authentication-agent-1 (optional)
  WAYLAND_DISPLAY=wayland-0 plasmashell                  (Plasma on wayland-0)
```

Moving `plasmashell` from `wayland-0` to `wayland-1` would deviate from this upstream topology without a hard-limit proof. This experiment:

- Is not driven by any source node in Webtop KDE, baseimage-selkies, or Selkies LSIO.
- Would require `plasmashell` and `kwin_wayland` to share `wayland-1`, which is not the distribution-tested socket split.
- Has no upstream precedent or documentation as a WSL-specific adaptation.
- Cannot qualify as a hard-limit deviation per the criteria in tasks 7.1-7.6: no upstream expected behavior identifies this topology change, and no WSL native attempt has been documented as failing that would force this change.

Decision recorded: `plasmashell to wayland-1` topology change is classified as a non-source-faithful, high-risk diagnostic candidate only. It MUST NOT be executed as the next implementation step unless all of the following are proven:

1. A specific source node in Webtop KDE, baseimage-selkies, or Selkies LSIO is identified that requires this topology for the popup/focus path.
2. The WSL native attempt to fix the popup via source-faithful means is documented as failed with evidence.
3. The deviation is the smallest adapter that preserves Webtop/Selkies semantics.
4. Critic/verifier sign-off accepts it as a WSL hard limit.

#### Current blocker: right-click popup/grab behavior is unresolved

The source-faithful mimic has confirmed the following resolved and unresolved items:

| Item | Status |
| --- | --- |
| KDE app launcher | Resolved: source-faithful gamepad failed-node env closure improved launcher behavior (user-confirmed). |
| Backend WebSocket plumbing (nginx + Selkies + MODE websockets) | Resolved: verified via curl, WebSocket handshake, and Windows `localhost:3200` HTTP reachability. |
| Source-faithful session topology (plasmashell on wayland-0, KWin on wayland-1) | Preserved: runtime matches upstream `startwm_wayland.sh` shape. |
| Right-click context menu popup | Unresolved blocker: popup appears then immediately disappears even while right button is held; no-move right-click also fails; `contextmenu.defaultPrevented=true` confirmed; no duplicate events confirmed from single right-click; no available source-faithful runtime config/env change directly addresses this without either a monkey patch or unevidenced topology change. |

The remaining evidence gap: whether the popup dismissal originates from (a) Selkies input path delivering unexpected focus/pointer events to KDE after a normal right-button press/release, or (b) KDE/Plasma popup losing focus because Selkies output/disconnect/resize lifecycle churn changes the compositor state under the popup. Current logs cannot distinguish these two paths without targeted diagnostics approved by the user.

DoD tasks 8.x must remain unchecked. The source-faithful mimic still has an unresolved KDE/Wayland popup/grab interaction blocker that prevents the browser desktop from being exactly same as Webtop KDE.

## Upstream Webtop KDE Behavior Comparison (2026-05-16)

本节汇总 upstream LinuxServer Webtop KDE 的直接已验证证据，以及当前 evidence gap。
所有内容均为已验证事实；未验证项明确标注。

### 官方文档与镜像证据

- LinuxServer Webtop 官方文档确认支持 `ubuntu-kde` flavor，访问地址为 `https://yourhost:3001/`。
- 官方 Docker run 示例端口映射：`-p 3000:3000 -p 3001:3001`，`CUSTOM_PORT=3000`（HTTP），`CUSTOM_HTTPS_PORT=3001`（HTTPS），`CUSTOM_WS_PORT=8082`（WebSocket，default 8082）。
- baseimage-selkies README 提供的 dev run command 使用 `ghcr.io/linuxserver/webtop:ubuntu-kde` 并映射 `-p 3001:3001`，没有 Docker Compose 变体。

### 源码 commit inventory

- `docker-webtop-ubuntu-kde`：commit `45619c47324ef14a39485fa96269d5ed3ce4ce14`，已在本地 source inventory 确认。
- `docker-baseimage-selkies`：commit `93d956bfecbc511dbeb8dbece741ad361f2d9a6e`，已在本地 source inventory 确认。
- `selkies-lsio`：commit `aae6a4de653bb95da0a6b820f885fb6b30a5e35c`，已在本地 source inventory 确认。
- Upstream topology：`startwm_wayland.sh:83-94` @ `45619c47324ef14a39485fa96269d5ed3ce4ce14` 定义 `kwin_wayland` 在 `wayland-1`，`plasmashell` 在 `wayland-0`。该拓扑已在当前 WSL mimic runtime 中忠实复现。

### Docker runtime reference snapshot

- Docker Desktop 已通过 `sc.exe start com.docker.service` 恢复；`docker info` 成功，Server Version `29.4.3`，Images `9`。
- image `linuxserver/webtop:ubuntu-kde`（digest `sha256:79521b69ab04ae57dffef7e75afe2a61f0580981d633c9c7d01e3f929751cd3d`，ID `sha256:bd4f49c04603b27f2b61ea6439aa7064d620086029363c3a14e4f7cf29f1734c`）存在，`docker image inspect` 和 compact `docker history` 均成功。
- 临时 reference container `webtop-kde-ref-snapshot` 已启动、runtime snapshot 采集完毕后通过 `docker rm -f webtop-kde-ref-snapshot` 移除。
- Runtime env 包含 `XDG_RUNTIME_DIR=/config/.XDG`。Sockets 包含 `/config/.XDG/wayland-0`、`/config/.XDG/wayland-1`、`/tmp/.X11-unix/X1`。Audio 包含 PulseAudio null sinks `output.monitor` 和 `input.monitor`。
- 进程包含 Selkies、pulseaudio、nginx、dbus、KWin、plasmashell、Xwayland、s6 supervisors。s6 services 包含 `svc-dbus`、`svc-de`、`svc-nginx`、`svc-pulseaudio`、`svc-selkies`、`svc-xorg`、`svc-xsettingsd`。
- 用户已确认 Docker reference container 主屏右键正常工作。
- 重要边界：该 Docker reference 仅作为只读 oracle 使用，不改变禁止 Docker 作为 WSL native implementation 路径的核心约束。

### 公开 issue 证据

- `linuxserver/docker-baseimage-selkies#89`：报告第二屏（second screen）无背景图、右键 context menu 不工作；reload/resize 有助于恢复；panel 右键及 panel 上右键正常；同时报告 WebSocket/session reset 症状。**注意**：此 issue 针对第二屏/XFCE 场景，不能视为 main KDE desktop 主屏右键行为的直接证明。
- `linuxserver/docker-webtop#251`：报告 ubuntu-kde black screen、scaling 异常、no input instability。属于 Webtop KDE upstream 已知不稳定问题，但未直接说明主屏右键行为。
- `linuxserver/docker-webtop#115`：建议设置合理最大分辨率、手动分辨率，以缓解 DRI3/choppy 问题。

### 排除项

- 当前 WSL runtime 中 `/home/cpf/.config/plasma-org.kde.plasma.desktop-appletsrc` 含 `RightButton;NoModifier=org.kde.contextmenu`，确认 KDE action plugin 已正确配置。
- 缺少 KDE contextmenu action 插件的假设已排除。

### Evidence gap（直接未验证项）

- Upstream 真实 Webtop KDE container 中主屏右键弹出框是否持续可用：**已通过 Docker reference container 直接验证，用户确认正常工作**。
- 右键弹出框消失是 Selkies input path 还是 KDE/Plasma compositor lifecycle 引起：**当前日志不能区分**（见 `design.md` 上一节 right-click popup blocker）。
- Upstream `#89` 的 second-screen 右键 fix 是否适用于 main KDE desktop 主屏：**未验证**，不可直接移植。

### Addendum: 维护者评论、exact-search 负结果、版本约束（2026-05-16 补充）

以下为后续补充证据，通过 GitHub API 直接验证或本机包检查确认。

#### 维护者评论证据（GitHub API 已验证，via `gh api`）

**`linuxserver/docker-baseimage-selkies#89`**（thelamer 评论，已查证原文）

- Stream resetting looks like a race condition in second screen config / first keyframe parsing。
- DE-specific behavior for multiple monitors is "a crap shoot"。
- 后续 linked #115，说明 out-of-box bug present unless set sane max resolution。

**`linuxserver/docker-webtop#251`**（thelamer 评论，已查证原文）

- Noble（Ubuntu 24.04+）is far more buggy than Bookworm for KDE；recommends `debian-kde` if able。
- Does not know why KWin is flaky on Noble。
- Later: modern kernel 6.6+ and DRI3 card resolves many `plasmaqml` crash/init issues。

**`linuxserver/docker-baseimage-selkies#115`**（正文/评论，已查证）

- Recommends setting sane max resolution / manual resolution via `SELKIES_MANUAL_WIDTH`、`SELKIES_MANUAL_HEIGHT`、`MAX_RESOLUTION`，以缓解 DRI3/choppy 问题。
- Webtop creates a 16K virtual screen；过大虚拟屏幕会引发 choppy/DRI3 相关问题。

**`linuxserver/docker-webtop#385`**（thelamer 评论，已查证）

- Issue is specific to KWin/KDE。KWin does not support the wlroots virtual-keyboard protocol。
- "We are only running portions of a KDE desktop in Docker"：no real systemd/dbus/udev/uinput。
- This is a KDE Wayland input integration limitation。
- **重要边界**：此评论描述的是 Wayland virtual-keyboard/input 限制，不是右键 context menu 直接失败的证明。记录为 input limitation context，NOT direct right-click proof。

#### Exact-search 负结果（直接 `gh search issues` 已执行）

在 `linuxserver/docker-webtop` 和 `linuxserver/docker-baseimage-selkies` 两个仓库执行以下精确查询：

- `right click context menu KDE webtop Selkies`
- `context menu disappears KDE Wayland Selkies`
- `right click menu disappears webtop`

三条查询均返回空结果（`[]`）。结论：no direct upstream issue titled/matching main KDE right-click disappears was found。

这一负结果是证据，不是盲区：它表明此右键弹出框消失问题没有在 upstream issue tracker 中形成独立 tracked 的已知 bug。

#### KDE/Qt 版本约束（本机包检查已验证）

当前 WSL 本机已安装包版本：

| 包 | 版本 |
| --- | --- |
| `kwin-wayland` | `4:6.6.4-0ubuntu1` (Plasma/KWin 6.6.4) |
| `plasma-workspace` | `4:6.6.4-0ubuntu2` (Plasma/KWin 6.6.4) |
| `qt6-wayland` | `6.10.2-4` (Qt 6.10.2) |
| `libqt6core6t64` | `6.10.2+dfsg-7` (Qt 6.10.2) |

**约束含义**：

- KDE Plasma 6.6.4 / Qt 6.10.2 是当前运行时实际版本，已超过 Qt 6.x 早期版本。
- 历史上 KDE popup bugs 在 Qt 6.x 某些版本中存在，且被后续版本修复。
- 因此，针对 Qt 6.x 早期版本的 KDE popup bug 引用只能作为机制参考，**不能**作为当前 right-click 问题的 root cause。
- 结论：当前运行时的右键弹出框消失问题若存在，其原因来自 Selkies/Wayland compositor 交互，而非 Qt/KDE 本身的已知历史 bug，因为这些 bug 已在当前版本之前被修复。

#### 本 addendum 对 evidence gap 的影响

这些补充证据 strengthen upstream-adjacent risk，但仍然 **NOT** 直接证明 upstream main KDE primary desktop right-click 行为好或坏：

- 维护者评论 (#251) 显示 Noble/KDE 在 upstream 中已知不稳定（buggy on Noble），但针对的是 black screen / plasmaqml crash，不是主屏右键。
- 维护者评论 (#89 / #115) 针对第二屏和分辨率场景，不是主屏右键直接验证。
- 维护者评论 (#385) 显示 KDE Wayland input path 缺少 systemd/udev/uinput；这是 input mechanism context，增加了 Selkies virtual input path 失效的机制合理性，但无法替代直接 right-click 验证。
- Exact-search 负结果意味着 upstream 没有专门 track 此问题，可能表明它在 upstream container 中并不普遍复现，也可能意味着未被报告。
- Version constraint 表明不应追查 Qt/KDE 早期 popup bug，当前版本已超越这些 bug 的修复点。

Evidence gap 核心陈述已更新：upstream 真实 Webtop KDE container 中主屏右键弹出框行为已通过 Docker reference instance 直接验证（用户确认正常）；remaining gap 已从“upstream 未验证”收窄为“WSL mimic 与 Docker reference 的 runtime divergence”——相同 upstream Selkies/KDE 在 Docker reference 中右键可用，但 WSL native runtime 中右键弹出框仍立即消失。

### Addendum: WSL-vs-Docker Puppeteer 自动化右键对比证据（2026-05-16 补充）

本节记录 reboot 后 runtime 重建完毕、通过 Puppeteer 自动化对比 WSL mimic 与 Docker reference 右键行为所得的完整证据。所有内容均为已验证事实，不含推测。

#### Post-reboot runtime 重建事实

- 系统 reboot 后 `/tmp` 下的 runtime/source/venv 目录消失（`/tmp` 在重启后清空为正常行为）。
- Runtime 已在 `/tmp` 下完整重建：source inventory、venv、nginx、Selkies backend、KDE session 均恢复就绪。
- 重建过程未修改任何 buntoolbox product repo 文件；重建完成不等于右键问题被修复。
- 重建后就绪验证：`http://127.0.0.1:3200` HTTP 200、page title `Selkies`、`#videoCanvas` 与 `#overlayInput` 尺寸 `1400x950`、stream 已启动。body/sidebar 仍显示 `Ubuntu KDE`，符合预期。

#### 浏览器 identity（两次自动化共同前提）

- 自动化工具：Puppeteer（从 WSL/Bun 进程运行）。
- 使用的 Chrome 可执行文件：Windows 侧路径 `/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe`，即 Windows 原生 Chrome 进程，**不是** WSL 内部安装的浏览器。
- WSL mimic 和 Docker reference 两次自动化使用完全相同的 Chrome 可执行文件和相同的 Puppeteer 脚本，确保浏览器变量不干扰对比结论。

#### WSL mimic 自动化右键结果（已验证）

- 目标 URL：`http://127.0.0.1:3200`。
- 页面就绪验证：HTTP 200，page title `Selkies`，`#videoCanvas` 和 `#overlayInput` 均为 `1400x950`，stream 已启动。
- 事件形态：单次受控右键产生一次 `pointerdown`（button 2）/ `pointerup` / `contextmenu` 序列，**无** `blur`、**无** `visibilitychange`。
- 菜单可见时刻：`~120ms`，bbox `[688,464,1040,672]`，菜单出现并可见。
- 保持按住约 `~1120ms` 时：bbox 退缩为 `[699,473,713,495]`（仅光标区域），菜单已消失，右键仍处于按下状态。
- 结论：WSL mimic 中右键弹出框在右键持续按住期间消失，复现了已知 blocker。

#### Docker reference 自动化右键结果（已验证）

- Reference container 名称：`webtop-kde-rc-ref`，基于 `linuxserver/webtop:ubuntu-kde`，端口映射 `33991:3000`。
- 就绪验证：`/config/.XDG/wayland-1` socket 存在且 HTTP `33991` 返回正常。
- 目标 URL：`http://127.0.0.1:33991`，使用与 WSL 完全相同的 Windows Chrome/Puppeteer 脚本。
- 事件形态：同样产生单次 `pointerdown` / `pointerup` / `contextmenu` 序列，**无** `blur`、**无** `visibilitychange`。
- 菜单可见时刻：`~120ms`，bbox `[688,464,1008,672]`，菜单出现并可见。
- 保持按住约 `~1120ms` 时：菜单仍可见，click region bbox `[580,355,920,675]`；held → after-up diff `nz 0`（像素无变化），菜单在松开前持续存在。
- 结论：Docker reference container 中右键弹出框在右键持续按住期间保持可见，与用户手动确认一致，证实 Docker reference 行为与 WSL mimic 存在显著差异。

#### 对比结论（仅排除项，不含 root cause 定论）

本次自动化对比使用了完全相同的浏览器可执行文件（Windows Chrome）、完全相同的 Puppeteer 脚本、完全相同的事件形态（单次 button 2 序列，无 blur/visibilitychange）。因此以下来源**已被排除**作为本受控样本的差异原因：

- 浏览器原生 contextmenu 行为差异（两次使用同一 Chrome 可执行文件）。
- DOM 层重复事件或 `contextmenu.defaultPrevented` 差异（事件形态完全相同）。
- WSL 内部浏览器 vs Windows 浏览器的歧义（均为同一 Windows Chrome 进程，从 WSL/Bun 通过 Puppeteer 控制）。

**剩余根因搜索范围**：差异必须来自浏览器 DOM 层以下。下一步诊断方向应聚焦于：WSL runtime 与 Docker reference 在 Selkies input path、KDE/Wayland compositor、Plasma popup lifecycle、compositor/session lifecycle 等层面的差异。当前日志无法区分 (a) Selkies input path 向 KDE 传递了非预期 focus/pointer 事件，与 (b) Selkies output/disconnect/resize lifecycle 改变了 compositor 状态导致 popup 失焦。

**不声明最终根因，不声明右键问题已修复。** DoD tasks 8.x 和 hard-limit tasks 7.2–7.6 保持 unchecked。

### Addendum: Trace3–5、/lsiopy 实验与决策边界更新（2026-05-16 补充）

本节记录 Puppeteer 对比完成后继续执行的 trace 与恢复实验所得完整证据。所有内容均为已验证事实，不含推测。不声明最终根因，不声明右键问题已修复。

#### Trace3：最新有效的完整 WSL-vs-Docker 对比（有效）

- Artifact：`/tmp/wsl-kde-rc-trace3-20260516-200113/`。
- WSL real-frame gate 通过；Docker reference 有效。
- DOM 事件形态相同（两侧均为单次 button 2 序列，无 blur/visibilitychange）。
- WSL：before→during-held AE `211`，during-held→after AE `707936`。
- Docker：before→during-held AE `794826`，during-held→after AE `0`。
- **边界**：Trace3 证实了有效的 below-DOM runtime divergence，不是最终根因或修复。

#### Trace4：Docker reference 因 Chrome 端口冲突导致无效

- Artifact：`/tmp/wsl-kde-rc-trace4-20260516-202404/`。
- WSL 样本有效。
- Docker host URL `33991` 返回空白页（`colors=1`，`Content-Length:0`），reference 无效。
- 根因验证：Windows Chrome 持有 `--remote-debugging-port=33991` 导致本地端口被占，不是 Webtop runtime 故障。
- Docker reference 已在 `/tmp/docker-ref-readiness-20260516-204016/` 恢复：bridge publish `0.0.0.0:33991->3000/tcp`，host body 762 bytes，real-frame smoke `1280x800 colors=27761 mean=0.487597 filesize=576017B`。
- **边界**：Trace4 整体无效，不得作为对比证据使用。

#### Trace5：WSL 样本因 KWin/Plasma 崩溃无效，已恢复

- Artifact：`/tmp/wsl-kde-rc-trace5-20260516-205914/`。
- WSL gate 失败：`1262x704 colors=88 mean=0.0943213 filesize=4902B`（近黑屏）。
- 进程/日志证据：Selkies/nginx 存活，但 KWin/Plasma/Xwayland 已死；日志含 `Wayland connection broke`、`kwin-xwayland.py ... Aborted`、`The Wayland connection broke. Did the Wayland compositor die?`。
- 通过已有的 `/tmp/wsl-kde-webtop/restart.sh` 恢复，未修改 repo/OpenSpec/runtime 任何脚本。
- 恢复后 real-frame smoke：`/tmp/wsl-kde-webtop/browser-smoke-trace5-recovery/frame.png`，`1262x704 colors=36675 mean=0.345487 filesize=495761B`。
- **边界**：Trace5 WSL 样本无效；KWin/Plasma 自发崩溃本身是 runtime 不稳定性证据。

#### /lsiopy 闭包移植实验：准备态失败，已回滚（2026-05-16）

- Artifact：`/tmp/wsl-kde-lsiopy-experiment-20260516-211137/`。
- 范围：将 Docker `/lsiopy` 复制到 `/tmp/wsl-kde-webtop/oracle-lsiopy`；仅修改 `/tmp/wsl-kde-webtop/start.sh`（disposable），unset `PYTHONPATH`，使用 oracle-lsiopy PATH，启动 `/tmp/wsl-kde-webtop/oracle-lsiopy/bin/python3 /tmp/wsl-kde-webtop/oracle-lsiopy/bin/selkies --addr=localhost --mode=websockets --port=8082`。
- 保留拓扑/env：`PIXELFLUX_WAYLAND=true`、`WAYLAND_DISPLAY=wayland-1`、`XDG_RUNTIME_DIR=/tmp/wsl-kde-webtop/xdg-runtime`、`DISPLAY=:1`、KWin/Plasma 拓扑不变。
- import probe 从 oracle-lsiopy 路径成功。
- mutation readiness 失败：端口 3200/8082 无响应，Wayland socket/X1 不存在，Selkies 日志为空，startwm/KWin/Plasma 出现失败行。
- 未运行右键 mini-check；实验对右键行为结论无效。
- 回滚恢复 `start.sh`（`diff_vs_baseline.returncode=0`）；real-frame readiness 恢复：`1262x704 colors=36663 mean=0.345483 filesize=495285B`。
- **边界**：直接 `/lsiopy` 替换在当前 WSL 拓扑下不是可行的准备态修复路径。

#### 更新后的决策边界（候选项，不含最终结论）

- 不重复执行 trace 到 WSL 再次崩溃；runtime 不稳定性本身已是可观测证据。
- 直接 `/lsiopy` 替换不是有效的 ready-state 修复路径。
- 下一步候选应聚焦于单变量实验，且与观测失败有更强耦合，例如：KWin/Plasma/session supervision 稳定性、Docker `/defaults`/s6 风格 service lifecycle 闭包、或 PulseAudio/null sink 闭包；不应是右键 monkey patch。
- 所有候选项须标注为候选，不声明为结论。DoD tasks 8.x 与 hard-limit tasks 7.2–7.6 保持 unchecked。

### Addendum: reusable trace harness 与 guest probes（2026-05-16 补充）

本节记录将临时 Puppeteer/CDP trace 固化为可复用 `/tmp` harness 后的验证结果。该工作只写入 `/tmp/wsl-kde-trace-harness` 诊断资产，不修改产品代码、runtime 配置或 Docker image。

#### Harness 资产与验证

- Harness：`/tmp/wsl-kde-trace-harness/run-trace.mjs`。
- 最新有效运行：`/tmp/wsl-kde-trace-harness/run-20260516-142300/`。
- 校验：`lsp_diagnostics /tmp/wsl-kde-trace-harness/run-trace.mjs` 返回 `No diagnostics found`；`node --check /tmp/wsl-kde-trace-harness/run-trace.mjs` 无输出，表示语法通过。
- Manual QA：执行 `bun /tmp/wsl-kde-trace-harness/run-trace.mjs` 退出码为 0，并产出 `report.md`、双目标截图、DOM events、console logs、guest probes、ImageMagick AE diff。

#### Harness 覆盖范围

- 使用 Windows Chrome 可执行文件 `/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe`，通过 Puppeteer 启动独立 profile。
- 对 WSL `http://127.0.0.1:3200` 与 Docker reference `http://127.0.0.1:33991` 执行同一套 stable-client right-click 序列。
- 两侧均执行 real-frame gate：HTTP probe、setup screenshot stats、DOM canvas/input 检查。
- 采集 before / during-held / after screenshots，并计算 before→during-held、during-held→after、before→after 的 AE diff。
- WSL guest probes 覆盖进程、Wayland/X11 socket、端口、`qdbus6`、KWin supportInformation、Selkies/KWin/Plasma/startwm/nginx logs。
- Docker guest probes 覆盖容器进程、Wayland/X11 socket、container logs、DBus socket 枚举。

#### 本次有效运行结果

- WSL readiness 通过：`width=1262 height=704 colors=93646 mean=0.348609 filesize=575957B`，title `Selkies`，`canvas=2`，`overlayInput=true`，`videoCanvas=true`。
- Docker readiness 通过：`width=1262 height=704 colors=66622 mean=0.491116 filesize=609206B`，title `Ubuntu KDE`，`canvas=2`，`overlayInput=true`，`videoCanvas=true`。
- DOM 事件形态同形：两侧均为 `pointerdown`/`mousedown`（button 2, buttons 2）→ hold → `pointerup`/`mouseup`/`auxclick`/`contextmenu`（buttons 0），target 为 `INPUT`，visibility 为 `visible`。
- WSL pixel diff：before→during-held AE `34212 (0.0385076)`，during-held→after AE `1752 (0.00197085)`，before→after AE `33581 (0.0377962)`。
- Docker pixel diff：before→during-held AE `711886 (0.801268)`，during-held→after AE `0`，before→after AE `711886 (0.801268)`。
- WSL during-held probes 显示 KWin/Plasma/Xwayland/Selkies/nginx 均存活；因此本次样本不是 trace5 的 dark/static frame，也不是 KWin/Plasma 已死样本。
- WSL KWin log 仍包含历史 `Wayland connection broke` 行，但 during-held 进程 probe 同时显示当前 KWin PID `43636`、Plasma PID `43667`、Xwayland PID `43676` 存活；该历史日志行不能单独解释本次 during-held 差分。

#### 更新后的边界

- reusable harness 已将 browser-side 对照、real-frame gate 与 guest probes 固化，后续实验应复用该 harness，而不是继续手写一次性 Puppeteer 脚本。
- 本次有效运行继续支持 browser DOM 层以下的 runtime divergence：Docker 在 held-button window 出现大面积变化并保持，WSL 在同形 DOM 事件下只出现小幅变化。
- 该结果仍不声明最终 root cause 或修复；下一步仍需单变量、source-faithful runtime closure 实验定位 guest-side 分叉点。

### Addendum: supervision 实验失败与 `DISPLAY=unix/:1` readiness 修复（2026-05-16 补充）

本节记录 reusable harness 完成后的第一个 runtime closure 实验，以及随后定位到的 WSL-specific readiness blocker。所有 runtime 改动均发生在 disposable `/tmp/wsl-kde-webtop`，不涉及产品代码或 Docker image。

#### KWin/Plasma supervisor-loop 实验（失败并回滚）

- 实验目标：模拟 Docker `svc-de` longrun 语义，在 WSL `startwm_wayland.sh` 中为 KWin/Plasma session 加 supervisor loop，避免 KWin/Plasma 死亡后 Selkies/nginx 继续输出 dark/static frame。
- 参考事实：Docker `/etc/s6-overlay/s6-rc.d/svc-de/type` 为 `longrun`；Wayland mode 中 `svc-de/run` 等待 `wayland-1` 后执行 `/defaults/startwm_wayland.sh`，等待 desktop 进程，随后以失败退出交给 s6 重启。
- 实验范围：只临时修改 `/tmp/wsl-kde-webtop/startwm_wayland.sh`；保留 KWin command、Plasma command、Wayland topology 与 Selkies/nginx env；备份 checksum `719e9d536f6e4c9da3a1028312426d16d1a6ea85f95ab5e525fa2393e46b389f`。
- 实验结果：readiness 未通过，`8082` 未 listening，Selkies log 停在 `[Wayland] Socket listening on: "wayland-1"`。未运行 post-experiment right-click trace。
- 回滚：`startwm_wayland.sh` 已恢复到 baseline checksum `719e9d536f6e4c9da3a1028312426d16d1a6ea85f95ab5e525fa2393e46b389f`。
- 回滚后发现：supervisor 实验的 `bash -lc ... SUPERVISOR_LOG=... while true` 进程仍残留，继续启动第二套 KWin/Plasma/Xwayland，造成 `wayland-0.lock` / `wayland-1.lock` contention 与 `wayland-2` fallback。该残留解释了回滚后 dark/static frame 与 duplicate compositor 现象。

#### `DISPLAY=:1` 在 WSL 中触发 X11 TCP timeout（readiness blocker）

- 证据：回滚清理后，Selkies 进程仍卡在 `8082` bind 前；`ss -apn` 显示 Selkies python 对 `127.0.0.1:6001` 处于 `SYN-SENT`。
- 线程状态：Selkies main thread `wait_woken`，另一个 thread `do_epoll_wait`；`strace` attach 因 ptrace 权限失败。
- 本机连接测试：WSL 内 `127.0.0.1:6000/6001/6002/5999` 均 timeout，而 Docker reference 内 `127.0.0.1:6001` 立即 `ConnectionRefusedError`。
- 路由证据：WSL `ip route get 127.0.0.1` 返回 `127.0.0.1 via 169.254.73.152 dev loopback0 table 127 src 127.0.0.1`，未监听 TCP loopback 端口会 timeout，而非快速拒绝。
- Source path：Selkies `input_handler.py` 在初始化时调用 `display.Display()`；在 `DISPLAY=:1` 下 Xlib 尝试连接 TCP `127.0.0.1:6001`，从而阻塞 Selkies 后续 `Data WebSocket Server listening on port 8082`。

#### `DISPLAY=unix/:1` 单变量恢复实验（readiness 修复，不修复右键）

- 临时改动：`/tmp/wsl-kde-webtop/start.sh` 中 `export DISPLAY=:1` 改为 `export DISPLAY=unix/:1`，只影响 WSL runtime 内 Xlib display transport，保留 `kwin-xwayland.py` 的 `--xwayland-display=:1` 与 `/tmp/.X11-unix/X1` topology。
- 结果：清理残留 supervisor/KWin/Plasma 后重启，full readiness 通过：`3200` 与 `8082` listening，KWin/Plasma/Xwayland/Selkies/nginx 存活，`wayland-0`、`wayland-1`、`X1` 存在，Selkies log 出现 `Data WebSocket Server listening on port 8082` 与 `SUCCESS: Capture started for 'primary'`。
- 这是 source-faithful readiness 修复候选：避免 WSL 异常 TCP loopback 路径，强制 Xlib 使用 Unix socket `/tmp/.X11-unix/X1`。
- Post-fix harness：`/tmp/wsl-kde-trace-harness/run-20260516-144809/`。
- Post-fix WSL readiness：`width=1262 height=704 colors=93692 mean=0.348622 filesize=576007B`，title `Selkies`，`canvas=2`，`overlayInput=true`，`videoCanvas=true`。
- Post-fix Docker readiness：`width=1262 height=704 colors=69231 mean=0.519381 filesize=597467B`，title `Ubuntu KDE`，`canvas=2`，`overlayInput=true`，`videoCanvas=true`。
- Post-fix DOM 事件仍同形，WSL/Docker 均为 single right-button sequence，visibility `visible`，target `INPUT`。
- Post-fix diff：WSL before→during-held AE `532 (0.000598797)`，during-held→after AE `1752 (0.00197085)`，before→after AE `2283 (0.00256965)`；Docker before→during-held AE `712218 (0.801642)`，during-held→after AE `13 (1.35067e-05)`，before→after AE `712222 (0.801646)`。
- 结论边界：`DISPLAY=unix/:1` 修复的是 WSL readiness/8082 bind blocker，不修复 right-click held-window behavior；post-fix WSL held-window 变化仍远小于 Docker。

#### 更新后的下一步边界

- 已排除：直接 `/lsiopy` 替换、KWin/Plasma supervisor loop、`DISPLAY=unix/:1` 作为 right-click 行为修复。
- 已保留：`DISPLAY=unix/:1` 可作为 WSL runtime readiness 修复候选，因为它解决 Selkies 8082 bind 前 Xlib TCP timeout。
- 下一个单变量候选应转向仍未闭合的 Docker-vs-WSL runtime closure，例如 PulseAudio/null sink closure 或更精确的 Docker `/defaults` startup sequencing；仍不得使用 right-click monkey patch。

### Addendum: PulseAudio/null sink closure 实验（2026-05-16 补充）

本节记录 `DISPLAY=unix/:1` readiness 修复之后执行的 PulseAudio/null sink 单变量实验。所有 runtime 改动均为可回滚的 WSL user-session audio module 与一次性环境变量；未修改产品代码、Docker image、Selkies/KDE/KWin source，也未使用 right-click monkey patch。

#### Docker reference 与 WSL audio closure 差异（已验证）

- Docker reference `webtop-kde-rc-ref` 中存在 `/usr/bin/pulseaudio`，服务进程为 `/usr/bin/pulseaudio --log-level=0 --log-target=stderr --exit-idle-time=-1`。
- Docker `svc-selkies/run` 在启动 Selkies 前执行两次 `pactl load-module module-null-sink`，创建 sink `output` 与 `input`；对应 sources 为 `output.monitor` 与 `input.monitor`。
- Docker `PULSE_RUNTIME_PATH=/defaults pactl list short sinks/sources` 验证：`output`、`input`、`output.monitor`、`input.monitor` 均存在。
- WSL 中无 `pulseaudio` binary；存在 `pipewire`、`pipewire-pulse` 与 `pactl`。默认 PulseAudio server 为 `/run/user/1000/pulse/native`，默认 sink/source 为 `RDPSink` 与 `RDPSource`。
- WSL baseline `pactl list short sinks/sources` 仅有 `RDPSink`、`RDPSink.monitor`、`RDPSource`，无 `output`、`input`、`output.monitor`、`input.monitor`。
- WSL baseline Selkies 继承 `XDG_RUNTIME_DIR=/tmp/wsl-kde-webtop/xdg-runtime`；在该环境下 `pactl info` 返回 `Connection refused`，而显式 `pactl --server=unix:/run/user/1000/pulse/native info` 成功。该事实解释了 Selkies log 中 `Initial PulseAudio connection failed` 与 `pa_simple_new() failed: Connection refused ('output.monitor')` 的来源。

#### Null sink only 实验（音频 sink 存在但 Selkies 仍连不上 server）

- Artifact：`/tmp/wsl-kde-pulseaudio-experiment-20260516-225648/`。
- 操作：对当前 WSL `pipewire-pulse` server 执行 `pactl load-module module-null-sink sink_name=output sink_properties=device.description=output` 与 `sink_name=input ...`，记录 module id `22`、`23`。
- 验证：`pactl list short sinks/sources` 出现 `output`、`input`、`output.monitor`、`input.monitor`。
- 重启 WSL runtime 后 readiness 通过，`3200` 与 `8082` listening。
- Harness：`/tmp/wsl-kde-trace-harness/run-20260516-145705/`。
- Harness diff：WSL before→during-held AE `33706 (0.0379381)`，during-held→after AE `34252 (0.0385526)`，before→after AE `2294 (0.00258203)`；Docker before→during-held AE `711953 (0.801343)`，during-held→after AE `13 (1.35067e-05)`，before→after AE `711957 (0.801348)`。
- Selkies log 仍出现 `Initial PulseAudio connection failed` 与 `pa_simple_new() failed: Connection refused ('output.monitor')`。
- 结论边界：只创建 null sinks 不足以闭合 WSL Selkies audio path，因为 Selkies 仍未连接到正确 PulseAudio server；该实验不修复 right-click held-window 行为。
- 回滚：已卸载 module `22`、`23`，WSL sinks/sources 恢复为 `RDPSink`、`RDPSink.monitor`、`RDPSource`。

#### `PULSE_SERVER` + null sinks 组合实验（音频闭合成功，但右键仍未修复）

- Artifact：`/tmp/wsl-kde-pulse-server-null-experiment-20260516-225853/`。
- 操作：重新加载 `output` / `input` null sinks，module id `24`、`25`；用一次性环境变量 `PULSE_SERVER=unix:/run/user/1000/pulse/native` 调用 `/tmp/wsl-kde-webtop/restart.sh`。
- 实际 Selkies 进程环境经 pidfile 验证：`PULSE_SERVER=unix:/run/user/1000/pulse/native` 生效，`XDG_RUNTIME_DIR=/tmp/wsl-kde-webtop/xdg-runtime` 保持不变，`DISPLAY=unix/:1`、`WAYLAND_DISPLAY=wayland-1` 保持不变；Wayland topology 未漂移。
- Readiness：`3200` 与 `8082` 在 2 秒内恢复，Selkies log 出现 `Data WebSocket Server listening on port 8082`。
- Audio closure 验证：Selkies log 出现 `PulseAudio connection established`、`Connected to PulseAudio`、`Opus encoder created`、`output.monitor, Rate: 48000, Channels: 2`、`First non-silent audio chunk detected! Encoding...`；未再出现该次运行中的 `pa_simple_new() failed: Connection refused ('output.monitor')`。
- Harness：`/tmp/wsl-kde-trace-harness/run-20260516-145919/`。
- Harness readiness：WSL `width=1262 height=704 colors=93574 mean=0.348645 filesize=575720B`，Docker `width=1262 height=704 colors=69203 mean=0.519388 filesize=597420B`，两侧均通过 real-frame gate。
- Harness diff：WSL before→during-held AE `252 (0.000282515)`，during-held→after AE `2032 (0.00228713)`，before→after AE `2283 (0.00256965)`；Docker before→during-held AE `712084 (0.801491)`，during-held→after AE `0`，before→after AE `712084 (0.801491)`。
- 结论边界：`PULSE_SERVER` + null sinks 成功闭合 WSL audio path，但不修复 right-click held-window behavior；WSL held-window 变化仍远小于 Docker reference。
- 回滚：已卸载 module `24`、`25` 并用无 `PULSE_SERVER` 的 baseline `/tmp/wsl-kde-webtop/restart.sh` 重启；pidfile 精确验证当前 Selkies env 无 `PULSE_SERVER`，`XDG_RUNTIME_DIR=/tmp/wsl-kde-webtop/xdg-runtime`，`DISPLAY=unix/:1`，`WAYLAND_DISPLAY=wayland-1`。

#### 更新后的下一步边界

- 已排除：PulseAudio/null sink closure 作为 right-click 行为修复。
- 已保留：`PULSE_SERVER=unix:/run/user/1000/pulse/native` + Docker-style `output`/`input` null sinks 可作为 audio closure 修复候选，但它不是 right-click blocker 的修复。
- 下一步应转向更接近 popup/capture timing 的 guest-side boundary，例如 KWin/Plasma popup lifecycle、Wayland pointer grab/focus、damage/capture timing 或 Docker `/defaults` startup sequencing 的更小闭包；仍不得使用 right-click monkey patch。

### right-click popup temporary mitigation via Selkies clipboard disable（2026-05-16 补充）

本节记录 right-click popup blocker 的当前临时缓解方案。所有行为改变均发生在 disposable WSL runtime `/tmp/wsl-kde-webtop`；未修改 buntoolbox product code、Docker image、Selkies/KDE/KWin source，也未使用 right-click monkey patch。该方案不是 final source-faithful runtime decision；clipboard sync 后续仍需单独设计。

#### 前置事实

- 后台与直接源码检索定位到 pixelflux/Smithay popup-grab 路径：`linuxserver/pixelflux` 的 `pixelflux_wayland/src/wayland/frontend.rs` 中 `new_popup` 调用 `self.popups.track_popup(PopupKind::Xdg(surface.clone()))`，失败时打印 `Failed to track popup: ...`；Smithay `PopupPointerGrab::button()` 会在 focus client 与 grabbed popup client 不一致时 dismiss popup。
- Docker reference 和 WSL runtime 的 pixelflux binary hash 相同：`pixelflux_wayland.cpython-314-x86_64-linux-gnu.so` 为 `190de91a70eb3cd64ff98d9bf778b187a0f4df497efb392281442157f75176f4`；`screen_capture_module.so` 为 `f266aca5e9354175f366f007bc812a46b82ef45ee2573131cd11f9e26016304c`。
- Docker reference 也设置 `PIXELFLUX_WAYLAND=true`，因此“Docker 正常是因为走 X11 backend”被当前证据排除。
- Docker reference 的 Wayland socket/runtime owner 为 `abc:abc`、`XDG_RUNTIME_DIR=/config/.XDG`；WSL runtime owner 为 `cpf:cpf`、`XDG_RUNTIME_DIR=/tmp/wsl-kde-webtop/xdg-runtime`。该差异被记录，但不是本次直接修复点。

#### Debug runtime evidence

- Debug 启动方式：使用 `SELKIES_DEBUG=true WAYLAND_DEBUG=1 RUST_BACKTRACE=1` 重启 WSL runtime，并运行 reusable harness `/tmp/wsl-kde-trace-harness/run-trace.mjs`。
- Artifact：`/tmp/wsl-kde-trace-harness/run-20260516-233115-debug-popup/`。
- Harness readiness：WSL 与 Docker real-frame gate 均通过。WSL `width=1262 height=704 colors=93659 mean=0.348606`；Docker `width=1262 height=704 colors=66994 mean=0.490689`。
- Harness diff：WSL before→during-held AE `2294 (0.00258203)`，during-held→after AE `11 (1.23811e-05)`，before→after AE `2283 (0.00256965)`；Docker before→during-held AE `711883 (0.801266)`，during-held→after AE `13 (1.35067e-05)`，before→after AE `711879 (0.801261)`。
- WSL protocol sequence in `/tmp/wsl-kde-webtop/logs/kwin.log` and `/tmp/wsl-kde-webtop/logs/plasmashell.log`:
  - right-button press：`wl_pointer#24.button(..., 273, 1)` at protocol time around `109361`。
  - popup create/grab：`xdg_surface#140.get_popup(new id xdg_popup#142, nil, xdg_positioner#141)` and `xdg_popup#142.grab(wl_seat#9, 9223)` around `109373`。
  - popup configured and mapped：`xdg_popup#142.configure(420, 330, 337, 192)` and `wl_surface#99.commit()`。
  - before right-button release, `wl-clipboard` / `wl-paste` appears as a 1x1 toplevel: `xdg_toplevel#14.set_title("wl-clipboard")`, `org_kde_plasma_window#137.app_id_changed("wl-paste")`, `geometry(630, 331, 1, 1)`。
  - keyboard focus leaves popup surface: `wl_keyboard#29.leave(..., wl_surface#99)`。
  - popup is dismissed before release: `xdg_popup#142.popup_done()` around `109687` / `109689`。
  - right-button release occurs later in Selkies log: `wl_pointer#24.button(..., 273, 0)` around `110774`。
- Interpretation: the WSL popup is not being dismissed by the ordinary mouse release; it is dismissed during the hold window after `wl-clipboard`/`wl-paste` helper activity steals focus from the popup surface.

#### Single-variable mitigation and env-name correction

- Single changed variable: restart the same WSL runtime with `SELKIES_ENABLE_CLIPBOARD=false` while preserving `PIXELFLUX_WAYLAND=true`, `WAYLAND_DISPLAY=wayland-1`, `DISPLAY=unix/:1`, `XDG_RUNTIME_DIR=/tmp/wsl-kde-webtop/xdg-runtime`, KWin on `wayland-1`, and Plasma on `wayland-0`。
- User-observed verification during the single-variable run: “aha, i saw it” and “right click menu did not disapear this time”。
- Artifact：`/tmp/wsl-kde-trace-harness/run-20260516-233439-clipboard-off/`。
- Harness readiness：WSL `width=1262 height=704 colors=93720 mean=0.348744`；Docker `width=1262 height=704 colors=68717 mean=0.530704`；both passed real-frame gate。
- Harness diff after disabling clipboard: WSL before→during-held AE `105680 (0.118948)`，during-held→after AE `11 (1.23811e-05)`，before→after AE `105691 (0.11896)`；Docker before→during-held AE `669427 (0.753478)`，during-held→after AE `0`，before→after AE `669427 (0.753478)`。
- Protocol evidence after disabling clipboard: during-held WSL Selkies probe contains right-button press `wl_pointer#24.button(..., 273, 1)`; after probe contains release `wl_pointer#24.button(..., 273, 0)`。The during-held probes no longer show the earlier popup-specific `xdg_popup.popup_done()` sequence before release.
- Env-name correction: later source verification showed WebSocket mode reads `settings.clipboard_enabled` from the `clipboard_enabled` definition in `settings.py`, whose standard env var is `SELKIES_CLIPBOARD_ENABLED`。`SELKIES_ENABLE_CLIPBOARD` is a distinct WebRTC-mode setting (`enable_clipboard`) and did not disable the WebSocket clipboard monitor; the failed final run with only `SELKIES_ENABLE_CLIPBOARD=false` still logged `Clipboard monitor running` and still showed `wl-clipboard` / `wl-paste` focus activity。
- Correct runtime fixed point: `/tmp/wsl-kde-webtop/start.sh` now exports `SELKIES_CLIPBOARD_ENABLED=false` before starting Selkies。
- Correct-variable revalidation: restarted through `/tmp/wsl-kde-webtop/restart.sh`; listeners existed on `127.0.0.1:3200` and `0.0.0.0:8082`; the Selkies process environment contained `SELKIES_CLIPBOARD_ENABLED=false`; Selkies log showed `INFO:webrtc_input:Skipping outbound clipboard service.` rather than `Clipboard monitor running`.
- Final harness after correct-variable restart: `/tmp/wsl-kde-trace-harness/run-20260516-234014-clipboard-enabled-false-final/`.
- Final harness readiness: WSL `width=1262 height=704 colors=95150 mean=0.34872 filesize=553113B`; Docker `width=1262 height=704 colors=71670 mean=0.550236 filesize=590847B`; both passed real-frame gate.
- Final harness diff: WSL before→during-held AE `714197 (0.803869)`，during-held→after AE `13 (1.35067e-05)`，before→after AE `714194 (0.803866)`；Docker before→during-held AE `668355 (0.752271)`，during-held→after AE `0`，before→after AE `668355 (0.752271)`。This puts WSL held-window popup behavior in the same large-change/stable-held class as Docker reference.
- Rollback: remove `SELKIES_CLIPBOARD_ENABLED=false` or set `SELKIES_CLIPBOARD_ENABLED=true` in `/tmp/wsl-kde-webtop/start.sh` and run `/tmp/wsl-kde-webtop/restart.sh`。

#### Boundary

- This is not a final source-faithful runtime decision. It is the current temporary accepted mitigation for the WSL-specific interaction bug: Selkies clipboard forwarding is disabled because clipboard helper windows are the observed popup-dismiss trigger in WSL native runtime, and the correct-variable revalidation restored right-click held-window popup behavior to the same class as Docker reference.
- Clipboard forwarding remains a degraded feature in the WSL mimic. User temporary decision on 2026-05-16: accept `SELKIES_CLIPBOARD_ENABLED=false` for now to keep KDE popup/menu behavior stable. This is an explicit temporary accepted degraded decision, not a claim that clipboard sync is fixed and not a proven WSL hard limit. If full clipboard support is required later, it needs a separate source-faithful design that prevents `wl-paste`/`wl-copy` helper windows from stealing focus during popup grabs.


### persistent WSL install root（2026-05-16 补充）

本节记录用户要求“不要继续把整个 WSL KDE Webtop 放在 `/tmp`，避免 reboot 后丢失”后的最小持久化迁移。迁移目标不是把 runtime 产品化进 buntoolbox image；它只把当前 WSL host 上已经调通的 WSL-native mimic 保存到用户级持久目录。

#### 持久化边界

- Persistent install root：`/home/cpf/.local/share/wsl-kde-webtop`。
- User command symlinks：
  - `/home/cpf/.local/bin/wsl-kde-webtop-start` → `~/.local/share/wsl-kde-webtop/start.sh`
  - `/home/cpf/.local/bin/wsl-kde-webtop-stop` → `~/.local/share/wsl-kde-webtop/stop.sh`
  - `/home/cpf/.local/bin/wsl-kde-webtop-restart` → `~/.local/share/wsl-kde-webtop/restart.sh`
  - `/home/cpf/.local/bin/wsl-kde-webtop-status` → `~/.local/share/wsl-kde-webtop/status.sh`
- Persisted assets copied from the previously working runtime:
  - `selkies-lsio-src/` from `/tmp/selkies-lsio-src/`
  - `selkies-lsio-venv/` from `/tmp/selkies-lsio-venv/`
  - `selkies-dashboard/` from `/tmp/wsl-kde-webtop/selkies-dashboard/`
  - `kwin-xwayland.py`
  - lifecycle scripts and nginx config
- Regenerated runtime root remains `/tmp/wsl-kde-webtop` because it contains Unix sockets, PID files, and logs:
  - `xdg-runtime/wayland-0`, `xdg-runtime/wayland-1`
  - `/tmp/.X11-unix/X1`
  - `logs/`
  - `pids/`

This split is intentional: the implementation survives WSL reboot via `~/.local/share`, while Wayland/XDG runtime state remains disposable and recreated on each start.

#### Current commands

```bash
# Start
wsl-kde-webtop-start

# Stop only this runtime's recorded PIDs and owned sockets
wsl-kde-webtop-stop

# Restart
wsl-kde-webtop-restart

# Status
wsl-kde-webtop-status

# Browser URL
http://127.0.0.1:3200
```

#### Verified state after migration

- Syntax check passed for:
  - `~/.local/share/wsl-kde-webtop/start.sh`
  - `~/.local/share/wsl-kde-webtop/startwm_wayland.sh`
  - `~/.local/share/wsl-kde-webtop/stop.sh`
  - `~/.local/share/wsl-kde-webtop/restart.sh`
  - `~/.local/share/wsl-kde-webtop/status.sh`
- `wsl-kde-webtop-restart` started the persistent entry successfully.
- `wsl-kde-webtop-status` showed:
  - nginx running with listener `127.0.0.1:3200`
  - Selkies running with listener `0.0.0.0:8082`
  - startwm running
- Selkies process environment after persistent restart contained:
  - `PYTHONPATH=/home/cpf/.local/share/wsl-kde-webtop/selkies-lsio-src/src`
  - `PATH=/home/cpf/.local/share/wsl-kde-webtop/selkies-lsio-venv/bin:...`
  - `XDG_RUNTIME_DIR=/tmp/wsl-kde-webtop/xdg-runtime`
  - `SELKIES_CLIPBOARD_ENABLED=false`
  - `PIXELFLUX_WAYLAND=true`
  - `WAYLAND_DISPLAY=wayland-1`
  - `DISPLAY=unix/:1`
- Persistent venv import check used `~/.local/share/wsl-kde-webtop/selkies-lsio-venv/bin/python -c 'import selkies, sys; ...'` and resolved `selkies` from the persistent venv site-packages.
- HTTP surface check returned `HTTP/1.1 200 OK` from `http://127.0.0.1:3200/` and served the Selkies dashboard root.
- Chrome DevTools browser check opened `http://127.0.0.1:3200/` and observed the Selkies page with title `Selkies` and visible sidebar heading `Ubuntu KDE`; screenshot was saved as `/tmp/wsl-kde-webtop/persistent-entry-browser-check.png`.
- Selkies log after persistent restart showed `Skipping outbound clipboard service.`, confirming the right-click popup fix variable is still active.

#### Known boundary

- The copied venv includes legacy activation/pip wrapper text that still mentions the original `/tmp/selkies-lsio-venv` path. The runtime does not use those wrappers; it directly invokes `~/.local/share/wsl-kde-webtop/selkies-lsio-venv/bin/python -m selkies`, which was verified by process environment and import check.
- `/tmp/wsl-kde-webtop` should still be expected to exist while the service is running. Losing it across reboot is acceptable; rerunning `wsl-kde-webtop-start` or `wsl-kde-webtop-restart` recreates the runtime directories and sockets.
- Clipboard forwarding remains disabled through `SELKIES_CLIPBOARD_ENABLED=false` as a temporary accepted mitigation for the WSL right-click popup/menu behavior. User temporary decision on 2026-05-16: accept this degraded clipboard state for now; this is not the final source-faithful runtime decision, and clipboard sync must be revisited as a separate future design rather than blocking current manual DoD validation.


### Current completion gate after user decisions（2026-05-16 补充）

User decisions applied after the persistent install work:

- Checklist cleanup: the stale `11.4` wording that said the right-click blocker was still pending is superseded. The current right-click popup/menu path is usable through the temporary accepted mitigation `SELKIES_CLIPBOARD_ENABLED=false`; this is explicitly not a final source-faithful runtime decision, and clipboard sync remains a future design item.
- Manual DoD: user reported on 2026-05-16: “8.x, eye ball ok”。Tasks 8.1-8.6 are therefore checked as user-reported Windows browser manual validation, not as a fresh agent-run browser test.
- Clipboard: user temporarily accepts clipboard forwarding as degraded. The current accepted state is `SELKIES_CLIPBOARD_ENABLED=false`, because the observed clipboard helper windows (`wl-clipboard` / `wl-paste`) steal focus during KDE popup grabs in WSL. This accepted state is temporary and explicit; it must not be described as clipboard sync fixed, and it must not be described as a proven WSL hard limit without a separate proof/design.

Current archive boundary:

- OpenSpec is valid and source evidence is recorded.
- OpenSpec current change is ready to call done after user-reported DoD 8.x validation. Clipboard forwarding remains a temporary accepted degraded decision and must not be described as final clipboard sync support.


### Hard-limit proof closure for current state（2026-05-16 补充）

This section closes tasks 7.2-7.6 for the current OpenSpec state without inventing a WSL hard-limit claim.

#### Audit result

- No current final difference is being claimed as a proven WSL hard limit.
- Historical WSL-only problems remain documented as evidence and debugging history, but they are not being used to justify a final hard-limit deviation at this checkpoint.
- The current clipboard state is explicitly separate: `SELKIES_CLIPBOARD_ENABLED=false` is a temporary accepted degraded decision, not a final source-faithful runtime decision and not a proven WSL hard limit.
- Final browser acceptance has now been recorded as user-reported manual DoD: “8.x, eye ball ok”。

#### Mapping to tasks 7.2-7.6

- 7.2 Native WSL attempted config: no active final hard-limit claim requires a native-attempt proof. Relevant native attempts for previous blockers are already recorded in the runtime evidence, pulse/audio experiments, right-click temporary mitigation, and persistent install sections.
- 7.3 Failing symptom: no active final hard-limit claim requires a new failing symptom record. Historical failing symptoms remain in the evidence sections and are not promoted to hard-limit conclusions.
- 7.4 Not a config gap: because no final hard-limit claim is asserted, there is no config-gap proof to close. Clipboard is explicitly not classified as a hard limit.
- 7.5 Chosen deviation: no hard-limit deviation is currently accepted. Clipboard-off is only a temporary accepted degraded decision that keeps popup/menu behavior usable while leaving clipboard sync for future design.
- 7.6 Reviewer sign-off: current sign-off is limited to wording discipline: the OpenSpec must not misuse WSL hard-limit language for the temporary clipboard decision. It is not sign-off that clipboard sync is solved, and it is not archive approval.

#### Current archive boundary

DoD 8.x has now been updated from the user's manual Windows browser validation: “8.x, eye ball ok”。At this checkpoint, the current change can be called done, with one explicit non-final boundary: clipboard forwarding is temporarily accepted as degraded via `SELKIES_CLIPBOARD_ENABLED=false` and remains future work if full clipboard sync is required.


### User-reported final DoD validation（2026-05-16 补充）

User reported: “8.x, eye ball ok”。This records user manual Windows browser validation for tasks 8.1-8.6.

Completion boundary:

- WSL KDE Webtop is accessible through the persisted entry at `http://127.0.0.1:3200`.
- User-reported visual/manual DoD is accepted for the current change.
- No current final difference is claimed as WSL hard limit.
- Clipboard forwarding remains disabled through `SELKIES_CLIPBOARD_ENABLED=false` as a temporary accepted degraded decision, not as final clipboard support.
