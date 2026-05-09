#!/bin/bash
# Install openvscode-server.

set -euo pipefail

: "${OPENVSCODE_VERSION:?OPENVSCODE_VERSION is required}"

mkdir -p /opt
curl -fsSL "https://github.com/gitpod-io/openvscode-server/releases/download/openvscode-server-v${OPENVSCODE_VERSION}/openvscode-server-v${OPENVSCODE_VERSION}-linux-x64.tar.gz" \
    | tar -xz -C /opt
ln -sf "/opt/openvscode-server-v${OPENVSCODE_VERSION}-linux-x64/bin/openvscode-server" /usr/local/bin/openvscode-server
