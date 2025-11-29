#!/bin/bash
# Build and test Docker image locally
# Usage: ./scripts/test-image.sh

set -e

IMAGE_NAME="buntoolbox:test"

echo "=========================================="
echo "Building Docker image..."
echo "=========================================="
docker build -t "$IMAGE_NAME" .

echo ""
echo "=========================================="
echo "Verifying installed tools..."
echo "=========================================="

docker run --rm "$IMAGE_NAME" bash -c '
set -e

check() {
    local name="$1"
    shift
    if output=$("$@" 2>&1); then
        echo "✓ $name: $(echo "$output" | head -1)"
    else
        echo "✗ $name: FAILED"
        exit 1
    fi
}

echo "=== Languages ==="
check "Java" java -version
check "Python" python --version
check "Node.js" node --version
check "Bun" bun --version
check "Go" go version
check "Rust" rustc --version
check "Cargo" cargo --version

echo ""
echo "=== Build Tools ==="
check "Maven" mvn --version
check "Gradle" gradle --version

echo ""
echo "=== Dev Tools ==="
check "Git" git --version
check "GitHub CLI" gh --version
check "jq" jq --version
check "ripgrep" rg --version
check "fd" fd --version
check "fzf" fzf --version
check "tmux" tmux -V
check "direnv" direnv version

echo ""
echo "=== TUI Tools ==="
check "lazygit" lazygit --version
check "helix" hx --version
check "bat" bat --version
check "eza" eza --version
check "delta" delta --version
check "btop" btop --version
check "starship" starship --version
check "zoxide" zoxide --version
'

echo ""
echo "=========================================="
echo "All tests passed!"
echo "=========================================="
