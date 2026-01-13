#!/bin/bash
# Check versions of tools installed in local WSL environment
# Compares against latest available versions (same sources as check-versions.sh)
# Usage: ./scripts/check-wsl-versions.sh [-v|--verbose]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERBOSE=false
CACHE_DIR="/tmp/check-versions-cache"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose) VERBOSE=true; shift ;;
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
    if command -v gh &>/dev/null && gh auth status &>/dev/null; then
        if data=$(gh api "repos/${repo}/releases/latest" 2>/dev/null); then
            echo "$data" > "$cache_file"
            echo "$data"
            return
        fi
    fi
    if data=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null); then
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
    curl -fsSL "https://services.gradle.org/versions/current" 2>/dev/null | jq -r '.version'
}

get_latest_node() {
    curl -fsSL "https://nodejs.org/dist/index.json" 2>/dev/null | jq -r '[.[] | select(.lts != false)][0].version' | sed 's/^v//' | cut -d'.' -f1
}

get_latest_claude() {
    curl -fsSL --max-time 5 "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/latest" 2>/dev/null
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

get_latest_jdtls() {
    local version timestamp
    version=$(curl -fsSL --max-time 5 "https://download.eclipse.org/jdtls/milestones/" 2>/dev/null | \
        grep -oE '1\.[0-9]+\.[0-9]+' | sort -V | tail -1)
    if [ -n "$version" ]; then
        timestamp=$(curl -fsSL --max-time 5 "https://download.eclipse.org/jdtls/milestones/${version}/" 2>/dev/null | \
            grep -oE "jdt-language-server-${version}-[0-9]+\\.tar\\.gz" | head -1 | \
            grep -oE "${version}-[0-9]+" | sed "s/${version}-//")
        if [ -n "$timestamp" ]; then
            echo "${version}-${timestamp}"
        else
            echo "$version"
        fi
    fi
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
            java -version 2>&1 | head -1 | grep -oE '[0-9]+' | head -1
            ;;
        python|python3)
            python3 --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1
            ;;
        node)
            node --version 2>/dev/null | sed 's/^v//' | cut -d'.' -f1
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
            uv --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
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
        zellij)
            zellij --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
            ;;
        bd)
            bd --help 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true
            ;;
        mihomo)
            mihomo -v 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sed 's/^v//'
            ;;
        claude)
            claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
            ;;
        jdtls)
            # Check for jdtls jar in common locations
            local jar_path=""
            for dir in ~/jdtls ~/.local/share/jdtls /opt/jdtls /usr/local/share/jdtls; do
                if [ -d "$dir/plugins" ]; then
                    jar_path=$(find "$dir/plugins" -name 'org.eclipse.jdt.ls.core_*.jar' 2>/dev/null | head -1)
                    [ -n "$jar_path" ] && break
                fi
            done
            if [ -n "$jar_path" ]; then
                # Extract version like 1.54.0.202511261751 -> 1.54.0-202511261751
                basename "$jar_path" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]{12}' | sed 's/\.\([0-9]\{12\}\)$/-\1/'
            fi
            ;;
        openvscode-server)
            # Try to extract version from binary path (e.g., openvscode-server-v1.106.3-linux-x64)
            local ovs_bin
            ovs_bin=$(which openvscode-server 2>/dev/null)
            if [ -n "$ovs_bin" ]; then
                local real_path
                real_path=$(readlink -f "$ovs_bin" 2>/dev/null || echo "$ovs_bin")
                echo "$real_path" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sed 's/^v//' | head -1
            fi
            ;;
        *)
            "$cmd" $version_flag 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
            ;;
    esac
}

# ============================================================================
# Main check logic
# ============================================================================

echo ""
echo "Checking WSL tool versions..."
echo ""
printf "%-12s %-10s %-12s %-12s %s\n" "Tool" "Installed" "Local" "Latest" "Status"
printf "%-12s %-10s %-12s %-12s %s\n" "----" "---------" "-----" "------" "------"

updates_available=0
not_installed=0

check_tool() {
    local name="$1"
    local cmd="$2"
    local latest="$3"

    local installed="✗"
    local local_ver="-"
    local status=""

    if command -v "$cmd" &>/dev/null; then
        installed="✓"
        local_ver=$(get_local_version "$cmd")
        [ -z "$local_ver" ] && local_ver="?"

        if [ -z "$latest" ]; then
            status="${RED}fetch failed${NC}"
        elif [ "$local_ver" = "?" ]; then
            status="${YELLOW}version unknown${NC}"
        elif [ "$local_ver" = "$latest" ]; then
            status="${GREEN}up-to-date${NC}"
        else
            status="${YELLOW}update available${NC}"
            updates_available=$((updates_available + 1))
        fi
    else
        status="${DIM}not installed${NC}"
        not_installed=$((not_installed + 1))
    fi

    printf "%-12s %-10s %-12s %-12s " "$name" "$installed" "$local_ver" "${latest:-?}"
    echo -e "$status"
}

echo ""
echo "=== 语言运行时 ==="
check_tool "JDK" "java" "$(get_latest_jdk_lts)"
check_tool "Python" "python3" "$(get_latest_python)"
check_tool "Node.js" "node" "$(get_latest_node)"
check_tool "Bun" "bun" "$(get_latest_github_release oven-sh/bun)"

echo ""
echo "=== 构建工具 ==="
check_tool "Gradle" "gradle" "$(get_latest_gradle)"
check_tool "Maven" "mvn" "$(get_latest_maven)"

echo ""
echo "=== 包管理器 ==="
check_tool "uv" "uv" "$(get_latest_github_release astral-sh/uv)"

echo ""
echo "=== Shell 增强 ==="
check_tool "starship" "starship" "$(get_latest_github_release starship/starship)"
check_tool "zoxide" "zoxide" "$(get_latest_github_release ajeetdsouza/zoxide)"

echo ""
echo "=== TUI 工具 ==="
check_tool "lazygit" "lazygit" "$(get_latest_github_release jesseduffield/lazygit)"
check_tool "helix" "hx" "$(get_latest_github_release helix-editor/helix)"
check_tool "eza" "eza" "$(get_latest_github_release eza-community/eza)"
check_tool "delta" "delta" "$(get_latest_github_release dandavison/delta)"
check_tool "procs" "procs" "$(get_latest_github_release dalance/procs)"
check_tool "zellij" "zellij" "$(get_latest_github_release zellij-org/zellij)"
check_tool "openvscode" "openvscode-server" "$(get_latest_github_release gitpod-io/openvscode-server | sed 's/^openvscode-server-v//')"
check_tool "jdtls" "jdtls" "$(get_latest_jdtls)"

echo ""
echo "=== 其他工具 ==="
check_tool "beads" "bd" "$(get_latest_github_release steveyegge/beads)"
# mihomo skipped for WSL (only used in Docker)
check_tool "claude" "claude" "$(get_latest_claude)"

echo ""
echo "----------------------------------------"
echo -e "Total: ${not_installed} not installed, ${updates_available} updates available"

if [ $updates_available -gt 0 ]; then
    echo -e "${YELLOW}Some updates are available.${NC}"
fi
