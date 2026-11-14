#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/bmux-codex-diag.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
swiftc -emit-library -emit-module -module-name BmuxSettings "$root/tests/fixtures/codex-monitor-diagnostics/BmuxSettings.swift" -o "$tmp/libBmuxSettings.dylib" -emit-module-path "$tmp/BmuxSettings.swiftmodule"
swiftc -I "$tmp" -L "$tmp" -lBmuxSettings \
  "$root/CLI/CLIProvenanceCodexTranscriptFileIdentity.swift" \
  "$root/CLI/CLIProvenanceCodexTranscriptCursor.swift" \
  "$root/CLI/CLIProvenanceCodexTranscriptCursorStore.swift" \
  "$root/CLI/BMUXCLI+ProvenanceCodexTranscriptDiagnostics.swift" \
  "$root/tests/fixtures/codex-monitor-diagnostics/Harness.swift" -o "$tmp/diagnostic"
for mode in quiet backlog; do
  output="$(TEST_STATE_DIR="$tmp/$mode" DYLD_LIBRARY_PATH="$tmp" "$tmp/diagnostic" "$mode")"
  [[ "$output" == *"Last monitor report:"* ]] || { echo "$mode: misleading report: $output" >&2; exit 1; }
  [[ "$output" != *"cursor is current"* ]] || { echo "$mode: unsupported currentness" >&2; exit 1; }
done
for mode in missing retrying skipped stale error long-backlog; do
  output="$(TEST_STATE_DIR="$tmp/$mode" DYLD_LIBRARY_PATH="$tmp" "$tmp/diagnostic" "$mode")"
  [[ "$output" == *"Needs attention:"* ]] || { echo "$mode: missing attention" >&2; exit 1; }
done
output="$(TEST_STATE_DIR="$tmp/missing-json" DYLD_LIBRARY_PATH="$tmp" "$tmp/diagnostic" missing --json)"
TEST_JSON="$output" python3 -c 'import json, os; r = json.loads(os.environ["TEST_JSON"]); assert not r["available"] and r["report_freshness"] == "unavailable" and r["cursor_offset"] is None and r["read_offset"] is None and r["unread_bytes"] is None and r["skipped_lines"] is None and r["append_or_read_failures"] is None and r["retrying"] is None'
output="$(TEST_STATE_DIR="$tmp/missing-text" DYLD_LIBRARY_PATH="$tmp" "$tmp/diagnostic" missing)"
[[ "$output" == *"No retained monitor report"* && "$output" != *"cursor 0"* ]]
output="$(TEST_STATE_DIR="$tmp/json" DYLD_LIBRARY_PATH="$tmp" "$tmp/diagnostic" quiet --json)"
TEST_JSON="$output" python3 -c 'import json, os; result = json.loads(os.environ["TEST_JSON"]); assert result["available"] is True and result["observation_health"] == "unknown" and result["cursor_currentness"] == "unknown" and result["report_freshness"] == "recent"'
output="$(TEST_STATE_DIR="$tmp/skipped-json" DYLD_LIBRARY_PATH="$tmp" "$tmp/diagnostic" skipped --json)"
TEST_JSON="$output" python3 -c 'import json, os; result = json.loads(os.environ["TEST_JSON"]); assert result["skipped_lines"] == 1 and result["needs_attention"] is True and result["skipped_lines_semantics"] == "cumulative_observations_may_include_replay"'
output="$(TEST_STATE_DIR="$tmp/backlog-json" DYLD_LIBRARY_PATH="$tmp" "$tmp/diagnostic" backlog --json)"
TEST_JSON="$output" python3 -c 'import json, os; r = json.loads(os.environ["TEST_JSON"]); assert r["unread_bytes"] == 5 and r["report_freshness"] == "recent" and r["cursor_currentness"] == "unknown" and r["observation_health"] == "unknown"'
output="$(TEST_STATE_DIR="$tmp/stale-json" DYLD_LIBRARY_PATH="$tmp" "$tmp/diagnostic" stale --json)"
TEST_JSON="$output" python3 -c 'import json, os; r = json.loads(os.environ["TEST_JSON"]); assert r["available"] and r["report_freshness"] == "stale" and r["needs_attention"]'
for mode in retrying error long-backlog; do
  output="$(TEST_STATE_DIR="$tmp/$mode-json" DYLD_LIBRARY_PATH="$tmp" "$tmp/diagnostic" "$mode" --json)"
  TEST_JSON="$output" TEST_MODE="$mode" python3 -c 'import json, os; r = json.loads(os.environ["TEST_JSON"]); mode = os.environ["TEST_MODE"]; assert r["needs_attention"] and r["observation_health"] == "unknown"; assert mode != "retrying" or r["retrying"] is True; assert mode != "error" or r["last_error_kind"] == "synthetic"; assert mode != "long-backlog" or (r["unread_bytes"] == 5 and r["ingestion_lag_seconds"] >= 600)'
done
echo "17 diagnostic cases passed"
