#!/usr/bin/env bash
# Fail closed when Webtop runtime scripts still contain abc runtime semantics or
# interactive /config defaults after root-first patching.
# Usage: root-first-guard.sh

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

SCAN_ROOT=${BUNTOOLBOX_WEBTOP_ROOT:-}

FATAL_ABC_PATTERNS=(
  's6-setuidgid[[:space:]]+abc'
  '(^|[;&|[:space:]])su[[:space:]][^#\n]*\babc\b'
  '\brunuser\b[^#\n]*\babc\b'
  '\bgosu[[:space:]]+abc\b'
  '\bsetpriv\b[^#\n]*\babc\b'
  '\bchown\b[^#\n]*(abc:|:abc|root:abc)'
  '\blsiown\b[^#\n]*(abc:|:abc|root:abc)'
  '\bpgrep\b[^#\n]*-u[[:space:]]*abc\b'
  '\bpkill\b[^#\n]*-u[[:space:]]*abc\b'
  '\bid([[:space:]]+(-[uGg][[:space:]]+)?)abc\b'
  '\busermod\b[^#\n]*\babc\b'
  '\bgroupmod\b[^#\n]*\babc\b'
  '\bcrontab\b[^#\n]*-u[[:space:]]+abc\b'
)

FATAL_CONFIG_PATTERNS=(
  'HOME=["'"'\'']?/config\b'
  'XDG_[A-Z_]*=["'"'\'']?/config\b'
  '/config/(Desktop|\.config|\.cache|\.local|autostart|i3|openbox|menus?|terminal|pcmanfm|thunar|selkies)\b'
  '\b(startwm|terminal|filemanager|file-manager|Desktop|XDG_|MENU|menu|i3)\b[^#\n]*/config\b'
)

existing_runtime_dirs() {
  local dir path
  for dir in "${RUNTIME_DIRS[@]}"; do
    path="${SCAN_ROOT}${dir}"
    if [[ -d "${path}" ]]; then
      printf '%s\n' "${path}"
    fi
  done
}

is_comment_or_doc_line() {
  local line=$1
  [[ "${line}" =~ ^[[:space:]]*$ ]] && return 0
  [[ "${line}" =~ ^[[:space:]]*# ]] && return 0
  [[ "${line}" =~ ^[[:space:]]*// ]] && return 0
  return 1
}

scan_file_for_pattern() {
  local file=$1
  local pattern=$2
  local label=$3
  local lineno=0 line failed=0

  while IFS= read -r line || [[ -n "${line}" ]]; do
    lineno=$((lineno + 1))
    if is_comment_or_doc_line "${line}"; then
      continue
    fi
    if printf '%s\n' "${line}" | grep -Eq "${pattern}"; then
      printf 'FATAL %s %s:%s:%s\n' "${label}" "${file}" "${lineno}" "${line}" >&2
      failed=1
    fi
  done < "${file}"

  return "${failed}"
}

scan_patterns() {
  local label=$1
  shift
  local patterns=("$@")
  local dirs=() files=() dir file pattern failed=0

  mapfile -t dirs < <(existing_runtime_dirs)
  if [[ ${#dirs[@]} -eq 0 ]]; then
    printf 'ERROR no runtime directories from configured guard surface exist.\n' >&2
    return 1
  fi

  for dir in "${dirs[@]}"; do
    while IFS= read -r -d '' file; do
      case "${file}" in
        *.md|*.rst|*.txt|*.html|*.css|*.map)
          continue
          ;;
      esac
      if [[ -r "${file}" ]] && grep -Iq . "${file}"; then
        files+=("${file}")
      fi
    done < <(find "${dir}" -type f -print0)
  done

  for file in "${files[@]}"; do
    for pattern in "${patterns[@]}"; do
      if ! scan_file_for_pattern "${file}" "${pattern}" "${label}"; then
        failed=1
      fi
    done
  done

  return "${failed}"
}

check_passwd_allows_abc() {
  local passwd_file="${SCAN_ROOT}/etc/passwd"
  if [[ -r "${passwd_file}" ]] && grep -Eq '^abc:' "${passwd_file}"; then
    printf 'INFO abc account remains in /etc/passwd for upstream compatibility; this is allowed.\n'
  fi
}

main() {
  local failed=0
  printf '== buntoolbox webtop root-first guard ==\n'
  check_passwd_allows_abc

  if ! scan_patterns 'abc-runtime' "${FATAL_ABC_PATTERNS[@]}"; then
    failed=1
  fi
  if ! scan_patterns 'interactive-config' "${FATAL_CONFIG_PATTERNS[@]}"; then
    failed=1
  fi

  if [[ "${failed}" -ne 0 ]]; then
    printf 'ERROR root-first guard found forbidden runtime surface.\n' >&2
    return 1
  fi

  printf 'root-first guard passed.\n'
}

main "$@"
