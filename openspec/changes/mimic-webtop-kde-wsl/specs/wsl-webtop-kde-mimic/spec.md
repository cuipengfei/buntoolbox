## ADDED Requirements

说明：本文档正文使用中文；`ADDED Requirements`、`Requirement`、`Scenario`、`SHALL`、`MUST`、`WHEN`、`THEN` 是 OpenSpec 规范关键字，按校验器要求保留英文。

### Requirement: Scope 必须限定为当前 WSL native KDE browser desktop

系统 SHALL 将本 capability 的实现目标限定为当前 WSL native 环境中可从 Windows 浏览器打开并使用完整 KDE desktop。

#### Scenario: 禁止 Docker/container/image 路线
- **WHEN** implementation 开始执行
- **THEN** implementation MUST NOT 使用 Docker、container、image、compose 或 Docker Desktop

#### Scenario: 禁止修改 buntoolbox 产品代码
- **WHEN** implementation 需要写入文件或修改配置
- **THEN** implementation MUST NOT 修改 buntoolbox 产品代码、Dockerfile、scripts、CI、README、image metadata、测试脚本或 release workflow

#### Scenario: 完成判断基于浏览器结果
- **WHEN** 判断 change 是否完成
- **THEN** 判断标准 MUST 是 Windows 浏览器中真实看到完整 KDE desktop，且视觉和交互与 LinuxServer Webtop KDE exactly same，除非 WSL hard limit

### Requirement: Webtop KDE 是 exact behavior template

系统 SHALL 以 LinuxServer Webtop KDE 的 browser desktop 行为作为精确模板，而不是近似参考。

#### Scenario: 必须复刻 browser desktop 交互
- **WHEN** Windows 浏览器打开 WSL 提供的本机 URL
- **THEN** 用户 MUST 看到完整 KDE Plasma desktop，包括桌面 shell、窗口管理、panel/launcher 和可启动的 Konsole 或 Dolphin

#### Scenario: 不能接受“像”或“差不多”
- **WHEN** 实际效果与 Webtop KDE 不一致
- **THEN** implementation MUST 继续修正，除非该差异被确认为 WSL hard limit

#### Scenario: WSL hard limit 必须明确
- **WHEN** implementation 保留任何差异
- **THEN** 差异 MUST 明确说明受哪个 WSL native 限制影响，例如 systemd/service supervisor、Wayland/X11/socket 权限、GPU/DRI/audio/input、network forwarding、certificate 或 browser API

#### Scenario: WSL hard limit 不能被滥用
- **WHEN** implementation 将差异归因于 WSL hard limit
- **THEN** 该限制 MUST 是经过合理 native 配置尝试后仍存在的平台/runtime 限制；缺包、未配置、未尝试的配置、实现困难、时间不足或便利取舍 MUST NOT 被归类为 WSL hard limit

### Requirement: Upstream source baseline 必须先建立

系统 SHALL 在执行 WSL native implementation 前建立可追溯的 LinuxServer Webtop KDE、baseimage-selkies、Selkies source baseline。

#### Scenario: 固定上游来源
- **WHEN** implementation 需要判断“与 Webtop KDE exactly same”
- **THEN** 判断 MUST 引用明确的 upstream branch、commit、file behavior，而不是主观印象、旧会话记忆或 trial-and-error 结果

#### Scenario: 上游源码优先级
- **WHEN** 本地经验、DeepWiki、Context7、网络资料或旧日志与上游源码不一致
- **THEN** implementation MUST 以当前确认的 upstream source inventory 为准，除非证明源码已经过时并刷新 source inventory

#### Scenario: 行为映射必须可追溯
- **WHEN** 设计 WSL native 等价组件
- **THEN** 每个关键组件 MUST 指向它 mimic 的上游行为节点，例如 `Dockerfile` env/package、`startwm_wayland.sh`、`kwin-xwayland.py`、`svc-selkies`、`svc-de`、nginx `/websocket` proxy 或 Selkies frontend/backend handshake

### Requirement: Distribution-faithful upstream reuse 必须优先

系统 SHALL 优先复用或忠实移植 LinuxServer Webtop KDE、baseimage-selkies 和 Selkies LSIO 的上游 runtime artifacts，不得用手写相似实现替代。

#### Scenario: 禁止手写 proxy/launcher/frontend 冒充
- **WHEN** implementation 需要提供 frontend、proxy、launcher 或 session startup
- **THEN** implementation MUST NOT 使用 handwritten proxy、handwritten launcher、handwritten frontend 或 looks-similar adapter，除非该替代通过 hard-limit proof template 并获得 critic/verifier sign-off

#### Scenario: 上游脚本不得被静默遗漏
- **WHEN** implementation 没有直接复用或忠实移植某个 upstream script 或关键行为
- **THEN** implementation MUST 列出 omitted source node、对应 branch/commit/path、遗漏原因、native WSL attempted config、failing symptom、chosen deviation 和 reviewer sign-off

#### Scenario: 禁止 arbitrary DISPLAY/env drift
- **WHEN** implementation 设置 display/session/Selkies/KDE env
- **THEN** `DISPLAY`、`WAYLAND_DISPLAY`、`XDG_RUNTIME_DIR`、`PIXELFLUX_WAYLAND`、`CUSTOM_WS_PORT`、`QT_QPA_PLATFORM`、`XDG_SESSION_TYPE`、`KDE_SESSION_VERSION` MUST match upstream source baseline unless a WSL hard-limit proof explicitly approves the drift

#### Scenario: 禁止 looks-similar 验收
- **WHEN** 浏览器画面看起来像 KDE 或像 Webtop
- **THEN** implementation MUST NOT mark DoD complete unless the result is source-backed and distribution-faithful to Webtop/Selkies behavior, including frontend asset/path, backend handshake, KDE session startup, and documented env/display contract

### Requirement: 失败处理必须 source-grounded

系统 SHALL 在任何失败或不一致发生时先回查 Webtop/Selkies source，再做最小实验。

#### Scenario: 禁止随机试错
- **WHEN** 出现白屏、黑屏、WebSocket 断连、waiting for server mode、KDE 闪现后退出、全屏不占满、输入/剪贴板/audio 异常或 session crash
- **THEN** implementation MUST NOT 随机装包、随机改 env、随机换 display server、随机换 streaming backend、随机杀进程或叠加 ad hoc hot fix

#### Scenario: 分层定位后再实验
- **WHEN** 需要修复失败
- **THEN** implementation MUST 先定位失败层级：browser frontend、nginx/proxy、websocket backend、Selkies frame/encoder pipeline、display server、KDE session、DBus、audio、clipboard/input、network/port；然后回查对应 upstream source，提出单一 hypothesis 和最小变更

#### Scenario: 空白页和黑屏排查源头
- **WHEN** 浏览器显示白屏、黑屏或 waiting for server mode
- **THEN** implementation MUST 优先核查 Selkies frontend/backend contract，包括 `/websocket` URL、`CUSTOM_WS_PORT`/proxy 对齐、backend 是否发送 `MODE websockets`、encoder/frame type/keyframe gate、fullscreen/resize/canvas 逻辑

#### Scenario: KDE session 问题排查源头
- **WHEN** KDE desktop 没有出现、只闪现、plasmashell 退出或 KWin/Xwayland 异常
- **THEN** implementation MUST 优先核查 Webtop KDE `startwm_wayland.sh`、`kwin-xwayland.py`、KDE env、DBus session、KWin compositing/autolock/clipboard rules 和 `svc-de` 启动顺序

### Requirement: MECE subagent concurrency 必须显式规划

系统 SHALL 将研究和执行任务拆成 MECE 切片以最大化 subagent 并发，同时由 main agent 统一编排和审阅。

#### Scenario: Discovery 可并行
- **WHEN** 进入 implementation 前的研究、映射、规划或审阅阶段
- **THEN** main agent MUST dispatch the listed MECE read-only subagent slices in parallel before implementation proceeds；切片包括 upstream source mapper、WSL baseline mapper、KDE session planner、Selkies/frontend planner、hard-limit verifier、critic/reviewer

#### Scenario: Mandatory slice 失败时不得继续 implementation
- **WHEN** 任何 mandatory read-only subagent slice 因工具错误、高负载、上下文问题或其他原因未成功完成
- **THEN** implementation MUST remain gated until that slice is rerun successfully or the user explicitly changes the requirement; main-agent fallback MAY inform diagnosis but MUST NOT satisfy the MECE subagent requirement

#### Scenario: WSL host mutation 必须串行
- **WHEN** 任务涉及 package install、service start/stop、port allocation、runtime file 写入、进程 kill、systemd 或 user service 配置
- **THEN** 这些 WSL host mutation MUST 由单一 executor 串行执行，其他 subagents MUST NOT 同时修改 WSL host 状态

#### Scenario: Main agent owns orchestration and review
- **WHEN** subagents 返回研究或实现结果
- **THEN** main agent MUST 审阅 source evidence、整合冲突结论、检查是否违反 no Docker/no productization/source-first triage，并决定下一步最小动作

### Requirement: Browser delivery 必须是 Webtop/Selkies-style streaming

系统 SHALL 使用 Webtop/Selkies-style browser streaming 方式提供 KDE 桌面。

#### Scenario: 服务关系正确
- **WHEN** KDE browser desktop 启动
- **THEN** 系统 MUST 具备 browser frontend、streaming backend、KDE desktop session、display/session services 的等价服务关系

#### Scenario: Selkies handshake 正确
- **WHEN** browser frontend 连接 backend
- **THEN** backend MUST 以 Webtop/Selkies websockets contract 工作：frontend 连接 `/websocket` 或 source-mapped 等价路径，upstream `default.conf` semantics 或最小 WSL-local adapter 指向 backend 的 `CUSTOM_WS_PORT`，backend 发送 `MODE websockets`，并随后进入 settings、capture、frame streaming 流程

#### Scenario: 禁止替代链路冒充成功
- **WHEN** WSLg 单应用窗口、VNC/noVNC、xrdp/RDP 或纯终端页面可用
- **THEN** 这些结果 MUST NOT 被记为本 capability 的成功

#### Scenario: Selkies 优先
- **WHEN** 选择 browser streaming 技术
- **THEN** implementation MUST 使用 Selkies；只有 Selkies 被确认受 WSL native hard limit 阻断时，才允许使用替代 streaming backend；替代 backend 仍 MUST 满足 Webtop/Selkies-style browser desktop 行为和完整 KDE Plasma desktop 呈现

### Requirement: KDE session 必须是完整 desktop

系统 SHALL 在 WSL native 中启动完整 KDE desktop session，而不是单个 KDE 应用。

#### Scenario: KDE desktop marker
- **WHEN** 浏览器显示 KDE session
- **THEN** session MUST 包含 Plasma Shell、窗口管理、Konsole 或 Dolphin、DBus/session runtime 中的关键能力

#### Scenario: 非完整桌面不通过
- **WHEN** 只显示单个 KDE app、terminal、登录错误页或空白页面
- **THEN** DoD MUST NOT 被标记为完成

### Requirement: DoD 不要求额外 evidence artifact

系统 SHALL 将 DoD 定义为实际浏览器可见结果，不把额外证据文件作为完成前置。

#### Scenario: 浏览器结果是完成标准
- **WHEN** Windows 浏览器打开本机 URL 并显示完整 KDE desktop
- **THEN** capability MUST NOT 被判定为完成，除非效果与 Webtop KDE exactly same，或所有差异都被明确证明为 WSL hard limit

#### Scenario: 证据文件不能替代视觉结果
- **WHEN** 只有命令输出、日志、截图说明或文档记录，但 Windows 浏览器没有实际显示完整 KDE desktop
- **THEN** implementation MUST NOT 被标记为完成

### Requirement: GPU/WSL 能力必须分层表达

系统 SHALL 把 KWin compositor、GUI app rendering、browser stream encoding 三层能力分开陈述，不能把任一层成功当作全部 GPU 加速成功。

#### Scenario: 最小成功不依赖 GPU
- **WHEN** 没有可用 GPU acceleration
- **THEN** browser-accessible KDE desktop 仍可满足最小成功标准，但前提是视觉和交互与 Webtop KDE exactly same，且没有声称 GPU 成功

#### Scenario: 不夸大 GPU/encoding
- **WHEN** 汇报 GPU 或 encoding 状态
- **THEN** implementation MUST 分别说明 compositor、app rendering、stream encoding 的状态，不能用设备存在或系统监控作为全部成功依据
