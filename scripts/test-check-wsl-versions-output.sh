#!/bin/bash
# Verify check-wsl-versions.sh uses Target wording in its table header.
# Usage: ./scripts/test-check-wsl-versions-output.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

header_lines="$("$PROJECT_ROOT/scripts/check-wsl-versions.sh" | sed -n '4,5p')"

printf '%s\n' "$header_lines" | grep -F "Target" >/dev/null
if printf '%s\n' "$header_lines" | grep -F "Latest" >/dev/null; then
    echo "Error: header still uses Latest"
    exit 1
fi

echo "ok"
