#!/bin/bash
# Install helix.

set -euo pipefail

: "${HELIX_VERSION:?HELIX_VERSION is required}"

curl -fsSL "https://github.com/helix-editor/helix/releases/download/${HELIX_VERSION}/helix-${HELIX_VERSION}-x86_64-linux.tar.xz" \
    | tar -xJ -C /opt
ln -sf "/opt/helix-${HELIX_VERSION}-x86_64-linux/hx" /usr/local/bin/hx
ln -sf "/opt/helix-${HELIX_VERSION}-x86_64-linux" /opt/helix-current
