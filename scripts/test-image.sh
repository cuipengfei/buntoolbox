#!/bin/bash
# Build and test Docker image locally
# Usage: ./scripts/test-image.sh [image_name]
# Example: ./scripts/test-image.sh cuipengfei/buntoolbox:latest

set -e

IMAGE_NAME="${1:-buntoolbox:test}"

# If no argument provided, build the image first
if [ -z "$1" ]; then
    echo "=========================================="
    echo "Building Docker image..."
    echo "=========================================="
    docker build -t "$IMAGE_NAME" .
    echo ""
fi

echo "=========================================="
echo "Testing image: $IMAGE_NAME"
echo "=========================================="

# Create test script
TEST_SCRIPT=$(cat << 'EOF'
PASSED=0
FAILED=0

check() {
    local name="$1"
    local version_cmd="$2"
    local usage_cmd="$3"
    local expected="$4"

    if ! output=$(eval "$version_cmd" 2>&1); then
        echo "✗ $name: FAILED (not found)"
        FAILED=$((FAILED+1))
        return
    fi
    version=$(echo "$output" | head -1 | cut -c1-50)

    if output=$(eval "$usage_cmd" 2>&1); then
        if [ -n "$expected" ]; then
            if echo "$output" | grep -qF "$expected"; then
                echo "✓ $name: $version"
                PASSED=$((PASSED+1))
            else
                echo "✗ $name: $version (usage mismatch)"
                FAILED=$((FAILED+1))
            fi
        else
            echo "✓ $name: $version"
            PASSED=$((PASSED+1))
        fi
    else
        echo "✗ $name: $version (usage failed)"
        FAILED=$((FAILED+1))
    fi
}

echo "=== OS ==="
. /etc/os-release && echo "$NAME $VERSION"

echo ""
echo "=== Environment ==="
check "Locale" "locale" "locale | grep LANG" "C.UTF-8"

echo ""
echo "=== Languages ==="

# Java - compile and run
echo 'public class T{public static void main(String[]a){System.out.println(1+1);}}' > /tmp/T.java
check "Java 21" "java -version" "javac /tmp/T.java && java -cp /tmp T" "2"

# Python
check "Python" "python --version" "python -c 'import json; print(json.dumps({\"a\":1}))'" '{"a": 1}'

# Node.js
check "Node.js" "node --version" "node -e 'console.log(JSON.stringify({a:1}))'" '{"a":1}'

# Bun
check "Bun" "bun --version" "bun -e 'console.log(JSON.stringify({a:1}))'" '{"a":1}'

echo ""
echo "=== Build Tools ==="
check "Maven" "mvn --version" "mvn --version" "Apache Maven"
check "Gradle" "gradle --version" "gradle --version" "Gradle"
printf 'test:\n\t@echo ok\n' > /tmp/Makefile
check "make" "make --version" "make -f /tmp/Makefile test" "ok"
check "cmake" "cmake --version" "cmake --version" "cmake"
check "ninja" "ninja --version" "ninja --version" ""

echo ""
echo "=== Package Managers ==="
check "uv" "uv --version" "uv --help" "package"
check "uvx" "uvx --version" "uvx --version" ""
check "pipx" "pipx --version" "pipx list" ""
check "npm" "npm --version" "npm --version" ""

echo ""
echo "=== Version Control ==="
check "Git" "git --version" "git init /tmp/test-repo" "Initialized"
check "git-lfs" "git lfs version" "git lfs version" "git-lfs"
check "GitHub CLI" "gh --version" "gh --version" "gh version"

echo ""
echo "=== Dev Tools ==="
check "jq" "jq --version" "echo '{\"a\":1,\"b\":2}' | jq '.a + .b'" "3"
check "ripgrep" "rg --version" "printf 'foo\nbar\nbaz' | rg -n bar" "2:bar"
check "fd" "fd --version" "fd --type f . /etc 2>/dev/null | head -1" ""
check "fzf" "fzf --version" "printf 'a\nb' | fzf --filter=a" "a"
check "tmux" "tmux -V" "tmux -V" "tmux"
check "direnv" "direnv version" "direnv version" ""
check "htop" "htop --version" "htop --version" "htop"
check "tree" "tree --version" "tree -L 1 /tmp" "/tmp"
check "curl" "curl --version" "curl --version" "curl"
check "wget" "wget --version" "wget --version" "GNU Wget"
echo test > /tmp/z.txt
check "zip" "zip --version" "zip -j /tmp/z.zip /tmp/z.txt" "adding"
check "unzip" "unzip -v" "unzip -l /tmp/z.zip" "z.txt"
check "less" "less --version" "echo test | less -FX" "test"

echo ""
echo "=== Editors ==="
check "vim" "vim --version" "vim --version" "VIM"
check "nano" "nano --version" "nano --version" "nano"
check "helix" "hx --version" "hx --version" "helix"

echo ""
echo "=== TUI Tools ==="
check "lazygit" "lazygit --version" "lazygit --version" "version="
check "bat" "bat --version" "printf 'line1\nline2' | bat -p --color=never" "line1"
check "eza" "eza --version" "eza -1 /" "bin"
check "delta" "delta --version" "delta --version" "delta"
check "btop" "btop --version" "btop --version" "btop"
check "starship" "starship --version" "starship --version" "starship"
check "zoxide" "zoxide --version" "zoxide --version" "zoxide"
check "bd" "bd --help 2>&1 | head -1" "bd --help" "beads"
check "mihomo" "mihomo --version" "mihomo --help" ""

echo ""
echo "=========================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "=========================================="

[ $FAILED -eq 0 ]
EOF
)

docker run --rm "$IMAGE_NAME" bash -c "$TEST_SCRIPT"

echo ""
echo "=========================================="
echo "All tests passed!"
echo "=========================================="
