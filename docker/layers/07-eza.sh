#!/bin/bash
# Install eza.

set -euo pipefail

: "${EZA_VERSION:?EZA_VERSION is required}"

curl -fsSL "https://github.com/eza-community/eza/releases/download/v${EZA_VERSION}/eza_x86_64-unknown-linux-gnu.tar.gz" \
    | tar -xz -C /usr/local/bin
