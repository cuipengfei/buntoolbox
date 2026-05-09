#!/bin/bash
# Install Bun.

set -euo pipefail

: "${BUN_VERSION:?BUN_VERSION is required}"

mkdir -p /root/.bun/bin
curl -fsSL "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-x64.zip" -o /tmp/bun.zip
unzip -q /tmp/bun.zip -d /tmp
mv /tmp/bun-linux-x64/bun /root/.bun/bin/bun
chmod +x /root/.bun/bin/bun
ln -sf /root/.bun/bin/bun /root/.bun/bin/bunx
rm -rf /tmp/bun.zip /tmp/bun-linux-x64
