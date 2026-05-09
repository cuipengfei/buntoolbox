#!/usr/bin/env bash
set -euo pipefail

REPO="${GITHUB_REPOSITORY:-cuipengfei/buntoolbox}"
IMAGE="${IMAGE:-docker.io/cuipengfei/buntoolbox}"
WORKFLOW="${WORKFLOW:-docker.yml}"
BASELINE_TAG="${BASELINE_TAG:-latest-m001-baseline}"
INCREMENT_TAG="${INCREMENT_TAG:-latest-m001-increment}"
BASELINE_BEADS_VERSION="${BASELINE_BEADS_VERSION:-1.0.3}"
INCREMENT_BEADS_VERSION="${INCREMENT_BEADS_VERSION:-1.0.2}"
REPORT="${REPORT:-.gsd/milestones/M001/slices/S03/S03-VERIFICATION.md}"
TMPDIR="${TMPDIR:-/tmp}"
RUN_CLEAN_PULL="${RUN_CLEAN_PULL:-0}"
USE_EXISTING_TAGS="${USE_EXISTING_TAGS:-0}"
BASELINE_RUN_ID="${BASELINE_RUN_ID:-}"
INCREMENT_RUN_ID="${INCREMENT_RUN_ID:-}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

need gh
need curl
need python3
need jq
need docker

run_workflow() {
  local tag="$1"
  local beads_version="$2"
  echo "Dispatching ${WORKFLOW}: latest_verification_tag=${tag}, latest_beads_version_override=${beads_version}" >&2
  gh workflow run "$WORKFLOW" \
    --repo "$REPO" \
    --ref master \
    -f "latest_verification_tag=${tag}" \
    -f "latest_beads_version_override=${beads_version}"

  local run_id=""
  for _ in {1..30}; do
    run_id=$(gh run list \
      --repo "$REPO" \
      --workflow "$WORKFLOW" \
      --branch master \
      --event workflow_dispatch \
      --json databaseId,status \
      --jq 'map(select(.status != "completed"))[0].databaseId // .[0].databaseId // empty')
    if [[ -n "$run_id" ]]; then
      break
    fi
    sleep 2
  done

  if [[ -z "$run_id" ]]; then
    echo "Could not find workflow_dispatch run for ${tag}" >&2
    exit 1
  fi

  echo "Watching run ${run_id} for ${tag}" >&2
  gh run watch "$run_id" --repo "$REPO" --exit-status >&2
  echo "$run_id"
}

fetch_manifest() {
  local tag="$1"
  local out="$2"
  local token raw child_digest
  token=$(curl -fsSL 'https://auth.docker.io/token?service=registry.docker.io&scope=repository:cuipengfei/buntoolbox:pull' \
    | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')

  raw="${out%.json}.raw.json"
  curl -fsSL \
    -H "Authorization: Bearer ${token}" \
    -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' \
    -H 'Accept: application/vnd.docker.distribution.manifest.list.v2+json' \
    -H 'Accept: application/vnd.oci.image.index.v1+json' \
    -H 'Accept: application/vnd.oci.image.manifest.v1+json' \
    "https://registry-1.docker.io/v2/cuipengfei/buntoolbox/manifests/${tag}" \
    > "$raw"

  child_digest=$(python3 - "$raw" <<'PY'
import json
import sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
if data.get('layers'):
    print('')
    raise SystemExit(0)
for manifest in data.get('manifests', []):
    platform = manifest.get('platform') or {}
    if platform.get('os') == 'linux' and platform.get('architecture') == 'amd64':
        print(manifest['digest'])
        raise SystemExit(0)
raise SystemExit('No linux/amd64 child manifest found')
PY
)

  if [[ -z "$child_digest" ]]; then
    cp "$raw" "$out"
    return
  fi

  curl -fsSL \
    -H "Authorization: Bearer ${token}" \
    -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' \
    -H 'Accept: application/vnd.oci.image.manifest.v1+json' \
    "https://registry-1.docker.io/v2/cuipengfei/buntoolbox/manifests/${child_digest}" \
    > "$out"
}

write_report() {
  local baseline_run="$1"
  local increment_run="$2"
  local diff_json="$3"
  local baseline_pull_log="$4"
  local increment_pull_log="$5"

  python3 - "$REPORT" "$BASELINE_TAG" "$INCREMENT_TAG" "$BASELINE_BEADS_VERSION" "$INCREMENT_BEADS_VERSION" "$baseline_run" "$increment_run" "$diff_json" "$baseline_pull_log" "$increment_pull_log" <<'PY'
import json
import sys
from pathlib import Path

report, baseline_tag, increment_tag, baseline_beads, increment_beads, baseline_run, increment_run, diff_path, baseline_pull_log, increment_pull_log = sys.argv[1:]
with open(diff_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

ratio = data['ratio']
verdict = 'PASS' if ratio <= 0.15 else 'FAIL'
mb = 1024 * 1024
lines = [
    f"{verdict}: S03 pull-size verification for R001/R008",
    "",
    "# S03 Verification — Real Docker Hub tag delta",
    "",
    f"status: {'passed' if verdict == 'PASS' else 'gaps_found'}",
    "",
    "## Inputs",
    "",
    f"- Baseline tag: `{baseline_tag}` (`BEADS_VERSION={baseline_beads}`)",
    f"- Increment tag: `{increment_tag}` (`BEADS_VERSION={increment_beads}`)",
    f"- Baseline GitHub Actions run: `{baseline_run}`",
    f"- Increment GitHub Actions run: `{increment_run}`",
    "",
    "## Manifest delta",
    "",
    f"- Baseline compressed total: {data['baseline_total_bytes'] / mb:.2f} MB ({data['baseline_total_bytes']} bytes)",
    f"- Increment compressed total: {data['increment_total_bytes'] / mb:.2f} MB ({data['increment_total_bytes']} bytes)",
    f"- Shared layers: {data['shared_layers']}",
    f"- New increment layers: {data['new_layers']}",
    f"- delta MB: {data['delta_bytes'] / mb:.2f} MB ({data['delta_bytes']} bytes)",
    f"- Ratio: {ratio * 100:.2f}%",
    f"- Threshold: 15.00%",
    "",
    "## New increment layers",
    "",
    "| Digest | Size MB | Size bytes |",
    "|---|---:|---:|",
]
for layer in data['new_layer_details']:
    lines.append(f"| `{layer['digest']}` | {layer['size'] / mb:.2f} | {layer['size']} |")
lines.extend([
    "",
    "## Requirement verdict",
    "",
    f"- R001: {'validated' if verdict == 'PASS' else 'not validated'} — single-tool pull delta is {ratio * 100:.2f}% of baseline.",
    f"- R008: {'validated' if verdict == 'PASS' else 'not validated'} — result is based on real Docker Hub pushed tags and Registry v2 layer sizes.",
    "",
    "## Clean pull sanity check",
    "",
    f"- Baseline pull log: `{baseline_pull_log}`",
    f"- Increment pull log: `{increment_pull_log}`",
    "- Note: manifest layer sizes are the authoritative wire-transfer metric; pull logs are retained as operational sanity evidence when `RUN_CLEAN_PULL=1`.",
    "",
    "## Artifacts",
    "",
    f"- `/tmp/s03-manifest-{baseline_tag}.json`",
    f"- `/tmp/s03-manifest-{increment_tag}.json`",
    "- `/tmp/s03-manifest-diff.json`",
    f"- `{baseline_pull_log}`",
    f"- `{increment_pull_log}`",
    "",
])
Path(report).parent.mkdir(parents=True, exist_ok=True)
Path(report).write_text('\n'.join(lines), encoding='utf-8')
PY
}

run_clean_pull_logs() {
  local baseline_log="$1"
  local increment_log="$2"

  if [[ "$RUN_CLEAN_PULL" != "1" ]]; then
    printf 'RUN_CLEAN_PULL=0; clean pull sanity check skipped.\n' > "$baseline_log"
    printf 'RUN_CLEAN_PULL=0; clean pull sanity check skipped.\n' > "$increment_log"
    return
  fi

  local docker_config
  docker_config=$(mktemp -d "${TMPDIR}/s03-docker-config.XXXXXX")
  docker system prune -a -f
  DOCKER_CONFIG="$docker_config" /usr/bin/time -v docker pull "${IMAGE}:${BASELINE_TAG}" 2>&1 | tee "$baseline_log"
  docker system prune -a -f
  DOCKER_CONFIG="$docker_config" /usr/bin/time -v docker pull "${IMAGE}:${INCREMENT_TAG}" 2>&1 | tee "$increment_log"
}

compare_manifests() {
  local baseline_manifest="$1"
  local increment_manifest="$2"
  local out="$3"

  python3 - "$baseline_manifest" "$increment_manifest" "$out" <<'PY'
import json
import sys

baseline_path, increment_path, out_path = sys.argv[1:]
with open(baseline_path, 'r', encoding='utf-8') as f:
    baseline = json.load(f)
with open(increment_path, 'r', encoding='utf-8') as f:
    increment = json.load(f)

baseline_layers = baseline.get('layers', [])
increment_layers = increment.get('layers', [])
base_by_digest = {layer['digest']: layer['size'] for layer in baseline_layers}
new_layers = [
    {'digest': layer['digest'], 'size': layer['size']}
    for layer in increment_layers
    if layer['digest'] not in base_by_digest
]
baseline_total = sum(layer['size'] for layer in baseline_layers)
increment_total = sum(layer['size'] for layer in increment_layers)
delta = sum(layer['size'] for layer in new_layers)
result = {
    'baseline_total_bytes': baseline_total,
    'increment_total_bytes': increment_total,
    'delta_bytes': delta,
    'ratio': delta / baseline_total if baseline_total else 1,
    'shared_layers': sum(1 for layer in increment_layers if layer['digest'] in base_by_digest),
    'new_layers': len(new_layers),
    'new_layer_details': new_layers,
}
with open(out_path, 'w', encoding='utf-8') as f:
    json.dump(result, f, indent=2)
PY
}

main() {
  local baseline_run increment_run
  if [[ "$USE_EXISTING_TAGS" == "1" ]]; then
    baseline_run="${BASELINE_RUN_ID:-existing-tag}"
    increment_run="${INCREMENT_RUN_ID:-existing-tag}"
  else
    baseline_run=$(run_workflow "$BASELINE_TAG" "$BASELINE_BEADS_VERSION")
    increment_run=$(run_workflow "$INCREMENT_TAG" "$INCREMENT_BEADS_VERSION")
  fi

  local baseline_manifest="${TMPDIR}/s03-manifest-${BASELINE_TAG}.json"
  local increment_manifest="${TMPDIR}/s03-manifest-${INCREMENT_TAG}.json"
  local diff_json="${TMPDIR}/s03-manifest-diff.json"
  local baseline_pull_log="${TMPDIR}/s03-baseline-pull.log"
  local increment_pull_log="${TMPDIR}/s03-increment-pull.log"

  fetch_manifest "$BASELINE_TAG" "$baseline_manifest"
  fetch_manifest "$INCREMENT_TAG" "$increment_manifest"
  compare_manifests "$baseline_manifest" "$increment_manifest" "$diff_json"
  run_clean_pull_logs "$baseline_pull_log" "$increment_pull_log"
  write_report "$baseline_run" "$increment_run" "$diff_json" "$baseline_pull_log" "$increment_pull_log"

  echo "Wrote ${REPORT}"
  jq . "$diff_json"
}

main "$@"
