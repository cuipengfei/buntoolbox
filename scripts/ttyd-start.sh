#!/bin/bash
# Start ttyd web terminal with sensible defaults
# Usage: ttyd-start [port] [additional ttyd args and command...]
# Examples:
#   ttyd-start                    # port 7681, bash
#   ttyd-start 8080               # port 8080, bash
#   ttyd-start 7681 zsh -l        # port 7681, login zsh
#   ttyd-start 7681 -t fontSize=16 bash  # with ttyd options

PORT="${1:-7681}"
shift 2>/dev/null || true

if [ $# -eq 0 ]; then
  exec ttyd -W -p "$PORT" bash
else
  exec ttyd -W -p "$PORT" "$@"
fi
