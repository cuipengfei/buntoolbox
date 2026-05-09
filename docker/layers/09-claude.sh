#!/bin/bash
# Install Claude Code.

set -euo pipefail

: "${CLAUDE_CODE_VERSION:?CLAUDE_CODE_VERSION is required}"

curl -fsSL https://claude.ai/install.sh | bash -s "${CLAUDE_CODE_VERSION}"
