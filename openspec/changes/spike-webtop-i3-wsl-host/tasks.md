## 1. 预检与边界确认

- [ ] 1.1 读取并记录当前 WSL 基线：`/etc/os-release`、WSL/kernel 信息、当前 `DISPLAY`/`WAYLAND_DISPLAY`、已有 3000/3001/3200/3201 端口占用、已有 `i3`/`Xvfb`/`selkies`/`nginx` 进程。
- [ ] 1.2 读取并记录 webtop-i3 证据来源：`ubuntu-i3` Dockerfile、`baseimage-selkies` Dockerfile、`startwm.sh`、`svc-xorg`、`svc-de`、`svc-selkies`、nginx/frontend template、当前本地 image metadata 或 image digest；把证据路径、commit/digest、关键摘录和验证命令写入 records。未完成本项时，不得声明 webtop 链路已在本次 spike 中复核。
- [ ] 1.3 明确本次 spike 的 in-scope 和 out-of-scope，并记录不照搬 s6、abc 用户、sudoers、Docker-in-Docker、proot-apps、system nginx、固定 3000/3001、真实 `$HOME=/config` 的原因。
- [ ] 1.4 创建或确认变更记录文件位置，例如 `~/.local/share/webtop-i3/records/YYYY-MM-DD-log.md`，记录后续每个安装、文件写入、配置变更和回退方式。
- [ ] 1.5 完成 Gate 0 判定：source/provenance、WSL baseline、端口、已有进程、已有包状态都已记录后才能继续；失败时停止并记录缺失证据。

## 2. User-level runtime 结构

- [ ] 2.1 创建 user-level runtime 根目录结构：`config/`、`venv/`、`logs/`、`run/`、`frontend/`、`proxy/`、`records/`，并记录每个目录的用途和删除回退方式。
- [ ] 2.2 设计并记录环境变量策略：只在 spike 子进程中设置 `HOME=<runtime>/config`、`DISPLAY=:1`、`VIRTUAL_ENV=<runtime>/venv`、Selkies 相关变量，不修改真实 shell profile。
- [ ] 2.3 设计 pid/state 文件格式，至少记录组件名、PID、PPID 或 process group、session id、启动命令、cmdline 摘要、端口、bind address、日志路径、runtime 根目录、display、启动时间和 ownership marker。
- [ ] 2.4 记录所有新增 launcher/config 文件路径，并为每个文件写明删除或回退方式，不做大体积目录备份。

## 3. 依赖安装与 Selkies 验证

- [ ] 3.1 生成候选 apt 依赖清单，至少覆盖 `i3`、`dbus-x11`、`xvfb`、X11 tools、Python venv、Selkies/frontend/proxy 所需依赖；安装前记录已安装状态。
- [ ] 3.2 安装或验证系统依赖时，把命令、包名、安装前状态、安装后验证、建议回退命令写入 records；禁止安装 Docker CE/dind/proot 或修改 sudoers。
- [ ] 3.3 在独立 venv 中尝试安装 Selkies，默认 pin 到 webtop baseimage 使用的 Selkies commit `96e1abbf9ba0e44a8dabbc425fcb8312792fe303`；若失败，记录失败命令、日志、Python/venv 版本和删除 venv 的回退方式。
- [ ] 3.4 验证 `selkies --help` 或等价命令可运行，并记录 venv 路径、安装来源、版本/commit、失败日志和删除 venv 的回退方式。
- [ ] 3.5 按默认顺序验证 frontend assets：先使用 pinned Selkies 来源提供或构建出的 assets；仅在该路径失败并记录后，才允许从已存在 pinned image digest 中提取 assets；不得为了 fallback 新拉取 image，除非用户另行批准。记录选择理由、路径、验证方式、失败停止条件和回退方式。

## 4. 最小 webtop-i3 mimic 链路

- [ ] 4.1 启动 isolated `Xvfb :1`，参数尽量贴近 webtop `svc-xorg`，并记录 PID、日志、display、分辨率和停止方式。
- [ ] 4.2 通过 `dbus-launch --exit-with-session /usr/bin/i3` 在该 display 上启动 i3，并验证 i3 进程绑定到目标 display。
- [ ] 4.3 完成 Gate 1 判定：Xvfb+i3 都启动并绑定目标 display，state 与 records 写入 PID、ownership marker、日志和 display；失败时停止并记录日志。
- [ ] 4.4 启动 Selkies websocket backend，记录监听地址、backend websocket port、日志路径和与 Xvfb/i3 display 的连接方式；默认 bind `127.0.0.1`。
- [ ] 4.5 启动 user-level frontend/proxy，默认 HTTP browser endpoint 为 `127.0.0.1:3200` 或自动选择的 localhost 端口，记录 public endpoint、backend port、配置文件路径、日志和停止方式；HTTPS/3201 后置为可选观察项。
- [ ] 4.6 完成 Gate 2 判定：Selkies backend 连接目标 display，frontend/proxy 能提供 browser endpoint；失败时停止并记录失败阶段，不把 WSLg 或 VNC/noVNC 成功误记为 webtop mimic 成功。
- [ ] 4.7 完成 Gate 3 minimal action：用 Windows browser 访问 endpoint，看到 i3 session，启动 terminal 或指定轻量 X app，完成一个 i3 workspace/fullscreen 类动作；记录证据和失败日志。

## 5. start/stop/status 操作模型

- [ ] 5.1 设计 `webtop-i3-start` 行为：preflight、端口选择、runtime 目录检查、逐步启动 Xvfb/i3/Selkies/frontend、写入 state 和 records。
- [ ] 5.2 设计 `webtop-i3-stop` 行为：只读取本 spike state 中记录的 PID，并在 kill 前通过 `/proc/<pid>` 复核 cmdline、启动时间或 runtime/session marker；不匹配时只报警不 kill；不使用 broad `pkill i3`、`pkill Xvfb`、`pkill nginx`。
- [ ] 5.3 设计 `webtop-i3-status` 行为：报告 PID 存活、ownership 验证结果、public endpoint、backend port、bind address、日志路径、config path、runtime root、资源采样、疑似残留进程。
- [ ] 5.4 验证 stop 后无本 spike 启动的 Xvfb、i3、Selkies、frontend/proxy 残留；验证必须基于 state ownership marker，而不是按进程名 broad 搜索后直接 kill；把验证命令和输出摘要写入 records。

## 6. 试用记录与 buntoolbox adoption 判断

- [ ] 6.1 按固定采样协议记录资源：启动前 baseline；Gate 3 后 idle 静置 30 秒并采样 3 次、间隔 10 秒；active 执行 terminal/轻量 X app + workspace/fullscreen 动作后采样 3 次、间隔 10 秒；Linux 侧记录 state 中 PID 的 `pid`、`ppid`、`stat`、`%cpu`、`rss`、`cmd` 和端口；可选 Windows `vmmemWSL` 只标注为粗粒度观察，不归因到单个进程。
- [ ] 6.2 记录 i3 使用体验：workspace、fullscreen、terminal 或轻量 X app、快捷键、中文输入或字体问题、浏览器交互延迟；Chromium 属于可选观察项，不是 Gate 3 最小成功前置条件。
- [ ] 6.3 记录与 webtop container 的差异：GPU/NVENC、音频、HTTPS、nginx、Selkies frontend、container user model、s6 service model、Wayland/labwc/openbox fallback。
- [ ] 6.4 试用一段时间后在 records 或后续 OpenSpec proposal 中输出四选一决策记录：保留 WSL spike、清理回退、继续改进 spike、或创建新的 buntoolbox adoption proposal。

## 7. 回退演练

- [ ] 7.1 按 records 执行一次非破坏性回退检查：确认知道如何停止进程、删除 launcher、删除 runtime、删除 venv、回退 proxy/frontend 配置。
- [ ] 7.2 对 apt 包只给出建议回退清单，不自动删除可能被其他项目使用的包；记录哪些包是本 spike 新装，哪些原本已存在。
- [ ] 7.3 验证回退后不影响 buntoolbox repo、真实 `$HOME`、system nginx、sudoers、Docker daemon 和其他长期服务。
