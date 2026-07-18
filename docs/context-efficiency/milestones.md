# Bmux Context Efficiency: Milestones

Status: proposed implementation sequence grounded in repository discovery.

## Milestone 1: Discovery and Schemas

Status: in progress with this documentation set.

Deliverables:

- `docs/context-efficiency/current-architecture.md`
- `docs/context-efficiency/proposed-integration.md`
- `docs/context-efficiency/domain-model.md`
- `docs/context-efficiency/milestones.md`
- Stored roadmap: `docs/context-efficiency/roadmap.md`

Done when:

- Existing subsystems are inventoried.
- Reuse/replacement decisions are documented.
- Unknowns and user decisions are recorded.
- Milestone 2 file-change map is explicit.

No runtime behavior changes belong in this milestone.

## Milestone 2: Read-Only Codex Telemetry

Status: complete as of 2026-07-17.

Implemented:

- `Packages/macOS/BmuxContextEfficiency`
- Streaming Codex rollout JSONL reader with byte offsets and incomplete-line carryover.
- Defensive rollout telemetry parser for token usage, compactions, tool calls, tool outputs, session metadata, and parser errors.
- SQLite store with schema version 1, import sources, cursors, parser errors, evidence-artifact references, thread projections, model calls, token telemetry, rollout events, tool calls, and tool outputs.
- Duplicate cumulative-token telemetry suppression by thread-local token fingerprint.
- Read-only thread inspection and day summary DTOs for future CLI/UI use.
- Package-local Swift Testing coverage for streaming, parser, duplicate suppression, cursor resume, parser-error recovery, and report reads.
- Workspace package grouping updated via `scripts/check-workspace-package-groups.py --write`.
- Codex `state_N.sqlite` metadata reader.
- App/CLI target integration for the `bmux context-efficiency ...` command surface.
- JSON diagnostics for import, inspect-thread, and summarize-day.
- Current-build CLI regression coverage in `tests/test_context_efficiency_cli.py`.

Closure decisions:

- Markdown/CSV export formatting is deferred; JSON diagnostics satisfy the Phase 2 read-only report contract.
- `codex-token-audit` remains legacy for now; replacement/removal is deferred to a cleanup slice after Phase 2 closure.

Phase 3 entry point:

- Start with command and output attribution in the context-efficiency package.
- Preserve Phase 2 invariants: raw evidence stays external and recoverable, reports remain bounded, and facts stay distinct from inference.
- Do not start lifecycle warnings, handoff recommendations, output filtering, UI, or automatic context mutation until their later milestones.


Goal:

Build an incremental, local-only Codex telemetry importer and report surface without changing live Codex execution.

Deliverables:

- Streaming Codex rollout JSONL parser.
- Codex state DB metadata reader.
- SQLite persistence with migrations.
- Import cursor and parser-error recording.
- Duplicate cumulative-token suppression.
- CLI JSON diagnostics; Markdown/CSV formatting deferred.
- Legacy disposition recorded for `codex-token-audit`; replacement/removal deferred to cleanup.

Proposed exact files to add:

- `Packages/macOS/BmuxContextEfficiency/Package.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Schema/ContextEfficiencySchemaVersion.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Model/AgentThreadRecord.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Model/ModelCallRecord.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Model/TokenTelemetryRecord.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Model/EvidenceArtifactRecord.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Import/CodexStateDatabaseReader.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Import/CodexRolloutJSONLStreamReader.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Import/CodexRolloutTelemetryParser.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Import/CodexImportCursor.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Store/ContextEfficiencySQLiteDatabase.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Store/ContextEfficiencyStore.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Store/ContextEfficiencyMigration.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Reports/ThreadInspectionReport.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Reports/DaySummaryReport.swift`
- `Packages/macOS/BmuxContextEfficiency/Tests/BmuxContextEfficiencyTests/CodexRolloutTelemetryParserTests.swift`
- `Packages/macOS/BmuxContextEfficiency/Tests/BmuxContextEfficiencyTests/ContextEfficiencyStoreTests.swift`
- `Packages/macOS/BmuxContextEfficiency/Tests/BmuxContextEfficiencyTests/Fixtures/normal-short-thread.jsonl`
- `Packages/macOS/BmuxContextEfficiency/Tests/BmuxContextEfficiencyTests/Fixtures/duplicated-token-telemetry.jsonl`
- `Packages/macOS/BmuxContextEfficiency/Tests/BmuxContextEfficiencyTests/Fixtures/malformed-lines.jsonl`
- `Packages/macOS/BmuxContextEfficiency/Tests/BmuxContextEfficiencyTests/Fixtures/compaction-thread.jsonl`

Proposed exact files to change:

- `bmux.xcodeproj/project.pbxproj` to include the new package if Xcode app/CLI target integration needs it.
- `bmux.xcworkspace/contents.xcworkspacedata` via `scripts/check-workspace-package-groups.py --write` after adding the package.
- `CLI/bmux.swift` to dispatch the new command group.
- `CLI/BMUXCLI+CodexTokenAudit.swift` to either call the new report layer or be marked legacy.
- Add `CLI/BMUXCLI+ContextEfficiency.swift` if the CLI command group stays in the monolithic CLI.
- `tests/test_codex_token_audit.py` or a new `tests/test_context_efficiency_cli.py` for CLI regression coverage.
- `docs/context-efficiency/milestones.md` after implementation to record the actual chosen command names and storage path.

Possible files to move or package after user decision:

- `Sources/WorkProvenance/*`
- `CLI/BMUXCLI+Provenance.swift`
- `CLI/CLIProvenance*.swift`
- `bmuxTests/WorkProvenance*.swift`

Out of scope:

- terminal PTY command capture;
- output filtering changes;
- lifecycle recommendations;
- UI fleet/thread views;
- handoff generation.

Validation:

- Package tests for parser and store.
- CLI fixture test with a temporary Codex home/state DB.
- Confirm importer resumes from offsets and does not load full rollout files.
- Confirm malformed lines record parser errors and do not abort import.
- Confirm no live Codex process is required.

## Milestone 3: Command and Output Attribution

Status: active. Command-attribution and work-item reference fact slices are implemented.

Goal:

Connect token/model-call telemetry to command activity and evidence artifacts.

Implemented in the first slice:

- `ContextEfficiencyCommandExecutionRecord`, `ContextEfficiencyCommandCategory`, and attribution confidence/model-call attribution value types.
- Deterministic command classifier for bounded Codex command summaries.
- Derived command execution candidates in `ContextEfficiencyThreadInspection`.
- Exact tool-call to tool-output links when Codex `call_id` matches.
- Temporal candidate attribution from command output to the next later model call.
- `inspect-thread --json` `command_executions` output with bounded counts, categories, confidence labels, and source references.
- Package and CLI regression coverage proving raw tool arguments/output are not included in the report.

Implemented in the second slice:

- `ContextEfficiencyWorkItemReferenceRecord` and closed enums for reference kind, source, and confidence.
- Schema v2 `work_item_references` table for bounded PR, issue, ticket, branch, and repository reference facts.
- Reference extraction from Codex state metadata and bounded rollout payload strings.
- `inspectThread` and `inspect-thread --json` work-item reference output with source references.
- Package and CLI regression coverage proving source messages and raw output are not retained in reports.

Expected work:

- Persist command execution candidates if derived reports prove insufficient.
- Add command-category aggregate counts to thread/day reports.
- Add repeated command/search/file-read detection as bounded facts.
- Index proxy `rawOutputRef` artifacts.
- Evaluate OSC 133 parsing for non-Codex terminal attribution.
- Link evidence-backed reference facts to future provenance work items or delegation inputs.

Candidate files:

- Add `CommandExecutionRecord`, `CommandCategory`, and attribution types to the context-efficiency package.
- Add command parser/classifier tests.
- Add importer support for tool call/output rows.
- Optionally add a bridge to `OSC133CommandParser`.

Stop condition:

- Reports must label attribution confidence and distinguish exact tool-call links from temporal candidates.

## Milestone 4: Efficiency Profiler

Goal:

Compute per-call, per-thread, per-command, and per-work-item metrics from stored facts.

Expected work:

- Cached/new/output totals where available.
- Context utilization and call deltas.
- Compaction effectiveness signals.
- Repeated command/search/file-read detection.
- Low-information/high-context heuristic signals.
- Possible-loop signal windows.

Rules:

- Heuristics are configurable and versioned.
- High token usage alone must not label a thread stuck.
- Reports show measurements and conditions, not opaque scores.

## Milestone 5: Project Progress and Provenance

Goal:

Integrate useful-work evidence with cost evidence.

Expected work:

- Decide package/store ownership for `WorkProvenance`.
- Link threads/model calls/commands to worktrees and contributions.
- Track decisions, discoveries, failed approaches, invariants, open questions, validations, and milestones.
- Update state incrementally from bounded event batches.

Risk:

- Model-derived summaries can be useful but must remain marked inferred.

## Milestone 6: Coordination UI

Goal:

Expose fleet, thread detail, work-item, and handoff-preview views without crowding the terminal workspace.

Expected work:

- Decide whether the first UI surface is Feed, Session Index detail, custom sidebar, or a new coordination window.
- Add token timelines and command/evidence drilldown.
- Add explanation UI for passive lifecycle signals.
- Link to raw evidence recovery.

Rules:

- UI warnings must show underlying measurements.
- No automatic interruption.

## Milestone 7: Shadow Lifecycle Engine

Goal:

Evaluate handoff and lifecycle policies in shadow mode.

Expected work:

- Policy version records.
- Threshold configuration.
- Shadow intervention logs.
- Later-outcome comparison reports.
- Handoff-point simulation.

Rules:

- No automatic thread kill.
- No recommendation without an explanation.

## Milestone 8: Assisted Handoffs

Goal:

Generate bounded structured handoff packages and measure post-handoff outcomes.

Expected work:

- Handoff schema and priority rules.
- Handoff preview/edit UI.
- Worktree/path/commit validation.
- New thread launch preparation.
- Post-handoff rediscovery metrics.

Rules:

- User approves transition.
- Raw artifacts remain referenced and recoverable.

## Milestone 9: Output Reduction Experiment

Goal:

Measure native/RTK-style command-output reduction separately from thread lifecycle savings.

Expected work:

- General artifact index for raw/reduced command output.
- Category-specific reducers behind an abstraction.
- Measurement of raw vs reduced bytes/tokens.
- Correctness impact tracking when omitted evidence is requested.

Rules:

- Unknown/interactive commands fall back safely.
- Do not hide failures, conflicts, or important diagnostics.

## Milestone 10: Adaptive Calibration

Goal:

Tune policies with interpretable, versioned historical evaluation.

Expected work:

- Replay framework for stored event streams.
- Offline policy comparisons.
- Global/model/repository/task/user calibration layers.
- Manual policy promotion with sample counts and confidence.

Rule:

- Do not optimize only for lower token totals.

## Architectural Risks

- Codex local schemas may change without notice.
- Cached-input token splits may be unavailable in local files.
- Large output capture can harm terminal responsiveness if placed on hot paths.
- App-target provenance code may slow testing and reuse if not packaged.
- UI warnings could become noisy before outcome validation.
- Summaries could incorrectly overwrite explicit user decisions if fact/inference boundaries are weak.

## Open User Decisions

- Package strategy for `WorkProvenance` versus new `BmuxContextEfficiency`.
- CLI command naming.
- Whether context-efficiency and provenance share one SQLite DB.
- Retention defaults for raw artifacts.
- First UI surface for lifecycle warnings and fleet view.

## Milestone 2 Review Checklist

- Parser version is persisted.
- Store schema version is migrated/tested.
- Every imported event has a source reference.
- Duplicate cumulative telemetry is skipped or marked duplicate.
- Parser errors are queryable.
- Large rollout import is streaming.
- CLI reports do not print raw rollout payloads.
- Tests cover malformed and duplicate data.
- No live Codex execution behavior changes.
