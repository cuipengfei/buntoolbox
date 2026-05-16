## 0. Scope guard

说明：本文档正文使用中文；命令、路径、变量名、OpenSpec 术语保留英文。

- [x] 0.1 确认实现目标是：当前 WSL native 环境可从 Windows 浏览器打开完整 KDE desktop。
- [x] 0.2 确认禁止使用 Docker、container、image、compose、Docker Desktop；这些词若出现，只能作为禁止项或上游背景名的一部分。
- [x] 0.3 确认 implementation 阶段不得修改 buntoolbox 产品代码、Dockerfile、scripts、CI、README、image metadata、测试脚本或 release workflow。
- [x] 0.4 确认 OpenSpec amendment 阶段只允许修改 `openspec/changes/mimic-webtop-kde-wsl/**`。
- [x] 0.5 确认 DoD 不是证据文件，而是 Windows 浏览器实际打开并看到 KDE desktop，且与 Webtop KDE exactly same，除非 WSL hard limit。

## 1. Upstream source inventory / behavior extraction

目标：先知道 Webtop KDE 到底怎么工作，再做 WSL native mimic；禁止凭印象或随机试错。

- [x] 1.1 Clone 或刷新上游源码到 `/tmp`，记录 branch 和 commit：`linuxserver/docker-webtop` 的 `ubuntu-kde` 分支、`linuxserver/docker-baseimage-selkies`、`selkies-project/selkies` 的 `lsio` 分支。
- [x] 1.2 读取 Webtop KDE flavor：`Dockerfile`、`root/defaults/startwm_wayland.sh`、`root/kwin-xwayland.py`、`root/defaults/startwm.sh`、`root/defaults/autostart`。
- [x] 1.3 读取 baseimage-selkies runtime：`init-selkies-config`、`init-nginx`、`svc-selkies`、`svc-de`、`svc-xorg`、`svc-nginx`、`svc-pulseaudio`、`svc-dbus`、`svc-watchdog`、`default.conf`。
- [x] 1.4 读取 Selkies LSIO backend/frontend contract：settings/env parser、`selkies.py` websocket handler、dashboard/core websocket frontend、fullscreen/resize/canvas、encoder/frame handling。
- [x] 1.5 输出 source-backed baseline：Webtop KDE 进程拓扑、KDE session 启动顺序、Selkies frontend/backend handshake、nginx/proxy route、关键 env vars、restart/supervision behavior。
- [x] 1.6 每个 baseline claim 必须挂 source path + branch/commit；若 Context7/DeepWiki/网络资料与源码不一致，以源码为准并注明差异。

## 2. MECE parallel discovery plan

目标：最大化 subagent 并发，但让 main agent 做 orchestration、review 和冲突裁决。

- [x] 2.1 `A-upstream-source-mapper`（只读，可并行）：输出 Webtop KDE/baseimage/Selkies exact behavior baseline。
- [x] 2.2 `B-wsl-baseline-mapper`（只读，可并行）：检查当前 WSL systemd、kernel、display、Wayland/X11/Xwayland、DBus、PulseAudio/PipeWire、GPU/DRI、localhost/ports、已安装 packages。
- [x] 2.3 `C-kde-session-planner`（只读，可并行）：设计 WSL native KDE session launcher，对齐 `startwm_wayland.sh` 和 `kwin-xwayland.py`；标出 WSL-only 差异候选。
- [x] 2.4 `D-selkies-frontend-planner`（只读，可并行）：设计 Selkies backend/frontend/nginx 或等价 local proxy，对齐 `/websocket`、`CUSTOM_WS_PORT`、`MODE websockets`、encoder/frame/fullscreen contract。
- [x] 2.5 `E-hard-limit-verifier`（只读，可并行）：审查所有差异是否真是 WSL hard limit，防止把未配置、没尝试或实现困难伪装成 hard limit。
- [x] 2.6 `F-reviewer/critic`（只读，可并行）：检查 no Docker、no productization、source-first triage、DoD、MECE 边界。
- [x] 2.7 Main agent 必须 review 所有子代理输出，去重、纠错、合并冲突；不得把子代理推测直接当结论。
- [x] 2.8 `H-implementation-executor` 是唯一可执行 WSL host mutation 的 owner；A/B/C/D/E/F 全只读，不得执行 package install、service start/stop、kill、端口占用或 runtime file 写入。
- [x] 2.9 A/B/C/D/E/F 是 mandatory subagent slices；main-agent fallback 不满足 MECE requirement。任何 slice 因工具错误、高负载、上下文问题或其他原因失败时，implementation 必须保持 gated，直到该 slice 由 subagent 成功完成或用户显式放宽。

## 3. Webtop KDE 行为映射到 WSL native

- [x] 3.1 将上游 KDE Wayland primary path 映射为 WSL native 目标：`PIXELFLUX_WAYLAND=true` 语义、Selkies Wayland backend、`wayland-1`/`wayland-0` sockets、KWin Wayland、Xwayland socket、Plasma Shell。
- [x] 3.2 映射 `svc-selkies`：生产命令 `selkies --addr=localhost --mode=websockets`、`CUSTOM_WS_PORT`、encoder/framerate/manual resolution、audio/gamepad/clipboard env。
- [x] 3.3 映射 frontend/proxy：Webtop nginx static frontend、`/websocket` proxy、dashboard/sidebar、fullscreen/canvas behavior；WSL 必须优先忠实复用 upstream `default.conf` semantics 或最小 source-mapped adapter，不得用 handwritten proxy/frontend 冒充 Selkies contract。
- [x] 3.4 映射 `svc-de`：等待 Wayland socket 后运行 `startwm_wayland.sh`；WSL 等价 launcher 必须明确等待条件和失败日志。
- [x] 3.5 映射 KDE session：`kwin-xwayland.py` 创建 `/tmp/.X11-unix/X1` 并传 `--xwayland-fd`；`dbus-run-session`；`WAYLAND_DISPLAY=wayland-1` 启动 KWin；`WAYLAND_DISPLAY=wayland-0` 启动 `plasmashell`；关闭 KWin compositing/autolock；执行 `kbuildsycoca6`；设置 KDE env。
- [x] 3.6 标出必须 exactly same 的部分：浏览器入口、Selkies 左侧 sidebar、完整 desktop、KDE 视觉、窗口交互、panel/launcher、Konsole 或 Dolphin 可启动、浏览器占满可用空间。
- [x] 3.7 标出只有 WSL hard limit 才允许不同的部分：s6 supervisor 等价替代、Wayland/X11 socket 权限、PulseAudio/PipeWire、GPU/DRI、gamepad/input devices、certificate/browser API、network forwarding。

## 4. WSL native baseline

- [x] 4.1 检查当前 WSL 发行版、版本、kernel、systemd 状态、package manager、sudo 权限、当前用户和 runtime dirs。
- [x] 4.2 检查 Windows browser 到 WSL localhost 的访问路径和可用端口，确认目标端口不会与已有服务冲突。
- [x] 4.3 检查 display/session 能力：Wayland、X11、Xwayland、`/tmp/.X11-unix`、`XDG_RUNTIME_DIR`、DBus、PulseAudio/PipeWire、GPU/DRI。
- [x] 4.4 检查 KDE/Selkies 依赖包是否已安装或可安装，区分缺包、配置缺失和平台限制。
- [x] 4.5 明确 WSL hard limit candidate vs config gap；未尝试配置前不得归类为 hard limit。

## 5. WSL native implementation plan（执行前必须审阅）

说明：本节是 implementation plan，不在 OpenSpec explore 阶段直接执行。

- [x] 5.1 设计 WSL-local runtime 路径和 owner，例如 `/tmp/wsl-kde-webtop` 或用户确认的 WSL-local 目录；不得写入 buntoolbox product files。
- [x] 5.2 设计启动顺序，等价替代 s6：init/env → frontend/proxy → Selkies backend → Wayland socket wait → KDE session → supervisor/watchdog。
- [x] 5.3 设计停止/重启/清理顺序，避免 `pkill -f` 误杀当前 shell，避免残留端口、Wayland socket、X lock、dbus session。
- [x] 5.4 设计最小 host mutation 执行清单：packages、runtime files、ports、services；每一项必须有 rollback 或 disable 说明。
- [x] 5.5 设计 source-first debug loop：失败层级、对应 source 文件、单一 hypothesis、最小实验、回滚条件。
- [x] 5.6 建立 source-backed reuse matrix：每个 upstream node 对应 local reuse/port/adapt 决策，至少覆盖 `startwm_wayland.sh`、`kwin-xwayland.py`、`init-selkies-config`、`init-nginx`、`default.conf`、`svc-selkies`、`svc-de`、Selkies frontend assets、Selkies backend websocket contract。
- [x] 5.7 禁止 handwritten proxy/launcher/frontend：若出现任何 local proxy、launcher、frontend 或 wrapper，必须证明它是 source-mapped minimal adapter，不是手写替代；否则不得执行。
- [x] 5.8 建立 env/display drift matrix：列出 upstream expected、local planned、deviation reason、hard-limit proof status；覆盖 `DISPLAY=:1`、`/tmp/.X11-unix/X1`、`WAYLAND_DISPLAY=wayland-1/wayland-0`、`XDG_RUNTIME_DIR`、`PIXELFLUX_WAYLAND`、`CUSTOM_WS_PORT`、KDE/Qt env。
- [x] 5.9 任何 `DISPLAY=:20` 或其他非 upstream display 值必须先纠正为 upstream baseline；若不能纠正，必须完成 hard-limit proof template，不得作为默认实现继续。
- [x] 5.10 建立 omitted upstream script checklist：任何未复用/未忠实移植的 upstream script 或行为必须记录 source path、line/behavior、遗漏原因、替代节点、rollback 和 reviewer sign-off。
- [x] 5.11 MUST obtain architect review before execution；确认 implementation plan 是 pure WSL native、source-grounded、no Docker、no productization，并验证 reuse matrix 与 env/display drift matrix。
- [x] 5.12 MUST obtain critic review before execution；确认没有 handwritten proxy、handwritten launcher、arbitrary DISPLAY drift、ad hoc env drift、omitted upstream script、looks-similar completion、随机试错、替代链路冒充、hard limit 滥用或并发踩踏。

## 6. Source-first failure triage rules

- [x] 6.1 白屏/空白页：先查 frontend 静态资源和 proxy route；回查 `default.conf`、dashboard build/static path，不直接改 KDE。
- [x] 6.2 `Connection established. Waiting for server mode`：先查 backend 是否发送 `MODE websockets`，回查 Selkies websocket handler 和 frontend mode handler。
- [x] 6.3 WebSocket disconnected/502：先查 `/websocket` URL、nginx `CWS`、backend `CUSTOM_WS_PORT`、端口监听，不随机换 backend。
- [x] 6.4 黑屏但连接成功：先查 encoder/frame type/keyframe gate/capture started/KDE compositor output，不随机降分辨率或改 audio。
- [x] 6.5 KDE 闪现后退出：先查 `startwm_wayland.sh`、`kwin-xwayland.py`、`dbus-run-session`、KWin/plasmashell logs，不随机切 X11。
- [x] 6.6 全屏不占满或左右留白：先查 Selkies frontend fullscreen/resize/CSS scaling/manual resolution contract，不先改 KDE panel 或 browser CSS。
- [x] 6.7 audio/gamepad/clipboard 异常：先查 Webtop env、PulseAudio null sink、mknod/gamepad fallback、wl-clipboard KWin rule，不把非关键功能失败当作 desktop DoD 完成或失败的唯一依据。
- [x] 6.8 每次修复只允许一个 hypothesis 和一个最小实验；实验失败必须回到 source 和日志，不叠加第二个随机 patch。

## 7. Hard limit proof template

每个 WSL hard limit 差异都必须包含：

- [x] 7.1 Upstream expected behavior：对应 Webtop/baseimage/Selkies source path、branch、commit、行为描述。
- [x] 7.2 Native WSL attempted config：current hard-limit audit completed; no current final difference is being claimed as a proven WSL hard limit. Clipboard-off is tracked separately as a temporary accepted degraded decision, not as a hard-limit claim.
- [x] 7.3 Failing symptom：no active hard-limit claim remains to prove. Historical symptoms and logs are recorded in design.md; current unresolved final validation is DoD 8.x, owned by user manual browser testing.
- [x] 7.4 Not a config gap：not applicable to a proven hard-limit claim because no current final difference is classified as WSL hard limit. The known clipboard degradation is explicitly not classified as hard limit.
- [x] 7.5 Chosen deviation：no hard-limit deviation is currently accepted. The only accepted deviation is temporary clipboard forwarding disabled via `SELKIES_CLIPBOARD_ENABLED=false`; it preserves popup/menu usability but remains a future design item, not a final hard-limit replacement.
- [x] 7.6 Reviewer sign-off：main-agent audit records that WSL hard-limit wording is not being used for the temporary clipboard decision; no hard-limit claim is being closed or archived before user DoD 8.x validation.

## 8. DoD 验收

- [x] 8.1 从 Windows browser 打开 WSL 暴露的本机 URL。User-reported manual validation on 2026-05-16: “8.x, eye ball ok”。
- [x] 8.2 浏览器中看到完整 KDE Plasma desktop，而不是错误页、纯终端、单个 Linux GUI app、VNC/noVNC/xrdp/RDP 页面。User-reported manual validation: eye-ball ok。
- [x] 8.3 画面使用 Webtop/Selkies 左侧 sidebar，浏览器内容占满可用空间；不是右侧大圆按钮或非 Webtop frontend。User-reported manual validation: eye-ball ok。
- [x] 8.4 KDE 视觉和交互与 LinuxServer Webtop KDE 对齐到当前验收标准：browser desktop、窗口管理、panel/launcher、Konsole 或 Dolphin 可启动。User-reported manual validation: eye-ball ok。
- [x] 8.5 差异处理：当前唯一明确保留差异是 clipboard forwarding disabled；它按用户确认记录为 temporary accepted degraded decision，不作为 WSL hard limit，不作为 final fix。
- [x] 8.6 DoD 汇报边界：用户已报告 Windows browser eye-ball ok；当前无已声明 WSL hard limit，clipboard-off 是 temporary accepted degraded decision。

## 9. Cleanup / repeatability

- [x] 9.1 提供启动、停止、重启 WSL native KDE browser desktop 的命令或服务说明。
- [x] 9.2 提供 runtime artifacts 清单：路径、用途、owner、是否可删除。
- [x] 9.3 提供可选卸载/禁用说明，但不自动破坏用户 WSL 环境。
- [x] 9.4 `git diff` 在 OpenSpec amendment 阶段必须只显示 `openspec/changes/mimic-webtop-kde-wsl/**`；若出现 product code 路径，必须回滚。

## 10. 审阅门禁

- [x] 10.1 MUST obtain architect review before implementation；审阅 proposal/design/spec/tasks，重点检查是否 pure WSL native、no Docker、no buntoolbox 产品化、source-grounded。
- [x] 10.2 MUST obtain critic review before implementation；重点检查是否仍有“差不多像”、替代链路冒充、证据文件替代 DoD、WSL hard limit 滥用、随机试错或并发踩踏。
- [x] 10.3 根据 architect 和 critic 意见修订 artifacts；未完成这一步不得进入 implementation。
- [x] 10.4 Architect review MUST verify source-backed distribution-faithful reuse, reuse matrix, env/display drift matrix, and omitted upstream script checklist before any WSL host mutation。
- [x] 10.5 Critic review MUST explicitly check: no handwritten proxy, no handwritten launcher, no handwritten frontend, no arbitrary DISPLAY drift, no ad hoc env drift, no omitted upstream script, no looks-similar completion, and source-backed distribution-faithful reuse。

## 11. Decision recording (2026-05-16)

- [x] 11.1 Record in `design.md`: plasmashell to wayland-1 topology experiment is NOT the next source-faithful action; classified as non-source-faithful high-risk diagnostic candidate only; requires source-node evidence + WSL hard-limit proof + critic sign-off before it may be executed.
- [x] 11.2 Record in `design.md`: right-click context menu popup is an unresolved blocker with current evidence (geometry A/B still fails, no-move right-click still fails, `contextmenu.defaultPrevented=true` confirmed, no duplicate events from single physical right-click, no OUTSIDE_VIEWPORT in no-move sample).
- [x] 11.3 Record in `design.md`: runtime readiness is restored (nginx 3200, Selkies 8082, MODE websockets verified, KWin geometry 1378x909 scale 1.25, plasma layout and portal ping ok); WAYLAND_DEBUG diagnostics were applied and restored; current topology source-faithful.
- [x] 11.4 Record in `design.md`: right-click blocker currently has a working temporary mitigation via `SELKIES_CLIPBOARD_ENABLED=false`; this is a temporary accepted degraded decision, not a final source-faithful runtime decision. DoD tasks 8.x remain unchecked pending user manual browser validation, while clipboard sync stays open as a future design item rather than a hidden hard-limit claim.

## 12. Upstream behavior comparison evidence recording (2026-05-16)

- [x] 12.1 记录官方 LinuxServer Webtop KDE 文档：`ubuntu-kde` flavor 支持、访问地址 `https://yourhost:3001/`、端口 `CUSTOM_PORT=3000`、`CUSTOM_HTTPS_PORT=3001`、`CUSTOM_WS_PORT=8082`（default 8082）；baseimage-selkies README dev run command 使用 `ghcr.io/linuxserver/webtop:ubuntu-kde -p 3001:3001`。
- [x] 12.2 记录源码 commit inventory：`docker-webtop-ubuntu-kde` @ `45619c47324ef14a39485fa96269d5ed3ce4ce14`、`docker-baseimage-selkies` @ `93d956bfecbc511dbeb8dbece741ad361f2d9a6e`、`selkies-lsio` @ `aae6a4de653bb95da0a6b820f885fb6b30a5e35c`；upstream topology KWin on wayland-1、plasmashell on wayland-0。
- [x] 12.3 记录 Docker reference instance 现状：Docker Desktop 已通过 `sc.exe start com.docker.service` 恢复；`docker info` 成功，Server Version `29.4.3`，Images `9`；image `linuxserver/webtop:ubuntu-kde`（digest `sha256:79521b69ab04ae57dffef7e75afe2a61f0580981d633c9c7d01e3f929751cd3d`，ID `sha256:bd4f49c04603b27f2b61ea6439aa7064d620086029363c3a14e4f7cf29f1734c`）存在，`docker image inspect` 和 `docker history` 均成功；临时 reference container `webtop-kde-ref-snapshot` 已启动、runtime snapshot 采集完毕后通过 `docker rm -f webtop-kde-ref-snapshot` 移除；用户已确认 Docker reference container 主屏右键正常工作。该 reference-only 使用不改变禁止 Docker 作为 WSL native implementation 路径的约束。
- [x] 12.4 记录公开 issue 证据：`docker-baseimage-selkies#89`（second-screen 右键/背景不工作，reload/resize 有助）、`docker-webtop#251`（ubuntu-kde black screen/scaling/no input）、`docker-webtop#115`（分辨率建议），并注明各 issue 不能直接证明 main KDE 主屏右键行为。
- [x] 12.5 记录排除项：`/home/cpf/.config/plasma-org.kde.plasma.desktop-appletsrc` 含 `RightButton;NoModifier=org.kde.contextmenu`，KDE contextmenu action plugin 已配置，缺插件假设排除。
- [x] 12.6 记录 evidence gap 更新：upstream reference gap 已关闭（Docker reference container 已运行并经用户确认主屏右键正常）；remaining gap 收窄为 WSL mimic 与 Docker reference 的 runtime divergence：相同 upstream Selkies/KDE 在 Docker reference 中右键可用，但 WSL native runtime 右键仍立即消失，根因（Selkies input path vs KDE/Plasma compositor lifecycle）当前日志不能区分；`#89` second-screen fix 不可直接移植。
- [x] 12.7 记录维护者评论证据（GitHub API 已验证）：`docker-baseimage-selkies#89` thelamer 评论 stream reset = race condition， multi-monitor is a crap shoot，out-of-box bug unless sane max resolution（后续 linked #115）；`docker-webtop#251` Noble far more buggy than Bookworm for KDE，recommends debian-kde，modern kernel 6.6+ and DRI3 resolves plasmaqml crash；`docker-baseimage-selkies#115` set sane max resolution/manual resolution（`SELKIES_MANUAL_WIDTH/HEIGHT`、`MAX_RESOLUTION`）for DRI3/choppy issues，webtop creates 16k virtual screen；`docker-webtop#385` KWin does not support wlroots virtual-keyboard protocol，only running portions of KDE in Docker，KDE Wayland input integration limitation（记录为 input limitation context，NOT right-click direct proof）。
- [x] 12.8 记录 exact-search 负结果：`gh search issues` 在 `linuxserver/docker-webtop` 和 `linuxserver/docker-baseimage-selkies` 对 `right click context menu KDE webtop Selkies`、`context menu disappears KDE Wayland Selkies`、`right click menu disappears webtop` 三个精确查询均返回空结果（`[]`）；no direct upstream issue titled/matching main KDE right-click disappears was found；此为有效证据，表明该问题未在 upstream tracker 形成独立 tracked 的已知 bug。
- [x] 12.9 记录版本约束：本机 WSL 包检查确认 Plasma/KWin `6.6.4`（`kwin-wayland 4:6.6.4-0ubuntu1`、`plasma-workspace 4:6.6.4-0ubuntu2`）和 Qt `6.10.2`（`qt6-wayland 6.10.2-4`、`libqt6core6t64 6.10.2+dfsg-7`）；历史 KDE popup bugs 在 Qt 6.x 早期已被修复，当前版本已超越这些修复点，因此旧 bug 只能作为机制参考，NOT 当前 root cause。
- [x] 12.10 记录 WSL-vs-Docker Puppeteer 自动化右键对比证据（post-reboot runtime rebuild、Windows Chrome 可执行文件身份、WSL mimic 右键自动化结果、Docker reference 右键自动化结果、browser DOM/native contextmenu layer 已排除结论）；根因范围收窄至浏览器 DOM 层以下的 WSL runtime Selkies/KDE/Wayland/compositor/lifecycle 差异；DoD tasks 8.x 与 hard-limit tasks 7.2-7.6 保持 unchecked；详见 design.md 对应 addendum「WSL-vs-Docker Puppeteer 自动化右键对比证据（2026-05-16 补充）」。
- [x] 12.11 记录 Trace3–5、/lsiopy 实验与决策边界更新（Trace3 有效对比 AE 211/707936 vs 794826/0、Trace4 Chrome 端口冲突导致 Docker reference 无效并恢复、Trace5 KWin/Plasma 自发崩溃并恢复、/lsiopy 闭包移植准备态失败并回滚、更新后的候选边界）；详见 design.md 对应 addendum「Trace3–5、/lsiopy 实验与决策边界更新（2026-05-16 补充）」；DoD tasks 8.x 与 hard-limit tasks 7.2–7.6 保持 unchecked。
- [x] 12.12 记录 reusable trace harness 与 guest probes 证据（`/tmp/wsl-kde-trace-harness/run-trace.mjs`，最新有效运行 `/tmp/wsl-kde-trace-harness/run-20260516-142300/`，WSL/Docker real-frame gate 均通过，DOM 事件同形，WSL AE `34212/1752/33581` vs Docker AE `711886/0/711886`，WSL during-held KWin/Plasma/Xwayland/Selkies/nginx 存活）；详见 design.md 对应 addendum「reusable trace harness 与 guest probes（2026-05-16 补充）」；不声明最终 root cause 或修复，DoD tasks 8.x 与 hard-limit tasks 7.2–7.6 保持 unchecked。
- [x] 12.13 记录 supervision 实验失败、WSL `DISPLAY=:1` 触发 Xlib TCP `127.0.0.1:6001` timeout、`DISPLAY=unix/:1` 恢复 Selkies 8082/capture readiness、以及 post-fix harness 仍未改善 right-click held-window 行为（WSL AE `532/1752/2283` vs Docker AE `712218/13/712222`）；详见 design.md 对应 addendum「supervision 实验失败与 `DISPLAY=unix/:1` readiness 修复（2026-05-16 补充）」；不声明最终 root cause 或修复，DoD tasks 8.x 与 hard-limit tasks 7.2–7.6 保持 unchecked。
- [x] 12.14 记录 PulseAudio/null sink closure 实验：Docker reference 使用 pulseaudio + `output`/`input` null sinks；WSL baseline 仅有 `RDPSink/RDPSource` 且 Selkies 因 `XDG_RUNTIME_DIR=/tmp/wsl-kde-webtop/xdg-runtime` 找不到 `/run/user/1000/pulse/native`；null-sink-only 实验未闭合 Selkies audio path 且未改善右键；`PULSE_SERVER=unix:/run/user/1000/pulse/native` + null sinks 成功闭合 audio path（`PulseAudio connection established`、`output.monitor` capture 成功），但 harness 仍显示 WSL held-window AE `252` vs Docker `712084`，右键行为未修复；所有 PulseAudio modules 已卸载并回滚 baseline runtime；详见 design.md 对应 addendum「PulseAudio/null sink closure 实验（2026-05-16 补充）」；不声明最终 root cause 或修复，DoD tasks 8.x 与 hard-limit tasks 7.2–7.6 保持 unchecked。
- [x] 12.15 记录 right-click popup root-cause closure：debug runtime 证实 WSL `xdg_popup.grab` 后、right-button release 前发生 `xdg_popup.popup_done()`；`popup_done` 前出现 `wl-clipboard`/`wl-paste` 1x1 helper window 抢 keyboard focus。源码核查确认 WebSocket mode 的有效 clipboard 主开关是 `SELKIES_CLIPBOARD_ENABLED=false`。运行时已改为 `/tmp/wsl-kde-webtop/start.sh` 中 `SELKIES_CLIPBOARD_ENABLED=false`；重启后进程环境确认该变量生效，Selkies log 显示 `Skipping outbound clipboard service.`，最终 harness `/tmp/wsl-kde-trace-harness/run-20260516-234014-clipboard-enabled-false-final/` 显示 WSL before→during-held AE `714197`，与 Docker `668355` 同量级，右键 popup held-window 行为恢复。详见 design.md 对应 addendum「right-click popup closure via Selkies clipboard disable（2026-05-16 补充）」；DoD 8.x 仍需完整 browser desktop 最终验收后再勾选。
- [x] 12.16 记录 WSL KDE Webtop 持久化迁移：可保存 install root 已迁到 `~/.local/share/wsl-kde-webtop`，用户级入口为 `~/.local/bin/wsl-kde-webtop-{start,stop,restart,status}`；`/tmp/wsl-kde-webtop` 仅保留每次启动可再生的 log、pid、Wayland/XDG socket runtime。重启后使用 `wsl-kde-webtop-restart` 恢复 `http://127.0.0.1:3200`。详见 design.md 对应 addendum「persistent WSL install root（2026-05-16 补充）」。
- [x] 12.17 记录 clipboard 临时接受决策：用户确认先把 `SELKIES_CLIPBOARD_ENABLED=false` 作为 temporary accepted degraded decision，以换取 WSL native KDE popup/menu 行为稳定；不声明 clipboard sync 已修复，也不把它伪装成已证明的 WSL hard limit。最终 DoD 8.x 仍等待用户手动验收后再勾选。
