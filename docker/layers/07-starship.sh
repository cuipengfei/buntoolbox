#!/bin/bash
# Install starship.

set -euo pipefail

: "${STARSHIP_VERSION:?STARSHIP_VERSION is required}"

curl -fsSL "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-x86_64-unknown-linux-gnu.tar.gz" \
    | tar -xz -C /usr/local/bin
