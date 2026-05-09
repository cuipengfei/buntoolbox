#!/usr/bin/env bash
# Print Webtop provenance and root-first patch inputs before patching.
# Usage: root-first-preflight.sh

set -euo pipefail

RUNTIME_DIRS=(
  /etc/s6-overlay
  /etc/services.d
  /etc/cont-init.d
  /etc/cont-finish.d
  /custom-services.d
  /defaults
  /usr/local/bin
)

ABC_INVENTORY_REGEX='(s6-setuidgid[[:space:]]+abc|chown[^#\n]*(abc:|:abc|root:abc)|pgrep[[:space:]][^#\n]*-u[[:space:]]*abc|pkill[[:space:]][^#\n]*-u[[:space:]]*abc|\b(id|usermod|groupmod|lsiown|crontab|setpriv|runuser|gosu|su)\b[^#\n]*\babc\b)'

existing_runtime_dirs() {
  local dir
  for dir in "${RUNTIME_DIRS[@]}"; do
    if [[ -d "${dir}" ]]; then
      printf '%s\n' "${dir}"
    fi
  done
}

grep_runtime_inventory() {
  local dirs=()
  mapfile -t dirs < <(existing_runtime_dirs)

  if [[ ${#dirs[@]} -eq 0 ]]; then
    printf 'No runtime directories from the configured scan surface exist.\n'
    return 0
  fi

  grep -RInE --exclude-dir='.git' --exclude='*.md' --exclude='*.txt' \
    "${ABC_INVENTORY_REGEX}" "${dirs[@]}" 2>/dev/null || true
}

print_image_release() {
  printf '## /etc/image-release\n'
  if [[ -r /etc/image-release ]]; then
    grep -Ein 'build|version|revision|webtop|linuxserver|selkies|base' /etc/image-release || cat /etc/image-release
  else
    printf 'MISSING /etc/image-release\n'
  fi
}

print_environment() {
  printf '\n## Webtop/root-first environment\n'
  env | sort | grep -E '^(BUILD|VERSION|LSIO|CUSTOM_|HOME=|PUID=|PGID=|TITLE=)' || true
}

check_key_surface() {
  local name=$1
  shift
  local candidate found=0

  printf '\n## key file: %s\n' "${name}"
  for candidate in "$@"; do
    if [[ -e "${candidate}" ]]; then
      printf 'FOUND %s\n' "${candidate}"
      found=1
    else
      printf 'missing %s\n' "${candidate}"
    fi
  done

  if [[ ${found} -eq 0 ]]; then
    printf 'WARNING no candidate found for %s; patch/guard must rely on broad scan.\n' "${name}"
  fi
}

main() {
  printf '== buntoolbox webtop root-first preflight ==\n'
  print_image_release
  print_environment

  printf '\n## runtime scan surface\n'
  existing_runtime_dirs || true

  printf '\n## runtime abc inventory\n'
  grep_runtime_inventory

  check_key_surface 'svc-xorg/run' \
    /etc/services.d/svc-xorg/run \
    /etc/s6-overlay/s6-rc.d/svc-xorg/run
  check_key_surface 'svc-de/run' \
    /etc/services.d/svc-de/run \
    /etc/s6-overlay/s6-rc.d/svc-de/run
  check_key_surface 'svc-selkies/run' \
    /etc/services.d/svc-selkies/run \
    /etc/s6-overlay/s6-rc.d/svc-selkies/run
  check_key_surface 'init-selkies-config/run' \
    /etc/cont-init.d/init-selkies-config/run \
    /etc/s6-overlay/s6-rc.d/init-selkies-config/run
  check_key_surface 'init-nginx/run' \
    /etc/cont-init.d/init-nginx/run \
    /etc/s6-overlay/s6-rc.d/init-nginx/run
  check_key_surface 'startwm.sh' \
    /defaults/startwm.sh \
    /usr/local/bin/startwm.sh \
    /etc/s6-overlay/s6-rc.d/svc-de/run
}

main "$@"
