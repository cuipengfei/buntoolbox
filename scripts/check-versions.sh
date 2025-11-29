#!/bin/bash
# Check for latest versions of tools in Dockerfile
# Usage: ./scripts/check-versions.sh [-v|--verbose]
# Dependencies: curl, jq

set -e

DOCKERFILE="Dockerfile"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VERBOSE=false

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

# Parse current version from Dockerfile
get_current_version() {
    grep "^ARG ${1}=" "$PROJECT_ROOT/$DOCKERFILE" | cut -d'=' -f2
}

# Get latest versions from APIs
get_latest_gradle() {
    curl -fsSL "https://services.gradle.org/versions/current" | jq -r '.version'
}

get_latest_node() {
    curl -fsSL "https://nodejs.org/dist/index.json" | jq -r '[.[] | select(.lts != false)][0].version' | sed 's/^v//' | cut -d'.' -f1
}

get_latest_github_release() {
    curl -fsSL "https://api.github.com/repos/${1}/releases/latest" | jq -r '.tag_name' | sed 's/^v//'
}

# Get all linux x86_64 assets for a GitHub repo
get_linux_assets() {
    local repo="$1"
    curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" | \
        jq -r '.assets[].name' | \
        grep -iE '(linux|x86_64|amd64)' | \
        grep -vE '\.(sha256|sig|asc)$' | \
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
    elif [ "$current" = "$latest" ]; then
        printf "%-12s %-12s %-12s ${GREEN}%s${NC}\n" "$name" "$current" "$latest" "up-to-date"
    else
        printf "%-12s %-12s %-12s ${YELLOW}%s${NC}\n" "$name" "$current" "$latest" "update available"
        updates_available=1
    fi

    # Show available assets in verbose mode
    if [ "$VERBOSE" = true ] && [ -n "$repo" ]; then
        echo -e "  ${DIM}使用: ${selected}${NC}"
        echo -e "  ${DIM}可选:${NC}"
        get_linux_assets "$repo" | while read -r asset; do
            if [ "$asset" = "$selected" ] || [[ "$selected" == *"$asset"* ]]; then
                echo -e "    ${GREEN}→ $asset${NC}"
            else
                echo -e "    ${DIM}  $asset${NC}"
            fi
        done
        echo ""
    fi
}

echo ""
echo "=== 语言运行时 ==="
check_version "Node.js" "$(get_current_version NODE_MAJOR)" "$(get_latest_node)" "" ""
check_version "Bun" "$(get_current_version BUN_VERSION)" "$(get_latest_github_release oven-sh/bun | sed 's/^bun-v//')" "oven-sh/bun" "bun-linux-x64.zip"

echo ""
echo "=== 构建工具 ==="
check_version "Gradle" "$(get_current_version GRADLE_VERSION)" "$(get_latest_gradle)" "" ""

echo ""
echo "=== 包管理器 ==="
check_version "uv" "$(get_current_version UV_VERSION)" "$(get_latest_github_release astral-sh/uv)" "astral-sh/uv" "uv-x86_64-unknown-linux-gnu.tar.gz"

echo ""
echo "=== Shell 增强 ==="
check_version "starship" "$(get_current_version STARSHIP_VERSION)" "$(get_latest_github_release starship/starship)" "starship/starship" "starship-x86_64-unknown-linux-gnu.tar.gz"
check_version "zoxide" "$(get_current_version ZOXIDE_VERSION)" "$(get_latest_github_release ajeetdsouza/zoxide)" "ajeetdsouza/zoxide" "zoxide-x86_64-unknown-linux-musl.tar.gz"

echo ""
echo "=== TUI 工具 ==="
check_version "lazygit" "$(get_current_version LAZYGIT_VERSION)" "$(get_latest_github_release jesseduffield/lazygit)" "jesseduffield/lazygit" "lazygit_Linux_x86_64.tar.gz"
check_version "helix" "$(get_current_version HELIX_VERSION)" "$(get_latest_github_release helix-editor/helix)" "helix-editor/helix" "helix-x86_64-linux.tar.xz"
check_version "eza" "$(get_current_version EZA_VERSION)" "$(get_latest_github_release eza-community/eza)" "eza-community/eza" "eza_x86_64-unknown-linux-gnu.tar.gz"
check_version "delta" "$(get_current_version DELTA_VERSION)" "$(get_latest_github_release dandavison/delta)" "dandavison/delta" "delta-x86_64-unknown-linux-gnu.tar.gz"

echo ""
echo "=== 其他工具 ==="
check_version "beads" "$(get_current_version BEADS_VERSION)" "$(get_latest_github_release steveyegge/beads)" "steveyegge/beads" "beads_linux_amd64.tar.gz"
check_version "mihomo" "$(get_current_version MIHOMO_VERSION)" "$(get_latest_github_release MetaCubeX/mihomo)" "MetaCubeX/mihomo" "mihomo-linux-amd64"

echo ""
if [ $updates_available -eq 1 ]; then
    echo -e "${YELLOW}Some updates are available. Edit Dockerfile ARGs to upgrade.${NC}"
else
    echo -e "${GREEN}All tools are up-to-date.${NC}"
fi
