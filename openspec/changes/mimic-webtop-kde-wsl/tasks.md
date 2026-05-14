## 1. 上游证据与差异基线

说明：本文档正文使用中文；命令、路径、变量名、OpenSpec 术语保留英文。

- [ ] 1.1 记录 `linuxserver/docker-webtop` `ubuntu-kde` Dockerfile 的来源、commit、关键内容和与本 repo 目标的对应关系：baseimage、`TITLE`、`PIXELFLUX_WAYLAND`、KDE package list、Chromium wrapper、wl-clipboard rust tools、`COPY /root /`、ports/volume。
- [ ] 1.2 记录 `linuxserver/docker-baseimage-selkies` `ubunturesolute` Dockerfile 和 runtime root 文件，至少覆盖 Selkies/frontend build、`/defaults/default.conf`、`init-nginx`、`init-selkies-config`、`svc-selkies`、`svc-de`、`svc-nginx`、`svc-dbus`、`svc-pulseaudio`、`svc-xorg`。
- [ ] 1.3 记录上游 KDE startup 文件：`/defaults/startwm_wayland.sh`、`/kwin-xwayland.py`、`wrapped-chromium`、`autostart`，并抽取必须 mimic 的 env、KWin/Plasma/clipboard/lockscreen/compositing 行为。
- [ ] 1.4 记录当前 remote image metadata：`lscr.io/linuxserver/webtop:ubuntu-kde` manifest digest、amd64/arm64 digest、image labels、Entrypoint、Env、ExposedPorts、build_version；若只用 GitHub source 未 pull image，必须说明缺口。
- [ ] 1.5 新增并维护 `openspec/changes/mimic-webtop-kde-wsl/evidence.md`，明确哪些行为照搬 upstream，哪些是 buntoolbox/WSL 必需差异，哪些暂不承诺；最小字段包括 source URL、branch/commit、image digest、runtime logs、endpoint checks、browser evidence、GPU optional evidence 或未测说明、known deviations、release verdict。

## 2. Build entry 与 KDE variant 合同

- [ ] 2.1 确认或补齐 `docker/webtop/Dockerfile` 的 KDE build 参数：`WEBTOP_BASE=lscr.io/linuxserver/webtop:ubuntu-kde`、`BUNTOOLBOX_VARIANT=kde`、`BUNTOOLBOX_DESKTOP_NAME=KDE`、description/labels/image-release 正确。
- [ ] 2.2 保留 Webtop `/init` entrypoint，不引入自定义 supervisor，不用 VNC/noVNC/xrdp 替代 Selkies。
- [ ] 2.3 保留上游 KDE Wayland contract：`PIXELFLUX_WAYLAND=true` 不被 buntoolbox layer 覆盖，`TITLE` 最终符合 KDE variant，`DISPLAY=:1` 和 KDE/Wayland env 不被 shared shell config 破坏。
- [ ] 2.4 确认 buntoolbox toolchain shared layers 在 KDE base 上可用且不覆盖 KDE runtime 必需包、capabilities、KWin/Plasma config、Selkies frontend assets。
- [ ] 2.5 确认 `EXPOSE`、labels、`/etc/image-release` 同时包含 `3000` OpenVSCode、`3200` Webtop HTTP、`3201` Webtop HTTPS、`7681` ttyd，且文档解释与 upstream `3000/3001` 的差异。

## 3. Root-first patch / guard 补强

- [ ] 3.1 在 KDE upstream base 上运行 root-first preflight，确认待 patch 的 `abc` runtime surface 覆盖 `/etc/s6-overlay/s6-rc.d`、`/defaults`、`/usr/local/bin`，而不是只覆盖旧路径。
- [ ] 3.2 确认 patch 后关键 Webtop support process 与 KDE process 不以 `abc` 运行：Selkies、DBus、PulseAudio、KWin、Xwayland、plasmashell、kded、polkit-kde agent；nginx worker 可为 `www-data` 或 nginx 默认服务用户，但不得为 `abc`。
- [ ] 3.3 确认 interactive HOME path 从 `/config` 改为 `/root`：KDE config、autostart、`$HOME/.XDG`、Desktop/file transfer path、Konsole/Dolphin 默认路径。
- [ ] 3.4 增加或更新 guard fixture，覆盖 KDE-specific fatal cases：`startwm_wayland.sh` 中写死 `/config`、`kwin`/`plasmashell` 被 `s6-setuidgid abc` 启动、KDE config 被 `chown abc:abc`。
- [ ] 3.5 明确允许项：`abc` account 保留在 `/etc/passwd`、文档注释出现 `abc`、nginx worker 非 root 用户；禁止项：正常 GUI/runtime path 依赖 `abc` user model。

## 4. nginx / Selkies / endpoint parity

- [ ] 4.1 验证 `init-nginx` 在 buntoolbox env 下生成正确 nginx config：`CUSTOM_PORT=3200`、`CUSTOM_HTTPS_PORT=3201`、`CUSTOM_USER=root`、`CUSTOM_WS_PORT` 内部 upstream、`SUBFOLDER` 默认 `/`。
- [ ] 4.2 验证 `/usr/share/selkies/web` frontend assets、manifest title/icon、`/websocket` proxy、`/files` alias 和 optional password auth 行为没有被 root-first 改坏。
- [ ] 4.3 验证 `svc-selkies` 以 `selkies --addr=localhost --mode=websockets` 或等价上游方式运行，并能与 nginx frontend websocket path 对接。
- [ ] 4.4 验证 Webtop HTTP `3200` 在容器内 `curl http://127.0.0.1:3200/` 有响应，HTTPS `3201` 必须至少可 TLS 握手或返回 self-signed cert 响应；`3201` 是 release MUST，不是可选配置检查；记录 HTTP/HTTPS 差异。
- [ ] 4.5 验证 Webtop 不监听 `3000`，并验证 `openvscode-start` 能在同一容器中启动并通过 `http://127.0.0.1:3000/` 响应。

## 5. KDE Wayland runtime 验证

- [ ] 5.1 启动 KDE variant 测试容器，等待 s6 ready，采集 `docker logs`、`ps -ef`、`ss -tlnp`、`env`、`/run/s6/container_environment/*` 摘要。
- [ ] 5.2 验证 KDE session marker：`kwin_wayland --no-lockscreen --xwayland`、`Xwayland :1`、`plasmashell`、DBus session、polkit KDE agent 或等价 marker。
- [ ] 5.3 验证 `startwm_wayland.sh` 行为生效：KWin compositing disabled config、screen lock disabled config、clipboard rule、`$HOME/.XDG` permissions、`QT_QPA_PLATFORM=wayland`、`XDG_SESSION_TYPE=wayland`。
- [ ] 5.4 验证 Konsole、Dolphin、Chromium desktop entry/wrapper 至少存在；browser minimal action 以前，容器内先验证命令路径和 desktop files。
- [ ] 5.5 如果 Wayland path fallback 或失败，记录 AVX2、seccomp、shared memory、KWin log、Selkies log，并在 `evidence.md` 将 release verdict 标为 blocker 或 non-mimic/degraded evidence；不得把 X11 fallback 或 WSLg display 当作 release pass。

## 6. WSL / Docker Desktop runbook 与 Windows browser 验收

- [ ] 6.1 编写 README 或 docs runbook，给出当前 WSL 中运行 KDE image 的命令，至少包含 `--shm-size=1gb`、`-p 3200:3200`、`-p 3201:3201`、可选 `-p 3000:3000`、volume 建议、seccomp 诊断建议。
- [ ] 6.2 在 runbook 中明确 GPU 分层：无 GPU/software path、官方 `/dev/dri`/NVIDIA path、WSL `/dev/dxg`/Mesa D3D12 optional path、Selkies encoding path，并写明哪些不是最小 DoD。
- [ ] 6.3 使用发布或 CI 产物镜像在当前 WSL 启动容器，Windows 浏览器访问 `http://localhost:3200/` 或 `https://localhost:3201/`，记录页面可达证据。
- [ ] 6.4 在 Windows browser 内完成 KDE minimal action：看到 Plasma desktop，打开 Konsole 或 Dolphin，执行一个简单命令或文件浏览动作；把证据写入 `evidence.md`，包含页面 URL、时间戳、截图路径或等价 artifact、动作描述、`ps`/`curl`/`ss`/`docker logs` 摘要。若无法保存截图，必须说明替代证据为什么可审计。
- [ ] 6.5 停止并删除容器后，记录 WSL/Docker Desktop 没有异常端口残留、没有本 runbook 创建的 host-level 长期进程、没有未说明的 host mutation。

## 7. 测试、CI 与文档收口

- [ ] 7.1 更新 `scripts/lib/test-kde-runtime.sh`，确保覆盖 KDE Wayland markers、no-abc KDE critical processes、root HOME、Webtop endpoint、OpenVSCode coexistence。
- [ ] 7.2 更新 `scripts/test-image.sh --variant kde` 路径，确保 common tool checks、shared webtop runtime checks、KDE-specific checks 都执行，并有 completion sentinel。
- [ ] 7.3 更新 GitHub Actions：PR 构建/测试 KDE CI tag，default branch 发布 `cuipengfei/buntoolbox:kde`，release tag 发布 `kde-*` tags，CI 输出 upstream base provenance。
- [ ] 7.4 更新 `README.md`、`image-release.txt`、必要的 docs，明确 KDE variant、端口、root-first、WSL run command、GPU/HTTPS/security caveats。
- [ ] 7.5 执行静态验证：`openspec validate --changes mimic-webtop-kde-wsl --strict`、`bash -n` 覆盖改动脚本、root-first guard fixture、README/runbook review。
- [ ] 7.6 发布后执行：`./scripts/test-image.sh --variant kde --image cuipengfei/buntoolbox:kde`，并附 Windows browser minimal action evidence。

## 8. 审阅门禁

- [ ] 8.1 实现前请 architect 审阅 proposal/design/spec/tasks，重点检查 Webtop KDE mimic 是否完整、WSL 差异是否合理、DoD 是否可测。
- [ ] 8.2 实现前请 critic 挑刺，重点检查是否仍有“半成品”风险：只看进程不看浏览器、只写 Dockerfile 不写 runbook、GPU claim 过度、端口/abc/root-first 漏洞。
- [ ] 8.3 根据 architect 和 critic 意见修订 artifacts；未完成这一步不得进入 `/opsx:apply` 或实现。
