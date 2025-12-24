# Zellij Interactive Command Control Guide

> Control interactive CLI programs from Claude Code using Zellij's native CLI

## Overview

Zellij (already installed in buntoolbox) provides powerful CLI commands to control terminal sessions from external processes. This enables Claude Code to:

- Run interactive programs (htop, vim, fzf, etc.)
- Send keystrokes and read output
- Manage multiple panes
- Automate terminal workflows

**No additional MCP servers needed** - Zellij's native CLI is sufficient.

---

## When to Use Zellij Control

### Use Zellij for Interactive Commands

| Program Type | Examples | Why Zellij Needed |
|-------------|----------|-------------------|
| TUI Apps | htop, btop, lazygit, gitui | Need keyboard navigation |
| Editors | vim, helix, nano | Need insert mode, ESC, save |
| Fuzzy Finders | fzf, skim | Need input and selection |
| REPLs | python, node, bun repl | Need interactive input |
| Debuggers | gdb, pdb | Step commands, breakpoints |
| Pagers | less, bat (paged) | Need q to quit |

### Don't Need Zellij for Non-Interactive Commands

```bash
# These work fine with normal Bash tool
ls -la
git status
cat file.txt
grep pattern files/
docker ps
```

---

## Quick Start

### 1. Check/Create Zellij Session

```bash
# List existing sessions
zellij list-sessions

# Create a new session (if needed)
zellij -s mysession

# Or attach to existing
zellij attach mysession
```

### 2. Basic Control Pattern

```bash
SESSION="likable-crab"  # Your session name

# Send a command
zellij -s $SESSION action write-chars 'htop'
zellij -s $SESSION action write-chars $'\n'

# Wait for output
sleep 2

# Read the screen
zellij -s $SESSION action dump-screen /tmp/output.txt
cat /tmp/output.txt

# Send quit key
zellij -s $SESSION action write-chars 'q'
```

---

## Core Commands Reference

### Sending Text and Keys

```bash
SESSION="your-session-name"

# Send plain text
zellij -s $SESSION action write-chars "echo hello"

# Send Enter key
zellij -s $SESSION action write-chars $'\n'

# Send ESC key
zellij -s $SESSION action write-chars $'\x1b'

# Send Ctrl+C
zellij -s $SESSION action write-chars $'\x03'

# Send Ctrl+D (EOF)
zellij -s $SESSION action write-chars $'\x04'

# Send Ctrl+Z (suspend)
zellij -s $SESSION action write-chars $'\x1a'

# Send Tab
zellij -s $SESSION action write-chars $'\t'

# Send Backspace
zellij -s $SESSION action write-chars $'\x7f'

# Send Arrow keys (ANSI escape sequences)
zellij -s $SESSION action write-chars $'\x1b[A'  # Up
zellij -s $SESSION action write-chars $'\x1b[B'  # Down
zellij -s $SESSION action write-chars $'\x1b[C'  # Right
zellij -s $SESSION action write-chars $'\x1b[D'  # Left
```

### Reading Output

```bash
# Dump current screen to file
zellij -s $SESSION action dump-screen /tmp/screen.txt

# Dump with full scrollback history
zellij -s $SESSION action dump-screen --full /tmp/full.txt

# Read and display
cat /tmp/screen.txt
```

### Pane Management

```bash
# Create new pane
zellij -s $SESSION action new-pane              # Auto direction
zellij -s $SESSION action new-pane -d right     # To the right
zellij -s $SESSION action new-pane -d down      # Below

# Navigate panes
zellij -s $SESSION action focus-next-pane
zellij -s $SESSION action focus-previous-pane
zellij -s $SESSION action move-focus right
zellij -s $SESSION action move-focus left

# Close pane
zellij -s $SESSION action close-pane

# Run command in new pane
zellij -s $SESSION run -- htop                  # New pane with htop
zellij -s $SESSION run -f -- htop               # Floating pane
zellij -s $SESSION run -c -- echo "done"        # Close on exit
```

### Session Info

```bash
# List sessions
zellij list-sessions

# Query tab names
zellij -s $SESSION action query-tab-names

# Dump current layout
zellij -s $SESSION action dump-layout
```

---

## Interactive Program Examples

### htop / btop (Process Monitor)

```bash
SESSION="mysession"

# Start htop
zellij -s $SESSION action write-chars 'htop'
zellij -s $SESSION action write-chars $'\n'
sleep 2

# Read process list
zellij -s $SESSION action dump-screen /tmp/htop.txt
cat /tmp/htop.txt

# Filter processes (press F4 then type)
zellij -s $SESSION action write-chars $'\x1b[14~'  # F4
zellij -s $SESSION action write-chars 'claude'
sleep 1

# Quit htop
zellij -s $SESSION action write-chars 'q'
```

### vim / helix (Text Editors)

```bash
SESSION="mysession"

# Open file in vim
zellij -s $SESSION action write-chars 'vim /tmp/test.txt'
zellij -s $SESSION action write-chars $'\n'
sleep 1

# Enter insert mode
zellij -s $SESSION action write-chars 'i'

# Type text
zellij -s $SESSION action write-chars 'Hello from Claude Code!'

# Exit insert mode (ESC)
zellij -s $SESSION action write-chars $'\x1b'

# Save and quit
zellij -s $SESSION action write-chars ':wq'
zellij -s $SESSION action write-chars $'\n'

# Verify file saved
cat /tmp/test.txt
```

### helix (Modal Editor)

```bash
SESSION="mysession"

# Open file in helix
zellij -s $SESSION action write-chars 'hx /tmp/test.txt'
zellij -s $SESSION action write-chars $'\n'
sleep 1

# Enter insert mode (same as vim)
zellij -s $SESSION action write-chars 'i'
zellij -s $SESSION action write-chars 'Hello from Helix!'
zellij -s $SESSION action write-chars $'\x1b'

# Save (:w) and quit (:q)
zellij -s $SESSION action write-chars ':w'
zellij -s $SESSION action write-chars $'\n'
zellij -s $SESSION action write-chars ':q'
zellij -s $SESSION action write-chars $'\n'
```

### fzf (Fuzzy Finder)

```bash
SESSION="mysession"

# Start fzf with file list
zellij -s $SESSION action write-chars 'ls -la | fzf'
zellij -s $SESSION action write-chars $'\n'
sleep 1

# Type filter text
zellij -s $SESSION action write-chars 'docker'
sleep 0.5

# Read filtered results
zellij -s $SESSION action dump-screen /tmp/fzf.txt
cat /tmp/fzf.txt

# Select with Enter or cancel with ESC
zellij -s $SESSION action write-chars $'\x1b'  # Cancel
```

### lazygit (Git TUI)

```bash
SESSION="mysession"

# Start lazygit
zellij -s $SESSION action write-chars 'lazygit'
zellij -s $SESSION action write-chars $'\n'
sleep 2

# Navigate (j/k for up/down)
zellij -s $SESSION action write-chars 'j'  # Down
zellij -s $SESSION action write-chars 'j'
zellij -s $SESSION action write-chars $'\n'  # Enter to expand

# Read screen
zellij -s $SESSION action dump-screen /tmp/lazygit.txt

# Quit
zellij -s $SESSION action write-chars 'q'
```

### Python REPL

```bash
SESSION="mysession"

# Start Python
zellij -s $SESSION action write-chars 'python3'
zellij -s $SESSION action write-chars $'\n'
sleep 1

# Run Python code
zellij -s $SESSION action write-chars 'print("Hello from Python!")'
zellij -s $SESSION action write-chars $'\n'
sleep 0.5

zellij -s $SESSION action write-chars '2 + 2'
zellij -s $SESSION action write-chars $'\n'
sleep 0.5

# Read output
zellij -s $SESSION action dump-screen /tmp/python.txt
cat /tmp/python.txt

# Exit Python (Ctrl+D)
zellij -s $SESSION action write-chars $'\x04'
```

### bun repl

```bash
SESSION="mysession"

# Start bun repl
zellij -s $SESSION action write-chars 'bun repl'
zellij -s $SESSION action write-chars $'\n'
sleep 1

# Run JavaScript
zellij -s $SESSION action write-chars 'console.log("Hello from Bun!")'
zellij -s $SESSION action write-chars $'\n'

# Exit
zellij -s $SESSION action write-chars '.exit'
zellij -s $SESSION action write-chars $'\n'
```

---

## Buntoolbox Tools with Zellij

### TUI Tools (Need Zellij)

| Tool | Start Command | Quit Key | Notes |
|------|--------------|----------|-------|
| **btop** | `btop` | `q` | System monitor |
| **htop** | `htop` | `q` | Process viewer |
| **lazygit** | `lazygit` | `q` | Git TUI |
| **yazi** | `yazi` | `q` | File manager (if installed) |
| **helix** | `hx file` | `:q` | Modal editor |
| **vim** | `vim file` | `:q` | Text editor |
| **bat** (paged) | `bat file` | `q` | When output is long |
| **less** | `less file` | `q` | Pager |
| **fzf** | `... \| fzf` | `ESC`/`Enter` | Fuzzy finder |
| **zoxide** | `zi` | `Enter`/`ESC` | Interactive cd |

### Non-Interactive Tools (Direct Bash)

| Tool | Example | Notes |
|------|---------|-------|
| **ripgrep** | `rg pattern` | Direct output |
| **fd** | `fd pattern` | Direct output |
| **eza** | `eza -la` | Direct output |
| **bat** | `bat -p file` | Plain mode, no pager |
| **dust** | `dust` | Direct output |
| **procs** | `procs` | Direct output |
| **delta** | `git diff \| delta` | Direct output |
| **tokei** | `tokei` | Direct output |
| **jq** | `jq . file.json` | Direct output |
| **starship** | N/A | Prompt, not interactive |

---

## Helper Script

Save this as `~/.local/bin/zj` for easier use:

```bash
#!/bin/bash
# zj - Zellij control helper for Claude Code
# Usage: zj <session> <action> [args...]

SESSION="${1:-$(zellij list-sessions | head -1 | awk '{print $1}')}"
ACTION="$2"
shift 2

case "$ACTION" in
  send)
    # Send text: zj session send "text"
    zellij -s "$SESSION" action write-chars "$*"
    ;;
  enter)
    # Send enter: zj session enter
    zellij -s "$SESSION" action write-chars $'\n'
    ;;
  esc)
    # Send ESC: zj session esc
    zellij -s "$SESSION" action write-chars $'\x1b'
    ;;
  ctrlc)
    # Send Ctrl+C: zj session ctrlc
    zellij -s "$SESSION" action write-chars $'\x03'
    ;;
  read)
    # Read screen: zj session read [file]
    OUTPUT="${1:-/tmp/zj-output.txt}"
    zellij -s "$SESSION" action dump-screen "$OUTPUT"
    cat "$OUTPUT"
    ;;
  run)
    # Run command: zj session run "command"
    zellij -s "$SESSION" action write-chars "$*"
    zellij -s "$SESSION" action write-chars $'\n'
    ;;
  quit)
    # Send q (common quit): zj session quit
    zellij -s "$SESSION" action write-chars 'q'
    ;;
  *)
    echo "Usage: zj <session> <action> [args]"
    echo "Actions: send, enter, esc, ctrlc, read, run, quit"
    ;;
esac
```

Usage:
```bash
chmod +x ~/.local/bin/zj

# Examples
zj mysession run "htop"
zj mysession read
zj mysession quit
```

---

## Best Practices

### 1. Always Wait for Programs to Start

```bash
zellij -s $SESSION action write-chars 'htop'
zellij -s $SESSION action write-chars $'\n'
sleep 2  # Give htop time to render
```

### 2. Read Output Before Sending More Commands

```bash
# Check if program is ready
zellij -s $SESSION action dump-screen /tmp/check.txt
if grep -q "pattern" /tmp/check.txt; then
  # Program is ready, continue
fi
```

### 3. Use Proper Exit Sequences

```bash
# For TUI apps: usually 'q'
zellij -s $SESSION action write-chars 'q'

# For vim/helix: ESC then :q
zellij -s $SESSION action write-chars $'\x1b'
zellij -s $SESSION action write-chars ':q!'
zellij -s $SESSION action write-chars $'\n'

# For REPLs: Ctrl+D or exit command
zellij -s $SESSION action write-chars $'\x04'
```

### 4. Clean Up After Yourself

```bash
# Remove temp files
rm -f /tmp/zj-*.txt

# Close extra panes if created
zellij -s $SESSION action close-pane
```

---

## Comparison: Zellij vs tmux-mcp

| Feature | Zellij (Native) | tmux-mcp |
|---------|----------------|----------|
| **GitHub Stars** | 23,000+ | 6 |
| **Dependencies** | None (built-in CLI) | npx, Node.js |
| **Installation** | Already in buntoolbox | Extra install |
| **Send text** | `action write-chars` | Yes |
| **Read output** | `action dump-screen` | Yes |
| **Pane control** | Full support | Yes |
| **Floating panes** | Yes | No |
| **Layout export** | Yes | No |
| **Stability** | Production-ready | New project |

**Conclusion**: Use Zellij's native CLI. No need for tmux-mcp.

---

## Troubleshooting

### Session Not Found

```bash
# List available sessions
zellij list-sessions

# Create new session if needed
zellij -s newsession
```

### Commands Not Executing

```bash
# Make sure to send Enter after command
zellij -s $SESSION action write-chars 'command'
zellij -s $SESSION action write-chars $'\n'  # Don't forget this!
```

### Screen Output Empty

```bash
# Wait longer for program to render
sleep 2

# Try full scrollback
zellij -s $SESSION action dump-screen --full /tmp/out.txt
```

### Program Not Responding

```bash
# Try Ctrl+C to interrupt
zellij -s $SESSION action write-chars $'\x03'

# Or close the pane
zellij -s $SESSION action close-pane
```
