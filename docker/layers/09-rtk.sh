#!/bin/bash
# Install rtk.

set -euo pipefail

: "${RTK_VERSION:?RTK_VERSION is required}"

curl -fsSL "https://github.com/rtk-ai/rtk/releases/download/v${RTK_VERSION}/rtk-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz -C /usr/local/bin
