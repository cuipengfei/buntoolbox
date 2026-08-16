#!/usr/bin/env python3
"""Validate Stack Scount's small, local, machine-readable state contract."""

from __future__ import annotations

import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[4]
STATE_PATH = ROOT / ".omx/state/stack-scount/state.json"
REQUIRED_TOP_LEVEL = {
    "schema_version",
    "system",
    "baseline_artifacts",
    "seed_sources",
    "candidate_index",
    "runs",
    "next_focus",
}
VALID_STATUSES = {
    "unseen",
    "seen",
    "not-recommended",
    "shortlisted",
    "deep-dive",
    "adopted",
    "superseded",
}


def fail(message: str) -> None:
    print(f"invalid Stack Scount state: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    if not STATE_PATH.is_file():
        fail(f"missing {STATE_PATH.relative_to(ROOT)}")

    try:
        state = json.loads(STATE_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"invalid JSON: {error}")

    missing = REQUIRED_TOP_LEVEL - state.keys()
    if missing:
        fail(f"missing top-level fields: {sorted(missing)}")

    for path in state["baseline_artifacts"]:
        if not (ROOT / path).is_file():
            fail(f"baseline artifact missing: {path}")

    for candidate in state["candidate_index"]:
        required = {"id", "name", "status", "evidence_paths", "last_verdict"}
        candidate_missing = required - candidate.keys()
        if candidate_missing:
            fail(f"candidate {candidate.get('id', '<unknown>')} missing: {sorted(candidate_missing)}")
        if candidate["status"] not in VALID_STATUSES:
            fail(f"candidate {candidate['id']} has invalid status: {candidate['status']}")
        for path in candidate["evidence_paths"]:
            if not (ROOT / path).is_file():
                fail(f"candidate {candidate['id']} references missing evidence: {path}")

    for run in state["runs"]:
        required = {"id", "date", "kind", "summary", "report_path"}
        run_missing = required - run.keys()
        if run_missing:
            fail(f"run {run.get('id', '<unknown>')} missing: {sorted(run_missing)}")
        if not (ROOT / run["report_path"]).is_file():
            fail(f"run {run['id']} report missing: {run['report_path']}")

    print(
        "Stack Scount state valid: "
        f"{len(state['candidate_index'])} candidates, {len(state['runs'])} runs."
    )


if __name__ == "__main__":
    main()
