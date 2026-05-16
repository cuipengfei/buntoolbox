## Why

说明：本文档正文使用中文；`Why`、`What Changes`、`Capabilities`、`Impact` 等标题是 OpenSpec schema 识别用语，按工具约定保留英文。

目标只有一个：让**当前这台 WSL native 环境**能使用 KDE，并能从 Windows 浏览器打开完整 KDE desktop。

完成效果必须和 LinuxServer Webtop KDE **exactly same**：浏览器里看到完整 KDE Plasma desktop，使用 Webtop/Selkies 风格的 browser desktop 交互，而不是 WSLg 弹出的单个 Linux GUI 窗口，也不是“差不多像”。只有遇到 WSL native 环境的硬限制时，才允许有差异；差异必须明确说明。

本 change 不是 buntoolbox 产品化，不改任何项目代码；也**不使用 Docker、container、image、compose、Docker Desktop 作为 WSL native implementation 路径**。允许例外：Docker/Webtop container 可作为只读 reference oracle 采集上游 runtime 证据（不改变 WSL native 实现路径）。Webtop KDE 只是上游行为和体验模板，用来决定 WSL native 方案应该启动哪些服务、呈现什么浏览器界面、达到什么桌面效果。

本次修订把“Webtop KDE exactly same”绑定到可追溯的上游源码，而不是凭记忆或 trial-and-error 判断。当前研究基线为：`linuxserver/docker-webtop` 的 `ubuntu-kde` 分支 commit `45619c47324ef14a39485fa96269d5ed3ce4ce14`、`linuxserver/docker-baseimage-selkies` commit `93d956bfecbc511dbeb8dbece741ad361f2d9a6e`、`selkies-project/selkies` 的 `lsio` 分支 commit `aae6a4de653bb95da0a6b820f885fb6b30a5e35c`。后续若这些来源更新，必须先刷新 source inventory，再判断行为是否变化。

## What Changes

- 将 scope 明确限定为当前 WSL native host：在 WSL 内安装/配置/启动 KDE desktop、Selkies/browser streaming 所需服务和本地浏览器入口。
- 以 Webtop KDE `ubuntu-kde` 分支和 `baseimage-selkies` 源码作为行为合同：浏览器访问一个本机 URL，进入 Selkies dashboard/frontend，frontend 通过 `/websocket` 连接 backend session，backend 捕获 KDE Plasma desktop。
- 以源码中 KDE Wayland 路径为 primary mimic：`PIXELFLUX_WAYLAND=true`；`svc-xorg` 在 Wayland 模式 sleep；`svc-selkies` 运行 `selkies --addr=localhost --mode=websockets`；`svc-de` 等待 `$XDG_RUNTIME_DIR/wayland-1` 后运行 `startwm_wayland.sh`；该脚本通过 `kwin-xwayland.py` 启动 `kwin_wayland --no-lockscreen --xwayland --xwayland-fd`，再启动 `WAYLAND_DISPLAY=wayland-0 plasmashell`。
- 参考 Webtop KDE 的 KDE session 形态：KWin Wayland、Xwayland socket、Plasma Shell、Konsole/Dolphin、KDE env、KWin rules、DBus、PulseAudio/null-sink 或 WSL 等价能力。
- 必须采用 source-backed distribution-faithful reuse：优先复用或忠实移植上游 `startwm_wayland.sh`、`kwin-xwayland.py`、baseimage `default.conf`、`init-selkies-config`、`init-nginx`、`svc-selkies`、`svc-de`、Selkies frontend assets、Selkies backend handshake 和关键 env/defaults；不得用手写 proxy、手写 launcher、手写 frontend 或任意“功能相似”的替代物冒充 Webtop KDE distribution 行为。
- 禁止 handwritten proxy/launcher/frontend 作为默认路线：任何 local proxy、launcher、frontend、wrapper 或 adapter 都必须先证明它是 source-mapped minimal WSL adapter，并明确替代哪个 upstream source node；否则视为 anti-pattern。
- 禁止 arbitrary DISPLAY/env drift：`DISPLAY`、`WAYLAND_DISPLAY`、`XDG_RUNTIME_DIR`、`PIXELFLUX_WAYLAND`、`CUSTOM_WS_PORT`、`QT_QPA_PLATFORM`、`XDG_SESSION_TYPE`、`KDE_SESSION_VERSION` 等 display/session/Selkies/KDE env 必须先按 upstream source baseline 实现；任何不同都必须完成 hard-limit proof 并通过 reviewer sign-off。特别是 `DISPLAY=:20` 或其他非 upstream display 值不得作为默认实现继续存在。
- 禁止 omitted upstream script：如果某个上游脚本或脚本行为未被直接复用或忠实移植，必须列出 source node、branch/commit/path、遗漏原因、WSL native attempted config、failing symptom、chosen deviation、rollback 和 reviewer sign-off；不得静默省略 clipboard KWin rule、autostart bridge、UDisks service removal、applications.menu/kbuildsycoca、`dbus-run-session` shape、Xwayland socket setup 或 env/export 顺序。
- 禁止 looks-similar 验收：能看到 KDE、能看到 sidebar、能连上 WebSocket、或视觉上“差不多像 Webtop KDE”都不等于完成；完成必须是 browser-visible DoD 加上 source-backed distribution-faithful behavior，除非差异已经被证明为 WSL hard limit。
- 只在 WSL native hard limit 下允许差异；例如 systemd、Wayland、GPU、audio、certificate、browser API、network forwarding 的 WSL 限制。差异必须是被限制迫使的，不是便利性替代。
- Definition of Done 不要求额外证据文件：只要求 Windows 浏览器打开地址后看到并能使用 KDE desktop，且效果与 Webtop KDE exactly same，除非 WSL hard limit。
- 将执行方式设计成 mandatory MECE 并发：upstream source、WSL baseline、KDE session、Selkies/frontend、hard-limit verifier、critic/reviewer 必须作为互不重叠的只读 subagent slices 执行并由 main agent 集成；main-agent fallback 可用于辅助诊断，但不满足 MECE subagent requirement，除非用户显式放宽。任何 WSL host mutation、端口占用、service 启停、package install 必须由单一 executor 串行执行，main agent 负责 orchestration、review、集成和最终验收。
- 加入 source-first failure triage：任何空白页、黑屏、WebSocket 断连、KDE session crash、全屏不一致、音频/剪贴板/输入异常，必须先定位层级并回查 Webtop/Selkies 源码，再提出单一 hypothesis 和最小实验；禁止随机装包、随机改 env、随机换 display server/backend 或 ad hoc hot fix 叠 patch。
- 保留 architect 和 critic 审阅门禁，重点检查是否仍误入 Docker/container/image、buntoolbox 产品化、随机试错或“差不多像”的方向。

## Capabilities

### New Capabilities

- `wsl-webtop-kde-mimic`: 定义当前 WSL native 环境中提供 browser-accessible KDE desktop 的行为、硬限制差异边界和完成标准。

### Modified Capabilities

- 无。

## Impact

- 影响当前 WSL native 环境的本机配置和运行方式：KDE packages、display/session 服务、Selkies/browser streaming、上游 nginx/default.conf 语义的忠实复用或最小 WSL-local adapter、端口、systemd/user services、启动/停止脚本。
- 不影响、不修改、不发布任何 buntoolbox 项目产物。
- 不修改 Dockerfile、scripts、CI、README、image metadata、测试脚本或 release workflow。
- 不使用 Docker、container、image、compose 或 Docker Desktop 作为 WSL native implementation 路径；Docker/container 仅允许作为只读 reference oracle。
- OpenSpec amendment 阶段只允许修改 `openspec/changes/mimic-webtop-kde-wsl/**`；WSL host implementation 阶段的 runtime artifacts 必须是当前 WSL host-local，并在 rollback 中列出，不进入 buntoolbox product files。
- 本 proposal amendment 明确把当前已观察到的 handwritten proxy、handwritten launcher、`DISPLAY=:20` drift、遗漏 upstream script 内容和 ad hoc env drift 归类为 anti-pattern；后续 implementation plan 必须先修正或完成 hard-limit proof，不得继续把这些当作可接受默认状态。
- 不以 WSLg 单应用窗口、VNC/noVNC、xrdp/RDP 或纯终端页面作为成功替代。
- 完成标准：Windows 浏览器打开本机 URL，看到完整 KDE desktop；视觉和交互与 LinuxServer Webtop KDE exactly same，除非 WSL hard limit 被明确识别。
