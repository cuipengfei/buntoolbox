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
    local usage_timeout="${6:-10}"

    local version_output
    local version
    local test_output
    local test_status
    local row_result

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
    test_output=$(timeout "$usage_timeout" bash -c "$usage_cmd" 2>&1)
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

# check_ver: like check() but also verifies version matches expected from shared env/Dockerfile.
# Usage: check_ver <name> <version_cmd> <usage_cmd> <expected> <test_desc> <expect_env_var>
check_ver() {
    local name="$1"
    local version_cmd="$2"
    local usage_cmd="$3"
    local expected="$4"
    local test_desc="$5"
    local expect_env_var="$6"
    local usage_timeout="${7:-10}"

    local version_output
    local version
    local test_output
    local test_status
    local row_result
    local expected_version

    expected_version="${!expect_env_var:-}"
    version_output=$(timeout 5 bash -c "$version_cmd" 2>&1)
    test_status=$?
    if [ $test_status -ne 0 ]; then
        printf "%-${COL_NAME}s %-${COL_VER}s %-${COL_TEST}s %s\n" "$name" "-" "$test_desc" "✗ MISS"
        FAILED=$((FAILED+1))
        return
    fi

    version=$(printf '%s\n' "$version_output" | grep -v '^$' | head -1 | cut -c1-${COL_VER})
    test_output=$(timeout "$usage_timeout" bash -c "$usage_cmd" 2>&1)
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

check "os-release" ". /etc/os-release && printf '%s\n' \"\$VERSION_ID\"" ". /etc/os-release && printf '%s %s\n' \"\$VERSION_ID\" \"\$VERSION_CODENAME\"" "26.04 resolute" "Verify Ubuntu 26.04 metadata"

echo ""
echo "=== Environment ==="
print_header
check "Locale" "locale" "locale | grep LANG" "C.UTF-8" "Check UTF-8 locale"

echo ""
echo "=== Languages ==="
print_header

echo 'public class T{public static void main(String[]a){System.out.println(1+1);}}' > /tmp/T.java
check_ver "Java" "java -version 2>&1 | sed -n '1s/.*version \"\([^\"]*\)\".*/\1/p'" "javac /tmp/T.java && java -cp /tmp T" "2" "Compile & run (1+1=2)" "EXPECT_JDK_RUNTIME_VERSION"
check_ver "JDK pkg" "dpkg -s zulu25-jdk-headless | awk -F': ' '/^Version: /{print \$2}'" "dpkg -s zulu25-jdk-headless | awk -F': ' '/^Package: /{print \$2}'" "zulu25-jdk-headless" "Check package version" "EXPECT_JDK_PACKAGE_VERSION"

check_ver "Python" "python --version | grep -oE '3\\.[0-9]+'" "python -c 'import json; print(json.dumps({\"a\":1}))'" '{"a": 1}' "JSON serialize dict" "EXPECT_PYTHON_VERSION"
check "pip" "pip --version" "pip list --format=columns | head -1" "Package" "List packages"

check_ver "Node.js" "node --version | sed 's/^v//'" "node -e 'console.log(JSON.stringify({a:1}))'" '{"a":1}' "JSON stringify object" "EXPECT_NODE_VERSION"

check_ver "Bun" "bun --version" "bun -e 'console.log(JSON.stringify({a:1}))'" '{"a":1}' "JSON stringify object" "EXPECT_BUN_VERSION"
check "bunx" "bunx --version" "bunx cowsay 'ok bunx' 2>/dev/null" "ok bunx" "Run package via bunx"

echo ""
echo "=== Build Tools ==="
print_header
check_ver "Maven" "mvn --version | grep -oE 'Maven [0-9.]+' | cut -d' ' -f2" "printf '<project><modelVersion>4.0.0</modelVersion><groupId>x</groupId><artifactId>y</artifactId><version>1</version></project>' > /tmp/mvn-pom.xml && mvn -q -f /tmp/mvn-pom.xml validate && echo ok" "ok" "Run mvn validate" "EXPECT_MAVEN_VERSION"
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
check_ver "httpie" "http --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1" "http --offline GET https://example.com >/dev/null && echo ok" "ok" "Execute offline request" "EXPECT_HTTPIE_VERSION"
check_ver "uv" "uv --version" "rm -rf /tmp/uv-smoke && uv venv /tmp/uv-smoke >/dev/null && [ -x /tmp/uv-smoke/bin/python ] && echo ok" "ok" "Create virtual env" "EXPECT_UV_VERSION"
check "uvx" "uvx --version" "uvx --from pycowsay pycowsay ok-uvx 2>/dev/null" "ok-uvx" "Run package via uvx"
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
check "htop" "htop --version | grep -oE '[0-9.]+' | head -1" "htop --help 2>&1 | head -1" "htop" "Show help"
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
check "vim" "vim --version | grep -oE 'Vi IMproved [0-9.]+' | grep -oE '[0-9.]+'" "printf 'ok\ngo-vim\n' > /tmp/vim-smoke.txt && vim -es -u NONE -c 'wq' /tmp/vim-smoke.txt && tail -1 /tmp/vim-smoke.txt" "go-vim" "Edit file in ex mode"
check "nano" "nano --version | grep -oE '[0-9.]+' | head -1" "nano --help 2>&1 | head -1" "Usage:" "Show help"
check_ver "helix" "hx --version | grep -oE '[0-9.]+' | head -1" "hx --health 2>&1 | head -1" "Config" "Health check" "EXPECT_HELIX_VERSION"
check_ver "openvscode-server" "openvscode-server --version | head -1" "openvscode-server --help >/dev/null 2>&1 && echo ok" "ok" "Show help" "EXPECT_OPENVSCODE_VERSION"
check_ver "ttyd" "ttyd --version | grep -oE '[0-9.]+' | head -1" "ttyd --version" "ttyd" "Verify installation" "EXPECT_TTYD_VERSION"

echo ""
echo "=== TUI Tools ==="
print_header
cd /tmp/test-repo 2>/dev/null || git init /tmp/test-repo >/dev/null
check_ver "lazygit" "lazygit --version | grep -oE 'version=[0-9.]+' | cut -d= -f2" "lazygit --help | head -1" "Usage:" "Show help" "EXPECT_LAZYGIT_VERSION"
check "bat" "bat --version | grep -oE '[0-9.]+' | head -1" "printf 'line1\nline2' | bat -p --color=never" "line1" "Syntax highlight"
check_ver "eza" "eza --version | grep -oE 'v[0-9.]+'" "eza -1 /" "bin" "List directory" "EXPECT_EZA_VERSION"
check_ver "delta" "delta --version | grep -oE '[0-9.]+'" "echo -e 'a\nb' | delta" "a" "Format diff" "EXPECT_DELTA_VERSION"
check "btop" "btop --version | grep -oE '[0-9.]+'" "btop --help 2>&1 | head -1" "btop" "Show help"
check_ver "procs" "procs --version | grep -oE '[0-9.]+' | head -1" "procs 1" "PID" "List processes" "EXPECT_PROCS_VERSION"
check_ver "zellij" "zellij --version | grep -oE '[0-9.]+'" "zellij setup --check 2>&1 | head -1" "" "Check setup" "EXPECT_ZELLIJ_VERSION"
check_ver "duf" "duf --version | grep -oE '[0-9.]+' | head -1" "duf --json / >/dev/null 2>&1 && echo ok" "ok" "Emit JSON disk stats" "EXPECT_DUF_VERSION"

echo ""
echo "=== Shell Enhancements ==="
print_header
check_ver "starship" "starship --version | grep -oE '[0-9.]+'" "starship print-config 2>&1 | head -1" "" "Print config" "EXPECT_STARSHIP_VERSION"
check_ver "zoxide" "zoxide --version | grep -oE '[0-9.]+'" "zoxide add /tmp && zoxide query tmp" "/tmp" "Add & query path" "EXPECT_ZOXIDE_VERSION"
check "zsh" "zsh --version | grep -oE '[0-9.]+' | head -1" "zsh -c 'echo ok'" "ok" "Run zsh command"
check "oh-my-zsh" "ls /root/.oh-my-zsh/oh-my-zsh.sh >/dev/null 2>&1 && echo installed" "test -d /root/.oh-my-zsh && echo ok" "ok" "Directory exists"
check "zsh-autosuggestions" "ls /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions >/dev/null 2>&1 && echo installed" "grep -q zsh-autosuggestions /root/.zshrc && echo ok" "ok" "Plugin enabled in zshrc"
check "zshrc" "test -f /root/.zshrc && echo exists" "grep -q 'ZSH_THEME' /root/.zshrc && echo ok" "ok" "Config file exists"

echo ""
echo "=== Other Tools ==="
print_header
check_ver "bd" "bd --version | grep -oE '[0-9.]+' | head -1" "bd --help | grep -qi 'beads' && echo ok" "ok" "Parse beads help output" "EXPECT_BEADS_VERSION"
check_ver "claude" "claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'" "claude --help </dev/null 2>&1 | grep -q 'Usage: claude' && echo ok" "ok" "Parse CLI help output" "EXPECT_CLAUDE_CODE_VERSION"
check_ver "rtk" "rtk --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1" "rtk --help 2>&1 | grep -q 'Usage:' && echo ok" "ok" "Show help" "EXPECT_RTK_VERSION"
check "gpg" "gpg --version | grep -oE '[0-9.]+' | head -1" "echo test | gpg --symmetric --batch --passphrase test -o /tmp/test.gpg && echo ok" "ok" "Symmetric encrypt"
check "lsb_release" "lsb_release -rs" "lsb_release -a 2>&1" "Ubuntu" "Show distro info"

echo ""
echo "=== Network Tools ==="
print_header
check "ping" "ping -V 2>&1 | grep -oE '[0-9]+' | head -1" "ping -c 1 127.0.0.1 2>&1" "1 packets" "Ping loopback"
check "ip" "ip -V 2>&1 | grep -oE 'iproute2-[0-9.]+' | cut -d- -f2" "ip addr" "lo:" "Show interfaces"
check "ss" "ss -V 2>&1 | grep -oE 'iproute2-[0-9.]+' | cut -d- -f2" "ss -tuln 2>&1 | head -1" "Netid" "List sockets"
check "dig" "dig -v 2>&1 | grep -oE '[0-9.]+' | head -1" "dig -h 2>&1 | head -1" "Usage" "Show help"
check "nslookup" "nslookup -version 2>&1 | grep -oE '[0-9.]+' | head -1" "nslookup localhost >/dev/null 2>&1 && echo ok" "ok" "Resolve localhost"
check "host" "host -V 2>&1 | grep -oE '[0-9.]+' | head -1" "host -h 2>&1 | head -1" "host" "Show help"
check "nc" "dpkg -l netcat-openbsd | grep -oE '[0-9.]+' | head -1" "nc -h 2>&1" "usage" "Show help"
check "traceroute" "traceroute --version 2>&1 | grep -oE '[0-9.]+'" "traceroute -n -m 1 127.0.0.1 2>&1 | grep -E '127\.0\.0\.1|\*'" "127.0.0.1" "Trace one hop localhost"
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

if [ "${BUNTOOLBOX_TEST_VARIANT:-latest}" != "i3" ]; then
    echo ""
    echo "=========================================="
    echo "Results: $PASSED passed, $FAILED failed"
    echo "BUNTOOLBOX_TESTS_COMPLETED"
    echo "=========================================="

    [ $FAILED -eq 0 ]
fi
