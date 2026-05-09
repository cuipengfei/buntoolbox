#!/bin/bash
# Install ttyd.

set -euo pipefail

: "${TTYD_VERSION:?TTYD_VERSION is required}"

curl -fsSL "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64" \
    -o /usr/local/bin/ttyd
chmod +x /usr/local/bin/ttyd
