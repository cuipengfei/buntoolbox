## Context

说明：本文档正文使用中文；`Context`、`Goals / Non-Goals`、`Decisions`、`Risks / Trade-offs`、`Open Questions` 等标题是 OpenSpec schema 识别用语，按工具约定保留英文。

本 change 的目标不是重新发明 remote desktop，也不是只把 KDE 包装进镜像，而是尽量照搬 LinuxServer Webtop KDE 的工作方式，让当前 WSL / Docker Desktop 环境可以启动 KDE，并从 Windows 浏览器打开 KDE 桌面。

上游当前结构可归纳为：

```text
lscr.io/linuxserver/webtop:ubuntu-kde
├─ docker-webtop ubuntu-kde layer
│  ├─ FROM ghcr.io/linuxserver/baseimage-selkies:ubunturesolute
│  ├─ ENV TITLE="Ubuntu KDE"
│  ├─ ENV PIXELFLUX_WAYLAND=true
│  ├─ apt install KDE Plasma / KWin / Konsole / Dolphin / Chromium 等
│  ├─ cargo install wl-clipboard-rs-tools
│  └─ COPY /root /
└─ baseimage-selkies
   ├─ /init + s6-overlay
   ├─ nginx frontend
   ├─ Selkies websocket backend
   ├─ PulseAudio / DBus
   ├─ Xvfb fallback surface
   ├─ Wayland / KWin / Xwayland / Pixelflux stack
   └─ abc + /config user model
```

关键 KDE Wayland runtime chain：

```text
/init
└─ s6
   ├─ init-nginx
   │  └─ 生成 nginx config: HTTP/HTTPS frontend + /websocket upstream
   ├─ init-selkies-config
   │  ├─ 检查 AVX2 / Wayland capability
   │  ├─ 设置 XDG_RUNTIME_DIR=$HOME/.XDG
   │  └─ 配置 GPU / DRI / hardening / menu / autostart
   ├─ svc-selkies
   │  └─ selkies --addr=localhost --mode=websockets
   └─ svc-de
      └─ 等待 $XDG_RUNTIME_DIR/wayland-1
         └─ /defaults/startwm_wayland.sh
            ├─ 禁用 KWin compositing / screen lock
            ├─ 设置 clipboard rules
            ├─ 设置 DISPLAY=:1 和 KDE/Wayland env
            └─ dbus-run-session
               ├─ kwin-xwayland.py
               │  └─ kwin_wayland --no-lockscreen --xwayland --xwayland-display=:1
               ├─ polkit-kde-authentication-agent
               └─ WAYLAND_DISPLAY=wayland-0 plasmashell
```

本 repo 当前已有 shared Webtop build entry：`docker/webtop/Dockerfile`，通过 build args 选择 `WEBTOP_BASE`、`BUNTOOLBOX_VARIANT`、`BUNTOOLBOX_DESKTOP_NAME`；也已有 root-first preflight/patch/guard、common webtop runtime test、`test-kde-runtime.sh` 的 KDE marker 检查。这个 proposal 的重点是把 KDE mimic 的完整上游合同、WSL runbook、差异说明和 Definition of Done 补齐，而不是停留在“构建出一个 kde tag”。

官方 Webtop 文档把 Webtop 定义为可通过现代浏览器访问的完整 desktop environment container，并列出 `ubuntu-kde` 为 KDE Ubuntu Wayland Only tag；官方默认端口语义是 `3000` HTTP 和 `3001` HTTPS，`/config` 是 `abc` 用户 home。buntoolbox 必须在这里做受控差异：`3000` 已属于 OpenVSCode，正常交互必须 root-first，因此 Webtop GUI 默认改为 `3200`/`3201`，`HOME=/root`。

## Goals / Non-Goals

**Goals:**

- 以 upstream Webtop KDE / baseimage-selkies 为事实基准，完整映射 Dockerfile、s6 services、nginx/Selkies、KDE Wayland startup、runtime env、ports、volumes、GPU knobs。
- 产出能指导实现的 OpenSpec artifacts：proposal、design、spec、tasks 全中文，且每个关键 claim 都能对应 source/runtime/test evidence。
- 让 `cuipengfei/buntoolbox:kde` 在当前 WSL / Docker Desktop 中可运行，并通过 Windows 浏览器访问 KDE Plasma desktop。
- 默认 mimic 上游 KDE Wayland path，不用 VNC/noVNC/xrdp/WSLg 替代成功。
- 只做必要差异：root-first `/root`、端口 `3200`/`3201`、保留 `3000` 给 OpenVSCode、WSL-specific GPU/设备说明。
- 维持 sibling variant 设计：`latest` 不引入 GUI，`i3` 不被 KDE 改动破坏，`kde` 复用 shared toolchain layer。
- 把 WSL/browser end-to-end minimal action 纳入 Definition of Done，而不是只检查容器内进程。

**Non-Goals:**

- 不把 KDE 加入 `buntoolbox:latest`。
- 不从零自建 Selkies/nginx/s6/KWin stack，除非 upstream 明确不适配且有记录。
- 不把 WSLg 单应用显示、VNC/noVNC、xrdp 或 RDP 当作 Webtop KDE mimic 成功。
- 不承诺首轮实现 GPU zero-copy、NVENC/VAAPI、音频完美、HTTPS 证书信任、中文输入完美或 Chromium 硬件加速完美。
- 不在本地执行耗时 Docker build，除非用户另行明确批准；正式构建由 CI 完成，发布后在 WSL 做 runtime/browser 验收。

## Decisions

### Decision: 继续使用 upstream Webtop KDE image 作为 base，而不是 WSL host native KDE

KDE mimic 的主体应是 containerized Webtop：`WEBTOP_BASE=lscr.io/linuxserver/webtop:ubuntu-kde` 或等价 digest，保留 `/init`、s6、nginx、Selkies、Wayland/KWin/Xwayland startup。WSL host 只负责 Docker Desktop runtime、端口映射、浏览器访问和可选设备透传。

替代方案：

- WSL host 原生安装 KDE + Selkies：拒绝，污染 host，且不等同 Webtop image。
- WSLg KDE app：拒绝，目标是 Windows browser 内完整 KDE desktop，不是 Windows 桌面上单独 Linux GUI window。
- VNC/noVNC：拒绝，传输、前端、输入、编码、服务模型都不是 Webtop KDE。

### Decision: KDE layer 必须薄，复杂度保留在 baseimage-selkies

实现应 mimic upstream：KDE-specific Dockerfile 只负责 base、title、Wayland flag、KDE packages、Chromium wrapper、wl-clipboard rust tool、`/root` overlay。复杂 runtime 不在 buntoolbox 重新写：仍由 baseimage-selkies 的 `init-nginx`、`init-selkies-config`、`svc-selkies`、`svc-de` 等驱动。

如果需要 patch，只 patch buntoolbox 必需差异：root-first、端口、metadata、toolchain layers、guard。不得把 s6 service graph 改成自定义 shell supervisor。

### Decision: root-first 是 buntoolbox 必需差异，但必须 fail-closed

上游 Webtop 使用 `abc` + `/config`；buntoolbox 的交互模型是 root-first + `/root`。因此 KDE variant 必须复用现有 root-first patch/guard，并增强到 KDE Wayland path：

```text
s6-setuidgid abc     -> root execution
chown abc/root:abc   -> root:root 或 :root
pgrep/pkill -u abc   -> -u root
id/usermod/groupmod/lsiown/crontab abc runtime mutation -> root 替代或禁用
/config interactive HOME paths -> /root interactive HOME paths
```

Guard 不只扫旧式 `/etc/services.d`，必须覆盖当前 `/etc/s6-overlay/s6-rc.d`、`/defaults`、`/usr/local/bin` 等 runtime surface。`abc` 留在 `/etc/passwd` 可接受；关键 runtime process、ownership、interactive HOME path 仍指向 `abc` 或 `/config` 必须 fail。

### Decision: 端口采用 buntoolbox-first policy

上游 Webtop 对外端口是 `3000` HTTP 和 `3001` HTTPS；buntoolbox 中 `3000` 保留给 `openvscode-start`。KDE variant 默认：

```text
CUSTOM_PORT=3200
CUSTOM_HTTPS_PORT=3201
CUSTOM_USER=root
HOME=/root
CUSTOM_WS_PORT 不主动暴露，默认仍作为 nginx -> Selkies 的内部 upstream
```

测试必须证明：Webtop HTTP `3200` 响应、Webtop HTTPS `3201` 至少能 TLS 握手或返回 self-signed HTTPS 响应、Webtop 不占用 `3000`、`openvscode-start` 可在 `3000` 响应。`3201` 不是可选配置项；它是 release readiness 的 MUST。手动 Windows browser minimal action 可以优先使用 `3200` HTTP，但发布前必须保留 `3201` HTTPS 可访问证据。

### Decision: KDE Wayland path 是默认成功路径，X11 fallback 只能作为记录化降级

官方标记 `ubuntu-kde` 为 Wayland Only；upstream Dockerfile 设置 `PIXELFLUX_WAYLAND=true`。因此 buntoolbox KDE 最小成功默认必须看到 KDE Wayland markers：`kwin_wayland`、`Xwayland :1`、`plasmashell`。

如果 baseimage 因 AVX2/环境问题 fallback，不能静默把 X11 当成功。对 `ubuntu-kde` mimic 来说，`kwin_wayland`/`Xwayland`/`plasmashell` 等 Wayland marker 不成立时，release verdict 必须是 blocker 或 non-mimic/degraded evidence；不得发布为 KDE mimic pass。即使某个 X11 fallback 能显示窗口，也只能作为诊断证据，不能替代本 change 的完成定义。

### Decision: WSL GPU 作为分层能力，不作为 DoD 前置

Webtop 官方 GPU contract 围绕 `/dev/dri`、NVIDIA runtime、`DRINODE`/`DRI_NODE`、Wayland zero-copy。WSL Docker Desktop 下可能存在 `/dev/dxg` + Mesa D3D12 的 GUI app OpenGL path，但这不是 LinuxServer 官方承诺。设计必须拆成三层：

```text
KWin compositor / Wayland session
GUI app OpenGL rendering
Selkies stream encoding
```

Definition of Done 的最小成功是 browser KDE desktop 可用；GPU 成功必须另有证据，不允许用设备存在、`nvidia-smi` 或系统监控当作 KDE/Selkies 加速证明。

### Decision: Windows browser minimal action 是最终验收，不是可选演示

容器内 `ps` marker 只能证明 session 可能启动。最终 DoD 必须包含 Windows browser 操作，并把证据写入 `openspec/changes/mimic-webtop-kde-wsl/evidence.md`：打开 `http://localhost:3200/` 或 `https://localhost:3201/`，看到 KDE Plasma，打开 Konsole 或 Dolphin，执行一个最小交互动作，并保留截图路径或等价可审计 artifact、页面 URL、时间戳、`docker exec ps`、`curl`、`ss`、`docker logs` 摘要。若无法保存截图，必须记录替代证据为什么足够。

### Decision: implementation evidence 必须集中落到 evidence.md

本 proposal 阶段不执行实现，但 implementation 阶段必须新增并维护：

```text
openspec/changes/mimic-webtop-kde-wsl/evidence.md
```

最小字段：

```text
采集日期 / 执行人或 agent
Upstream source URL / branch / commit / image digest
Baseimage-selkies source URL / branch / commit
KDE Dockerfile 摘要
s6/service/startwm/nginx/Selkies 文件摘要
构建或 CI run URL / image tag / image digest
容器启动命令 / Docker Desktop / WSL baseline
HTTP 3200 证据
HTTPS 3201 证据
内部 websocket upstream 证据
KDE Wayland process evidence
root-first/no-abc evidence
Windows browser minimal action evidence
GPU optional evidence 或明确未测
失败、偏差、release verdict
```

没有 evidence.md 或 evidence.md 缺少 release verdict 时，不得把 implementation 标记为完成。

### Decision: 文档和 CI 与实现同等重要

完成不仅是 Dockerfile 改动。必须更新 README、image metadata、test scripts、GitHub Actions、WSL runbook 和 release verification。否则这个 proposal 仍然会落入“半成品”：镜像也许能构建，但用户不知道如何在 WSL/Windows browser 里稳定使用，也没有证据说明和 Webtop KDE 的差异。

## Risks / Trade-offs

- [Risk] Upstream baseimage-selkies service surface 漂移，root-first patch 漏掉 KDE-specific `abc` path。→ Mitigation: Gate 0 重新采集 upstream evidence；preflight 要求最低 match；post-patch broad guard；KDE-specific process ownership test。
- [Risk] `ubuntu-kde` Wayland Only 在当前 WSL/Docker Desktop 上因 AVX2、seccomp、shared memory 或设备限制启动失败。→ Mitigation: runbook 明确 `--shm-size=1gb`、必要时 `--security-opt seccomp=unconfined` 的诊断路径；失败时记录为 blocker，不用 VNC/WSLg 冒充。
- [Risk] 端口语义混淆导致 Webtop 抢占 OpenVSCode 的 `3000`。→ Mitigation: env/label/test 三处固定 `3200`/`3201`，测试 `3000` free 后启动 OpenVSCode。
- [Risk] root-first 改动破坏 upstream hardening 或 file transfer path。→ Mitigation: tasks 要求检查 nginx `FILE_MANAGER_PATH`、`/files` alias、`/root/Desktop`、basic auth/password、hardening env 的行为；nginx worker 可使用 `www-data` 或 nginx 默认服务用户，但不得以 `abc` 运行。
- [Risk] GPU 讨论扩大成不可收口优化。→ Mitigation: GPU 只作为可选分层验收；最小 DoD 不依赖 GPU；GPU claim 必须分别证明 compositor/rendering/encoding。
- [Risk] 本地 Docker build 耗时/耗流量。→ Mitigation: 本地只做静态和脚本验证；CI 构建后再用发布镜像在 WSL runtime 验收。

## Migration Plan

1. Gate 0：重新采集 upstream Webtop KDE 和 baseimage-selkies evidence，记录 source URL、commit、image digest、关键 Dockerfile/service/startwm/nginx 文件。
2. Gate 1：审查现有 `docker/webtop/Dockerfile` 是否能以 `WEBTOP_BASE=lscr.io/linuxserver/webtop:ubuntu-kde`、`BUNTOOLBOX_VARIANT=kde`、`BUNTOOLBOX_DESKTOP_NAME=KDE` 构建；补齐 labels/env/metadata。
3. Gate 2：增强 root-first preflight/patch/guard，确保 KDE Wayland path 下 `/root` 和 root process ownership 成立。
4. Gate 3：补齐 KDE runtime checks：nginx/Selkies endpoint、KWin Wayland/Xwayland/plasmashell markers、no abc critical processes、OpenVSCode 3000 coexistence。
5. Gate 4：补齐 README/WSL runbook/image-release/CI，对 KDE 发布 tag 和 post-push tests 做闭环。
6. Gate 5：发布后在当前 WSL 使用 `cuipengfei/buntoolbox:kde` 完成 Windows browser minimal action，并记录证据。

## Rollback Strategy

- 若 KDE variant 构建失败，只回退 KDE-specific build args/CI/docs/test additions，不影响 `latest` 和 `i3`。
- 若 shared root-first guard 因 KDE 补强影响 i3，通过 i3 regression test 定位并拆分 guard fixture；不得放宽 fatal pattern 来让 KDE 通过。
- 若发布后 WSL browser 验收失败，不发布或撤回 `kde` tag；保留 CI artifact 和 logs 作为 blocker evidence。
- 若 GPU path 不稳定，默认关闭 GPU-specific 文档承诺，只保留 software/CPU minimal path 和实验附录。

## Open Questions

- 是否要 pin `lscr.io/linuxserver/webtop:ubuntu-kde` digest，还是跟随 moving tag 并在每次 CI 记录 digest？默认建议先记录 digest，不 pin；如果 upstream drift 频繁破坏 patch，再 pin。
- `3201` HTTPS 是否必须作为首轮 browser minimal action，还是首轮以 `3200` HTTP + 说明 WebCodecs/HTTPS 限制收口？已决：两者都必须启动；manual minimal action 可先走 HTTP `3200`，但 HTTPS `3201` 至少握手或 self-signed 响应是 release MUST。
- WSL Docker Desktop 下是否要提供 `/dev/dxg` 实验 runbook？默认放在 optional GPU section，不纳入最小 DoD。
