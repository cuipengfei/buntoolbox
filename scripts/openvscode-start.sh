#!/bin/bash
# Start OpenVSCode Server with sensible defaults
# Usage: openvscode-start [port] [additional args...]

PORT="${1:-3000}"
shift 2>/dev/null || true

exec openvscode-server --host 0.0.0.0 --without-connection-token --port "$PORT" "$@"
