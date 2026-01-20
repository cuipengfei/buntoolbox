#!/bin/bash
# Test Docker image (pull from Docker Hub by default, no local build)
# Usage: ./scripts/test-image.sh [image_name]
# Example: ./scripts/test-image.sh cuipengfei/buntoolbox:latest

set -e

# Options:
#   -v, --verbose   Print full command outputs for each check
#   --no-pull       Skip docker pull (useful when offline if image already exists)
# Env:
#   DOCKER_BIN      Override docker CLI (e.g. Windows Docker Desktop docker.exe)
#   VERBOSE=1       Same as -v
#   SKIP_PULL=1     Same as --no-pull

DOCKER_BIN="${DOCKER_BIN:-docker}"
VERBOSE="${VERBOSE:-0}"
SKIP_PULL="${SKIP_PULL:-0}"
IMAGE_NAME="cuipengfei/buntoolbox:latest"

while [ $# -gt 0 ]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        --no-pull)
            SKIP_PULL=1
            shift
            ;;
        -i|--image)
            IMAGE_NAME="$2"
            shift 2
            ;;
        *)
            IMAGE_NAME="$1"
            shift
            ;;
    esac
done

echo "=========================================="
echo "Pulling image: $IMAGE_NAME"
echo "=========================================="
if [ "$SKIP_PULL" = "1" ]; then
  echo "(skip pull)"
else
  "$DOCKER_BIN" pull "$IMAGE_NAME"
fi
echo ""

echo "=========================================="
echo "Testing image: $IMAGE_NAME"
echo "=========================================="

# Extract expected versions from Dockerfile for verification
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE="$SCRIPT_DIR/../Dockerfile"
get_dockerfile_version() {
    grep "^ARG ${1}=" "$DOCKERFILE" 2>/dev/null | cut -d'=' -f2
}

# Extract JDK major version from zulu<N>-jdk-headless
get_dockerfile_jdk() {
    grep "zulu.*-jdk-headless" "$DOCKERFILE" | grep -oE 'zulu[0-9]+' | sed 's/zulu//'
}

# Extract Python version from python3.XX
get_dockerfile_python() {
    grep "python3\.[0-9]" "$DOCKERFILE" | grep -oE 'python3\.[0-9]+' | head -1 | sed 's/python//'
}

# Export versions as environment variables for container
EXPECTED_VERSIONS=""
EXPECTED_VERSIONS="$EXPECTED_VERSIONS -e EXPECT_JDK_MAJOR=$(get_dockerfile_jdk)"
EXPECTED_VERSIONS="$EXPECTED_VERSIONS -e EXPECT_PYTHON_VERSION=$(get_dockerfile_python)"
EXPECTED_VERSIONS="$EXPECTED_VERSIONS -e EXPECT_BUN_VERSION=$(get_dockerfile_version BUN_VERSION)"
EXPECTED_VERSIONS="$EXPECTED_VERSIONS -e EXPECT_NODE_MAJOR=$(get_dockerfile_version NODE_MAJOR)"
EXPECTED_VERSIONS="$EXPECTED_VERSIONS -e EXPECT_GRADLE_VERSION=$(get_dockerfile_version GRADLE_VERSION)"
EXPECTED_VERSIONS="$EXPECTED_VERSIONS -e EXPECT_MAVEN_VERSION=$(get_dockerfile_version MAVEN_VERSION)"
EXPECTED_VERSIONS="$EXPECTED_VERSIONS -e EXPECT_UV_VERSION=$(get_dockerfile_version UV_VERSION)"
EXPECTED_VERSIONS="$EXPECTED_VERSIONS -e EXPECT_BEADS_VERSION=$(get_dockerfile_version BEADS_VERSION)"
EXPECTED_VERSIONS="$EXPECTED_VERSIONS -e EXPECT_LAZYGIT_VERSION=$(get_dockerfile_version LAZYGIT_VERSION)"
EXPECTED_VERSIONS="$EXPECTED_VERSIONS -e EXPECT_HELIX_VERSION=$(get_dockerfile_version HELIX_VERSION)"
EXPECTED_VERSIONS="$EXPECTED_VERSIONS -e EXPECT_EZA_VERSION=$(get_dockerfile_version EZA_VERSION)"
EXPECTED_VERSIONS="$EXPECTED_VERSIONS -e EXPECT_DELTA_VERSION=$(get_dockerfile_version DELTA_VERSION)"
EXPECTED_VERSIONS="$EXPECTED_VERSIONS -e EXPECT_ZOXIDE_VERSION=$(get_dockerfile_version ZOXIDE_VERSION)"
EXPECTED_VERSIONS="$EXPECTED_VERSIONS -e EXPECT_STARSHIP_VERSION=$(get_dockerfile_version STARSHIP_VERSION)"
EXPECTED_VERSIONS="$EXPECTED_VERSIONS -e EXPECT_PROCS_VERSION=$(get_dockerfile_version PROCS_VERSION)"
EXPECTED_VERSIONS="$EXPECTED_VERSIONS -e EXPECT_ZELLIJ_VERSION=$(get_dockerfile_version ZELLIJ_VERSION)"
EXPECTED_VERSIONS="$EXPECTED_VERSIONS -e EXPECT_OPENVSCODE_VERSION=$(get_dockerfile_version OPENVSCODE_VERSION)"
EXPECTED_VERSIONS="$EXPECTED_VERSIONS -e EXPECT_MIHOMO_VERSION=$(get_dockerfile_version MIHOMO_VERSION)"
EXPECTED_VERSIONS="$EXPECTED_VERSIONS -e EXPECT_JDTLS_VERSION=$(get_dockerfile_version JDTLS_VERSION | cut -d'-' -f1)"

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

    local version_output
    local version
    local test_output
    local test_status
    local row_result

    # Get version (with timeout)
    version_output=$(timeout 5 bash -c "$version_cmd" 2>&1)
    test_status=$?
    if [ $test_status -ne 0 ]; then
        printf "%-${COL_NAME}s %-${COL_VER}s %-${COL_TEST}s %s\n" "$name" "-" "$test_desc" "✗ MISS"
        FAILED=$((FAILED+1))

        if [ "${VERBOSE:-0}" = "1" ]; then
            echo "---- ${name} (version_cmd failed) ----"
            echo "\$ $version_cmd"
            printf '%s\n' "$version_output"
            echo "--------------------------------------"
        fi
        return
    fi

    version=$(printf '%s\n' "$version_output" | grep -v '^$' | head -1 | cut -c1-${COL_VER})

    # Run functional test (with timeout)
    test_output=$(timeout 10 bash -c "$usage_cmd" 2>&1)
    test_status=$?

    row_result="✓ PASS"

    if [ $test_status -eq 0 ]; then
        if [ -n "$expected" ]; then
            if printf '%s\n' "$test_output" | grep -qF "$expected"; then
                row_result="✓ PASS"
                PASSED=$((PASSED+1))
            else
                row_result="✗ FAIL"
                FAILED=$((FAILED+1))
            fi
        else
            row_result="✓ PASS"
            PASSED=$((PASSED+1))
        fi
    else
        row_result="✗ FAIL"
        FAILED=$((FAILED+1))
    fi

    printf "%-${COL_NAME}s %-${COL_VER}s %-${COL_TEST}s %s\n" "$name" "$version" "$test_desc" "$row_result"

    if [ "${VERBOSE:-0}" = "1" ]; then
        echo "---- ${name} ----"
        echo "\$ $version_cmd"
        printf '%s\n' "$version_output"
        echo "\$ $usage_cmd"
        printf '%s\n' "$test_output"
        echo "--------------"
    fi
}

# check_ver: like check() but also verifies version matches expected from Dockerfile
# Usage: check_ver <name> <version_cmd> <usage_cmd> <expected> <test_desc> <expect_env_var>
check_ver() {
    local name="$1"
    local version_cmd="$2"
    local usage_cmd="$3"
    local expected="$4"
    local test_desc="$5"
    local expect_env_var="$6"

    local version_output
    local version
    local test_output
    local test_status
    local row_result
    local expected_version

    # Get expected version from environment
    expected_version="${!expect_env_var:-}"

    # Get version (with timeout)
    version_output=$(timeout 5 bash -c "$version_cmd" 2>&1)
    test_status=$?
    if [ $test_status -ne 0 ]; then
        printf "%-${COL_NAME}s %-${COL_VER}s %-${COL_TEST}s %s\n" "$name" "-" "$test_desc" "✗ MISS"
        FAILED=$((FAILED+1))
        return
    fi

    version=$(printf '%s\n' "$version_output" | grep -v '^$' | head -1 | cut -c1-${COL_VER})

    # Run functional test (with timeout)
    test_output=$(timeout 10 bash -c "$usage_cmd" 2>&1)
    test_status=$?

    row_result="✓ PASS"

    if [ $test_status -eq 0 ]; then
        if [ -n "$expected" ]; then
            if ! printf '%s\n' "$test_output" | grep -qF "$expected"; then
                row_result="✗ FAIL"
                FAILED=$((FAILED+1))
                printf "%-${COL_NAME}s %-${COL_VER}s %-${COL_TEST}s %s\n" "$name" "$version" "$test_desc" "$row_result"
                return
            fi
        fi
        # Version verification
        if [ -n "$expected_version" ]; then
            if printf '%s\n' "$version_output" | grep -qF "$expected_version"; then
                row_result="✓ PASS"
                PASSED=$((PASSED+1))
            else
                row_result="✗ VER (expect $expected_version)"
                FAILED=$((FAILED+1))
            fi
        else
            PASSED=$((PASSED+1))
        fi
    else
        row_result="✗ FAIL"
        FAILED=$((FAILED+1))
    fi

    printf "%-${COL_NAME}s %-${COL_VER}s %-${COL_TEST}s %s\n" "$name" "$version" "$test_desc" "$row_result"

    if [ "${VERBOSE:-0}" = "1" ]; then
        echo "---- ${name} ----"
        echo "\$ $version_cmd"
        printf '%s\n' "$version_output"
        echo "\$ $usage_cmd"
        printf '%s\n' "$test_output"
        [ -n "$expected_version" ] && echo "Expected version: $expected_version"
        echo "--------------"
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
check_ver "Java" "java -version 2>&1 | grep -oE 'version \"[0-9]+' | grep -oE '[0-9]+'" "javac /tmp/T.java && java -cp /tmp T" "2" "Compile & run (1+1=2)" "EXPECT_JDK_MAJOR"

check_ver "Python" "python --version | grep -oE '3\\.[0-9]+'" "python -c 'import json; print(json.dumps({\"a\":1}))'" '{"a": 1}' "JSON serialize dict" "EXPECT_PYTHON_VERSION"
check "pip" "pip --version" "pip list --format=columns | head -1" "Package" "List packages"

check_ver "Node.js" "node --version | grep -oE '[0-9]+' | head -1" "node -e 'console.log(JSON.stringify({a:1}))'" '{"a":1}' "JSON stringify object" "EXPECT_NODE_MAJOR"

check_ver "Bun" "bun --version" "bun -e 'console.log(JSON.stringify({a:1}))'" '{"a":1}' "JSON stringify object" "EXPECT_BUN_VERSION"
check "bunx" "bunx --version" "bunx --help | head -1" "Usage" "Show help"

echo ""
echo "=== Build Tools ==="
print_header
check_ver "Maven" "mvn --version | grep -oE 'Maven [0-9.]+' | cut -d' ' -f2" "mvn --version" "Apache Maven" "Verify installation" "EXPECT_MAVEN_VERSION"
check_ver "Gradle" "gradle --version | grep -oE 'Gradle [0-9.]+' | cut -d' ' -f2" "gradle --version" "Gradle" "Verify installation" "EXPECT_GRADLE_VERSION"
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
check_ver "uv" "uv --version" "uv venv --help | head -1" "Create" "Show venv help" "EXPECT_UV_VERSION"
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
check_ver "helix" "hx --version | grep -oE '[0-9.]+' | head -1" "hx --health 2>&1 | head -1" "Config" "Health check" "EXPECT_HELIX_VERSION"
check_ver "openvscode-server" "openvscode-server --version | head -1" "openvscode-server --help 2>&1 | head -1" "OpenVSCode Server" "Show help" "EXPECT_OPENVSCODE_VERSION"

echo ""
echo "=== TUI Tools ==="
print_header
cd /tmp/test-repo 2>/dev/null || git init /tmp/test-repo >/dev/null
check_ver "lazygit" "lazygit --version | grep -oE 'version=[0-9.]+' | cut -d= -f2" "lazygit --version" "version" "Verify installation" "EXPECT_LAZYGIT_VERSION"
check "bat" "bat --version | grep -oE '[0-9.]+' | head -1" "printf 'line1\nline2' | bat -p --color=never" "line1" "Syntax highlight"
check_ver "eza" "eza --version | grep -oE 'v[0-9.]+'" "eza -1 /" "bin" "List directory" "EXPECT_EZA_VERSION"
check_ver "delta" "delta --version | grep -oE '[0-9.]+'" "echo -e 'a\nb' | delta" "a" "Format diff" "EXPECT_DELTA_VERSION"
check "btop" "btop --version | grep -oE '[0-9.]+'" "btop --version" "btop" "Verify installation"
check_ver "procs" "procs --version | grep -oE '[0-9.]+' | head -1" "procs 1" "PID" "List processes" "EXPECT_PROCS_VERSION"
check_ver "zellij" "zellij --version | grep -oE '[0-9.]+'" "zellij setup --check 2>&1 | head -1" "" "Check setup" "EXPECT_ZELLIJ_VERSION"
check_ver "jdtls" "ls /opt/jdtls/plugins/org.eclipse.jdt.ls.core_*.jar 2>/dev/null | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+' | head -1" "jdtls --help 2>&1 | head -1" "usage" "Show help" "EXPECT_JDTLS_VERSION"

echo ""
echo "=== Shell Enhancements ==="
print_header
check_ver "starship" "starship --version | grep -oE '[0-9.]+'" "starship print-config 2>&1 | head -1" "" "Print config" "EXPECT_STARSHIP_VERSION"
check_ver "zoxide" "zoxide --version | grep -oE '[0-9.]+'" "zoxide add /tmp && zoxide query tmp" "/tmp" "Add & query path" "EXPECT_ZOXIDE_VERSION"

echo ""
echo "=== Other Tools ==="
print_header
check_ver "bd" "bd --version | grep -oE '[0-9.]+' | head -1" "bd --help" "beads" "Show help" "EXPECT_BEADS_VERSION"
check_ver "mihomo" "mihomo -v | grep -oE 'v[0-9.]+' | head -1" "mihomo -h" "Usage" "Show help" "EXPECT_MIHOMO_VERSION"
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
check "sshd" "sshd -V 2>&1 | grep -oE '[0-9.]+p[0-9]' | head -1" "sshd -t 2>&1; echo ok" "ok" "Validate config"
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
echo "=== Image Metadata ==="
print_header
check "image-release" "cat /etc/image-release | grep -c '^-' || echo 0" "cat /etc/image-release | grep -q 'buntoolbox' && echo ok" "ok" "Buntoolbox info present"

echo ""
echo "=========================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "=========================================="

[ $FAILED -eq 0 ]
EOF
)

"$DOCKER_BIN" run --rm -t -e VERBOSE="$VERBOSE" $EXPECTED_VERSIONS "$IMAGE_NAME" bash -c "$TEST_SCRIPT"

echo ""
echo "=========================================="
echo "All tests passed!"
echo "=========================================="
