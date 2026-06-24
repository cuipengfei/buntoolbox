#!/bin/bash
# Install herdr.

set -euo pipefail

: "${HERDR_VERSION:?HERDR_VERSION is required}"
: "${HERDR_REPO:?HERDR_REPO is required}"

tag="v${HERDR_VERSION}"
asset="herdr-linux-x86_64"
base_url="https://github.com/${HERDR_REPO}/releases/download/${tag}"
install_dir="${HERDR_INSTALL_DIR:-/usr/local/bin}"

curl -fsSL -o "${install_dir}/herdr" "${base_url}/${asset}"
chmod 0755 "${install_dir}/herdr"

"${install_dir}/herdr" --version | grep -F "$HERDR_VERSION" >/dev/null
