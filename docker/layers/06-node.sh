#!/bin/bash
# Install Node.js from the official tarball.

set -euo pipefail

: "${NODE_VERSION:?NODE_VERSION is required}"

curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
    | tar -xJ --strip-components=1 -C /usr/local
