## 1. Gate 0 evidence 与设计收口

- [x] 1.1 记录 webtop base 证据：`lscr.io/linuxserver/webtop:ubuntu-i3` 的 manifest digest；本地已有等价 digest 的 `linuxserver/webtop:ubuntu-i3` 的 `build_version`、upstream revision、`Entrypoint`、`Cmd`、`Env`、`ExposedPorts`；并在 evidence 中明确 canonical tag 的 build metadata 仍需 CI provenance 输出收口。
- [x] 1.2 记录 webtop runtime `abc` inventory：扫描 `/etc/s6-overlay`、`/etc/services.d`、`/etc/cont-init.d`、`/etc/cont-finish.d`、`/custom-services.d`、`/defaults`、`/usr/local/bin` 和相关 wrapper，保存命令与输出摘要。
- [x] 1.3 记录 webtop 关键文件存在性：至少覆盖 `svc-xorg/run`、`svc-de/run`、`svc-selkies/run`、`init-selkies-config/run`、`init-nginx/run`、`startwm.sh`。
- [x] 1.4 记录在 webtop base 上模拟安装当前 buntoolbox apt base packages 的命令和输出摘要，确认是否存在 remove/conflict。
- [x] 1.5 明确 `CUSTOM_WS_PORT` 决策：保持 upstream 默认或迁移到新端口；记录 expose/test 策略和理由。
- [x] 1.6 明确 openvscode-server 在 `buntoolbox:i3` 中是否默认自动启动；若不自动启动，记录 `openvscode-start` 手动启动为验收路径。

## 2. 抽取共享构建层并保持 latest 兼容

- [x] 2.1 新增共享构建目录结构，例如 `docker/layers/`，并把现有 Dockerfile 的 apt base package 安装抽成可复用脚本。
- [x] 2.2 抽取 JDK、Python、Maven、GitHub CLI、Node、低频 CLI、中频 CLI、高频 CLI、beads、shell config、image-release 等层，保持接近现有 Dockerfile 的 layer 顺序和 cache 粒度。
- [x] 2.3 将工具版本从根 Dockerfile ARG 迁移到细粒度共享 env/snippet 或等价单点来源，避免 `latest` 与 `i3` 双份版本漂移。
- [x] 2.4 更新根 `Dockerfile` 使用共享 layer scripts，同时保持 `FROM ubuntu:26.04`、`EXPOSE 22 7681`、`CMD ["/bin/bash"]` 和 openvscode/ttyd 既有语义。
- [x] 2.5 确保高频工具层独立：修改 beads/rtk/claude 等高频版本不得使 JDK、Python、Node 等早期重层因单个大 install-all 层而重建。
- [x] 2.6 运行静态检查确认共享 shell scripts 可解析：使用 portable `find scripts docker -name '*.sh' -print0 | xargs -0 bash -n` 或等价命令。

## 3. 新增 i3 image 构建路径

- [x] 3.1 新增 `Dockerfile.i3` 或等价 i3 build entry；后续已收敛为 `docker/webtop/Dockerfile` shared entry，base 通过 `WEBTOP_BASE=lscr.io/linuxserver/webtop:ubuntu-i3` 或明确记录的 digest/tag 指定。
- [x] 3.2 在 i3 build 中设置 root-first env：`HOME=/root`、`CUSTOM_USER=root`、`CUSTOM_PORT=3200`、`CUSTOM_HTTPS_PORT=3201`，并按第 1.5 项处理 `CUSTOM_WS_PORT`。
- [x] 3.3 保留 webtop `/init` 作为默认 GUI stack entrypoint，除非第 1.6 项明确另一个默认 runtime model。
- [x] 3.4 在 i3 build 中复用共享 buntoolbox toolchain layers，不复制完整根 Dockerfile 工具安装内容。
- [x] 3.5 设置 i3 image metadata 和 exposed ports，至少覆盖 `22`、`3000`、`3200`、`3201`、`7681`，并与 docs/test 保持一致。

## 4. Root-first webtop patch 与 guard

- [x] 4.1 新增 root-first preflight/guard 脚本，pre-patch 阶段打印 upstream revision/build_version、runtime `abc` inventory 和关键文件存在性。
- [x] 4.2 新增 root-first patch，覆盖 `s6-setuidgid abc`、`chown abc:abc`、`chown root:abc`、`pgrep -u abc`、`id/usermod/groupmod/lsiown/crontab` 等 runtime `abc` 行为。
- [x] 4.3 patch application 必须严格：上下文不匹配、patch reject 或未预期文件变化时 build 失败，不静默继续。
- [x] 4.4 post-patch guard 必须 broad scan runtime surface，而不是只检查已知文件；发现 fatal `abc` runtime pattern 时 build 失败。
- [x] 4.5 guard 必须允许 `/etc/passwd` 中保留 `abc` account，并区分文档/注释中的 `abc` 与 runtime user/process/ownership 语义中的 `abc`。
- [x] 4.6 guard 必须检查 `/config` 引用；影响 interactive HOME、Desktop、menu、XDG、terminal、file manager 默认路径的 `/config` 引用必须被 patch 到 `/root` 或导致失败。

## 5. 测试脚本共享与 variant checks

- [x] 5.1 重构 `scripts/test-image.sh`，保持无参数默认测试 `cuipengfei/buntoolbox:latest`。
- [x] 5.2 抽取 common buntoolbox tool checks 到共享测试逻辑，例如 `scripts/lib/test-common-tools.sh` 或等价结构。
- [x] 5.3 更新测试脚本的版本读取逻辑，使其读取共享版本来源，而不是只从根 Dockerfile ARG 读取。
- [x] 5.4 增加 i3 variant 测试入口，例如 `scripts/test-image.sh --variant i3 <image>`，复用 common tool checks。
- [x] 5.5 i3 variant checks 必须验证：webtop HTTP 在 `3200` 响应、webtop 未监听 `3000`、`openvscode-start` 可监听并服务 `3000`。
- [x] 5.6 i3 variant checks 必须验证 root-first：interactive shell 或等价命令显示 `whoami=root`、`HOME=/root`，关键 GUI/runtime 进程不以 `abc` 运行。
- [x] 5.7 i3 variant checks 必须验证 root-first guard 生效；可通过 fixture 或受控扫描样例证明新增 fatal `abc` runtime pattern 会 fail。

## 6. GitHub Actions 发布路径

- [x] 6.1 保留现有 latest build/tag/push 路径，确保 i3 build 不会发布 `latest`。
- [x] 6.2 新增 i3 build metadata 和 build-push step/job，使用 `Dockerfile.i3` 或后续 shared `docker/webtop/Dockerfile` 等价入口。
- [x] 6.3 PR 中 `latest`、`i3` 均 build/test 但不 push；后续 KDE 扩展要求 `latest`、`i3`、`kde` 均 build/test 但不 push。
- [x] 6.4 default branch push 发布 `latest` 和 `i3`；后续 KDE 扩展还发布 `kde`。
- [x] 6.5 release tag 发布 `X.Y.Z`、`X.Y`、`i3-X.Y.Z`、`i3-X.Y`；后续 KDE 扩展还发布 `kde-X.Y.Z`、`kde-X.Y`。
- [x] 6.6 workflow_dispatch 的 verification tag / override 行为如需支持 GUI variants，必须明确命名，避免 verification tag 误覆盖 latest、i3 或 kde。

## 7. 文档与 metadata

- [x] 7.1 更新 README，明确 `cuipengfei/buntoolbox:latest` 是既有 terminal/TUI image，`cuipengfei/buntoolbox:i3` 是 browser-delivered i3 desktop image；后续 KDE 扩展还需明确 `cuipengfei/buntoolbox:kde` 是 browser-delivered KDE desktop image。
- [x] 7.2 README i3 示例必须包含 `3200` webtop GUI 端口、`3000` openvscode 端口、`7681` ttyd 端口，并说明 `3201` HTTPS 行为。
- [x] 7.3 README i3 示例必须包含 desktop runtime 注意项，例如 `--shm-size=1gb` 或等价说明。
- [x] 7.4 README 必须包含 local-only/security warning，说明 browser desktop endpoint 不应无保护直接暴露到公网。
- [x] 7.5 更新 `image-release.txt` 或 variant-specific metadata，确保 latest、i3 与 kde 的身份、base 和端口语义可追踪。
- [x] 7.6 文档必须说明 `buntoolbox:i3` / `buntoolbox:kde` 是 root-first；`abc` account 即使存在也不是正常交互 workflow。

## 8. 验证与收口

- [x] 8.1 运行 `openspec validate add-webtop-i3-root-variant --strict` 并修复所有错误。
- [x] 8.2 运行 shell syntax checks，至少覆盖 `scripts/` 与新增 `docker/` 下所有 shell scripts。
- [x] 8.3 验证 `scripts/test-image.sh` 默认路径仍指向 latest，并能运行 common checks。
- [x] 8.4 验证 i3 variant test path 能运行 common checks 和 i3 runtime checks。
- [x] 8.5 验证 CI 配置语义：PR 不 push，default branch 发布 `latest`、`i3`、`kde`，release tag 发布 semver、i3-semver、kde-semver。
- [x] 8.6 记录无法在本地完成的重型验证，例如 Docker build/push，交由 GitHub Actions 或用户批准后的环境执行。
