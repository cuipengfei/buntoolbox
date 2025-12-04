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

# Column widths
COL_NAME=12
COL_VER=12
COL_TEST=32

print_header() {
    printf "%-${COL_NAME}s %-${COL_VER}s %-${COL_TEST}s %s\n" "Tool" "Version" "Test" "Result"
    printf "%-${COL_NAME}s %-${COL_VER}s %-${COL_TEST}s %s\n" "------------" "------------" "--------------------------------" "------"
}

check() {
    local name="$1"
    local version_cmd="$2"
    local usage_cmd="$3"
    local expected="$4"
    local test_desc="$5"

    # Get version (with timeout)
    if ! output=$(timeout 5 bash -c "$version_cmd" 2>&1); then
        printf "%-${COL_NAME}s %-${COL_VER}s %-${COL_TEST}s %s\n" "$name" "-" "$test_desc" "✗ MISS"
        FAILED=$((FAILED+1))
        return
    fi
    version=$(echo "$output" | grep -v '^$' | head -1 | cut -c1-${COL_VER})

    # Run functional test (with timeout)
    if output=$(timeout 10 bash -c "$usage_cmd" 2>&1); then
        if [ -n "$expected" ]; then
            if echo "$output" | grep -qF "$expected"; then
                printf "%-${COL_NAME}s %-${COL_VER}s %-${COL_TEST}s %s\n" "$name" "$version" "$test_desc" "✓ PASS"
                PASSED=$((PASSED+1))
            else
                printf "%-${COL_NAME}s %-${COL_VER}s %-${COL_TEST}s %s\n" "$name" "$version" "$test_desc" "✗ FAIL"
                FAILED=$((FAILED+1))
            fi
        else
            printf "%-${COL_NAME}s %-${COL_VER}s %-${COL_TEST}s %s\n" "$name" "$version" "$test_desc" "✓ PASS"
            PASSED=$((PASSED+1))
        fi
    else
        printf "%-${COL_NAME}s %-${COL_VER}s %-${COL_TEST}s %s\n" "$name" "$version" "$test_desc" "✗ FAIL"
        FAILED=$((FAILED+1))
    fi
}

echo "=== OS ==="
. /etc/os-release && echo "$NAME $VERSION"

echo ""
echo "=== Environment ==="
print_header
check "Locale" "locale" "locale | grep LANG" "C.UTF-8" "Check UTF-8 locale"

echo ""
echo "=== Languages ==="
print_header

# Java - compile and run
echo 'public class T{public static void main(String[]a){System.out.println(1+1);}}' > /tmp/T.java
check "Java" "java -version" "javac /tmp/T.java && java -cp /tmp T" "2" "Compile & run (1+1=2)"

check "Python" "python --version" "python -c 'import json; print(json.dumps({\"a\":1}))'" '{"a": 1}' "JSON serialize dict"

check "Node.js" "node --version" "node -e 'console.log(JSON.stringify({a:1}))'" '{"a":1}' "JSON stringify object"

check "Bun" "bun --version" "bun -e 'console.log(JSON.stringify({a:1}))'" '{"a":1}' "JSON stringify object"
check "bunx" "bunx --version" "bunx --help | head -1" "Usage" "Show help"

echo ""
echo "=== Build Tools ==="
print_header
check "Maven" "mvn --version | grep -oE 'Maven [0-9.]+' | cut -d' ' -f2" "mvn --version" "Apache Maven" "Verify installation"
check "Gradle" "gradle --version | grep -oE 'Gradle [0-9.]+' | cut -d' ' -f2" "gradle --version" "Gradle" "Verify installation"
printf 'test:\n\t@echo ok\n' > /tmp/Makefile
check "make" "make --version | grep -oE '[0-9.]+' | head -1" "make -f /tmp/Makefile test" "ok" "Run Makefile target"
printf 'cmake_minimum_required(VERSION 3.10)\nproject(test)\n' > /tmp/CMakeLists.txt
check "cmake" "cmake --version | grep -oE '[0-9.]+' | head -1" "cmake -S /tmp -B /tmp/cmake-build 2>&1" "Configuring done" "Configure CMake project"
echo 'rule echo' > /tmp/build.ninja && echo '  command = echo ok' >> /tmp/build.ninja && echo 'build out: echo' >> /tmp/build.ninja
check "ninja" "ninja --version" "ninja -C /tmp -t targets" "out" "Parse build.ninja"
check "gcc" "gcc --version | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+' | head -1" "echo 'int main(){return 0;}' > /tmp/t.c && gcc /tmp/t.c -o /tmp/t && /tmp/t && echo ok" "ok" "Compile & run C"
check "g++" "g++ --version | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+' | head -1" "echo 'int main(){return 0;}' > /tmp/t.cpp && g++ /tmp/t.cpp -o /tmp/t2 && /tmp/t2 && echo ok" "ok" "Compile & run C++"
check "pkg-config" "pkg-config --version" "pkg-config --modversion zlib 2>/dev/null || pkg-config --list-all | head -1" "" "Query installed packages"

echo ""
echo "=== Package Managers ==="
print_header
check "uv" "uv --version" "uv venv --help | head -1" "Create" "Show venv help"
check "uvx" "uvx --version" "uvx --help | head -3" "Run a command" "Show help"
check "pipx" "pipx --version" "pipx list" "pipx" "List packages"
check "npm" "npm --version" "npm config list" "node" "Show config"

echo ""
echo "=== Version Control ==="
print_header
check "Git" "git --version | grep -oE '[0-9.]+'" "git init /tmp/test-repo" "Initialized" "Init repository"
check "git-lfs" "git lfs version | grep -oE '[0-9.]+' | head -1" "git lfs install --skip-repo" "LFS" "Install LFS hooks"
check "GitHub CLI" "gh --version | grep -oE '[0-9.]+' | head -1" "gh help" "USAGE" "Show help"

echo ""
echo "=== Dev Tools ==="
print_header
check "jq" "jq --version | grep -oE '[0-9.]+'" "echo '{\"a\":1,\"b\":2}' | jq '.a + .b'" "3" "Parse JSON (1+2=3)"
check "ripgrep" "rg --version | grep -oE '[0-9.]+' | head -1" "printf 'foo\nbar\nbaz' | rg -n bar" "2:bar" "Search text"
check "fd" "fd --version | grep -oE '[0-9.]+'" "fd --type f . /etc 2>/dev/null | head -1" "/" "Find files in /etc"
check "fzf" "fzf --version | grep -oE '[0-9.]+' | head -1" "printf 'a\nb' | fzf --filter=a" "a" "Filter list"
check "tmux" "tmux -V | grep -oE '[0-9.]+'" "tmux new-session -d -s test && tmux kill-session -t test && echo ok" "ok" "Create/kill session"
check "direnv" "direnv version" "direnv stdlib | head -1" "#!/" "Dump stdlib"
check "htop" "htop --version | grep -oE '[0-9.]+' | head -1" "htop --version" "htop" "Verify installation"
check "tree" "tree --version | grep -oE '[0-9.]+' | head -1" "tree -L 1 /tmp" "/tmp" "List directory tree"
check "curl" "curl --version | grep -oE '[0-9.]+' | head -1" "curl -s --connect-timeout 1 http://localhost 2>&1 || echo ok" "ok" "Test HTTP client"
check "wget" "wget --version | grep -oE '[0-9.]+' | head -1" "wget --spider --timeout=1 http://localhost 2>&1 || echo ok" "ok" "Test HTTP client"
echo test > /tmp/z.txt
check "zip" "zip --version | grep -oE 'Zip [0-9.]+' | grep -oE '[0-9.]+'" "zip -j /tmp/z.zip /tmp/z.txt" "adding" "Create archive"
check "unzip" "unzip -v | grep -oE '[0-9.]+' | head -1" "unzip -l /tmp/z.zip" "z.txt" "List archive"
check "less" "less --version | grep -oE '[0-9]+' | head -1" "echo test | less -FX" "test" "Page text"

echo ""
echo "=== Editors ==="
print_header
check "vim" "vim --version | grep -oE 'Vi IMproved [0-9.]+' | grep -oE '[0-9.]+'" "vim --version | head -1" "VIM" "Verify installation"
check "nano" "nano --version | grep -oE '[0-9.]+' | head -1" "nano --version" "nano" "Verify installation"
check "helix" "hx --version | grep -oE '[0-9.]+' | head -1" "hx --health 2>&1 | head -1" "Config" "Health check"

echo ""
echo "=== TUI Tools ==="
print_header
cd /tmp/test-repo 2>/dev/null || git init /tmp/test-repo >/dev/null
check "lazygit" "lazygit --version | grep -oE 'version=[0-9.]+' | cut -d= -f2" "lazygit --version" "version" "Verify installation"
check "bat" "bat --version | grep -oE '[0-9.]+' | head -1" "printf 'line1\nline2' | bat -p --color=never" "line1" "Syntax highlight"
check "eza" "eza --version | grep -oE 'v[0-9.]+'" "eza -1 /" "bin" "List directory"
check "delta" "delta --version | grep -oE '[0-9.]+'" "echo -e 'a\nb' | delta" "a" "Format diff"
check "btop" "btop --version | grep -oE '[0-9.]+'" "btop --version" "btop" "Verify installation"
check "procs" "procs --version | grep -oE '[0-9.]+' | head -1" "procs 1" "PID" "List processes"

echo ""
echo "=== Shell Enhancements ==="
print_header
check "starship" "starship --version | grep -oE '[0-9.]+'" "starship print-config 2>&1 | head -1" "" "Print config"
check "zoxide" "zoxide --version | grep -oE '[0-9.]+'" "zoxide add /tmp && zoxide query tmp" "/tmp" "Add & query path"

echo ""
echo "=== Other Tools ==="
print_header
check "bd" "bd --version | grep -oE '[0-9.]+' | head -1" "bd --help" "beads" "Show help"
check "mihomo" "mihomo -v | grep -oE 'v[0-9.]+' | head -1" "mihomo -h" "Usage" "Show help"
check "gpg" "gpg --version | grep -oE '[0-9.]+' | head -1" "echo test | gpg --symmetric --batch --passphrase test -o /tmp/test.gpg && echo ok" "ok" "Symmetric encrypt"
check "lsb_release" "lsb_release -rs" "lsb_release -a 2>&1" "Ubuntu" "Show distro info"

echo ""
echo "=== Network Tools ==="
print_header
check "ping" "ping -V 2>&1 | grep -oE '[0-9]+' | head -1" "ping -c 1 127.0.0.1 2>&1" "1 packets" "Ping loopback"
check "ip" "ip -V 2>&1 | grep -oE 'iproute2-[0-9.]+' | cut -d- -f2" "ip addr" "lo:" "Show interfaces"
check "ss" "ss -V 2>&1 | grep -oE 'iproute2-[0-9.]+' | cut -d- -f2" "ss -tuln 2>&1 | head -1" "Netid" "List sockets"
check "dig" "dig -v 2>&1 | grep -oE '[0-9.]+' | head -1" "dig -h 2>&1 | head -1" "Usage" "Show help"
check "nslookup" "nslookup -version 2>&1 | grep -oE '[0-9.]+' | head -1" "nslookup -version 2>&1" "nslookup" "Verify installation"
check "host" "host -V 2>&1 | grep -oE '[0-9.]+' | head -1" "host -h 2>&1 | head -1" "host" "Show help"
check "nc" "dpkg -l netcat-openbsd | grep -oE '[0-9.]+' | head -1" "nc -h 2>&1" "usage" "Show help"
check "traceroute" "traceroute --version 2>&1 | grep -oE '[0-9.]+'" "traceroute --version 2>&1" "traceroute" "Verify installation"
check "socat" "socat -V 2>&1 | grep -oE '[0-9.]+\\.[0-9.]+' | head -1" "echo test | socat - -" "test" "Echo via socat"
check "ssh" "ssh -V 2>&1 | grep -oE '[0-9.]+p[0-9]' | head -1" "ssh -V 2>&1" "OpenSSH" "Verify installation"
check "scp" "ssh -V 2>&1 | grep -oE '[0-9.]+p[0-9]' | head -1" "scp 2>&1 | head -1" "usage" "Show help"
check "sftp" "ssh -V 2>&1 | grep -oE '[0-9.]+p[0-9]' | head -1" "sftp -h 2>&1 | head -1" "usage" "Show help"
check "telnet" "dpkg -l telnet | grep -oE '[0-9]+\\.[0-9]+' | head -1" "echo quit | telnet 2>&1 | head -1" "telnet" "Start client"

echo ""
echo "=== Development Tools ==="
print_header
check "file" "file --version 2>&1 | grep -oE '[0-9.]+'" "file /bin/bash" "ELF" "Detect file type"
check "lsof" "lsof -v 2>&1 | grep -oE '[0-9.]+' | head -1" "lsof -v 2>&1" "lsof" "Verify installation"
check "killall" "killall -V 2>&1 | grep -oE '[0-9.]+'" "killall -V 2>&1" "killall" "Verify installation"
check "fuser" "fuser -V 2>&1 | grep -oE '[0-9.]+'" "fuser -V 2>&1" "PSmisc" "Verify installation"
check "pstree" "pstree -V 2>&1 | grep -oE '[0-9.]+'" "pstree 1 2>&1 | head -1" "" "Show process tree"
check "bc" "bc --version 2>&1 | grep -oE '[0-9.]+' | head -1" "echo '2+2' | bc" "4" "Calculate 2+2=4"

echo ""
echo "=========================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "=========================================="

[ $FAILED -eq 0 ]
EOF
)

docker run --rm -t "$IMAGE_NAME" bash -c "$TEST_SCRIPT"

echo ""
echo "=========================================="
echo "All tests passed!"
echo "=========================================="
