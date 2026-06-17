#!/bin/bash
# Check versions of tools installed in local WSL environment
# Compares against project targets, apt candidates, or upstream fallbacks
# depending on how each tool is managed.
# Usage: ./scripts/check-wsl-versions.sh [-v|--verbose] [--smoke]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LAYERS_DIR="$PROJECT_ROOT/docker/layers"
VERBOSE=false
CACHE_DIR="/tmp/check-versions-cache"
RUN_SMOKE=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose) VERBOSE=true; shift ;;
        --smoke) RUN_SMOKE=1; shift ;;
        *) shift ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

# Check dependencies
if ! command -v jq &>/dev/null; then
    echo -e "${RED}Error: jq is required. Install it first.${NC}"
    exit 1
fi

# Setup cache directory
mkdir -p "$CACHE_DIR"

# ============================================================================
# Version fetching functions (same as check-versions.sh)
# ============================================================================

fetch_github_release() {
    local repo="$1"
    local cache_file="$CACHE_DIR/$(echo "$repo" | tr '/' '_').json"

    if [ -f "$cache_file" ] && [ $(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file"))) -lt 300 ]; then
        cat "$cache_file"
        return
    fi

    local data
    if command -v gh &>/dev/null && timeout 5 gh auth status &>/dev/null; then
        if data=$(timeout 5 gh api "repos/${repo}/releases/latest" 2>/dev/null); then
            echo "$data" > "$cache_file"
            echo "$data"
            return
        fi
    fi
    if data=$(curl -fsSL --max-time 5 "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null); then
        echo "$data" > "$cache_file"
        echo "$data"
    else
        echo ""
    fi
}

get_latest_github_release() {
    fetch_github_release "$1" | jq -r '.tag_name // empty' | sed 's/^v//' | sed 's/^bun-v//'
}

get_latest_gradle() {
    curl -fsSL --max-time 5 "https://services.gradle.org/versions/current" 2>/dev/null | jq -r '.version'
}

get_latest_node() {
    local major
    major=$(node --version 2>/dev/null | sed 's/^v//' | cut -d'.' -f1)
    curl -fsSL --max-time 5 "https://nodejs.org/dist/index.json" 2>/dev/null | jq -r --arg v "$major" '[.[] | select(.version | startswith("v" + $v + "."))][0].version' | sed 's/^v//'
}

get_latest_jdk_lts() {
    curl -fsSL --max-time 5 "https://endoflife.date/api/azul-zulu.json" 2>/dev/null | \
        jq -r '[.[] | select(.lts == true)] | sort_by(.cycle | tonumber) | reverse | .[0].cycle'
}

get_latest_python() {
    curl -fsSL --max-time 5 "https://endoflife.date/api/python.json" 2>/dev/null | \
        jq -r '.[0].cycle'
}

get_latest_maven() {
    curl -fsSL --max-time 5 "https://endoflife.date/api/maven.json" 2>/dev/null | \
        jq -r '.[0].latest'
}

get_latest_httpie() {
    curl -fsSL --max-time 5 "https://pypi.org/pypi/httpie/json" 2>/dev/null | \
        jq -r '.info.version'
}

get_latest_apt_candidate() {
    local pkg="$1"
    if ! command -v apt-cache &>/dev/null; then
        echo ""
        return
    fi
    apt-cache policy "$pkg" 2>/dev/null | awk '/Candidate:/ {print $2; exit}' | sed 's/^[0-9]\+://; s/-.*$//'
}

get_shared_version() {
    local key="$1"
    local file

    [ -d "$LAYERS_DIR" ] || return 1

    while IFS= read -r -d '' file; do
        awk -F= -v key="$key" '
            {
                lhs = $1
                sub(/^export[[:space:]]+/, "", lhs)
            }
            lhs == key {
                value = $0
                sub("^[^=]*=", "", value)
                sub(/[[:space:]]*#.*/, "", value)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
                gsub(/^"|"$/, "", value)
                if (value ~ /^\$\{[A-Za-z_][A-Za-z0-9_]*:-[^}]+\}$/) {
                    sub(/^\$\{[A-Za-z_][A-Za-z0-9_]*:-/, "", value)
                    sub(/\}$/, "", value)
                }
                print value
                found = 1
                exit
            }
            END { exit found ? 0 : 1 }
        ' "$file" && return 0
    done < <(find "$LAYERS_DIR" -type f -name '*.env' -print0 2>/dev/null | sort -z)

    return 1
}

expected_or_latest() {
    local key="$1"
    shift

    get_shared_version "$key" || "$@"
}

# ============================================================================
# Local version detection functions
# ============================================================================

get_local_version() {
    local cmd="$1"
    local version_flag="${2:---version}"

    if ! command -v "$cmd" &>/dev/null; then
        echo ""
        return
    fi

    # Special handling for different tools
    case "$cmd" in
        java)
            if command -v dpkg-query &>/dev/null && dpkg-query -W -f='${Version}\n' zulu25-jdk-headless 2>/dev/null; then
                true
            else
                java -version 2>&1 | head -1 | grep -oE '[0-9]+(\.[0-9]+)*' | head -1
            fi
            ;;
        python|python3)
            python3 --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1
            ;;
        node)
            node --version 2>/dev/null | sed 's/^v//'
            ;;
        bun)
            bun --version 2>/dev/null
            ;;
        gradle)
            gradle --version 2>/dev/null | grep -E "^Gradle" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
            ;;
        mvn)
            mvn --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
            ;;
        uv)
            uv --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
            ;;
        http)
            http --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
            ;;
        gh)
            gh --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
            ;;
        starship)
            starship --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
            ;;
        zoxide)
            zoxide --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
            ;;
        lazygit)
            lazygit --version 2>/dev/null | grep -oE 'version=[0-9]+\.[0-9]+\.[0-9]+' | head -1 | sed 's/version=//'
            ;;
        hx)
            hx --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
            ;;
        eza)
            eza --version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sed 's/^v//'
            ;;
        delta)
            delta --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
            ;;
        procs)
            procs --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
            ;;
        zsh)
            zsh --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1
            ;;
        zellij)
            zellij --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
            ;;
        duf)
            duf --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
            ;;
        tmux)
            tmux -V 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?[a-z]?'
            ;;
        bd)
            (bd --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || \
            bd --help 2>&1 | grep -m1 -oE '[0-9]+\.[0-9]+\.[0-9]+' || true) | head -1
            ;;
        *)
            "$cmd" $version_flag 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?[a-z]?'
            ;;
    esac
}

is_command_usable() {
    local cmd="$1"

    command -v "$cmd" >/dev/null 2>&1
}

run_smoke_test() {
    local cmd="$1"

    case "$cmd" in
        java) timeout 8 bash -c "java -XshowSettings:properties -version >/dev/null 2>&1" ;;
        python3|python) timeout 8 bash -c "python3 -c 'print(1+1)' >/dev/null" ;;
        node) timeout 8 bash -c "node -e 'console.log(1+1)' >/dev/null" ;;
        bun) timeout 8 bash -c "bun -e 'console.log(1+1)' >/dev/null" ;;
        gradle) timeout 8 bash -c "gradle -q help >/dev/null 2>&1" ;;
        mvn) timeout 8 bash -c "mvn -q -version >/dev/null 2>&1" ;;
        http) timeout 8 bash -c "http --help >/dev/null 2>&1" ;;
        uv) timeout 8 bash -c "uv --help >/dev/null 2>&1" ;;
        gh) timeout 8 bash -c "gh --help >/dev/null 2>&1" ;;
        git) timeout 8 bash -c "git --help >/dev/null 2>&1" ;;
        jq) timeout 8 bash -c "printf '{\"a\":1}' | jq -e '.a==1' >/dev/null" ;;
        rg) timeout 8 bash -c "printf 'a\nb\n' | rg -q b" ;;
        fd) timeout 8 bash -c "fd --version >/dev/null 2>&1" ;;
        fzf) timeout 8 bash -c "printf 'a\nb\n' | fzf --filter=a >/dev/null" ;;
        tmux) timeout 8 bash -c "tmux -V >/dev/null 2>&1" ;;
        btop) timeout 8 bash -c "btop --help >/dev/null 2>&1" ;;
        starship) timeout 8 bash -c "starship print-config >/dev/null 2>&1" ;;
        zoxide) timeout 8 bash -c "zoxide add /tmp >/dev/null 2>&1 && zoxide query tmp >/dev/null 2>&1" ;;
        zsh) timeout 8 bash -c "zsh -c 'echo ok' >/dev/null" ;;
        lazygit) timeout 8 bash -c "lazygit --version >/dev/null 2>&1" ;;
        hx) timeout 8 bash -c "hx --health >/dev/null 2>&1 || hx --version >/dev/null 2>&1" ;;
        eza) timeout 8 bash -c "eza -1 / >/dev/null 2>&1" ;;
        delta) timeout 8 bash -c "printf 'a\nb\n' | delta >/dev/null 2>&1" ;;
        procs) timeout 8 bash -c "procs 1 >/dev/null 2>&1" ;;
        zellij) timeout 8 bash -c "zellij setup --check >/dev/null 2>&1" ;;
        duf) timeout 8 bash -c "duf >/dev/null 2>&1" ;;
        ttyd) timeout 8 bash -c "ttyd --help >/dev/null 2>&1" ;;
        bd) timeout 8 bash -c "bd --help >/dev/null 2>&1" ;;
        rtk) timeout 8 bash -c "rtk --help >/dev/null 2>&1" ;;
        *) timeout 8 bash -c "$cmd --help >/dev/null 2>&1 || $cmd --version >/dev/null 2>&1" ;;
    esac
}

# ============================================================================
# Main check logic
# ============================================================================

echo ""
echo "Checking WSL tool versions..."
echo ""
printf "%-12s %-10s %-12s %-12s %-8s %s\n" "Tool" "Installed" "Local" "Target" "Smoke" "Status"
printf "%-12s %-10s %-12s %-12s %-8s %s\n" "----" "---------" "-----" "------" "-----" "------"

updates_available=0
not_installed=0
smoke_failed=0

check_tool() {
    local name="$1"
    local cmd="$2"
    local latest="$3"

    local installed="✗"
    local local_ver="-"
    local status=""
    local smoke="-"

    if is_command_usable "$cmd"; then
        installed="✓"
        local_ver=$(get_local_version "$cmd" || true)
        [ -z "$local_ver" ] && local_ver="?"
    fi

    if [ "$installed" = "✓" ]; then
        if [ -z "$latest" ]; then
            status="${RED}fetch failed${NC}"
        elif [ "$local_ver" = "?" ]; then
            status="${YELLOW}version unknown${NC}"
        elif [ "$local_ver" = "$latest" ] || [[ "$local_ver" == *"$latest"* ]]; then
            status="${GREEN}up-to-date${NC}"
        else
            status="${YELLOW}update available${NC}"
            updates_available=$((updates_available + 1))
        fi

        if [ "$RUN_SMOKE" = "1" ]; then
            if run_smoke_test "$cmd"; then
                smoke="ok"
            else
                smoke="fail"
                smoke_failed=$((smoke_failed + 1))
            fi
        fi
    else
        status="${DIM}not installed${NC}"
        not_installed=$((not_installed + 1))
    fi

    printf "%-12s %-10s %-12s %-12s %-8s " "$name" "$installed" "$local_ver" "${latest:-?}" "$smoke"
    echo -e "$status"
}

echo ""
echo "=== 语言运行时 ==="
check_tool "JDK" "java" "$(expected_or_latest JDK_PACKAGE_VERSION get_latest_jdk_lts)"
check_tool "Python" "python3" "$(expected_or_latest PYTHON_VERSION get_latest_python)"
check_tool "Node.js" "node" "$(expected_or_latest NODE_VERSION get_latest_node)"
check_tool "Bun" "bun" "$(expected_or_latest BUN_VERSION get_latest_github_release oven-sh/bun)"

echo ""
echo "=== 构建工具 ==="
check_tool "Gradle" "gradle" "$(expected_or_latest GRADLE_VERSION get_latest_gradle)"
check_tool "Maven" "mvn" "$(expected_or_latest MAVEN_VERSION get_latest_maven)"

echo ""
echo "=== 包管理器 ==="
check_tool "httpie" "http" "$(expected_or_latest HTTPIE_VERSION get_latest_httpie)"
check_tool "uv" "uv" "$(expected_or_latest UV_VERSION get_latest_github_release astral-sh/uv)"

echo ""
echo "=== 基础开发工具 ==="
check_tool "gh" "gh" "$(get_latest_apt_candidate gh)"
check_tool "git" "git" "$(get_latest_apt_candidate git)"
check_tool "jq" "jq" "$(get_latest_apt_candidate jq)"
check_tool "ripgrep" "rg" "$(get_latest_apt_candidate ripgrep)"
check_tool "fd" "fd" "$(get_latest_apt_candidate fd-find)"
check_tool "fzf" "fzf" "$(get_latest_apt_candidate fzf)"
check_tool "tmux" "tmux" "$(get_latest_apt_candidate tmux)"
check_tool "btop" "btop" "$(get_latest_apt_candidate btop)"

echo ""
echo "=== Shell 增强 ==="
check_tool "starship" "starship" "$(expected_or_latest STARSHIP_VERSION get_latest_github_release starship/starship)"
check_tool "zoxide" "zoxide" "$(expected_or_latest ZOXIDE_VERSION get_latest_github_release ajeetdsouza/zoxide)"
check_tool "zsh" "zsh" "$(get_latest_apt_candidate zsh)"

echo ""
echo "=== TUI 工具 ==="
check_tool "lazygit" "lazygit" "$(expected_or_latest LAZYGIT_VERSION get_latest_github_release jesseduffield/lazygit)"
check_tool "helix" "hx" "$(expected_or_latest HELIX_VERSION get_latest_github_release helix-editor/helix)"
check_tool "eza" "eza" "$(expected_or_latest EZA_VERSION get_latest_github_release eza-community/eza)"
check_tool "delta" "delta" "$(expected_or_latest DELTA_VERSION get_latest_github_release dandavison/delta)"
check_tool "procs" "procs" "$(expected_or_latest PROCS_VERSION get_latest_github_release dalance/procs)"
check_tool "zellij" "zellij" "$(expected_or_latest ZELLIJ_VERSION get_latest_github_release zellij-org/zellij)"
check_tool "duf" "duf" "$(expected_or_latest DUF_VERSION get_latest_github_release muesli/duf)"
check_tool "ttyd" "ttyd" "$(expected_or_latest TTYD_VERSION get_latest_github_release tsl0922/ttyd)"
echo ""
echo "=== 其他工具 ==="
check_tool "beads (bd)" "bd" "$(expected_or_latest BEADS_VERSION get_latest_github_release gastownhall/beads)"
check_tool "rtk" "rtk" "$(expected_or_latest RTK_VERSION get_latest_github_release rtk-ai/rtk)"
check_tool "plannotator" "plannotator" "$(expected_or_latest PLANNOTATOR_VERSION get_latest_github_release backnotprop/plannotator)"

echo ""
echo "----------------------------------------"
echo -e "Total: ${not_installed} not installed, ${updates_available} updates available"
if [ "$RUN_SMOKE" = "1" ]; then
    echo -e "Smoke: ${smoke_failed} failed"
fi

if [ $updates_available -gt 0 ]; then
    echo -e "${YELLOW}Some updates are available.${NC}"
fi
