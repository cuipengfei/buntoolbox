#!/bin/bash
# Check for latest versions of tools in Dockerfile
# Usage: ./scripts/check-versions.sh [-v|--verbose]
# Dependencies: curl, jq

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKERFILE="$PROJECT_ROOT/Dockerfile"
LAYERS_DIR="$PROJECT_ROOT/docker/layers"
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
    echo "  Windows: winget install jqlang.jq"
    echo "  macOS:   brew install jq"
    echo "  Linux:   apt install jq"
    exit 1
fi

# Setup cache directory
mkdir -p "$CACHE_DIR"

# Fetch GitHub release data with caching (one request per repo)
# Uses gh api if available (authenticated, no rate limit), falls back to curl
fetch_github_release() {
    local repo="$1"
    local cache_file="$CACHE_DIR/$(echo "$repo" | tr '/' '_').json"

    # Use cache if exists and less than 5 minutes old
    if [ -f "$cache_file" ] && [ $(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file"))) -lt 300 ]; then
        cat "$cache_file"
        return
    fi

    # Fetch and cache - prefer gh api (authenticated) over curl (rate limited)
    local data
    if command -v gh &>/dev/null && gh auth status &>/dev/null; then
        if data=$(gh api "repos/${repo}/releases/latest" 2>/dev/null); then
            echo "$data" > "$cache_file"
            echo "$data"
            return
        fi
    fi
    # Fallback to curl
    if data=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null); then
        echo "$data" > "$cache_file"
        echo "$data"
    else
        echo ""
    fi
}

# Parse current version from shared layer env snippets.
get_current_version() {
    awk -F= -v name="$1" '
        $1 ~ "^(export[[:space:]]+)?" name "$" {
            value=$2
            sub(/[[:space:]]*#.*/, "", value)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            gsub(/^\"|\"$/, "", value)
            if (value ~ /^\$\{[A-Za-z_][A-Za-z0-9_]*:-[^}]+\}$/) {
                sub(/^\$\{[A-Za-z_][A-Za-z0-9_]*:-/, "", value)
                sub(/\}$/, "", value)
            }
            print value
            exit
        }
    ' "$LAYERS_DIR"/*.env
}

# Get latest versions from APIs
get_latest_gradle() {
    curl -fsSL "https://services.gradle.org/versions/current" 2>/dev/null | jq -r '.version'
}

get_latest_node() {
    local major
    major=$(get_current_version NODE_VERSION | cut -d'.' -f1)
    curl -fsSL "https://nodejs.org/dist/index.json" 2>/dev/null | jq -r --arg v "$major" '[.[] | select(.version | startswith("v" + $v + "."))][0].version' | sed 's/^v//'
}

get_latest_github_release() {
    fetch_github_release "$1" | jq -r '.tag_name // empty' | sed 's/^v//' | sed 's/^bun-v//'
}

get_latest_zulu_package_version() {
    curl -fsSL --retry 3 --retry-all-errors --max-time 15 "https://repos.azul.com/zulu/deb/dists/stable/main/binary-amd64/Packages.gz" 2>/dev/null | \
        gzip -dc 2>/dev/null | \
        awk 'BEGIN{RS="\n\n"} /Package: zulu25-jdk-headless/ {for (i=1; i<=NF; i++) if ($i=="Version:") print $(i+1)}' | \
        sort -V | tail -1
}


# Get current Ubuntu base image version from Dockerfile
get_current_ubuntu() {
    grep "^FROM ubuntu:" "$DOCKERFILE" | sed 's/FROM ubuntu://'
}

# Get latest Ubuntu LTS version from official Ubuntu meta-release
get_latest_ubuntu_lts() {
    curl -fsSL --max-time 5 "https://changelogs.ubuntu.com/meta-release-lts" 2>/dev/null | \
        grep -E "^Version:" | tail -1 | grep -oE '[0-9]+\.[0-9]+' | head -1
}

# Get current JDK package version from Dockerfile
get_current_jdk() {
    get_current_version JDK_PACKAGE_VERSION
}

# Get latest Azul Zulu package version from official apt metadata
get_latest_jdk_lts() {
    get_latest_zulu_package_version
}

# Get current Python major.minor version from Dockerfile (extracts from python3.XX)
get_current_python() {
    get_current_version PYTHON_VERSION
}

# Get latest Python stable version from endoflife.date API
get_latest_python() {
    curl -fsSL --max-time 5 "https://endoflife.date/api/python.json" 2>/dev/null | \
        jq -r '.[0].cycle'
}

# Get latest Maven version from endoflife.date API
get_latest_maven() {
    curl -fsSL --max-time 5 "https://endoflife.date/api/maven.json" 2>/dev/null | \
        jq -r '.[0].latest'
}

get_latest_httpie() {
    curl -fsSL --max-time 15 "https://pypi.org/pypi/httpie/json" 2>/dev/null | \
        jq -r '.info.version'
}

# Get linux x86_64 assets only (no arm, no windows, no macos, no other archs)
get_linux_assets() {
    local repo="$1"
    fetch_github_release "$repo" | \
        jq -r '.assets[].name // empty' | \
        grep -iE 'linux' | \
        grep -iE '(x86_64|amd64|x64)' | \
        grep -viE '(arm|aarch|mips|ppc|riscv|loong|s390|i686|386|32-bit)' | \
        grep -vE '\.(sha256|sig|asc|zsync)$' | \
        sort
}

# Print header
echo ""
echo "Checking tool versions..."
echo ""
printf "%-12s %-12s %-12s %s\n" "Tool" "Current" "Latest" "Status"
printf "%-12s %-12s %-12s %s\n" "----" "-------" "------" "------"

updates_available=0

check_version() {
    local name="$1" current="$2" latest="$3" repo="$4" selected="$5"
    if [ -z "$latest" ]; then
        printf "%-12s %-12s %-12s ${RED}%s${NC}\n" "$name" "$current" "?" "fetch failed"
        updates_available=1
    elif [ "$current" = "$latest" ]; then
        printf "%-12s %-12s %-12s ${GREEN}%s${NC}\n" "$name" "$current" "$latest" "up-to-date"
    else
        printf "%-12s %-12s %-12s ${YELLOW}%s${NC}\n" "$name" "$current" "$latest" "update available"
        updates_available=1
    fi

    # Show available assets in verbose mode
    if [ "$VERBOSE" = true ] && [ -n "$repo" ]; then
        local assets
        assets=$(get_linux_assets "$repo")
        local count
        count=$(echo "$assets" | grep -c . || true)

        if [ "$count" -ge 1 ]; then
            echo -e "  ${DIM}使用: ${selected}${NC}"
            echo -e "  ${DIM}可选:${NC}"
            echo "$assets" | while read -r asset; do
                # Simple exact match
                if [ "$asset" = "$selected" ]; then
                    echo -e "    ${GREEN}→ $asset${NC}"
                else
                    echo -e "    ${DIM}  $asset${NC}"
                fi
            done
            echo ""
        fi
    fi
}

echo ""
echo "=== 基础镜像 ==="
check_version "Ubuntu" "$(get_current_ubuntu)" "$(get_latest_ubuntu_lts)" "" ""

echo ""
echo "=== 语言运行时 ==="
check_version "JDK" "$(get_current_jdk)" "$(get_latest_jdk_lts)" "" ""
check_version "Python" "$(get_current_python)" "$(get_latest_python)" "" ""
check_version "Node.js" "$(get_current_version NODE_VERSION)" "$(get_latest_node)" "" ""
check_version "Bun" "$(get_current_version BUN_VERSION)" "$(get_latest_github_release oven-sh/bun | sed 's/^bun-v//')" "oven-sh/bun" "bun-linux-x64.zip"

echo ""
echo "=== 构建工具 ==="
check_version "Gradle" "$(get_current_version GRADLE_VERSION)" "$(get_latest_gradle)" "" ""
check_version "Maven" "$(get_current_version MAVEN_VERSION)" "$(get_latest_maven)" "" ""

echo ""
echo "=== 包管理器 ==="
check_version "httpie" "$(get_current_version HTTPIE_VERSION)" "$(get_latest_httpie)" "" ""
check_version "uv" "$(get_current_version UV_VERSION)" "$(get_latest_github_release astral-sh/uv)" "astral-sh/uv" "uv-x86_64-unknown-linux-gnu.tar.gz"

echo ""
echo "=== Shell 增强 ==="
check_version "starship" "$(get_current_version STARSHIP_VERSION)" "$(get_latest_github_release starship/starship)" "starship/starship" "starship-x86_64-unknown-linux-gnu.tar.gz"
check_version "zoxide" "$(get_current_version ZOXIDE_VERSION)" "$(get_latest_github_release ajeetdsouza/zoxide)" "ajeetdsouza/zoxide" "zoxide-$(get_current_version ZOXIDE_VERSION)-x86_64-unknown-linux-musl.tar.gz"

echo ""
echo "=== TUI 工具 ==="
check_version "lazygit" "$(get_current_version LAZYGIT_VERSION)" "$(get_latest_github_release jesseduffield/lazygit)" "jesseduffield/lazygit" "lazygit_$(get_current_version LAZYGIT_VERSION)_linux_x86_64.tar.gz"
check_version "eza" "$(get_current_version EZA_VERSION)" "$(get_latest_github_release eza-community/eza)" "eza-community/eza" "eza_x86_64-unknown-linux-gnu.tar.gz"
check_version "delta" "$(get_current_version DELTA_VERSION)" "$(get_latest_github_release dandavison/delta)" "dandavison/delta" "delta-$(get_current_version DELTA_VERSION)-x86_64-unknown-linux-musl.tar.gz"
check_version "procs" "$(get_current_version PROCS_VERSION)" "$(get_latest_github_release dalance/procs)" "dalance/procs" "procs-v$(get_current_version PROCS_VERSION)-x86_64-linux.zip"
check_version "zellij" "$(get_current_version ZELLIJ_VERSION)" "$(get_latest_github_release zellij-org/zellij)" "zellij-org/zellij" "zellij-x86_64-unknown-linux-musl.tar.gz"
check_version "duf" "$(get_current_version DUF_VERSION)" "$(get_latest_github_release muesli/duf)" "muesli/duf" "duf_$(get_current_version DUF_VERSION)_linux_amd64.deb"
check_version "ttyd" "$(get_current_version TTYD_VERSION)" "$(get_latest_github_release tsl0922/ttyd)" "tsl0922/ttyd" "ttyd.x86_64"
echo ""
echo "=== 其他工具 ==="
check_version "beads" "$(get_current_version BEADS_VERSION)" "$(get_latest_github_release gastownhall/beads)" "gastownhall/beads" "beads_$(get_current_version BEADS_VERSION)_linux_amd64.tar.gz"
check_version "rtk" "$(get_current_version RTK_VERSION)" "$(get_latest_github_release rtk-ai/rtk)" "rtk-ai/rtk" "rtk-$(get_current_version RTK_VERSION)-x86_64-unknown-linux-musl.tar.gz"
check_version "plannotator" "$(get_current_version PLANNOTATOR_VERSION)" "$(get_latest_github_release backnotprop/plannotator)" "backnotprop/plannotator" "plannotator-linux-x64"
check_version "herdr" "$(get_current_version HERDR_VERSION)" "$(get_latest_github_release ogulcancelik/herdr)" "ogulcancelik/herdr" "herdr-linux-x86_64"

echo ""
if [ $updates_available -eq 1 ]; then
    echo -e "${YELLOW}Some updates are available. Edit docker/layers/*.env version snippets to upgrade.${NC}"
else
    echo -e "${GREEN}All tools are up-to-date.${NC}"
fi
