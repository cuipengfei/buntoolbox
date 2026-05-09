#!/bin/bash
# Install beads (bd issue tracker).

set -euo pipefail

: "${BEADS_VERSION:?BEADS_VERSION is required}"

curl -fsSL "https://github.com/gastownhall/beads/releases/download/v${BEADS_VERSION}/beads_${BEADS_VERSION}_linux_amd64.tar.gz" \
    | tar -xz -C /usr/local/bin bd
