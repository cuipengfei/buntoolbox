#!/bin/bash
# Install duf.

set -euo pipefail

: "${DUF_VERSION:?DUF_VERSION is required}"

curl -fsSL "https://github.com/muesli/duf/releases/download/v${DUF_VERSION}/duf_${DUF_VERSION}_linux_amd64.deb" -o /tmp/duf.deb
apt-get install -y /tmp/duf.deb
rm /tmp/duf.deb
