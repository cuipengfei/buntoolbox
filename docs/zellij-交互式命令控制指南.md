# Zellij 交互式命令控制指南

> 使用 Zellij 原生 CLI 从 Claude Code 控制交互式 CLI 程序

## 概述

Zellij（已安装在 buntoolbox 中）提供强大的 CLI 命令来从外部进程控制终端会话。这使 Claude Code 能够：

- 运行交互式程序（htop、vim、fzf 等）
- 发送按键并读取输出
- 管理多个窗格
- 自动化终端工作流

**无需额外的 MCP 服务器** - Zellij 的原生 CLI 就足够了。

---

## 何时使用 Zellij 控制

### 需要 Zellij 的交互式命令

| 程序类型 | 示例 | 为何需要 Zellij |
|---------|------|----------------|
| TUI 应用 | htop, btop, lazygit | 需要键盘导航 |
| 模糊查找器 | fzf, skim | 需要输入和选择 |
| REPL | python, node, bun repl | 需要交互式输入 |
| 调试器 | gdb, pdb | 步进命令、断点 |
| 分页器 | less, bat (分页模式) | 需要按 q 退出 |

### 不需要 Zellij 的非交互式命令

```bash
# 这些命令直接使用 Bash 工具即可
ls -la
git status
cat file.txt
grep pattern files/
docker ps
```

---

## 快速开始

### 1. 检查/创建 Zellij 会话

```bash
# 列出现有会话
zellij list-sessions

# 创建新会话（如需要）
zellij -s mysession

# 或附加到现有会话
zellij attach mysession
```

### 2. 基本控制模式

```bash
SESSION="likable-crab"  # 你的会话名称

# 发送命令
zellij -s $SESSION action write-chars 'htop'
zellij -s $SESSION action write-chars $'\n'

# 等待输出
sleep 2

# 读取屏幕
zellij -s $SESSION action dump-screen /dev/shm/zj.txt && cat /dev/shm/zj.txt

# 发送退出键
zellij -s $SESSION action write-chars 'q'
```

---

## 核心命令参考

### 发送文本和按键

```bash
SESSION="your-session-name"

# 发送普通文本
zellij -s $SESSION action write-chars "echo hello"

# 发送 Enter 键
zellij -s $SESSION action write-chars $'\n'

# 发送 ESC 键
zellij -s $SESSION action write-chars $'\x1b'

# 发送 Ctrl+C
zellij -s $SESSION action write-chars $'\x03'

# 发送 Ctrl+D (EOF)
zellij -s $SESSION action write-chars $'\x04'

# 发送 Ctrl+Z (挂起)
zellij -s $SESSION action write-chars $'\x1a'

# 发送 Tab
zellij -s $SESSION action write-chars $'\t'

# 发送 Backspace
zellij -s $SESSION action write-chars $'\x7f'

# 发送方向键（ANSI 转义序列）
zellij -s $SESSION action write-chars $'\x1b[A'  # 上
zellij -s $SESSION action write-chars $'\x1b[B'  # 下
zellij -s $SESSION action write-chars $'\x1b[C'  # 右
zellij -s $SESSION action write-chars $'\x1b[D'  # 左
```

### 读取输出

```bash
# 使用 /dev/shm 内存文件系统（不写磁盘，速度快）
zellij -s $SESSION action dump-screen /dev/shm/zj.txt && cat /dev/shm/zj.txt

# 转储包含完整回滚历史
zellij -s $SESSION action dump-screen --full /dev/shm/zj.txt
```

### 窗格管理

```bash
# 创建新窗格
zellij -s $SESSION action new-pane              # 自动方向
zellij -s $SESSION action new-pane -d right     # 向右
zellij -s $SESSION action new-pane -d down      # 向下

# 导航窗格
zellij -s $SESSION action focus-next-pane
zellij -s $SESSION action focus-previous-pane
zellij -s $SESSION action move-focus right
zellij -s $SESSION action move-focus left

# 关闭窗格
zellij -s $SESSION action close-pane

# 在新窗格中运行命令
zellij -s $SESSION run -- htop                  # 新窗格运行 htop
zellij -s $SESSION run -f -- htop               # 浮动窗格
zellij -s $SESSION run -c -- echo "done"        # 退出时关闭
```

### 会话信息

```bash
# 列出会话
zellij list-sessions

# 查询标签名
zellij -s $SESSION action query-tab-names

# 转储当前布局
zellij -s $SESSION action dump-layout
```

---

## 交互式程序示例

### htop / btop (进程监视器)

```bash
SESSION="mysession"

# 启动 htop
zellij -s $SESSION action write-chars 'htop'
zellij -s $SESSION action write-chars $'\n'
sleep 2

# 读取进程列表
zellij -s $SESSION action dump-screen /dev/shm/zj.txt && cat /dev/shm/zj.txt

# 过滤进程（按 F4 然后输入）
zellij -s $SESSION action write-chars $'\x1b[14~'  # F4
zellij -s $SESSION action write-chars 'claude'
sleep 1

# 退出 htop
zellij -s $SESSION action write-chars 'q'
```

### fzf (模糊查找器)

```bash
SESSION="mysession"

# 使用文件列表启动 fzf
zellij -s $SESSION action write-chars 'ls -la | fzf'
zellij -s $SESSION action write-chars $'\n'
sleep 1

# 输入过滤文本
zellij -s $SESSION action write-chars 'docker'
sleep 0.5

# 读取过滤结果
zellij -s $SESSION action dump-screen /dev/shm/zj.txt && cat /dev/shm/zj.txt

# 使用 Enter 选择或使用 ESC 取消
zellij -s $SESSION action write-chars $'\x1b'  # 取消
```

### lazygit (Git TUI)

```bash
SESSION="mysession"

# 启动 lazygit
zellij -s $SESSION action write-chars 'lazygit'
zellij -s $SESSION action write-chars $'\n'
sleep 2

# 导航（j/k 上下移动）
zellij -s $SESSION action write-chars 'j'  # 下
zellij -s $SESSION action write-chars 'j'
zellij -s $SESSION action write-chars $'\n'  # Enter 展开

# 读取屏幕
zellij -s $SESSION action dump-screen /dev/shm/zj.txt

# 退出
zellij -s $SESSION action write-chars 'q'
```

### Python REPL

```bash
SESSION="mysession"

# 启动 Python
zellij -s $SESSION action write-chars 'python3'
zellij -s $SESSION action write-chars $'\n'
sleep 1

# 运行 Python 代码
zellij -s $SESSION action write-chars 'print("Hello from Python!")'
zellij -s $SESSION action write-chars $'\n'
sleep 0.5

zellij -s $SESSION action write-chars '2 + 2'
zellij -s $SESSION action write-chars $'\n'
sleep 0.5

# 读取输出
zellij -s $SESSION action dump-screen /dev/shm/zj.txt && cat /dev/shm/zj.txt

# 退出 Python（Ctrl+D）
zellij -s $SESSION action write-chars $'\x04'
```

### bun repl

```bash
SESSION="mysession"

# 启动 bun repl
zellij -s $SESSION action write-chars 'bun repl'
zellij -s $SESSION action write-chars $'\n'
sleep 1

# 运行 JavaScript
zellij -s $SESSION action write-chars 'console.log("Hello from Bun!")'
zellij -s $SESSION action write-chars $'\n'

# 退出
zellij -s $SESSION action write-chars '.exit'
zellij -s $SESSION action write-chars $'\n'
```

---

## Buntoolbox 工具与 Zellij

### TUI 工具（需要 Zellij）

| 工具 | 启动命令 | 退出键 | 说明 |
|------|---------|-------|------|
| **btop** | `btop` | `q` | 系统监视器 |
| **htop** | `htop` | `q` | 进程查看器 |
| **lazygit** | `lazygit` | `q` | Git TUI |
| **bat** (分页) | `bat file` | `q` | 输出较长时 |
| **less** | `less file` | `q` | 分页器 |
| **fzf** | `... \| fzf` | `ESC`/`Enter` | 模糊查找器 |
| **zoxide** | `zi` | `Enter`/`ESC` | 交互式 cd |

### 非交互式工具（直接使用 Bash）

| 工具 | 示例 | 说明 |
|------|------|------|
| **ripgrep** | `rg pattern` | 直接输出 |
| **fd** | `fd pattern` | 直接输出 |
| **eza** | `eza -la` | 直接输出 |
| **bat** | `bat -p file` | 纯文本模式，无分页器 |
| **dust** | `dust` | 直接输出 |
| **procs** | `procs` | 直接输出 |
| **delta** | `git diff \| delta` | 直接输出 |
| **tokei** | `tokei` | 直接输出 |
| **jq** | `jq . file.json` | 直接输出 |
| **starship** | N/A | 提示符，非交互式 |

---

## 辅助脚本

将此脚本保存为 `~/.local/bin/zj` 以便更方便地使用：

```bash
#!/bin/bash
# zj - Claude Code 的 Zellij 控制辅助脚本
# 用法: zj <session> <action> [args...]

SESSION="${1:-$(zellij list-sessions | head -1 | awk '{print $1}')}"
ACTION="$2"
shift 2

case "$ACTION" in
  send)
    # 发送文本: zj session send "text"
    zellij -s "$SESSION" action write-chars "$*"
    ;;
  enter)
    # 发送 enter: zj session enter
    zellij -s "$SESSION" action write-chars $'\n'
    ;;
  esc)
    # 发送 ESC: zj session esc
    zellij -s "$SESSION" action write-chars $'\x1b'
    ;;
  ctrlc)
    # 发送 Ctrl+C: zj session ctrlc
    zellij -s "$SESSION" action write-chars $'\x03'
    ;;
  read)
    # 读取屏幕: zj session read [file]
    OUTPUT="${1:-/dev/shm/zj.txt}"
    zellij -s "$SESSION" action dump-screen "$OUTPUT"
    cat "$OUTPUT"
    ;;
  run)
    # 运行命令: zj session run "command"
    zellij -s "$SESSION" action write-chars "$*"
    zellij -s "$SESSION" action write-chars $'\n'
    ;;
  quit)
    # 发送 q（常见退出键）: zj session quit
    zellij -s "$SESSION" action write-chars 'q'
    ;;
  *)
    echo "用法: zj <session> <action> [args]"
    echo "操作: send, enter, esc, ctrlc, read, run, quit"
    ;;
esac
```

用法：
```bash
chmod +x ~/.local/bin/zj

# 示例
zj mysession run "htop"
zj mysession read
zj mysession quit
```

---

## 最佳实践

### 1. 始终等待程序启动

```bash
zellij -s $SESSION action write-chars 'htop'
zellij -s $SESSION action write-chars $'\n'
sleep 2  # 给 htop 时间渲染
```

### 2. 在发送更多命令前读取输出

```bash
# 检查程序是否就绪
zellij -s $SESSION action dump-screen /dev/shm/zj.txt
if grep -q "pattern" /dev/shm/zj.txt; then
  # 程序就绪，继续
fi
```

### 3. 使用适当的退出序列

```bash
# 对于 TUI 应用：通常是 'q'
zellij -s $SESSION action write-chars 'q'

# 对于 REPL：Ctrl+D 或 exit 命令
zellij -s $SESSION action write-chars $'\x04'
```

### 4. 完成后清理

```bash
# /dev/shm 是内存文件系统，无需清理
# 如果创建了额外的窗格，则关闭它们
zellij -s $SESSION action close-pane
```

---

## 对比：Zellij vs tmux-mcp

| 功能 | Zellij（原生）| tmux-mcp |
|------|--------------|----------|
| **GitHub Stars** | 23,000+ | 6 |
| **依赖** | 无（内置 CLI）| npx, Node.js |
| **安装** | 已在 buntoolbox 中 | 需额外安装 |
| **发送文本** | `action write-chars` | 是 |
| **读取输出** | `action dump-screen` | 是 |
| **窗格控制** | 完整支持 | 是 |
| **浮动窗格** | 是 | 否 |
| **布局导出** | 是 | 否 |
| **稳定性** | 生产就绪 | 新项目 |

**结论**：使用 Zellij 的原生 CLI。无需 tmux-mcp。

---

## 故障排除

### 会话未找到

```bash
# 列出可用会话
zellij list-sessions

# 如需要创建新会话
zellij -s newsession
```

### 命令未执行

```bash
# 确保在命令后发送 Enter
zellij -s $SESSION action write-chars 'command'
zellij -s $SESSION action write-chars $'\n'  # 别忘了这个！
```

### 屏幕输出为空

```bash
# 等待更长时间让程序渲染
sleep 2

# 尝试完整回滚
zellij -s $SESSION action dump-screen --full /dev/shm/zj.txt
```

### 程序无响应

```bash
# 尝试 Ctrl+C 中断
zellij -s $SESSION action write-chars $'\x03'

# 或关闭窗格
zellij -s $SESSION action close-pane
```

---

## 测试结果总结

**经过验证的工具** (2025-12-24):

- ✓ **btop**: 系统监视器加载正常
- ✓ **htop**: 进程查看器工作正常
- ✓ **lazygit**: Git TUI 加载正常
- ✓ **fzf**: 模糊查找器支持过滤
- ✓ **Python REPL**: 正确评估表达式
- ✓ **less**: 分页器正常显示内容
- ✓ **bat with pager**: 语法高亮器支持分页
- ✓ **Bun REPL**: JavaScript 表达式正确评估

所有测试在 WSL2 环境的 buntoolbox Docker 镜像中完成。
