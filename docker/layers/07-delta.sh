#!/bin/bash
# Install delta.

set -euo pipefail

: "${DELTA_VERSION:?DELTA_VERSION is required}"

curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/delta-${DELTA_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz --strip-components=1 -C /usr/local/bin "delta-${DELTA_VERSION}-x86_64-unknown-linux-musl/delta"
