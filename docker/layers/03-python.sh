#!/bin/bash
# Install Python and configure python/python3 alternatives.

set -euo pipefail

: "${PYTHON_VERSION:?PYTHON_VERSION is required}"

apt-get update
apt-get install -y --no-install-recommends \
    "python${PYTHON_VERSION}" \
    "python${PYTHON_VERSION}-venv" \
    "python${PYTHON_VERSION}-dev" \
    python3-pip
rm -rf /var/lib/apt/lists/*
update-alternatives --install /usr/bin/python3 python3 "/usr/bin/python${PYTHON_VERSION}" 1
update-alternatives --install /usr/bin/python python "/usr/bin/python${PYTHON_VERSION}" 1
