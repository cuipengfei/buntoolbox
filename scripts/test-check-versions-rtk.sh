#!/bin/bash
# Verify rtk release asset checks for available and missing downloads.
# Usage: bash scripts/test-check-versions-rtk.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Keep the checker isolated from the shared release cache and the network.
mkdir() {
    if [[ "$*" != "-p /tmp/check-versions-cache" ]]; then
        command mkdir "$@"
    fi
}
gh() { return 1; }
jq() {
    if [[ "${!#}" == '.tag_name // empty' ]]; then
        command cat >/dev/null
        printf 'v999.0.0\n'
    else
        command jq "$@"
    fi
}
curl() {
    local url="${!#}"
    case "$url" in
        https://api.github.com/*) return 1 ;;
        https://changelogs.ubuntu.com/*) printf 'Version: 26.04\n' ;;
        https://repos.azul.com/*)
            printf 'Package: zulu25-jdk-headless\nVersion: 25.0.5.0.3-5\n\n' | gzip -c
            ;;
        https://endoflife.date/api/python.json) printf '[{"cycle":"3.14"}]' ;;
        https://endoflife.date/api/maven.json) printf '[{"latest":"3.10.0"}]' ;;
        https://nodejs.org/dist/index.json) printf '[{"version":"v24.22.3"}]' ;;
        https://services.gradle.org/versions/current) printf '{"version":"9.9.1"}' ;;
        https://pypi.org/pypi/httpie/json) printf '{"info":{"version":"3.2.4"}}' ;;
        https://github.com/rtk-ai/rtk/releases/download/*)
            if [[ "$url" == */rtk-x86_64-unknown-linux-musl.tar.gz ]]; then
                printf '%s' "$RTK_ASSET_STATUS"
            else
                printf '404'
            fi
            ;;
        https://github.com/*/releases/download/*) printf '200' ;;
        *) return 1 ;;
    esac
}
export -f mkdir gh jq curl

available_output="$(RTK_ASSET_STATUS=200 "$SCRIPT_DIR/check-versions.sh" 2>&1)"
if ! grep -Eq '^rtk[[:space:]]+[^[:space:]]+[[:space:]]+999\.0\.0' <<< "$available_output"; then
    echo 'rtk update was not checked' >&2
    exit 1
fi
if grep -Fq 'asset missing: rtk-' <<< "$available_output"; then
    grep -F 'asset missing: rtk-' <<< "$available_output" >&2
    exit 1
fi

missing_output="$(RTK_ASSET_STATUS=404 "$SCRIPT_DIR/check-versions.sh" 2>&1)"
if ! grep -Fq 'asset missing: rtk-x86_64-unknown-linux-musl.tar.gz' <<< "$missing_output"; then
    echo 'missing rtk asset was not reported' >&2
    exit 1
fi

echo 'rtk release asset checks: PASS'
