#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/bmux-snapshot-tests.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
swiftc -swift-version 6 -warnings-as-errors \
  CLI/CodexTranscriptSnapshot.swift tests/codex_transcript_snapshot_experiment.swift \
  -o "$test_dir/snapshot-tests"
"$test_dir/snapshot-tests"
BMUX_SNAPSHOT_TEST_BINARY="$test_dir/snapshot-tests" python3 tests/codex_snapshot_special_files.py -v
