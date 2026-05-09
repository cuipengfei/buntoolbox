#!/bin/bash
# Test Docker image (pull from Docker Hub by default, no local build)
# Usage: ./scripts/test-image.sh [--variant latest|i3|kde] [--image image_name] [image_name]
# Examples:
#   ./scripts/test-image.sh
#   ./scripts/test-image.sh --variant i3 --image cuipengfei/buntoolbox:i3

set -e

# Options:
#   -v, --verbose          Print full command outputs for each check
#   --no-pull              Skip docker pull (useful when offline if image already exists)
#   --variant latest|i3|kde    Select variant checks to run (default: latest)
#   -i, --image IMAGE      Docker image to test
#   -h, --help             Show usage
# Env:
#   DOCKER_BIN             Override docker CLI (e.g. Windows Docker Desktop docker.exe)
#   VERBOSE=1              Same as -v
#   SKIP_PULL=1            Same as --no-pull
#   PULL_TIMEOUT           Timeout in seconds for docker pull (default: 120)
#   RUN_TIMEOUT            Timeout in seconds for docker run (default: 300)

DOCKER_BIN="${DOCKER_BIN:-docker}"
VERBOSE="${VERBOSE:-0}"
SKIP_PULL="${SKIP_PULL:-0}"
PULL_TIMEOUT="${PULL_TIMEOUT:-120}"
RUN_TIMEOUT="${RUN_TIMEOUT:-300}"
VARIANT="latest"
IMAGE_NAME=""

usage() {
    cat <<'EOF'
Usage: ./scripts/test-image.sh [options] [image_name]

Options:
  -v, --verbose          Print full command outputs for each check
  --no-pull              Skip docker pull
  --variant latest|i3|kde    Select variant checks to run (default: latest)
  -i, --image IMAGE      Docker image to test
  -h, --help             Show this help

Defaults:
  latest variant tests cuipengfei/buntoolbox:latest
  i3 variant tests cuipengfei/buntoolbox:i3 unless --image or positional image is provided
  kde variant tests cuipengfei/buntoolbox:kde unless --image or positional image is provided
EOF
}

die() {
    echo "Error: $*" >&2
    exit 2
}

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
        --variant)
            [ $# -ge 2 ] || die "--variant requires latest, i3, or kde"
            VARIANT="$2"
            shift 2
            ;;
        -i|--image)
            [ $# -ge 2 ] || die "--image requires an image name"
            IMAGE_NAME="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            die "unknown option: $1"
            ;;
        *)
            IMAGE_NAME="$1"
            shift
            ;;
    esac
done

[ $# -eq 0 ] || die "unexpected extra arguments: $*"

case "$VARIANT" in
    latest|i3|kde)
        ;;
    *)
        die "unsupported variant: $VARIANT"
        ;;
esac

if [ -z "$IMAGE_NAME" ]; then
    case "$VARIANT" in
        latest) IMAGE_NAME="cuipengfei/buntoolbox:latest" ;;
        i3) IMAGE_NAME="cuipengfei/buntoolbox:i3" ;;
        kde) IMAGE_NAME="cuipengfei/buntoolbox:kde" ;;
    esac
fi

is_webtop_variant() {
    case "$VARIANT" in
        i3|kde) return 0 ;;
        *) return 1 ;;
    esac
}

TEST_IMAGE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$TEST_IMAGE_SCRIPT_DIR/lib"

# shellcheck source=scripts/lib/test-versions.sh
. "$LIB_DIR/test-versions.sh"

EXPECTED_VERSIONS=""
add_expected_version() {
    local env_name="$1"
    local value="$2"

    EXPECTED_VERSIONS="$EXPECTED_VERSIONS -e ${env_name}=${value}"
}

add_expected_version EXPECT_JDK_PACKAGE_VERSION "$(get_expected_version JDK_PACKAGE_VERSION)"
add_expected_version EXPECT_JDK_RUNTIME_VERSION "$(get_expected_jdk_runtime_version)"
add_expected_version EXPECT_PYTHON_VERSION "$(get_expected_python_version)"
add_expected_version EXPECT_BUN_VERSION "$(get_expected_version BUN_VERSION)"
add_expected_version EXPECT_NODE_VERSION "$(get_expected_version NODE_VERSION)"
add_expected_version EXPECT_GRADLE_VERSION "$(get_expected_version GRADLE_VERSION)"
add_expected_version EXPECT_MAVEN_VERSION "$(get_expected_version MAVEN_VERSION)"
add_expected_version EXPECT_HTTPIE_VERSION "$(get_expected_version HTTPIE_VERSION)"
add_expected_version EXPECT_UV_VERSION "$(get_expected_version UV_VERSION)"
add_expected_version EXPECT_BEADS_VERSION "$(get_expected_version BEADS_VERSION)"
add_expected_version EXPECT_LAZYGIT_VERSION "$(get_expected_version LAZYGIT_VERSION)"
add_expected_version EXPECT_HELIX_VERSION "$(get_expected_version HELIX_VERSION)"
add_expected_version EXPECT_EZA_VERSION "$(get_expected_version EZA_VERSION)"
add_expected_version EXPECT_DELTA_VERSION "$(get_expected_version DELTA_VERSION)"
add_expected_version EXPECT_ZOXIDE_VERSION "$(get_expected_version ZOXIDE_VERSION)"
add_expected_version EXPECT_STARSHIP_VERSION "$(get_expected_version STARSHIP_VERSION)"
add_expected_version EXPECT_PROCS_VERSION "$(get_expected_version PROCS_VERSION)"
add_expected_version EXPECT_ZELLIJ_VERSION "$(get_expected_version ZELLIJ_VERSION)"
add_expected_version EXPECT_DUF_VERSION "$(get_expected_version DUF_VERSION)"
add_expected_version EXPECT_OPENVSCODE_VERSION "$(get_expected_version OPENVSCODE_VERSION)"
add_expected_version EXPECT_TTYD_VERSION "$(get_expected_version TTYD_VERSION)"
add_expected_version EXPECT_CLAUDE_CODE_VERSION "$(get_expected_version CLAUDE_CODE_VERSION)"
add_expected_version EXPECT_RTK_VERSION "$(get_expected_version RTK_VERSION)"

echo "=========================================="
echo "Pulling image: $IMAGE_NAME"
echo "Variant: $VARIANT"
echo "=========================================="
if [ "$SKIP_PULL" = "1" ]; then
  echo "(skip pull)"
else
  timeout "$PULL_TIMEOUT" "$DOCKER_BIN" pull "$IMAGE_NAME"
fi
echo ""

echo "=========================================="
echo "Testing image: $IMAGE_NAME"
echo "Variant: $VARIANT"
echo "=========================================="

if is_webtop_variant; then
    GUARD_FIXTURE_OUTPUT="$(mktemp)"
    GUARD_ROOT="$(mktemp -d)"
    mkdir -p "$GUARD_ROOT/etc/s6-overlay/s6-rc.d/fatal"
    cp "$TEST_IMAGE_SCRIPT_DIR/fixtures/root-first-guard/fatal-abc-runtime.sh" "$GUARD_ROOT/etc/s6-overlay/s6-rc.d/fatal/run"
    if BUNTOOLBOX_WEBTOP_ROOT="$GUARD_ROOT" bash "$TEST_IMAGE_SCRIPT_DIR/../docker/webtop/root-first-guard.sh" >"$GUARD_FIXTURE_OUTPUT" 2>&1; then
        cat "$GUARD_FIXTURE_OUTPUT"
        rm -f "$GUARD_FIXTURE_OUTPUT"
        rm -rf "$GUARD_ROOT"
        die "root-first guard fixture unexpectedly passed"
    else
        GUARD_FIXTURE_STATUS=$?
        if [ "$GUARD_FIXTURE_STATUS" -ne 1 ]; then
            cat "$GUARD_FIXTURE_OUTPUT"
            rm -f "$GUARD_FIXTURE_OUTPUT"
            rm -rf "$GUARD_ROOT"
            die "root-first guard fixture returned unexpected status: $GUARD_FIXTURE_STATUS"
        fi
    fi
    rm -f "$GUARD_FIXTURE_OUTPUT"
    rm -rf "$GUARD_ROOT"
    echo "Root-first guard fixture: expected fatal abc runtime pattern was rejected"
fi

CONTAINER_SCRIPT=$(cat "$LIB_DIR/test-common-tools.sh")

if is_webtop_variant; then
    CONTAINER_SCRIPT="$CONTAINER_SCRIPT
$(cat "$LIB_DIR/test-webtop-runtime.sh")"
fi

if [ "$VARIANT" = "i3" ]; then
    CONTAINER_SCRIPT="$CONTAINER_SCRIPT
$(cat "$LIB_DIR/test-i3-runtime.sh")"
fi

if [ "$VARIANT" = "kde" ]; then
    CONTAINER_SCRIPT="$CONTAINER_SCRIPT
$(cat "$LIB_DIR/test-kde-runtime.sh")"
fi

CONTAINER_SCRIPT="$CONTAINER_SCRIPT"'
echo ""
echo "=========================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "BUNTOOLBOX_TESTS_COMPLETED"
echo "=========================================="
[ $FAILED -eq 0 ]'

if is_webtop_variant; then
    CONTAINER_NAME="buntoolbox-${VARIANT}-test-$$"
    cleanup_webtop_container() {
        "$DOCKER_BIN" rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    }

    trap cleanup_webtop_container EXIT

    timeout "$RUN_TIMEOUT" "$DOCKER_BIN" run -d --name "$CONTAINER_NAME" \
        -e VERBOSE="$VERBOSE" \
        -e BUNTOOLBOX_TEST_VARIANT="$VARIANT" \
        $EXPECTED_VERSIONS \
        "$IMAGE_NAME" >/dev/null

    set +e
    TEST_OUTPUT=$(timeout "$RUN_TIMEOUT" "$DOCKER_BIN" exec -t \
        -e VERBOSE="$VERBOSE" \
        -e BUNTOOLBOX_TEST_VARIANT="$VARIANT" \
        $EXPECTED_VERSIONS \
        "$CONTAINER_NAME" bash -c "$CONTAINER_SCRIPT")
    TEST_STATUS=$?
    set -e
else
    set +e
    TEST_OUTPUT=$(timeout "$RUN_TIMEOUT" "$DOCKER_BIN" run --rm -t \
        -e VERBOSE="$VERBOSE" \
        -e BUNTOOLBOX_TEST_VARIANT="$VARIANT" \
        $EXPECTED_VERSIONS \
        "$IMAGE_NAME" bash -c "$CONTAINER_SCRIPT")
    TEST_STATUS=$?
    set -e
fi

printf '%s\n' "$TEST_OUTPUT"
if [ "$TEST_STATUS" -ne 0 ]; then
    die "container test command failed with status: $TEST_STATUS"
fi
if ! printf '%s\n' "$TEST_OUTPUT" | grep -q 'BUNTOOLBOX_TESTS_COMPLETED'; then
    die "container test output missing completion sentinel"
fi

echo ""
echo "=========================================="
echo "All tests passed!"
echo "=========================================="
