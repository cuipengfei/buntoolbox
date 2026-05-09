## Context

前序调研记录显示 `linuxserver/webtop:ubuntu-i3` 工作链路是 `Xvfb -> i3 -> Selkies websocket -> nginx/frontend`。实施 Gate 0 必须重新记录该前提的来源证据：`ubuntu-i3` Dockerfile、`baseimage-selkies` Dockerfile、`/defaults/startwm.sh`、相关 service 文件、nginx/frontend 配置、image digest 或本地 image metadata。只有 Gate 0 证据写入 records 后，后续步骤才能把该链路作为已验证前提。

当前目标不是直接修改 buntoolbox，而是在当前 WSL 里建立一个低污染、可回退的 user-level spike，用一段时间感受 browser-delivered i3 workflow，再决定是否进入 buntoolbox adoption。所有 Markdown 记录使用中文；所有安装、文件变更、配置变更和回退方式必须被记录，但不做大体积备份。

## Goals / Non-Goals

**Goals:**

- 在当前 WSL 中以 user-level 方式启动一个尽量接近 webtop-i3 container 工作方式的 i3 session。
- 保留影响体验判断的核心链路：`Xvfb :1`、`dbus-launch i3`、Selkies websocket streaming、browser endpoint。
- 所有 runtime 状态限制在 `~/.local/share/webtop-i3/` 一类用户级目录下，包括 config、venv、logs、run/pid、proxy/frontend 配置。
- 提供 `start`、`stop`、`status` 操作模型，`stop` 只能清理本 spike 启动并记录的 PID。
- 记录所有实际安装、文件写入、配置修改、端口占用和环境变量设置，并记录如何回退。
- 保留后续迁移到 buntoolbox 的证据：资源占用、可用性、残留进程、端口冲突、是否值得采用。

**Non-Goals:**

- 不在本变更中修改 buntoolbox Dockerfile、README、image-release.txt 或 CI。
- 不复刻 s6-overlay、`/init`、`with-contenv`、LinuxServer `abc` 用户模型。
- 不修改 `/etc/sudoers`，不设置 NOPASSWD，不新增 Docker-in-Docker 或 proot-apps。
- 不启动或配置 system-level nginx，不固定占用 3000/3001。
- 不把真实 WSL `$HOME` 改成 `/config`，不修改全局 shell profile 来强制加载该环境。
- 不承诺 GPU/NVENC、音频、joystick/fake-udev、Wayland/labwc/openbox fallback 的完整 parity。
- 不把 WSLg 当作 webtop mimic fallback；WSLg 只作为明确排除或诊断项。

## Decisions

### Decision: 以 browser-streamed webtop mimic 为主，而不是 WSLg 或 VNC/noVNC

webtop-i3 镜像中存在 `/lsiopy/bin/selkies`、`/usr/bin/Xvfb`、`/usr/sbin/nginx`、`/usr/bin/i3`，未找到 `websockify`、`x11vnc`、`vncserver`。因此 mimic 目标必须以 `Xvfb + i3 + Selkies + frontend/proxy` 为核心。

替代方案：

- WSLg：适合单个 Linux GUI app 融入 Windows 桌面，但不是 webtop 的浏览器内完整 i3 session。
- VNC/noVNC：更容易实现，但不是 webtop-i3 的真实链路，输入、编码和浏览器交互路径不同。

### Decision: user-level runtime 目录模拟 `/config` 和 `/lsiopy`

使用 `~/.local/share/webtop-i3/` 作为根目录，建议结构：

```text
~/.local/share/webtop-i3/
  config/      # 模拟 webtop HOME=/config
  venv/        # 模拟 /lsiopy Python venv
  logs/        # Xvfb/i3/Selkies/proxy 日志
  run/         # pid、port、state 文件
  frontend/    # Selkies frontend assets 或本地 proxy 静态资源
  proxy/       # user-level proxy/nginx 配置
  records/     # 安装和回退记录
```

该目录是 spike 的唯一持久化区域。启动脚本只在子进程环境里设置 `HOME=~/.local/share/webtop-i3/config`，不得改变真实 shell 的 `$HOME`。

### Decision: 用 start/stop/status 替代 s6-overlay

WSL host 不应直接搬 container supervisor。设计上应提供用户级命令或脚本：

```text
webtop-i3-start
webtop-i3-stop
webtop-i3-status
```

`start` 负责 preflight、端口选择、启动进程、写入 PID/state。state 至少记录 component、PID、PPID 或 process group、启动时间、启动命令、cmdline 摘要、runtime root、log path、display、端口和 session id。`stop` 读取 state 后，必须先用 `/proc/<pid>` 复核 cmdline、启动时间或 runtime/session marker；不匹配时只报警不 kill。`status` 输出 PID、端口、日志路径、config 路径、进程存活状态、ownership 验证结果和主要资源占用。

### Decision: 端口必须可配置并默认避开 3000/3001

webtop 默认 3000/3001，但当前项目已有 openvscode 默认 3000 的历史约定。WSL spike 默认使用 `127.0.0.1:3200` 作为 HTTP browser endpoint；如 Selkies backend 需要独立端口，该端口也默认绑定 `127.0.0.1`，只供 frontend/proxy 访问。`3201`/HTTPS 后置为可选观察项，不是 Gate 3 最小成功条件。若端口冲突，start 可自动选择其他 localhost 端口，但必须在 state/records 中记录 browser public endpoint、backend websocket port、bind address 和访问 URL。

### Decision: Selkies/frontend/proxy 路径必须先收敛再执行

webtop baseimage 从 `selkies-project/selkies` 特定 commit `96e1abbf9ba0e44a8dabbc425fcb8312792fe303` 安装到 `/lsiopy`。WSL spike 应使用独立 venv，并记录安装来源、commit、pip 包、系统包、失败日志和回退命令。

默认路径：

- backend：在 `~/.local/share/webtop-i3/venv` 中从 `selkies-project/selkies` 的 commit `96e1abbf9ba0e44a8dabbc425fcb8312792fe303` 安装或验证 Selkies；若必须偏离 commit，records 必须写明原因和差异。
- frontend assets：优先使用同一 Selkies 来源提供或构建出的 assets；只有该路径失败并记录日志后，才允许从已存在的 pinned image digest 中提取 assets 作为 fallback。不得为了提取 assets 新拉取镜像，除非用户另行批准。
- proxy：使用 user-level frontend/proxy 或轻量静态服务暴露 browser endpoint；不得启动或配置 system nginx。

失败与停止条件：如果 pinned Selkies backend 无法安装或无法连接 Xvfb/i3 display，记录为 Selkies path failure；不得用 VNC/noVNC 或 WSLg 成功替代 webtop mimic 成功。如果 frontend fallback 也失败，停止在对应 gate，保留日志和回退记录，不扩大到 system nginx 或其他全局服务。

### Decision: phase gates 和最小成功标准

实施必须按 gate 推进，每个 gate 都要写入 records：通过条件、失败条件、证据路径和下一步决定。

- Gate 0：source/provenance 与 WSL preflight。通过条件是 webtop-i3 外部证据、WSL baseline、端口占用、已有进程和包状态都已记录；失败时停止并说明缺失证据。
- Gate 1：runtime + Xvfb+i3。通过条件是 user-level runtime 已建立、`Xvfb :1` 启动、`dbus-launch --exit-with-session /usr/bin/i3` 绑定该 display，state 记录 PID/日志/display；失败时停止并记录日志。
- Gate 2：Selkies + frontend/proxy。通过条件是 Selkies backend 连接目标 display，user-level frontend/proxy 在 localhost endpoint 暴露 browser 页面，端口角色写入 state；失败时停止，不使用 VNC/WSLg 冒充成功。
- Gate 3：browser minimal action。通过条件是 Windows browser 能访问 endpoint、看到 i3 session、启动 terminal 或指定轻量 X app、完成一个 i3 workspace/fullscreen 类最小动作、`webtop-i3-stop` 后 status 报告无 spike-owned 残留。
- Gate 4：usability/adoption observation。Chromium、中文输入、字体、HTTPS、音频、GPU/NVENC、vmmemWSL 和更长时间试用都属于观察项；这些失败不得推翻 Gate 3 的最小 mimic 成功，但必须记录差异。

### Decision: 变更记录优先于大体积备份

用户要求不要备份一堆太重的东西，但要知道如何回退。因此每一步安装或配置必须记录：

```text
动作
时间
命令或文件路径
新增/修改/删除的对象
为什么需要
如何回退
是否已验证
```

记录位置建议：

```text
~/.local/share/webtop-i3/records/YYYY-MM-DD-log.md
```

## Risks / Trade-offs

- [Risk] Selkies 在 WSL Ubuntu 26 / Python 3.14 上源码安装失败或行为不同。→ Mitigation: 独立 venv、pin commit、先做最小安装验证，失败时保留日志并删除 venv 即可回退。
- [Risk] user-level frontend/proxy 与 webtop nginx 行为不完全一致。→ Mitigation: 第一阶段只要求 browser 可访问和 i3 可操作，不要求 byte-for-byte parity；记录差异。
- [Risk] 进程残留污染 WSL。→ Mitigation: 必须使用 pid/state 文件，`stop` 禁止 broad `pkill`，`status` 必须报告残留。
- [Risk] PID 被复用导致误杀无关进程。→ Mitigation: state 记录 session id、启动时间、cmdline/runtime marker；stop 前通过 `/proc/<pid>` 复核 ownership，不匹配时只报告不 kill。
- [Risk] 端口冲突。→ Mitigation: 默认避开 3000/3001，支持配置或自动检测，并记录实际端口。
- [Risk] 安装系统包污染 WSL。→ Mitigation: 系统包安装前列清单，记录 apt manual/auto 状态和建议回退命令；不安装 Docker CE/dind/proot，不改 sudoers。
- [Risk] 误把 WSLg 或 VNC/noVNC 结果当作 webtop mimic。→ Mitigation: proposal/spec/tasks 明确 browser mimic 的必需链路是 Xvfb + i3 + Selkies/frontend。

## Migration Plan

1. 创建 OpenSpec proposal/design/spec/tasks，只记录计划，不安装。
2. Gate 0：做 source/provenance 与 WSL preflight，确认 OS、端口、已有进程、已有包、Python/venv 能力。
3. Gate 1：建立 user-level runtime 目录和 records 日志，验证 Xvfb+i3。
4. Gate 2：验证 pinned Selkies backend 与 user-level frontend/proxy。
5. Gate 3：用 Windows browser 完成 minimal action，并验证 stop/status 无 spike-owned 残留。
6. Gate 4：试用期间记录资源占用、体验和与 webtop container 的差异。
7. 试用结束后，基于 records 输出四选一决策：保留 WSL spike、清理回退、继续改进 spike、或进入 buntoolbox adoption proposal。

## Rollback Strategy

回退不依赖大体积备份，依赖可审计记录：

- 停止服务：运行 `webtop-i3-stop`；stop 必须先验证 state 中 PID 的 ownership，确认属于本 spike 后再停止，不匹配的 PID 只报告不 kill。
- 删除 user-level runtime：删除 `~/.local/share/webtop-i3/` 下 venv、config、logs、run、frontend/proxy；保留 records 可选。
- 删除 user-level launcher：删除 `~/.local/bin/webtop-i3-start`、`webtop-i3-stop`、`webtop-i3-status`，前提是它们确认为本 spike 创建。
- 回退 apt 包：根据 records 中记录的包清单决定是否 `apt remove`；不得自动删除用户已有包或其他项目依赖。
- 回退端口和配置：删除仅属于本 spike 的 proxy config，不影响 system nginx 或其他服务。

## Resource Sampling Protocol

资源采样由 `status` 或等价命令提供固定输出，records 至少包含：

- baseline：启动前记录相关进程和端口。
- idle：Gate 3 成功后静置 30 秒，采样 3 次，每次间隔 10 秒。
- active：执行固定最小动作后采样 3 次，每次间隔 10 秒；固定动作至少包含 terminal 或轻量 X app 启动、一次 workspace/fullscreen 操作。
- Linux 侧进程：对 state 中 spike-owned PID 记录 `pid`、`ppid`、`stat`、`%cpu`、`rss`、`cmd`，并记录端口监听。
- Windows `vmmemWSL`：只作为可选粗粒度观察，不归因到单个 Linux 进程；如果记录，必须注明该限制。

## Resolved Questions

- Selkies/frontend 默认先走 pinned Selkies commit；frontend fallback 只有在默认路径失败并记录后才允许从已存在 pinned image digest 提取。
- 首轮最小成功只要求 HTTP localhost browser endpoint；HTTPS 3201 后置为可选观察项。
- 首轮 minimal action 不要求 Chromium；terminal 或指定轻量 X app 足够。Chromium 属于 Gate 4 usability observation。
- 资源记录由 status 或等价固定采样协议提供，不使用随意手动采样作为唯一证据。
