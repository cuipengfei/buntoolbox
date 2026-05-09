#!/bin/bash
# Install uv/uvx and pipx.

set -euo pipefail

: "${UV_VERSION:?UV_VERSION is required}"

mkdir -p /root/.local/bin
curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz" \
    | tar -xz -C /root/.local/bin --strip-components=1
PATH="/root/.local/bin:${PATH}"
uv tool install pipx
pipx ensurepath
rm -rf /root/.cache/uv
