# Container Access Methods for Buntoolbox

Access buntoolbox container from Windows host (no WSL) via browser.

## Context

Buntoolbox is designed for Windows users with WSL disabled by enterprise policy. This document covers different methods to access the container's terminal, IDE, and optional browser-delivered Linux desktop.

## Current Options in Buntoolbox

| Method | Already Included | Port |
|--------|-----------------|------|
| OpenVSCode Server | ✅ Yes | 3000 |
| SSH | ✅ Yes (sshd) | 22 |
| Zellij | ✅ Yes | - |
| ttyd | ✅ Yes | 7681 |
| Webtop i3 desktop | ✅ Yes, in `cuipengfei/buntoolbox:i3` | 3200 / 3201 |
| Webtop KDE desktop | ✅ Yes, in `cuipengfei/buntoolbox:kde` | 3200 / 3201 |

## Solution Options

### Option A: ttyd + Zellij (Lightweight Terminal)

Lightweight web terminal serving Zellij over WebSocket. **Included in buntoolbox.**

```
Container                          Windows
┌─────────────────────┐            ┌──────────┐
│ ttyd ─▶ Zellij ─▶ sh│──WebSocket─▶│ Browser  │
│ :7681               │   (text)   │          │
└─────────────────────┘            └──────────┘
```

**To add to Dockerfile:**
```dockerfile
# ttyd (~5MB addition)
RUN apt-get update && apt-get install -y ttyd && rm -rf /var/lib/apt/lists/*
```

**Usage:**
```bash
docker run -d -p 7681:7681 cuipengfei/buntoolbox:latest \
  ttyd -W -p 7681 zellij attach --create main
# Access: http://localhost:7681
```

**ttyd flags:**
| Flag | Purpose |
|------|---------|
| `-W` | Enable write (bidirectional) |
| `-p 7681` | Listen port |
| `-c user:pass` | Optional: basic auth |
| `-t fontSize=16` | Optional: font size |

**Zellij config** (`~/.config/zellij/config.kdl`):
```kdl
keybinds {
    locked {
        bind "Ctrl g" { SwitchToMode "Normal"; }
    }
}
default_mode "locked"
```

Start locked to avoid browser shortcut conflicts. `Ctrl+g` unlocks.

### Option B: OpenVSCode Server (Current Default)

**Already included in buntoolbox.**

```bash
# Quick start
docker run -d -p 3000:3000 cuipengfei/buntoolbox:latest openvscode-start

# Custom port
docker run -d -p 8080:8080 cuipengfei/buntoolbox:latest openvscode-start 8080

# With authentication
docker run -d -p 3000:3000 cuipengfei/buntoolbox:latest \
  openvscode-server --host 0.0.0.0 --port 3000 --connection-token mypassword
```

Access: http://localhost:3000

### Option C: Webtop Desktop (`buntoolbox:i3` / `buntoolbox:kde`)

Run a browser-delivered Linux desktop while keeping buntoolbox's normal developer ports intact. Choose `i3` for the lighter tiling desktop or `kde` for a more traditional desktop feel.

```powershell
docker run -d --name mydev-i3 `
  --shm-size=1gb `
  -p 3200:3200 `
  -p 3201:3201 `
  -p 3000:3000 `
  -p 7681:7681 `
  -v ${PWD}:/workspace `
  cuipengfei/buntoolbox:i3
```

KDE uses the same port contract:

```powershell
docker run -d --name mydev-kde `
  --shm-size=1gb `
  -p 3200:3200 `
  -p 3201:3201 `
  -p 3000:3000 `
  -p 7681:7681 `
  -v ${PWD}:/workspace `
  cuipengfei/buntoolbox:kde
```

Access:

- Webtop desktop HTTP: http://localhost:3200
- Webtop desktop HTTPS: https://localhost:3201
- Optional OpenVSCode Server after running `openvscode-start`: http://localhost:3000
- Optional ttyd after running `ttyd-start`: http://localhost:7681

Notes:

- `buntoolbox:latest` remains the terminal/TUI image and does not include GUI desktop stacks.
- `buntoolbox:i3` and `buntoolbox:kde` are root-first for normal interactive workflows: `whoami=root`, `HOME=/root`.
- `buntoolbox:kde` is based on LinuxServer Webtop Ubuntu KDE, which is Wayland-only upstream and heavier than i3.
- The LinuxServer/Webtop base may still contain an `abc` account for upstream compatibility, but critical GUI/runtime processes are tested not to run as `abc`.
- Keep `--shm-size=1gb` or an equivalent shared-memory setting for browser/desktop workloads.
- Treat `3200`/`3201`, `3000`, and `7681` as local-only unless protected by auth, firewall, TLS/proxy controls, or another access-control layer.

KDE GPU notes for Windows + Docker Desktop + WSL2:

- This path requires Docker Desktop's WSL2 backend. If WSL2 is not available at all, treat the Webtop desktop as CPU-rendered.
- Use WSLg/Mesa D3D12 for GUI application GPU rendering. Pass `/dev/dxg`, mount the full `/usr/lib/wsl` tree read-only, set `LD_LIBRARY_PATH=/usr/lib/wsl/lib`, and set `GALLIUM_DRIVER=d3d12`. This is the buntoolbox-tested WSLg path; LinuxServer/Webtop documents `/dev/dri` and NVIDIA GPU paths, not WSLg `/dev/dxg` as an upstream-supported Webtop GPU path.
- Prefer mounting `/usr/lib/wsl`, not only `/usr/lib/wsl/lib`, because Mesa's D3D12 path can need the WSL driver files under the same tree.
- Set `LIBVA_DRIVER_NAME=d3d12` for the matching VAAPI path when available.
- Set `DISABLE_DRI3=true` in this WSL2 Webtop shape so Webtop/Selkies does not try to treat WSL's virtual `/dev/dri` nodes like a normal Linux DRM render path. On the validated host, `/dev/dri/card0` reported `drmIsKMS = 0`, so it is not a KMS-capable device for KWin's DRM display backend.
- Do not rely on Docker Desktop `--gpus all` as the GUI OpenGL answer. It is useful for NVIDIA/CUDA style exposure, but WSLg OpenGL apps use `/dev/dxg` plus Mesa D3D12.
- Verify with `glxinfo -B`, `eglinfo`, and an actual OpenGL app such as `glxgears -info`. Good evidence is `D3D12 (...)`, `Microsoft Corporation`, and `Accelerated: yes`.
- Keep three GPU layers separate: container GPU visibility, GUI application OpenGL rendering, and Webtop/Selkies stream encoding/KWin compositor behavior. Current buntoolbox evidence covers application OpenGL through D3D12. It does not prove Selkies hardware stream encoding and does not make KWin compositor GPU rendering the success criterion.
- In Docker Desktop + WSL2 Webtop, design around KWin using its software compositor path even when Linux OpenGL applications are accelerated through D3D12. A real KWin OpenGL compositor generally needs a platform/backend it can use for accelerated compositing; the WSLg `/dev/dxg` path is not a DRM/KMS display pipeline.

GPU-enabled KDE run example:

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

GPU verification commands:

```bash
docker exec mydev-kde-gpu glxinfo -B
docker exec mydev-kde-gpu eglinfo
docker exec -d mydev-kde-gpu glxgears -info
```

Optional Selkies VAAPI experiment:

```powershell
docker run --rm -d --name mydev-kde-vaapi-poc `
  --shm-size=1gb `
  --device /dev/dxg `
  --device /dev/dri `
  --mount type=bind,source=/usr/lib/wsl,target=/usr/lib/wsl,readonly `
  -e LD_LIBRARY_PATH=/usr/lib/wsl/lib `
  -e GALLIUM_DRIVER=d3d12 `
  -e LIBVA_DRIVER_NAME=d3d12 `
  -e DISABLE_DRI3=true `
  -e SELKIES_DEBUG=true `
  -e SELKIES_ENCODER=x264enc `
  -e SELKIES_DRI_NODE=/dev/dri/renderD128 `
  -e SELKIES_USE_CPU=false `
  -p 3290:3200 `
  cuipengfei/buntoolbox:kde
```

Check logs before trusting this path:

```bash
docker logs mydev-kde-vaapi-poc 2>&1 \
  | grep -Ei 'encoder|dri|vaapi|pixel|gpu|x264|error|warn|fallback|capture|screen'
```

Important boundary:

- Do not set `SELKIES_ENCODER=vah264enc` for the current LinuxServer Webtop WebSocket/Pixelflux service. That service accepts Webtop encoder names such as `x264enc`, `x264enc-striped`, and `jpeg`, not raw GStreamer element names.
- `SELKIES_DRI_NODE` / `DRI_NODE` is the VAAPI render-node knob for this service.
- A local PoC made `vainfo` report D3D12 H.264 encode entrypoints, but FFmpeg `h264_vaapi` produced a zero-byte stream and GStreamer VAAPI encode was not reliable. Treat Selkies VAAPI on WSLg as experimental until an end-to-end browser session proves stable quality and real hardware encoding.

### Option D: noVNC + GUI Terminal

Full GUI terminal rendered inside container, streamed as images. **Not currently in buntoolbox.**

```
Container                                    Windows
┌────────────────────────────────────┐       ┌──────────┐
│ Xvfb ─▶ terminal ─▶ Zellij ─▶ sh   │       │          │
│   │                                │       │ Browser  │
│ x11vnc ─▶ noVNC :6080 ─────────────┼─image─▶│          │
└────────────────────────────────────┘       └──────────┘
```

**Trade-offs:**
- Image size: +200MB
- Full keyboard control (no browser shortcut conflicts)
- Clipboard sync required
- Higher latency than text-based solutions

### Option E: KasmVNC (Universal GUI Solution)

Run **any Linux GUI application** inside container, access via browser.

```
Container                                    Windows
┌────────────────────────────────────┐       ┌──────────┐
│  Any GUI App (Lapce, Zed, VS Code) │       │          │
│         │                          │       │ Browser  │
│    KasmVNC :6901 ──────────────────┼──────▶│          │
└────────────────────────────────────┘       └──────────┘
```

One port, all GUI apps visible in browser.

**vs noVNC:**
| Aspect | noVNC | KasmVNC |
|--------|-------|---------|
| Protocol | Traditional VNC | WebSocket + H.264/WebP |
| Performance | Moderate | Better (lower latency) |
| Bandwidth | High | Lower (better compression) |
| Clipboard | Unstable | Improved sync |
| Audio | No | Yes |

**Supported Applications:** Any Linux GUI app works (Lapce, Zed, VS Code native, IntelliJ, Firefox, etc.)

**Quick Start (not in buntoolbox, use Kasm base image):**
```bash
docker run -d -p 6901:6901 -e VNC_PW=password kasmweb/desktop:1.14.0
# Access: https://localhost:6901
```

**Custom image with Lapce + Zed:**
```dockerfile
FROM kasmweb/desktop:1.14.0

# Install Lapce
RUN curl -L https://github.com/lapce/lapce/releases/latest/download/Lapce-linux.tar.gz \
    | tar xz -C /usr/local/bin

# Install Zed
RUN curl -L https://zed.dev/api/releases/stable/latest/zed-linux-x86_64.tar.gz \
    | tar xz -C /opt && ln -s /opt/zed*/zed /usr/local/bin/zed

EXPOSE 6901
```

## Comparison

| Aspect | ttyd | OpenVSCode | noVNC | KasmVNC |
|--------|------|------------|-------|---------|
| Image size delta | ~5MB | Already included | ~200MB | ~500MB+ |
| Type | Terminal only | Full IDE | GUI desktop | GUI desktop |
| Copy/paste | Native | Native | Clipboard sync | Better sync |
| Keyboard | Browser may capture | Works well | Full control | Full control |
| Latency | Low (text) | Low | Higher (images) | Medium |
| Can run any GUI | No | No | Yes | Yes |

## Solution Matrix

| Need | Recommended Solution |
|------|---------------------|
| Terminal only (minimal) | **ttyd + Zellij** |
| VS Code experience | **OpenVSCode Server** (already in buntoolbox) |
| Any Linux GUI app | **KasmVNC** |
| JetBrains IDE | **KasmVNC** |
| Minimal footprint | **ttyd** (~5MB) |
| Maximum flexibility | **KasmVNC** (any app) |

## Web Terminal Comparison: ttyd vs GoTTY

| Aspect | ttyd | GoTTY |
|--------|------|-------|
| Stars | 10,849 | 19,377 |
| Last update | 2025-07-27 ✅ | 2024-08-01 |
| Language | C + libuv | Go |
| Rendering | WebGL2 (faster) | xterm.js/hterm |
| Special features | CJK/IME, Sixel, ZMODEM | Random URL, tmux sharing |

**Recommendation:** ttyd is more actively maintained with better terminal features.

## Web IDE Comparison

| Option | Maintainer | License | Extension Market |
|--------|------------|---------|------------------|
| **OpenVSCode Server** | Gitpod | MIT | Open VSX |
| code-server | Coder | MIT | Open VSX |
| VS Code Server (official) | Microsoft | Proprietary | Official ✅ |
| Theia | Eclipse Foundation | EPL-2.0 | Partial |

**Buntoolbox uses OpenVSCode Server** - good balance of features and open source.

## Non-Browser Alternatives

If Windows software installation is allowed:

| Option | Windows Requirement | Experience |
|--------|---------------------|------------|
| VS Code Remote - Containers | VS Code + Docker | Best native experience |
| SSH + terminal editor | None (built-in terminal) | Buntoolbox includes sshd |
| X11 Forwarding | X Server (VcXsrv) | Native Linux GUI |

## Recommendations for Buntoolbox

1. **Current setup (OpenVSCode) is good** for most VS Code users
2. **Consider adding ttyd** for lightweight terminal-only access (~5MB)
3. **KasmVNC is separate** - use Kasm base images when you need full GUI apps

## See Also

- [Zellij 交互式命令控制指南](zellij-交互式命令控制指南.md)
