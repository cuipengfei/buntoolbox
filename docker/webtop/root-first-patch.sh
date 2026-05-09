#!/usr/bin/env bash
# Apply deterministic root-first rewrites to Webtop runtime scripts.
# Usage: root-first-patch.sh

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

ABC_RUNTIME_REGEX='(s6-setuidgid[[:space:]]+abc|chown[^#\n]*(abc:|:abc|root:abc)|pgrep[[:space:]][^#\n]*-u[[:space:]]*abc|pkill[[:space:]][^#\n]*-u[[:space:]]*abc|\b(id|usermod|groupmod|lsiown|crontab|setpriv|runuser|gosu|su)\b[^#\n]*\babc\b)'

FILES=()
REQUIRED_MATCH_TOTAL=20
REQUIRED_PATCH_REGEXES=(
  's6-setuidgid[[:space:]]+abc'
  'chown[^#\n]*(abc:abc|root:abc|:abc)'
  '\b(pgrep|pkill)[[:space:]][^#\n]*-u[[:space:]]*abc\b'
  '\bid([[:space:]]+(-[uGg][[:space:]]+)?)abc\b'
  '\blsiown[[:space:]][^#\n]*(abc:abc|root:abc|:abc)'
  '\bcrontab[[:space:]][^#\n]*-u[[:space:]]+abc\b'
  '\b(usermod|groupmod)\b[^#\n]*\babc\b'
)

collect_files() {
  local dir path
  FILES=()
  for dir in "${RUNTIME_DIRS[@]}"; do
    path="${SCAN_ROOT}${dir}"
    if [[ -d "${path}" ]]; then
      while IFS= read -r -d '' file; do
        FILES+=("${file}")
      done < <(find "${path}" -type f -print0)
    fi
  done
}

grep_count() {
  local regex=$1 file count
  count=0
  for file in "${FILES[@]}"; do
    if [[ -r "${file}" ]] && grep -Iq . "${file}"; then
      if grep -Eq "${regex}" "${file}"; then
        count=$((count + $(grep -Ec "${regex}" "${file}")))
      fi
    fi
  done
  printf '%s\n' "${count}"
}

perl_rewrite_all() {
  local description=$1
  local perl_expr=$2
  local regex=$3
  local before after file

  before=$(grep_count "${regex}")
  printf 'patch: %s before=%s\n' "${description}" "${before}"
  if [[ "${before}" -eq 0 ]]; then
    return 0
  fi

  for file in "${FILES[@]}"; do
    if [[ -r "${file}" && -w "${file}" ]] && grep -Iq . "${file}" && grep -Eq "${regex}" "${file}"; then
      perl -0pi -e "${perl_expr}" "${file}"
    fi
  done

  after=$(grep_count "${regex}")
  printf 'patch: %s after=%s\n' "${description}" "${after}"
  if [[ "${after}" -ne 0 ]]; then
    printf 'ERROR patch context still present after rewrite: %s\n' "${description}" >&2
    return 1
  fi
}

comment_out_mutation_lines() {
  local description=$1
  local regex=$2
  local before after file

  before=$(grep_count "${regex}")
  printf 'patch: %s before=%s\n' "${description}" "${before}"
  if [[ "${before}" -eq 0 ]]; then
    return 0
  fi

  for file in "${FILES[@]}"; do
    if [[ -r "${file}" && -w "${file}" ]] && grep -Iq . "${file}" && grep -Eq "${regex}" "${file}"; then
      perl -0pi -e "s/^[^#\n]*${regex}[^\n]*\$/# buntoolbox root-first disabled upstream user or group mutation/mg" "${file}"
    fi
  done

  after=$(grep_count "${regex}")
  printf 'patch: %s after=%s\n' "${description}" "${after}"
  if [[ "${after}" -ne 0 ]]; then
    printf 'ERROR mutation line still active after rewrite: %s\n' "${description}" >&2
    return 1
  fi
}

ensure_upstream_surface() {
  local matches regex required_matches=0
  matches=$(grep_count "${ABC_RUNTIME_REGEX}")
  printf 'pre-patch abc runtime matches=%s\n' "${matches}"
  if [[ "${matches}" -lt "${REQUIRED_MATCH_TOTAL}" ]]; then
    printf 'ERROR expected at least %s abc runtime matches; found %s. Upstream layout may have drifted or patch inputs are wrong.\n' "${REQUIRED_MATCH_TOTAL}" "${matches}" >&2
    return 1
  fi

  for regex in "${REQUIRED_PATCH_REGEXES[@]}"; do
    required_matches=$(grep_count "${regex}")
    if [[ "${required_matches}" -eq 0 ]]; then
      printf 'ERROR required root-first patch surface missing: %s\n' "${regex}" >&2
      return 1
    fi
  done
}

apply_root_home_defaults() {
  perl_rewrite_all \
    '/config Desktop paths -> /root Desktop paths' \
    's#/config/Desktop#/root/Desktop#g' \
    '/config/Desktop'
  perl_rewrite_all \
    '/config XDG/cache/local paths -> /root paths' \
    's#/config/\.config#/root/.config#g; s#/config/\.cache#/root/.cache#g; s#/config/\.local#/root/.local#g' \
    '/config/\.(config|cache|local)'
  perl_rewrite_all \
    'HOME=/config defaults -> HOME=/root' \
    's#HOME=("?)/config\b#HOME=${1}/root#g' \
    'HOME="?/config\b'
}

run_guard() {
  BUNTOOLBOX_WEBTOP_ROOT="${SCAN_ROOT}" bash "$(dirname "${BASH_SOURCE[0]}")/root-first-guard.sh"
}

main() {
  collect_files
  if [[ ${#FILES[@]} -eq 0 ]]; then
    printf 'ERROR no files found in Webtop runtime scan surface.\n' >&2
    return 1
  fi

  ensure_upstream_surface

  perl_rewrite_all \
    's6-setuidgid abc -> root execution' \
    's#\bs6-setuidgid\s+abc\s+##g' \
    's6-setuidgid[[:space:]]+abc'
  perl_rewrite_all \
    'chown abc/root:abc ownership -> root:root ownership' \
    's#\bchown(\s+(?:-[A-Za-z]+\s+)*)abc:abc\b#chown${1}root:root#g; s#\bchown(\s+(?:-[A-Za-z]+\s+)*)root:abc\b#chown${1}root:root#g; s#\bchown(\s+(?:-[A-Za-z]+\s+)*):abc\b#chown${1}:root#g' \
    'chown[^#\n]*(abc:abc|root:abc|:abc)'
  perl_rewrite_all \
    'pgrep/pkill -u abc -> -u root' \
    's{\b(pgrep|pkill)([^\n#]*?)-u\s*abc\b}{$1${2}-u root}g' \
    '\b(pgrep|pkill)[[:space:]][^#\n]*-u[[:space:]]*abc\b'
  perl_rewrite_all \
    'id abc lookups -> root lookups' \
    's#\bid(\s+(?:-[uGg]\s+)?)abc\b#id${1}root#g; s#\bid\s+abc\b#id root#g' \
    '\bid([[:space:]]+(-[uGg][[:space:]]+)?)abc\b'
  perl_rewrite_all \
    'lsiown abc ownership -> root ownership' \
    's#\blsiown(\s+)abc:abc\b#lsiown${1}root:root#g; s#\blsiown(\s+)root:abc\b#lsiown${1}root:root#g; s#\blsiown(\s+):abc\b#lsiown${1}:root#g' \
    '\blsiown[[:space:]][^#\n]*(abc:abc|root:abc|:abc)'
  perl_rewrite_all \
    'crontab -u abc -> -u root' \
    's{\bcrontab([^\n#]*?)-u\s+abc\b}{crontab${1}-u root}g' \
    '\bcrontab[[:space:]][^#\n]*-u[[:space:]]+abc\b'
  comment_out_mutation_lines \
    'usermod/groupmod abc runtime mutation disabled' \
    '\b(usermod|groupmod)\b[^#\n]*\babc\b'
  perl_rewrite_all \
    'runuser/gosu/setpriv/su abc launchers -> root launchers' \
    's{\brunuser(\s+-u\s+)abc\b}{runuser${1}root}g; s{\bgosu\s+abc\b}{gosu root}g; s{\bsetpriv([^\n#]*?)abc\b}{setpriv${1}root}g; s{\bsu(\s+-[^\n#]*\s+)abc\b}{su${1}root}g' \
    '\b(runuser|gosu|setpriv|su)\b[^#\n]*\babc\b'

  apply_root_home_defaults

  run_guard
}

main "$@"
