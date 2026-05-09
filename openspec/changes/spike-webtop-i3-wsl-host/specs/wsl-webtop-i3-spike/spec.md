## ADDED Requirements

### Requirement: 用户级 webtop-i3 runtime 隔离
本 spike MUST 把持久化 runtime 状态放在用户级目录下，并且不得要求修改用户真实 home、system nginx service、sudoers、Docker daemon 或 buntoolbox 源码文件。

#### Scenario: 创建 runtime 目录
- **WHEN** spike 准备 runtime 状态
- **THEN** config、venv、logs、pid/state 文件、frontend/proxy 文件和 records 都放在用户级 webtop-i3 目录下

#### Scenario: 真实 home 保持不变
- **WHEN** spike 启动 i3 或 Selkies 进程
- **THEN** 任何 `HOME=/config` mimic 行为都只作用于这些子进程，用户真实 shell 的 home 保持不变

### Requirement: 浏览器 mimic 链路
在声明自己 mimic webtop-i3 之前，spike MUST 实现或显式验证 webtop 风格链路：`Xvfb -> i3 -> Selkies websocket -> browser frontend/proxy`。

#### Scenario: Xvfb 先于 i3 启动
- **WHEN** browser mimic mode 启动
- **THEN** 先启动隔离的 Xvfb display，再用 `dbus-launch` 把 i3 启动到该 display 上

#### Scenario: Selkies 是 webtop mimic 的必需部分
- **WHEN** spike 声称具备 browser-streamed webtop mimic 行为
- **THEN** 已按记录的 webtop provenance pin 住 Selkies，或记录了 Selkies source/version 偏离及明确理由，并且 Selkies 已运行且连接到 i3 display

#### Scenario: frontend fallback 受限
- **WHEN** 默认 Selkies frontend assets 路径失败
- **THEN** 只有在记录失败日志和 pinned image digest 后，才允许从已存在的 pinned image 中提取 frontend assets；不得为了 fallback 新拉取 image，除非用户另行批准

#### Scenario: 最小浏览器动作成功
- **WHEN** spike 报告最小 webtop-i3 mimic 成功
- **THEN** Windows browser 能访问 localhost endpoint、看到 i3 session、启动 terminal 或指定轻量 X app，并完成一个 i3 workspace 或 fullscreen 类动作

#### Scenario: VNC 和 WSLg 不被误标
- **WHEN** 探索过程中使用了 VNC/noVNC 或 WSLg-only 路径
- **THEN** 结果必须记录为 non-webtop-mimic fallback 或 comparison，不得记录为成功的 webtop-i3 mimic

### Requirement: 安全进程生命周期
spike MUST 提供 start、stop 和 status 操作，并且这些操作只能管理本 spike 创建的进程。

#### Scenario: start 记录进程状态
- **WHEN** spike 启动 Xvfb、i3、Selkies 或 frontend/proxy 进程
- **THEN** state 文件记录它们的 PID、PPID 或 process group、session id、start time、command 或 cmdline 摘要、port、bind address、log path、display 和 runtime directory

#### Scenario: stop 避免 broad kill
- **WHEN** spike 执行停止操作
- **THEN** 先用 `/proc/<pid>` ownership 证据校验每个已记录 PID，例如 cmdline、start time、session id 或 runtime marker，然后再停止；并且不得依赖杀掉所有 `i3`、所有 `Xvfb` 或所有 `nginx` 这类 broad command

#### Scenario: 陈旧 PID 不被 kill
- **WHEN** 已记录 PID 不再匹配 spike ownership 证据
- **THEN** stop 报告该 mismatch，并且不得 kill 该 PID

#### Scenario: status 报告证据
- **WHEN** 用户运行 status
- **THEN** status 报告进程存活状态、ownership validation、public endpoint、backend port、bind address、log path、config path、resource samples，以及任何检测到的 spike-owned 残留进程

### Requirement: 分 gate 执行和最小成功标准
spike MUST 按显式 gate 推进，并且在最小浏览器动作和安全停止检查通过之前，不得声明成功。

#### Scenario: Gate 0 记录 provenance
- **WHEN** spike 开始执行
- **THEN** 记录 WSL baseline、port/process/package baseline，以及 webtop source provenance，例如 Dockerfile path、commit 或 digest、关键 service 文件和验证命令

#### Scenario: gate 定义停止条件
- **WHEN** Xvfb/i3、Selkies/frontend 或 browser minimal action 失败
- **THEN** spike 记录失败 gate、日志、rollback guidance 和下一步允许动作，而不是静默切换到另一套架构继续

#### Scenario: 可选观察项不作为成功 gate
- **WHEN** 测试 Chromium、HTTPS、audio、GPU/NVENC、中文输入或 Wayland/labwc 行为
- **THEN** 这些结果记录为 usability observation 或差异项，不要求它们通过后才算最小 webtop-i3 mimic 成功

### Requirement: localhost 端口角色
spike MUST 定义 browser-facing 和 backend 端口角色，并且默认只绑定 localhost。

#### Scenario: browser endpoint 是本地端口
- **WHEN** frontend/proxy 启动
- **THEN** browser-facing endpoint 默认绑定 `127.0.0.1`，可用时优先使用 port `3200`，记录实际 URL，并避免固定使用 `3000` 或 `3001`

#### Scenario: backend port 被明确标识
- **WHEN** Selkies 或 websocket backend 监听独立端口
- **THEN** state 把该 backend port 与 browser endpoint 分开记录，并且 backend port 默认绑定 localhost

### Requirement: 变更与回退记录
spike MUST 记录所有安装、文件写入、配置变更、端口选择和环境变量，以便复现或回退 setup，同时不得创建大体积备份。

#### Scenario: 安装被记录
- **WHEN** spike 安装或计划安装系统包、Python 包或 frontend assets
- **THEN** records 记录 command、package/source、适用时的 prior installed/manual/auto state、reason、verification result 和 manual rollback guidance

#### Scenario: 文件变更被记录
- **WHEN** spike 创建或修改 launcher、config file、venv、frontend/proxy file 或 runtime state file
- **THEN** records 记录 path、purpose、change owner，以及如何删除或回退

#### Scenario: 避免大体积备份
- **WHEN** 捕获 rollback 信息
- **THEN** spike 记录如何回退，而不是复制大目录或 image contents 作为备份

### Requirement: 资源采样协议
spike MUST 为 idle 和 active observation 使用可重复的资源采样协议。

#### Scenario: idle 和 active samples 可比较
- **WHEN** 为 adoption 判断记录资源占用
- **THEN** records 包含 startup baseline、quiet period 后的三次 idle samples、固定 terminal 或轻量 X app 加 i3 workspace/fullscreen 动作后的三次 active samples、sampling intervals、commands used，以及每个 spike PID 的 CPU/RSS data

#### Scenario: Windows vmmemWSL 是粗粒度数据
- **WHEN** 记录 Windows `vmmemWSL` 或等价 host observation
- **THEN** 明确标注它是可选的 WSL-wide 粗粒度数据，不能归因到单个 Linux process

### Requirement: 显式 scope 边界
spike MUST 记录哪些 LinuxServer webtop 组件被有意排除在 WSL host mimic 之外，并说明原因。

#### Scenario: 排除 container-only 组件
- **WHEN** design 或 implementation 讨论 s6-overlay、`abc` user、sudoers changes、Docker-in-Docker、proot-apps、fake udev、joystick interposer 或 full locale/theme builds
- **THEN** 每个被省略的组件都标为 out of scope，并给出与 WSL safety、pollution risk 或 i3 workflow testing 无关性相关的原因

#### Scenario: 不承诺 GPU 和 audio parity
- **WHEN** spike 报告成功
- **THEN** 明确说明 GPU/NVENC、DRI/Zink、audio、HTTPS 和 Wayland/labwc parity 是已验证、已省略，还是留到后续
