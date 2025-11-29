#!/bin/bash
# Check for latest versions of tools in Dockerfile
# Usage: ./scripts/check-versions.sh
# Dependencies: curl, jq

set -e

DOCKERFILE="Dockerfile"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
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

# Print header
echo ""
echo "Checking tool versions..."
echo ""
printf "%-12s %-12s %-12s %s\n" "Tool" "Current" "Latest" "Status"
printf "%-12s %-12s %-12s %s\n" "----" "-------" "------" "------"

updates_available=0

check_version() {
    local name="$1" current="$2" latest="$3"
    if [ -z "$latest" ]; then
        printf "%-12s %-12s %-12s ${RED}%s${NC}\n" "$name" "$current" "?" "fetch failed"
    elif [ "$current" = "$latest" ]; then
        printf "%-12s %-12s %-12s ${GREEN}%s${NC}\n" "$name" "$current" "$latest" "up-to-date"
    else
        printf "%-12s %-12s %-12s ${YELLOW}%s${NC}\n" "$name" "$current" "$latest" "update available"
        updates_available=1
    fi
}

check_version "Node.js" "$(get_current_version NODE_MAJOR)" "$(get_latest_node)"
check_version "Gradle" "$(get_current_version GRADLE_VERSION)" "$(get_latest_gradle)"
check_version "lazygit" "$(get_current_version LAZYGIT_VERSION)" "$(get_latest_github_release jesseduffield/lazygit)"
check_version "helix" "$(get_current_version HELIX_VERSION)" "$(get_latest_github_release helix-editor/helix)"
check_version "eza" "$(get_current_version EZA_VERSION)" "$(get_latest_github_release eza-community/eza)"
check_version "delta" "$(get_current_version DELTA_VERSION)" "$(get_latest_github_release dandavison/delta)"
check_version "zoxide" "$(get_current_version ZOXIDE_VERSION)" "$(get_latest_github_release ajeetdsouza/zoxide)"
check_version "beads" "$(get_current_version BEADS_VERSION)" "$(get_latest_github_release steveyegge/beads)"

echo ""
if [ $updates_available -eq 1 ]; then
    echo -e "${YELLOW}Some updates are available. Edit Dockerfile ARGs to upgrade.${NC}"
else
    echo -e "${GREEN}All tools are up-to-date.${NC}"
fi
echo ""
