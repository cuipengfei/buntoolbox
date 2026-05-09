#!/bin/bash
# Install procs.

set -euo pipefail

: "${PROCS_VERSION:?PROCS_VERSION is required}"

curl -fsSL "https://github.com/dalance/procs/releases/download/v${PROCS_VERSION}/procs-v${PROCS_VERSION}-x86_64-linux.zip" \
    -o /tmp/procs.zip
unzip -q /tmp/procs.zip -d /usr/local/bin
rm /tmp/procs.zip
