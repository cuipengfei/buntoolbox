#!/bin/bash
# Install HTTPie.

set -euo pipefail

: "${HTTPIE_VERSION:?HTTPIE_VERSION is required}"

python3 -m pip install --no-cache-dir --break-system-packages "httpie==${HTTPIE_VERSION}"
