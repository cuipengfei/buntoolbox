#!/bin/bash
# Install zellij.

set -euo pipefail

: "${ZELLIJ_VERSION:?ZELLIJ_VERSION is required}"

curl -fsSL "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz -C /usr/local/bin
