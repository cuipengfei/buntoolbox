#!/bin/bash
# Test Docker image (pull from Docker Hub by default, no local build)
# Usage: ./scripts/test-image.sh [image_name]
# Example: ./scripts/test-image.sh cuipengfei/buntoolbox:latest

set -e

IMAGE_NAME="${1:-cuipengfei/buntoolbox:latest}"

echo "=========================================="
echo "Pulling image: $IMAGE_NAME"
echo "=========================================="
docker pull "$IMAGE_NAME"
echo ""

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
    version=$(echo "$output" | grep -v '^$' | head -1 | cut -c1-60)

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
check "Maven" "mvn --version | grep -oE 'Maven [0-9.]+' | cut -d' ' -f2" "mvn --version" "Apache Maven"
check "Gradle" "gradle --version | grep -oE 'Gradle [0-9.]+' | cut -d' ' -f2" "gradle --version" "Gradle"
printf 'test:\n\t@echo ok\n' > /tmp/Makefile
check "make" "make --version | grep -oE '[0-9.]+' | head -1" "make -f /tmp/Makefile test" "ok"
check "cmake" "cmake --version | grep -oE '[0-9.]+' | head -1" "cmake --version" "cmake"
check "ninja" "ninja --version" "ninja --version" ""
check "gcc" "gcc --version | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+' | head -1" "echo 'int main(){return 0;}' > /tmp/t.c && gcc /tmp/t.c -o /tmp/t && /tmp/t && echo ok" "ok"
check "g++" "g++ --version | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+' | head -1" "echo 'int main(){return 0;}' > /tmp/t.cpp && g++ /tmp/t.cpp -o /tmp/t2 && /tmp/t2 && echo ok" "ok"
check "pkg-config" "pkg-config --version" "pkg-config --version" ""

echo ""
echo "=== Package Managers ==="
check "uv" "uv --version" "uv --help" "package"
check "uvx" "uvx --version" "uvx --version" ""
check "pipx" "pipx --version" "pipx list" ""
check "npm" "npm --version" "npm --version" ""

echo ""
echo "=== Version Control ==="
check "Git" "git --version | grep -oE '[0-9.]+'" "git init /tmp/test-repo" "Initialized"
check "git-lfs" "git lfs version | grep -oE '[0-9.]+' | head -1" "git lfs version" "git-lfs"
check "GitHub CLI" "gh --version | grep -oE '[0-9.]+' | head -1" "gh --version" "gh version"

echo ""
echo "=== Dev Tools ==="
check "jq" "jq --version | grep -oE '[0-9.]+'" "echo '{\"a\":1,\"b\":2}' | jq '.a + .b'" "3"
check "ripgrep" "rg --version | grep -oE '[0-9.]+' | head -1" "printf 'foo\nbar\nbaz' | rg -n bar" "2:bar"
check "fd" "fd --version | grep -oE '[0-9.]+'" "fd --type f . /etc 2>/dev/null | head -1" ""
check "fzf" "fzf --version | grep -oE '[0-9.]+' | head -1" "printf 'a\nb' | fzf --filter=a" "a"
check "tmux" "tmux -V | grep -oE '[0-9.]+'" "tmux -V" "tmux"
check "direnv" "direnv version" "direnv version" ""
check "htop" "htop --version | grep -oE '[0-9.]+' | head -1" "htop --version" "htop"
check "tree" "tree --version | grep -oE '[0-9.]+' | head -1" "tree -L 1 /tmp" "/tmp"
check "curl" "curl --version | grep -oE '[0-9.]+' | head -1" "curl --version" "curl"
check "wget" "wget --version | grep -oE '[0-9.]+' | head -1" "wget --version" "GNU Wget"
echo test > /tmp/z.txt
check "zip" "zip --version | grep -oE 'Zip [0-9.]+' | grep -oE '[0-9.]+'" "zip -j /tmp/z.zip /tmp/z.txt" "adding"
check "unzip" "unzip -v | grep -oE '[0-9.]+' | head -1" "unzip -l /tmp/z.zip" "z.txt"
check "less" "less --version | grep -oE '[0-9]+' | head -1" "echo test | less -FX" "test"

echo ""
echo "=== Editors ==="
check "vim" "vim --version | grep -oE 'Vi IMproved [0-9.]+' | grep -oE '[0-9.]+'" "vim --version" "VIM"
check "nano" "nano --version | grep -oE '[0-9.]+' | head -1" "nano --version" "nano"
check "helix" "hx --version | grep -oE '[0-9.]+' | head -1" "hx --version" "helix"

echo ""
echo "=== TUI 工具 ==="
check "lazygit" "lazygit --version | grep -oE 'version=[0-9.]+' | cut -d= -f2" "lazygit --version" "version="
check "bat" "bat --version | grep -oE '[0-9.]+' | head -1" "printf 'line1\nline2' | bat -p --color=never" "line1"
check "eza" "eza --version | grep -oE 'v[0-9.]+'" "eza -1 /" "bin"
check "delta" "delta --version | grep -oE '[0-9.]+'" "delta --version" "delta"
check "btop" "btop --version | grep -oE '[0-9.]+'" "btop --version" "btop"

echo ""
echo "=== Shell 增强 ==="
check "starship" "starship --version | grep -oE '[0-9.]+'" "starship --version" "starship"
check "zoxide" "zoxide --version | grep -oE '[0-9.]+'" "zoxide --version" "zoxide"

echo ""
echo "=== 其他工具 ==="
check "bd" "bd --version | grep -oE '[0-9.]+' | head -1" "bd --help" "beads"
check "mihomo" "mihomo -v | grep -oE 'v[0-9.]+' | head -1" "mihomo -h" "Usage"
check "gpg" "gpg --version | grep -oE '[0-9.]+' | head -1" "gpg --version" "GnuPG"
check "lsb_release" "lsb_release -rs" "lsb_release -a 2>&1" "Ubuntu"

echo ""
echo "=== 网络工具 ==="
check "ping" "ping -V 2>&1 | grep -oE '[0-9]+' | head -1" "ping -c 1 127.0.0.1 2>&1" "1 packets"
check "ip" "ip -V 2>&1 | grep -oE 'iproute2-[0-9.]+' | cut -d- -f2" "ip addr" "lo:"
check "ss" "ss -V 2>&1 | grep -oE 'iproute2-[0-9.]+' | cut -d- -f2" "ss -tuln" ""
check "dig" "dig -v 2>&1 | grep -oE '[0-9.]+' | head -1" "dig +short localhost || true" ""
check "nslookup" "nslookup -version 2>&1 | grep -oE '[0-9.]+' | head -1" "nslookup localhost 2>&1 | head -1" ""
check "host" "host -V 2>&1 | grep -oE '[0-9.]+' | head -1" "host localhost 2>&1 | head -1" ""
check "nc" "dpkg -l netcat-openbsd | grep -oE '[0-9.]+' | head -1" "nc -h 2>&1 | head -1" ""
check "traceroute" "traceroute --version 2>&1 | grep -oE '[0-9.]+'" "traceroute --version 2>&1" "traceroute"
check "socat" "socat -V 2>&1 | grep -oE '[0-9.]+\\.[0-9.]+' | head -1" "socat -V 2>&1" "socat"
check "ssh" "ssh -V 2>&1 | grep -oE '[0-9.]+p[0-9]' | head -1" "ssh -V 2>&1" "OpenSSH"
check "scp" "ssh -V 2>&1 | grep -oE '[0-9.]+p[0-9]' | head -1" "command -v scp" ""
check "sftp" "ssh -V 2>&1 | grep -oE '[0-9.]+p[0-9]' | head -1" "command -v sftp" ""
check "telnet" "dpkg -l telnet | grep -oE '[0-9]+\\.[0-9]+' | head -1" "command -v telnet" ""

echo ""
echo "=== 开发工具 ==="
check "file" "file --version 2>&1 | grep -oE '[0-9.]+'" "file /bin/bash" "ELF"
check "lsof" "lsof -v 2>&1 | grep -oE '[0-9.]+' | head -1" "lsof -v 2>&1" "revision"
check "killall" "killall -V 2>&1 | grep -oE '[0-9.]+'" "killall -V 2>&1" "killall"
check "fuser" "fuser -V 2>&1 | grep -oE '[0-9.]+'" "fuser -V 2>&1" "PSmisc"
check "pstree" "pstree -V 2>&1 | grep -oE '[0-9.]+'" "pstree -V 2>&1" "pstree"
check "bc" "bc --version 2>&1 | grep -oE '[0-9.]+' | head -1" "echo '2+2' | bc" "4"

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
