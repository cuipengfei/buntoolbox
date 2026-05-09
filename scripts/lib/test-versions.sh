#!/bin/bash
# Shared version readers for image tests.
# Prefer shared docker/layers/*.env version snippets when present, with a
# migration-period fallback to root Dockerfile ARG declarations.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOCKERFILE="$REPO_ROOT/Dockerfile"
LAYERS_DIR="$REPO_ROOT/docker/layers"

get_layer_env_version() {
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

get_dockerfile_arg_version() {
    local key="$1"

    grep "^ARG ${key}=" "$DOCKERFILE" 2>/dev/null | head -1 | cut -d'=' -f2-
}

get_expected_version() {
    local key="$1"

    get_layer_env_version "$key" || get_dockerfile_arg_version "$key"
}

get_expected_jdk_runtime_version() {
    get_expected_version JDK_PACKAGE_VERSION | sed 's/-[^-]*$//'
}

get_expected_python_version() {
    local from_env

    from_env="$(get_expected_version PYTHON_VERSION || true)"
    if [ -n "$from_env" ]; then
        printf '%s\n' "$from_env"
        return 0
    fi

    grep "python3\.[0-9]" "$DOCKERFILE" 2>/dev/null \
        | grep -oE 'python3\.[0-9]+' \
        | head -1 \
        | sed 's/python//'
}
