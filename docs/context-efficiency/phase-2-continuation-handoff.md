# Bmux Context Efficiency Phase 2 Continuation Handoff

Archival note, 2026-07-18: Phase 2 is closed. Do not use this file as the live handoff index. Continue from `docs/context-efficiency/current-status.md`, then read `docs/context-efficiency/subsession-delegation-integration-plan.md` before any subsession/delegation provenance work.

## Archived Goal

This file records the earlier Phase 2 continuation state for the Bmux Context Efficiency and Thread Lifecycle System.

Phase 2 is read-only telemetry ingestion:

- stream-parse Codex rollout JSONL;
- persist compact facts in local SQLite;
- preserve raw evidence by source path and byte offset, not by copying full raw payloads;
- suppress duplicate cumulative token telemetry;
- expose inspection and day-summary diagnostics;
- do not change live Codex execution, terminal output, lifecycle policy, handoff behavior, or UI yet.

## Repository State Caveats

The worktree is heavily dirty with many user-owned changes outside this effort. Do not revert or normalize unrelated files.

Known files/directories from this context-efficiency work:

- `docs/context-efficiency/roadmap.md`
- `docs/context-efficiency/current-architecture.md`
- `docs/context-efficiency/proposed-integration.md`
- `docs/context-efficiency/domain-model.md`
- `docs/context-efficiency/milestones.md`
- `docs/context-efficiency/phase-2-continuation-handoff.md`
- `Packages/macOS/BmuxContextEfficiency/`
- `bmux.xcworkspace/contents.xcworkspacedata`
- `CLAUDE.md` was updated earlier with a pointer to the roadmap.

The new package directory may show as entirely untracked. Be careful not to add package-local build products under:

- `Packages/macOS/BmuxContextEfficiency/.build/`

No git commit has been made for this work.

## Implemented In First Phase 2 Slice

New package:

- `Packages/macOS/BmuxContextEfficiency`

Main public API:

- `ContextEfficiencyStore`
- `ContextEfficiencyAgentThreadRecord`
- `ContextEfficiencyModelCallRecord`
- `ContextEfficiencyTokenTelemetryRecord`
- `ContextEfficiencyToolCallRecord`
- `ContextEfficiencyToolOutputRecord`
- `ContextEfficiencyParserErrorRecord`
- `CodexRolloutImportCursor`
- `CodexRolloutImportResult`
- `ContextEfficiencyThreadInspection`
- `ContextEfficiencyDaySummary`

Internal implementation:

- `CodexRolloutJSONLStreamReader`
- `CodexRolloutTelemetryParser`
- `CodexTokenUsageExtractor`
- `ContextEfficiencySQLiteDatabase`
- `ContextEfficiencySQLiteStatement`
- `ContextEfficiencySQLiteMigration`
- `ContextEfficiencyStableIDFactory`

Implemented behavior:

- Streaming JSONL read from a byte cursor.
- Complete newline-terminated lines are processed.
- Incomplete trailing lines are left pending for a later import.
- Each imported fact records source path, byte offset, line number, and parser version.
- Valid unknown rollout lines import as compact `rollout_events`.
- Malformed complete JSON lines record parser errors without aborting import.
- Token telemetry is detected defensively from snake_case and camelCase token fields, including nested `usage`, `token_usage`, and `tokenUsage`.
- Duplicate cumulative telemetry is skipped when the newest token fingerprint matches the thread's prior stored telemetry.
- Tool-call rows store only bounded command summaries and argument byte counts.
- Tool-output rows store output byte counts, estimated original token counts from bmux reduction metadata, and raw-output reference counts, not raw output.
- Rollout source itself is represented as an `evidence_artifacts` external file reference.
- Thread IDs are normalized as `codex:<external-id>`.
- Fallback external thread ID is derived from `rollout-*.jsonl` filename when the event does not carry one.

SQLite schema v1 tables:

- `schema_migrations`
- `import_sources`
- `import_cursors`
- `evidence_artifacts`
- `agent_threads`
- `rollout_events`
- `parser_errors`
- `token_telemetry_events`
- `model_calls`
- `tool_calls`
- `tool_outputs`

Workspace grouping was updated with:

```bash
python3 scripts/check-workspace-package-groups.py --write
```

This added `BmuxContextEfficiency` to `bmux.xcworkspace/contents.xcworkspacedata`.

## 2026-07-17 Status Update

The package, CLI command group, Codex state metadata reader, default local storage path, JSON diagnostics, and current-build CLI regression are now implemented and covered by tests. Latest validation used the existing tagged `context-efficiency` build and did not rebuild the app. See `docs/context-efficiency/current-status.md` for the current validation bundle and Phase 2 closure targets.

## 2026-07-17 Status Update

The package, CLI command group, Codex state metadata reader, default local storage path, JSON diagnostics, and current-build CLI regression are now implemented and covered by tests.

Latest validation used the existing tagged `context-efficiency` build and did not rebuild the app. See `docs/context-efficiency/current-status.md` for the current validation bundle and Phase 2 closure targets.

## Verification Already Run

Package tests:

```bash
swift test --package-path Packages/macOS/BmuxContextEfficiency
```

Result: passed, 6 tests.

Workspace grouping:

```bash
python3 scripts/check-workspace-package-groups.py --check
```

Result: passed.

Tagged Debug build:

```bash
./scripts/reload.sh --tag context-efficiency
```

Result: succeeded.

Built app path:

```text
/Users/brianbusby/Library/Developer/Xcode/DerivedData/bmux-context-efficiency/Build/Products/Debug/bmux DEV context-efficiency.app
```

## Tests Added

- `CodexRolloutJSONLStreamReaderTests`
  - verifies complete-line streaming and incomplete trailing-line carryover.
- `CodexRolloutTelemetryParserTests`
  - verifies token telemetry extraction;
  - verifies tool-call and tool-output summary extraction;
  - verifies malformed JSON becomes a parser-error event.
- `ContextEfficiencyStoreTests`
  - verifies incremental import;
  - verifies duplicate token telemetry suppression;
  - verifies parser-error persistence;
  - verifies tool-call/tool-output persistence;
  - verifies cursor resume after appended JSONL;
  - verifies thread inspection and day-summary reads.

## Important Existing Code To Reuse

Do not rediscover these from scratch:

- `CLI/BMUXCLI+CodexTokenAudit.swift`
  - currently untracked prototype;
  - reads Codex state DB rows;
  - reads rollout files into memory, which Phase 2 should replace.
- `Sources/SessionIndexStore+CodexSQL.swift`
  - reads Codex `state_N.sqlite` safely by copying DB and sidecars before opening.
- `Packages/Shared/BmuxAgentChat/Sources/BmuxAgentChat/Parsing/CodexTranscriptParser.swift`
  - chat-display parser, not telemetry parser; do not overload it.
- `Sources/Mobile/AgentChat/AgentChatTranscriptResolver.swift`
  - resolves Codex rollout JSONL paths.
- `Sources/Mobile/AgentChat/AgentChatSessionRegistry+ObserveScan.swift`
  - discovers live Codex rollout file paths via process FD scanning.
- `Sources/WorkProvenance/`
  - untracked partial provenance store; useful design reference, but do not move it without a deliberate package decision.

## Deferred Phase 2 Work

The next coherent slice should add CLI/state metadata integration around the package rather than changing parser/store behavior first.

Recommended next steps:

1. Add a package-level Codex state DB metadata reader.
   - Reuse SQL field knowledge from `CLI/BMUXCLI+CodexTokenAudit.swift`.
   - Reuse safe snapshot style from `Sources/SessionIndexStore+CodexSQL.swift`.
   - Do not open live Codex SQLite files directly if a snapshot copy is needed.
   - Stream/import rollout paths referenced by state DB rows.

2. Add a default storage location.
   - Proposed path from docs: `~/.local/state/bmux/context-efficiency/bmux-context-efficiency.sqlite`.
   - Keep paths injectable for tests.

3. Link `BmuxContextEfficiency` into the app/CLI target only when CLI integration begins.
   - Expected file: `bmux.xcodeproj/project.pbxproj`.
   - Follow the package wiring pattern from existing leaf packages.
   - Run `scripts/normalize-pbxproj.py` and `scripts/check-pbxproj.sh` after project edits.

4. Add a CLI command group.
   - Expected files:
     - `CLI/bmux.swift`
     - `CLI/BMUXCLI+ContextEfficiency.swift`
     - possibly `CLI/BMUXCLI+CodexTokenAudit.swift`
   - Proposed commands:
     - `bmux context-efficiency import <rollout-path> [--database <path>]`
     - `bmux context-efficiency inspect-thread <thread-id> [--database <path>] [--json]`
     - `bmux context-efficiency summarize-day YYYY-MM-DD [--database <path>] [--json]`
   - If command text, help, or error strings are added, update `Resources/Localizable.xcstrings`.

5. Add CLI regression tests.
   - Expected test harness:
     - `tests/test_context_efficiency_cli.py`, or the nearest existing CLI test pattern.
   - Keep tests behavior-based; do not add grep/source-shape tests.

6. Add JSON/Markdown report formatting.
   - Do not print raw rollout payloads.
   - Reports should show source paths/offsets for recoverability.

## Guardrails For The Next Agent

- Phase 3 command/output attribution is active; see `current-status.md` for current allowed work.
- Do not add lifecycle policy, warnings, handoff recommendations, or output filtering yet.
- Do not move `Sources/WorkProvenance/` into a package without confirming the package strategy.
- Do not use the existing full-file rollout analyzer as the importer.
- Do not put multi-megabyte command or rollout output into SQLite rows.
- Preserve original rollout files as external evidence; store references and offsets.
- Keep facts distinct from inferred labels.
- Version parser and schema changes.
- Keep public package APIs documented with DocC comments.
- Use Swift Testing for package tests.
- After code changes, run package tests and a tagged reload build.

## Localization Notes

The first package slice added no UI and no CLI user-facing strings.

If the next slice adds CLI commands, help, notes, or localized errors, use `String(localized:defaultValue:)` and update every supported locale in `Resources/Localizable.xcstrings`.

This handoff file is internal planning documentation and is not localized.
