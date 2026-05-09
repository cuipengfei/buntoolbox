# Buntoolbox

> **Bun** + **Ubuntu** + **Toolbox** = 全能开发环境 Docker 镜像

**Ideal for Windows users with WSL disabled by enterprise policy** - provides a complete Linux development environment via Docker.

## 包含组件

- **运行时**: Bun, Node.js 24, Python 3.14 (pip/uv/pipx), HTTPie, Claude Code, rtk (Rust Token Killer)
- **JDK**: Azul Zulu 25 headless
- **基础镜像**: Ubuntu 26.04 LTS
- **常用工具**: git, gh, jq, ripgrep, fd, fzf, tmux, zellij, lazygit, helix, bat, eza, delta, btop, starship, zoxide, procs, duf, HTTPie, Claude Code, rtk, zsh (oh-my-zsh), bd, sshd, openvscode-server, ttyd 等

## 使用方式

### Image Variants

- `cuipengfei/buntoolbox:latest` 是既有 terminal/TUI image，面向 shell、SSH、OpenVSCode Server 和 ttyd 等开发工作流。
- `cuipengfei/buntoolbox:i3` 是 browser-delivered i3 desktop image，面向需要在浏览器里打开 i3 desktop GUI 的场景。
- `cuipengfei/buntoolbox:kde` 是 browser-delivered KDE desktop image，面向需要更接近传统桌面/Windows-like GUI 的场景。
- `latest` 不包含 GUI desktop stack；需要浏览器桌面时请显式选择 `i3` 或 `kde` tag。
- 三个 image 共享 buntoolbox toolchain 版本来源和测试逻辑；`i3` / `kde` 在 common tool checks 之外额外运行 webtop/root-first runtime checks。

### Basic Usage

```bash
docker pull cuipengfei/buntoolbox:latest
docker run -it cuipengfei/buntoolbox
```

### Browser i3 Desktop Variant

`cuipengfei/buntoolbox:i3` 提供 browser-delivered i3 desktop，并保留 buntoolbox 的开发入口端口语义：

- `3200`: webtop GUI HTTP endpoint
- `3201`: webtop GUI HTTPS endpoint
- `3000`: OpenVSCode Server (`openvscode-start` 默认端口)
- `7681`: ttyd web terminal

```powershell
docker run -d --name mydev-i3 `
  --shm-size=1gb `
  -p 3200:3200 `
  -p 3201:3201 `
  -p 3000:3000 `
  -p 7681:7681 `
  -v ${PWD}:/workspace `
  cuipengfei/buntoolbox:i3

# Browser desktop GUI:
#   http://localhost:3200
#   https://localhost:3201
# Optional developer services inside the same container:
#   openvscode-start   # serves on http://localhost:3000 by default
#   ttyd-start         # serves on http://localhost:7681 by default
```

Desktop runtime note: keep at least `--shm-size=1gb` or an equivalent shared-memory setting for browser/desktop workloads. Without enough `/dev/shm`, Chromium- or desktop-heavy sessions may become unstable.

Security note: treat the i3 desktop endpoint as local-only unless you add appropriate protection. Do not expose `3200`/`3201`, `3000`, or `7681` directly to the public internet without authentication, TLS/proxy controls, firewall rules, or another access-control layer.

Root-first note: `buntoolbox:i3` is designed for normal interactive workflows as `root` with `HOME=/root`. The LinuxServer/Webtop base may still contain an `abc` account for upstream compatibility, but `abc` is not the normal buntoolbox i3 desktop workflow.

Validation note: CI builds and tests all variants before publishing. `latest` runs the common toolchain smoke tests; browser desktop variants run the same common tests plus checks for webtop on `3200`, OpenVSCode availability on `3000`, root-first session behavior, and absence of critical `abc` GUI processes.

### Browser KDE Desktop Variant

`cuipengfei/buntoolbox:kde` 提供 browser-delivered KDE desktop，并保留与 i3 variant 相同的 buntoolbox 端口语义：

- `3200`: webtop GUI HTTP endpoint
- `3201`: webtop GUI HTTPS endpoint
- `3000`: OpenVSCode Server (`openvscode-start` 默认端口)
- `7681`: ttyd web terminal

```powershell
docker run -d --name mydev-kde `
  --shm-size=1gb `
  -p 3200:3200 `
  -p 3201:3201 `
  -p 3000:3000 `
  -p 7681:7681 `
  -v ${PWD}:/workspace `
  cuipengfei/buntoolbox:kde

# Browser desktop GUI:
#   http://localhost:3200
#   https://localhost:3201
# Optional developer services inside the same container:
#   openvscode-start   # serves on http://localhost:3000 by default
#   ttyd-start         # serves on http://localhost:7681 by default
```

KDE runtime note: this image is based on LinuxServer Webtop Ubuntu KDE, which is Wayland-only upstream. It is heavier than `i3`, but offers a more traditional desktop feel.

Security and root-first notes are the same as `i3`: keep desktop endpoints local-only unless protected, and expect normal interactive workflows to run as `root` with `HOME=/root`.

#### KDE GPU acceleration on Windows + Docker Desktop + WSL2

For the KDE flavor, the practical Windows GPU path we can verify on Docker Desktop's WSL2 backend is WSLg/Mesa D3D12. This can make Linux OpenGL GUI applications inside the Webtop desktop use the Windows GPU as much as this stack allows.

This section requires Docker Desktop's WSL2 backend. If your environment truly forbids WSL2 entirely, do not design the KDE flavor around GPU acceleration; run it as CPU-rendered Webtop instead.

Use this run shape when Docker Desktop is using the WSL2 backend and the host WSL filesystem contains `/dev/dxg` and `/usr/lib/wsl`. This is a buntoolbox-tested WSLg path, not a LinuxServer/Webtop upstream guarantee:

```powershell
docker run --rm -d --name mydev-kde-gpu `
  --shm-size=1gb `
  --device /dev/dxg `
  --mount type=bind,source=/usr/lib/wsl,target=/usr/lib/wsl,readonly `
  -e LD_LIBRARY_PATH=/usr/lib/wsl/lib `
  -e GALLIUM_DRIVER=d3d12 `
  -e LIBVA_DRIVER_NAME=d3d12 `
  -e DISABLE_DRI3=true `
  -p 3200:3200 `
  -p 3201:3201 `
  -p 3000:3000 `
  -p 7681:7681 `
  -v ${PWD}:/workspace `
  cuipengfei/buntoolbox:kde
```

Open the desktop at `http://localhost:3200`.

Verify app-level OpenGL GPU rendering inside the container:

```bash
docker exec mydev-kde-gpu glxinfo -B
docker exec mydev-kde-gpu eglinfo
```

Expected good evidence includes:

- `OpenGL renderer string: D3D12 (...)`
- `Vendor: Microsoft Corporation`
- `Accelerated: yes`
- a visible OpenGL app such as `glxgears -info` showing `GL_RENDERER = D3D12 (...)`

Do not treat `btop`, `nvidia-smi`, or `--gpus all` alone as proof that the KDE desktop compositor is using GPU rendering. Those are different layers. In this stack:

- Container GPU visibility is provided by `/dev/dxg` plus the WSL libraries mounted at `/usr/lib/wsl`.
- Linux OpenGL GUI apps can render through Mesa's `d3d12` driver.
- WSL's `/dev/dri/card0` should not be treated like a normal KMS-capable Linux display device for KWin. On the validated host it reported `drmIsKMS = 0`.
- Docker Desktop's `--gpus all` path is primarily the NVIDIA compute/CUDA path and is not the required path for WSLg OpenGL GUI rendering.
- Webtop/Selkies stream encoding acceleration is separate again. LinuxServer documents `/dev/dri`/NVIDIA paths for that layer, but does not document WSLg `/dev/dxg` as a supported Webtop encoding path.
- KDE/KWin compositor acceleration is separate from application OpenGL acceleration. In Docker Desktop + WSL2 Webtop, design around KWin using its software compositor path even while OpenGL apps are GPU accelerated.

VAAPI stream-encoding status for this WSLg path:

- `vainfo --display drm --device /dev/dri/renderD128` can report Mesa D3D12 H.264 encode entrypoints when `/dev/dxg`, `/dev/dri`, and `/usr/lib/wsl` are passed into a test container.
- That is not enough to switch Selkies to hardware encoding. In local PoC, FFmpeg `h264_vaapi` initialized successfully but produced a zero-byte H.264 stream, and GStreamer `vaapih264enc` failed to produce a reliable encoded stream.
- The newer GStreamer `vah264enc` element was not available from the tested Ubuntu 26.04 packages, and the legacy `gstreamer1.0-vaapi` path exposed `vaapih264enc`, not `vah264enc`.
- Current LinuxServer Webtop runs Selkies in WebSocket/Pixelflux mode. In that mode `SELKIES_ENCODER` accepts Webtop values such as `x264enc`, `x264enc-striped`, and `jpeg`; it does not accept GStreamer element names like `vah264enc` or `nvh264enc`.
- `SELKIES_DRI_NODE=/dev/dri/renderD128` is the right knob to experiment with Selkies VAAPI on this stack, while keeping `SELKIES_ENCODER=x264enc` and `SELKIES_USE_CPU=false`. A local debug run confirmed Selkies read `dri_node=/dev/dri/renderD128` and initialized the Wayland GL renderer with that device.
- Therefore the KDE image should keep Selkies on its stable `x264enc,jpeg` default on this WSLg path. Do not change the image default to a VAAPI encoder unless a fresh end-to-end Selkies/Webtop session proves non-CPU stream encoding without blank output, crashes, or text-quality regressions.

For maximum reliability on this stack, optimize for GPU-accelerated GUI apps, not for forcing KWin itself to become an OpenGL compositor. For a lower-resource browser desktop, prefer the `i3` variant.

### Windows (WSL Disabled) - Project Development

```powershell
# Mount your project folder into the container
docker run -it -v ${PWD}:/workspace -w /workspace cuipengfei/buntoolbox:latest

# With Git credentials sharing
docker run -it -v ${PWD}:/workspace -w /workspace `
  -v ${HOME}/.ssh:/root/.ssh:ro `
  -v ${HOME}/.gitconfig:/root/.gitconfig:ro `
  cuipengfei/buntoolbox:latest
```

### VS Code Dev Containers (Recommended)

1. Install the "Dev Containers" extension in VS Code
2. Clone this repo or copy `.devcontainer/devcontainer.json` to your project
3. Open your project in VS Code
4. Command Palette → "Dev Containers: Reopen in Container"

### Persistent Development Environment

```powershell
# Create a named container that persists between sessions
docker create --name mydev -it -v ${PWD}:/workspace -w /workspace cuipengfei/buntoolbox:latest
docker start -ai mydev

# Later, reconnect to same container with all your state preserved
docker start -ai mydev
```

### SSH Access (Remote Development)

```powershell
# Run container with SSH port exposed (default password: root)
docker run -d -p 2222:22 --name mydev-ssh cuipengfei/buntoolbox:latest /usr/sbin/sshd -D

# Connect via SSH
ssh -p 2222 root@localhost

# Or use with VS Code Remote-SSH extension
# Add to ~/.ssh/config:
#   Host docker-dev
#     HostName localhost
#     Port 2222
#     User root
```

### OpenVSCode Server (Browser-based VS Code)

```powershell
# Quick start (default port 3000, no authentication)
docker run -d -p 3000:3000 --name mydev-web cuipengfei/buntoolbox:latest openvscode-start

# Custom port
docker run -d -p 8080:8080 --name mydev-web cuipengfei/buntoolbox:latest openvscode-start 8080

# With connection token for security
docker run -d -p 3000:3000 --name mydev-web cuipengfei/buntoolbox:latest \
  openvscode-server --host 0.0.0.0 --port 3000 --connection-token mypassword

# Visit http://localhost:3000 in your browser
# Full VS Code experience in the browser, no installation needed!
```

### ttyd Web Terminal (Lightweight Browser Terminal)

```powershell
# Quick start (default port 7681, writable terminal)
docker run -d -p 7681:7681 --name mydev-ttyd cuipengfei/buntoolbox:latest ttyd-start

# Custom port
docker run -d -p 8080:8080 --name mydev-ttyd cuipengfei/buntoolbox:latest ttyd-start 8080

# With Zellij (terminal multiplexer)
docker run -d -p 7681:7681 --name mydev-ttyd cuipengfei/buntoolbox:latest \
  ttyd-start 7681 zellij attach --create main

# Visit http://localhost:7681 in your browser
# Lightweight terminal - no IDE overhead, just a fast shell!
```

## 命名由来

| 组合 | 含义 |
|------|------|
| Bun | 现代 JS 运行时 |
| (U)buntu | 稳定的 Linux 基底 |
| Toolbox | 多语言工具箱 |

## Documentation

- [REVIEW.md](REVIEW.md) - Detailed assessment for WSL replacement and tool recommendations
- [CLAUDE.md](CLAUDE.md) - AI agent instructions and project overview
- [AGENTS.md](AGENTS.md) - Issue tracking with bd (beads)

---

*一个镜像，无限可能。*
