# Gate 0 Evidence: add-webtop-i3-root-variant

采集日期：2026-05-09

本记录覆盖 tasks 1.1-1.6 的证据与决策。记录范围仅限 Gate 0 evidence；`tasks.md` 由主代理统一勾选。

## 约束

- 未执行 `docker pull`。
- 未执行 `docker build`。
- 未提交、未推送。
- 本地 Docker daemon 可用：`docker version --format '{{.Client.Version}} {{.Server.Version}}'` 输出 `29.4.1 29.4.0`。

## 1.1 Canonical webtop base evidence

### 命令

```bash
docker image ls --format '{{.Repository}}:{{.Tag}} {{.ID}} {{.Digest}}' \
  | grep -E '(^lscr\.io/linuxserver/webtop:ubuntu-i3|linuxserver/webtop:ubuntu-i3|webtop.*ubuntu-i3|buntoolbox.*i3)' || true

docker image inspect lscr.io/linuxserver/webtop:ubuntu-i3

docker image inspect linuxserver/webtop:ubuntu-i3 | jq '.[0] | {
  Id,
  RepoTags,
  RepoDigests,
  Config:{
    Entrypoint:.Config.Entrypoint,
    Cmd:.Config.Cmd,
    Env:.Config.Env,
    ExposedPorts:.Config.ExposedPorts,
    Labels:.Config.Labels
  }
}'
```

### 结果摘要

本地未找到 canonical tag `lscr.io/linuxserver/webtop:ubuntu-i3`：

```text
[]
Error response from daemon: No such image: lscr.io/linuxserver/webtop:ubuntu-i3
```

本地存在等价 Docker Hub tag `linuxserver/webtop:ubuntu-i3`：

```text
linuxserver/webtop:ubuntu-i3 e61c0978279f sha256:767ea42ee70457484a089a18a05e5a1ca9beabfddaef28941804de51726ab90c
```

对 `linuxserver/webtop:ubuntu-i3` 的 inspect 结果摘要：

```json
{
  "Id": "sha256:e61c0978279f704f95d986d45029799f8e7721fc3833747be4a2281d333a5f6a",
  "RepoTags": ["linuxserver/webtop:ubuntu-i3"],
  "RepoDigests": ["linuxserver/webtop@sha256:767ea42ee70457484a089a18a05e5a1ca9beabfddaef28941804de51726ab90c"],
  "Config": {
    "Entrypoint": ["/init"],
    "Cmd": null,
    "ExposedPorts": {
      "3000/tcp": {},
      "3001/tcp": {}
    }
  }
}
```

关键 Env：

```text
PATH=/lsiopy/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOME=/config
DISPLAY=:1
TITLE=Ubuntu i3
LSIO_FIRST_PARTY=true
```

关键 labels：

```text
build_version=Linuxserver.io version:- 3ea11274-ls272 Build-date:- 2026-05-08T17:17:47+00:00
org.opencontainers.image.ref.name=644ca2270fd0f8d22ce3d61145add4f89f4d9bd7
org.opencontainers.image.revision=644ca2270fd0f8d22ce3d61145add4f89f4d9bd7
org.opencontainers.image.source=https://github.com/linuxserver/docker-webtop
org.opencontainers.image.url=https://github.com/linuxserver/docker-webtop/packages
org.opencontainers.image.version=3ea11274-ls272
```

补充远端 manifest 查询：在不执行 `docker pull` 的前提下，使用临时空 `DOCKER_CONFIG` 运行 `docker buildx imagetools inspect lscr.io/linuxserver/webtop:ubuntu-i3`，返回 manifest list digest：

```text
Name:      lscr.io/linuxserver/webtop:ubuntu-i3
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:767ea42ee70457484a089a18a05e5a1ca9beabfddaef28941804de51726ab90c
linux/amd64 manifest: sha256:2daed62f7d65eebe1d9064d7394c4e315905c825c52ca85ee9c900a8b5868110
linux/arm64 manifest: sha256:c90e71c7bb25d4ae2db74ceaa736abd7886e03b8de09a707018e87d53061b9a6
```

结论：canonical `lscr.io/linuxserver/webtop:ubuntu-i3` 的 manifest list digest 已验证为 `sha256:767ea42ee70457484a089a18a05e5a1ca9beabfddaef28941804de51726ab90c`，与本地已有 `linuxserver/webtop:ubuntu-i3` 的 RepoDigest 摘要一致。canonical image 的 `build_version` / revision 仍未通过直接拉取 canonical tag 验证；当前 build_version/revision 证据来自本地 Docker Hub tag inspect，CI 已增加 i3 base provenance 输出用于后续收口。

## 1.2 Runtime `abc` inventory

### 命令

```bash
docker run --rm --entrypoint /bin/bash linuxserver/webtop:ubuntu-i3 -lc '
set -e
for d in /etc/s6-overlay /etc/services.d /etc/cont-init.d /etc/cont-finish.d /custom-services.d /defaults /usr/local/bin; do
  if [ -e "$d" ]; then
    c=$(grep -RInE "s6-setuidgid[[:space:]]+abc|su[[:space:]-].*abc|runuser.*abc|gosu[[:space:]]+abc|chown[[:space:]].*abc|pgrep[[:space:]].*-u[[:space:]]+abc|pkill[[:space:]].*-u[[:space:]]+abc|id[[:space:]].*abc|usermod.*abc|groupmod.*abc|lsiown[[:space:]]+abc|crontab[[:space:]].*-u[[:space:]]+abc|setpriv.*abc" "$d" 2>/dev/null | wc -l)
    printf "%s %s\n" "$d" "$c"
  else
    printf "%s MISSING\n" "$d"
  fi
done
grep -RInE "s6-setuidgid[[:space:]]+abc|su[[:space:]-].*abc|runuser.*abc|gosu[[:space:]]+abc|chown[[:space:]].*abc|pgrep[[:space:]].*-u[[:space:]]+abc|pkill[[:space:]].*-u[[:space:]]+abc|id[[:space:]].*abc|usermod.*abc|groupmod.*abc|lsiown[[:space:]]+abc|crontab[[:space:]].*-u[[:space:]]+abc|setpriv.*abc" \
  /etc/s6-overlay /etc/services.d /etc/cont-init.d /etc/cont-finish.d /custom-services.d /defaults /usr/local/bin 2>/dev/null | head -n 80 || true
'
```

### 结果摘要

```text
/etc/s6-overlay 67
/etc/services.d MISSING
/etc/cont-init.d MISSING
/etc/cont-finish.d MISSING
/custom-services.d MISSING
/defaults 0
/usr/local/bin 0
```

样例命中：

```text
/etc/s6-overlay/s6-rc.d/svc-watchdog/run:16:  if pgrep -o -u abc -f "$AUTOSTART_CMD" > /dev/null; then
/etc/s6-overlay/s6-rc.d/svc-watchdog/run:31:    s6-setuidgid abc $AUTOSTART_CMD &
/etc/s6-overlay/s6-rc.d/svc-xsettingsd/run:12:chown abc:abc "${HOME}/.xsettingsd"
/etc/s6-overlay/s6-rc.d/svc-xsettingsd/run:15:exec s6-setuidgid abc \
/etc/s6-overlay/s6-rc.d/init-video/run:10:    if id -u abc | grep -qw "${VIDEO_UID}"; then
/etc/s6-overlay/s6-rc.d/init-video/run:27:            usermod -a -G "${VIDEO_NAME}" abc
/etc/s6-overlay/s6-rc.d/svc-dbus/run:5:chown abc:abc /run/dbus
/etc/s6-overlay/s6-rc.d/svc-dbus/run:9:exec s6-setuidgid abc \
/etc/s6-overlay/s6-rc.d/svc-pulseaudio/run:3:exec s6-setuidgid abc \
/etc/s6-overlay/s6-rc.d/svc-xorg/run:37:exec s6-setuidgid abc \
/etc/s6-overlay/s6-rc.d/svc-de/run:54:exec s6-setuidgid abc \
/etc/s6-overlay/s6-rc.d/svc-selkies/run:63:exec s6-setuidgid abc \
/etc/s6-overlay/s6-rc.d/init-nginx/run:26:  chown -R abc:abc /config/ssl
/etc/s6-overlay/s6-rc.d/init-selkies-config/run:26:chown abc:abc "$HOME/.config"
/etc/s6-overlay/s6-rc.d/init-selkies-config/run:145:    chown root:abc "$AUTOSTART_SCRIPT"
/etc/s6-overlay/s6-rc.d/init-adduser/run:9:    usermod -d "/root" abc
/etc/s6-overlay/s6-rc.d/init-adduser/run:54:    lsiown abc:abc /app
/etc/s6-overlay/s6-rc.d/svc-cron/run:4:if builtin command -v crontab >/dev/null 2>&1 && [[ -n "$(crontab -l -u abc 2>/dev/null || true)" || -n "$(crontab -l -u root 2>/dev/null || true)" ]]; then
```

结论：本地等价 webtop image 的 runtime `abc` 行为集中在 `/etc/s6-overlay/s6-rc.d`，当前旧式 `/etc/services.d`、`/etc/cont-init.d`、`/etc/cont-finish.d`、`/custom-services.d` 不存在。后续 guard 必须覆盖 `/etc/s6-overlay/s6-rc.d`，不能只扫描旧式目录。

## 1.3 关键文件存在性

### 命令

```bash
docker run --rm --entrypoint /bin/bash linuxserver/webtop:ubuntu-i3 -lc '
for p in \
  /etc/services.d/svc-xorg/run \
  /etc/services.d/svc-de/run \
  /etc/services.d/svc-selkies/run \
  /etc/cont-init.d/init-selkies-config/run \
  /etc/cont-init.d/init-nginx/run \
  /defaults/startwm.sh \
  /usr/local/bin/startwm.sh; do
  if [ -e "$p" ]; then ls -ld "$p"; else printf "MISSING %s\n" "$p"; fi
done
'
```

### 结果摘要

```text
MISSING /etc/services.d/svc-xorg/run
MISSING /etc/services.d/svc-de/run
MISSING /etc/services.d/svc-selkies/run
MISSING /etc/cont-init.d/init-selkies-config/run
MISSING /etc/cont-init.d/init-nginx/run
-rwxr-xr-x 1 root root 380 May  8 17:15 /defaults/startwm.sh
MISSING /usr/local/bin/startwm.sh
```

结论：任务文本列出的关键 service/init 文件名在当前本地 image 中不位于旧路径；从 1.2 的 scan 输出可确认当前对应路径为 `/etc/s6-overlay/s6-rc.d/svc-xorg/run`、`/etc/s6-overlay/s6-rc.d/svc-de/run`、`/etc/s6-overlay/s6-rc.d/svc-selkies/run`、`/etc/s6-overlay/s6-rc.d/init-selkies-config/run`、`/etc/s6-overlay/s6-rc.d/init-nginx/run`。`/defaults/startwm.sh` 存在。

## 1.4 Apt base packages simulation on webtop base

### 命令

命令从当前根 `Dockerfile` 的 system base apt package list 采集，使用 webtop 临时容器内 `apt-get -s install` 模拟安装：

```bash
docker run --rm --entrypoint /bin/bash linuxserver/webtop:ubuntu-i3 -lc '
set -e
packages=(
ca-certificates curl wget gnupg lsb-release software-properties-common
build-essential pkg-config git git-lfs vim nano make cmake ninja-build
jq htop tree zip unzip xz-utils less tmux direnv zsh ripgrep fd-find fzf
bat btop iputils-ping iproute2 dnsutils netcat-openbsd traceroute socat
openssh-client openssh-server telnet file lsof psmisc bc
)
apt-get update
apt-get -s install --no-install-recommends "${packages[@]}"
'
```

### 结果摘要

`apt-get update` 成功完成并从 Ubuntu resolute、Docker、NodeSource、xtradeb 等源读取索引。`apt-get -s install` 的摘要为：

```text
The following NEW packages will be installed:
  bat bc bind9-dnsutils bind9-host bind9-libs btop build-essential bzip2
  direnv dpkg-dev fd-find fzf git-lfs htop inetutils-telnet iproute2
  iputils-ping less libbpf1 libdpkg-perl libevent-core-2.1-7t64 libgit2-1.9
  libgpm2 libjemalloc2 liblmdb0 liblsof0 libmaxminddb0 libpkgconf7
  libpython3.14 libsodium23 libtext-charwidth-perl libtext-wrapi18n-perl
  liburcu8t64 lsof lto-disabled-list nano ninja-build openssh-server
  openssh-sftp-server patch pkg-config pkgconf pkgconf-bin ripgrep socat
  telnet tmux traceroute tree ucf unzip vim vim-common vim-runtime wget
  xz-utils zip zsh zsh-common
0 upgraded, 59 newly installed, 0 to remove and 3 not upgraded.
```

输出中没有出现 `Remv` 行；本次模拟未显示 package removal/conflict。未执行真实安装，未验证安装后的 runtime 行为。

## 1.5 `CUSTOM_WS_PORT` decision

决策：保持 upstream 内部默认，不对外 expose；外部验收只验证 `3200`、`3201`，`3000` 留给 `openvscode-start` / openvscode-server。

理由：

- 当前本地 webtop base inspect 显示 upstream 对外暴露 `3000/tcp`、`3001/tcp`。
- 本 change 的目标端口语义要求 webtop HTTP/HTTPS 迁移到 `3200`/`3201`，并保留 `3000` 给 openvscode。
- Gate 0 未发现必须暴露 `CUSTOM_WS_PORT` 的证据。

实现/测试策略：

- i3 image 设置 webtop HTTP/HTTPS 外部默认端口为 `CUSTOM_PORT=3200`、`CUSTOM_HTTPS_PORT=3201`。
- 不新增 `CUSTOM_WS_PORT` 的 Docker `EXPOSE`。
- i3 runtime tests 验证 webtop HTTP 在 `3200` 响应、HTTPS 策略覆盖 `3201`、webtop 不监听 `3000`。
- `3000` 的验收归属 openvscode-server：验证 `openvscode-start` 可手动启动并监听/服务 `3000`。

## 1.6 openvscode-server auto-start decision

决策：`buntoolbox:i3` 不默认自动启动 openvscode-server；`openvscode-start` 手动启动占用 `3000` 是验收路径。

理由：

- 当前 `buntoolbox:latest` 的 README/设计语义是通过 `openvscode-start` 使用默认端口 `3000`。
- i3 image 的默认 entrypoint 应保留 webtop `/init` 以启动 browser desktop GUI stack。
- 自动启动 openvscode-server 会增加默认进程与端口竞争面；Gate 0 未发现必须自动启动的需求或证据。

验收策略：

- i3 默认 runtime 启动 webtop GUI，不启动 openvscode-server。
- 测试中显式运行 `openvscode-start`，确认其可在 `3000` listen/serve。
- Webtop runtime test 同时证明 webtop 不占用 `3000`。

## 已收口验证

本 change 后续已通过 GitHub Actions 和本地 post-push image smoke tests 收口。项目约束仍然是不在本机执行耗时 `docker build`；真实 build 由 GitHub Actions 完成，本机只执行 pull/test。

### GitHub Actions 验证

- Run `25601833365`（commit `cef8323`）成功完成 `latest` 与 `i3` 的 build/test/push，全流程用时 `8m02s`。
- Run `25602411197`（commit `0778dae`，升级 `uv` 和 `claude`）成功完成 `latest` 与 `i3` 的 build/test/push，全流程用时 `7m59s`。
- `latest` CI 路径：先 build `buntoolbox:ci-latest-test`，再运行 `bash ./scripts/test-image.sh --no-pull --variant latest buntoolbox:ci-latest-test`，通过后发布 `latest`。
- `i3` CI 路径：先 build `buntoolbox:ci-i3-test`，记录 `lscr.io/linuxserver/webtop:ubuntu-i3` provenance，再运行 `bash ./scripts/test-image.sh --no-pull --variant i3 buntoolbox:ci-i3-test`，通过后发布 `i3`。
- `Record i3 base provenance` 在 CI 中执行 `docker buildx imagetools inspect lscr.io/linuxserver/webtop:ubuntu-i3`，并从 `buntoolbox:ci-i3-test` 的 `/etc/image-release` 输出 build/version/revision 相关记录。

### 本地 post-push image 验证

已对 Docker Hub 上发布后的两个 tags 执行本地 smoke tests：

```bash
./scripts/test-image.sh --variant latest --image cuipengfei/buntoolbox:latest
./scripts/test-image.sh --variant i3 --image cuipengfei/buntoolbox:i3
```

结果：

- `cuipengfei/buntoolbox:latest`: `83 passed, 0 failed`。
- `cuipengfei/buntoolbox:i3`: `89 passed, 0 failed`。
- `i3` 多出的 6 项 runtime checks 验证：`whoami=root`、`HOME=/root`、webtop HTTP 在 `3200` 响应、webtop 不监听 `3000`、`openvscode-start` 可在 `3000` 服务、关键 GUI processes 不以 `abc` 运行。
- `i3` root-first guard fixture 已验证：受控 fatal `abc` runtime pattern 会被拒绝。

### 版本与层复用观察

- `uv` 已升级并验证为 `0.11.12`。
- `claude` 已升级并验证为 `2.1.126`。
- 升级后本地 pull 观察显示：`latest` 前段大量 layers 为 `Already exists`，只拉后段约 14 个新 layers；`i3` 前段大量 layers 为 `Already exists`，只拉后段约 15 个新 layers。
- 本地 inspect 显示当前 `latest` 为 60 layers、约 2.64GB；当前 `i3` 为 81 layers、约 5.10GB。

### 仍需注意的边界

- 本地没有执行 `docker build`；这是项目约束而不是未完成验证。真实 build/test/push 由 GitHub Actions 收口。
- `latest` 与 `i3` 是 sibling images，最终 RootFS layer digest 不共享；它们共享的是维护层面的版本来源、安装脚本和测试逻辑。
- Webtop upstream tag 未来可能 drift；root-first patch 与 guard 的目的就是在 upstream 重新引入未审查 `abc` runtime 行为时 fail closed。
