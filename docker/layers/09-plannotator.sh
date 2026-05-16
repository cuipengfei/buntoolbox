#!/bin/bash
# Install Plannotator CLI binary only.
#
# Intentionally does not install agent skills, slash commands, hooks, plugins,
# or user-level config. Users may mount their own ~/.codex / ~/.claude /
# ~/.config/opencode into the container, so image build-time agent config would
# either be hidden by mounts or unexpectedly mutate default homes.

set -euo pipefail

: "${PLANNOTATOR_VERSION:?PLANNOTATOR_VERSION is required}"

repo="backnotprop/plannotator"
tag="v${PLANNOTATOR_VERSION}"
asset="plannotator-linux-x64"
base_url="https://github.com/${repo}/releases/download/${tag}"
install_dir="${PLANNOTATOR_INSTALL_DIR:-/usr/local/bin}"
tmp_file="$(mktemp)"
tmp_sha="$(mktemp)"

cleanup() {
    rm -f "$tmp_file" "$tmp_sha"
}
trap cleanup EXIT

curl -fsSL -o "$tmp_file" "${base_url}/${asset}"
curl -fsSL -o "$tmp_sha" "${base_url}/${asset}.sha256"

expected_checksum="$(cut -d' ' -f1 < "$tmp_sha")"
actual_checksum="$(sha256sum "$tmp_file" | cut -d' ' -f1)"

if [ "$actual_checksum" != "$expected_checksum" ]; then
    echo "Plannotator checksum verification failed" >&2
    echo "expected: $expected_checksum" >&2
    echo "actual:   $actual_checksum" >&2
    exit 1
fi

mkdir -p "$install_dir"
install -m 0755 "$tmp_file" "$install_dir/plannotator"

"$install_dir/plannotator" --version | grep -F "$PLANNOTATOR_VERSION" >/dev/null
