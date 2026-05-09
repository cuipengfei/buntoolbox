#!/bin/bash
# Install lazygit.

set -euo pipefail

: "${LAZYGIT_VERSION:?LAZYGIT_VERSION is required}"

curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_linux_x86_64.tar.gz" \
    | tar -xz -C /usr/local/bin lazygit
