# Container Access Methods for Buntoolbox

Access buntoolbox container from Windows host (no WSL) via browser.

## Context

Buntoolbox is designed for Windows users with WSL disabled by enterprise policy. This document covers different methods to access the container's terminal and IDE.

## Current Options in Buntoolbox

| Method | Already Included | Port |
|--------|-----------------|------|
| OpenVSCode Server | ✅ Yes | 3000 |
| SSH | ✅ Yes (sshd) | 22 |
| Zellij | ✅ Yes | - |

## Solution Options

### Option A: ttyd + Zellij (Lightweight Terminal)

Lightweight web terminal serving Zellij over WebSocket. **Not currently in buntoolbox.**

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

### Option C: noVNC + GUI Terminal

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

### Option D: KasmVNC (Universal GUI Solution)

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
