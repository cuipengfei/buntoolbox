#!/bin/bash
# Install zoxide.

set -euo pipefail

: "${ZOXIDE_VERSION:?ZOXIDE_VERSION is required}"

curl -fsSL "https://github.com/ajeetdsouza/zoxide/releases/download/v${ZOXIDE_VERSION}/zoxide-${ZOXIDE_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz -C /usr/local/bin zoxide
