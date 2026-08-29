# Bmux Context Efficiency: Milestones

Status: implementation sequence reconciled on 2026-07-19 after merging the subsession/delegation integration plan, the agent retrieval/knowledge-projection plan, and the provenance observability integration plan into the original context-efficiency roadmap.

Planning authority: this file is detailed context-efficiency and provenance extraction history. The canonical bmux product roadmap is `docs/roadmap.md`. The canonical monorepo architecture and Project Truth roadmap begin at `docs/architecture/README.md` and `docs/generated/nested-roadmap.md`.

Cross-cutting plans:

- `docs/context-efficiency/adr-001-provenance-engine-extraction.md`
- `docs/context-efficiency/provenance-engine-extraction-phase0-report.md`
- `docs/context-efficiency/provenance-engine-contracts-phase1-plan.md`
- `docs/context-efficiency/provenance-engine-phase3-plan.md`
- `docs/context-efficiency/provenance-engine-phase3a-decisions.md`
- `docs/context-efficiency/provenance-engine-phase4-reconnect-plan.md`
- `docs/context-efficiency/provenance-engine-semantic-roadmap.md`
- `docs/context-efficiency/cross-session-coordination-active-work-awareness.md`
- `docs/context-efficiency/subsession-delegation-integration-plan.md`
- `docs/context-efficiency/agent-retrieval-knowledge-projection-plan.md`
- `docs/context-efficiency/provenance-observability-integration-plan.md`

ADR-001 is accepted and establishes the Provenance Engine as an independent product. Future provenance milestones should treat bmux as the first client, not as the owner of the engine. Migration work should introduce public SDK/API contracts before moving implementation, keep the engine local-first for V1, and avoid new bmux assumptions in reusable provenance logic.

The semantic-processing and agent-context roadmap is canonical in
`docs/context-efficiency/provenance-engine-semantic-roadmap.md`. It makes
structured engineering decisions, stable project facts, selective semantic
processing, semantic cost telemetry, privacy policy, and task-specific context
packs first-class Provenance Engine capabilities. It does not expand the current
Phase 3 storage foundation or Phase 4 bmux adoption scope.

The next accepted live-session direction is canonical in
`BrianBusby/provenance-engine:docs/session-work-model.md`. It introduces
PE-owned richer completed evidence ingestion, inference records, milestone
semantics, scoped architecture projections, and a high-level `SessionWorkModel`
consumer projection. Older milestone language that suggests bmux owns semantic
progress modeling should now be read as historical product motivation only.
Session Outcome is the deterministic factual aggregation layer that now sits
between `TurnOutcome` revisions and later semantic/cross-session consumers.

The cross-session coordination roadmap is recorded in
`docs/context-efficiency/cross-session-coordination-active-work-awareness.md`.
It makes active session/task registries, active-work indexing, cross-session
queries, and passive conflict detection later Provenance Engine capabilities,
with bmux responsible for display, prompt assembly, and user workflow.

The ADR-001 Phase 3 entry plan is now drafted in
`docs/context-efficiency/provenance-engine-phase3-plan.md`.
It starts Phase 3 but does not complete it. ADR-001 Phase 3A is complete in
`docs/context-efficiency/provenance-engine-phase3a-decisions.md` and resolves
the next skeleton's repo path, GitHub repository owner/name, Swift/SwiftPM V1 choice,
standalone SwiftPM artifact shape, first package/module names, in-process-first
SDK relationship, new-data storage default, and initial observability exclusion.
ADR-001 Phase 3B created the minimal independent skeleton locally at
`/Users/brianbusby/repos/provenance-engine`: package `ProvenanceEngine`, initial
module/product `ProvenanceEngineContracts`, and Foundation-only
health/capability contracts. The canonical GitHub repository is now
`BrianBusby/provenance-engine`, with remote URL
`git@github.com:BrianBusby/provenance-engine.git`. The provenance engine is
initially owned and maintained under the `BrianBusby` GitHub account. It may be
transferred to a future organization, for example `manaflow-ai`, once the
project matures. Repository ownership is an implementation detail and must not
affect package names, APIs, module boundaries, documentation, storage defaults,
or bmux integration. GitHub repository
`BrianBusby/provenance-engine` now exists publicly, the local engine repo's `origin`
points at `git@github.com:BrianBusby/provenance-engine.git`, and external
skeleton commit `9e8fa620ccd04040968e0afab591feb48c8c11d0` is pushed to
`origin/main`. ADR-001 Phase 3C lifted the initial in-process public contract
surface into `ProvenanceEngineContracts` at commit
`0b2529170ef4b0d67f8050f89786d439bbab6d27`. ADR-001 Phase 3D started
with the smallest storage boundary: internal engine-owned SQLite connection and
statement support in `ProvenanceEngineSQLite` at commit
`ec8b84bc2f8ac7e98c0e22cac67bf6895e7882ac`. A second Phase 3D slice added
internal SQLite schema-versioning and migration scaffolding at commit
`9f7333799ef4f036b06b580fcbac3cde9398b306`. A third Phase 3D slice added a
minimal internal SQLite repository actor at commit
`dfd57a6441d5090130476893502c3091d2769440`. A fourth Phase 3D slice added the
first internal repository-owned event-ledger table and narrow append/read path
at commit `f96858fb8f1a207426ad78c2524ab5b5c9b74121`. A fifth Phase 3D slice
added the first internal repository-owned session projection table and narrow
read path at commit `ad1eec1dd7a0cabd3e78943ff798f21ee7665fa2`. A sixth Phase 3D
slice added internal repository/worktree projection bootstrap and a bounded
worktree-list read model at commit
`fe1a4c5712eefc7ab2e2e3b271d0dc1e91a442e1`. A seventh Phase 3D slice added
internal session-relationship and external-identity projection tables plus
bounded session-tree reads at commit
`aff90f9c28b9a66bbb7014918c9e23338d706c6b` on branch
`provenance-session-tree-storage`. An eighth Phase 3D slice added internal
work-item, contribution, checkpoint, change-set, and file-change projection
tables plus focused file-explanation reads at commit
`1032a752db589e670917b56b5bbbefe6442843bd` on branch
`provenance-session-tree-storage`. A ninth Phase 3D slice added internal
validation-run projection storage plus bounded current-context projection reads
at commit `09628cf4e1ffc0a055dd683cdad5f8da1341a0e2` on branch
`provenance-session-tree-storage`. A scoped autoreview follow-up bounded
session-tree traversal at commit `bc86510426aba51afd4ed3f1e0fe509ae77f5ec7`
on branch `provenance-session-tree-storage`. A tenth Phase 3D storage slice
added an internal SQLite implementation of the existing normalized
subsession-lifecycle recording contract, deterministic engine-owned stable IDs,
lifecycle event construction, append response handling, and behavior coverage at
commit `94d67f4ee3fe59a7458fc2d1c03793cd67c04466` on branch
`provenance-session-tree-storage`; draft PR:
https://github.com/BrianBusby/provenance-engine/pull/1. An autoreview follow-up
preserved existing child-session start times when recording stop lifecycle
events at commit `def6a66d6fd9be0bba281cf9edb26319319cd6cb`. An eleventh
Phase 3D storage slice added internal SQLite-backed `ProvenanceEngineClient`
conformance, including health and append request wrappers over the existing
internal storage/query paths, at commit
`29c483078c4637631add212f9c2840b1caf4d328` on branch
`provenance-session-tree-storage`; draft PR:
https://github.com/BrianBusby/provenance-engine/pull/1. An autoreview follow-up
enforced `ProvenanceSessionTreeRequest.limit` as a combined
session-plus-relationship row bound while preserving coherent parent-child edges
at commit `ebf2d437bc48b875c84f5794387e2437dc8b82b4`. A twelfth Phase 3D
storage slice added an internal engine-owned default SQLite storage-location
resolver for `~/.local/state/provenance-engine/provenance.sqlite` plus
repository opening coverage, without exporting storage or moving bmux data, on
branch `provenance-session-tree-storage`, at commit
`f3767534fbd89a473bd003eb1421ed56acc82827`. No public storage SDK, daemon,
storage path move, schema move, data migration, bmux reconnect, retrieval layer,
lifecycle policy, UI, or broad observability expansion was created. A
thirteenth Phase 3D storage slice added bounded internal append-order
event-ledger cursor reads over the existing `provenance_events` table on branch
`provenance-session-tree-storage`, at commit
`4ff1837e40a9dd2c0ad6a9552260cf3afaa9c7d9`. A fourteenth Phase 3D storage
slice added internal current-state projection rebuild from immutable
event-ledger replay on branch `provenance-session-tree-storage`, at commit
`d18d5596c3e0bd4e8e9ffd7680dd6bc6139fc2bb`. A fifteenth Phase 3D storage
slice added an internal repository-owned SQLite storage summary read model for
ledger/projection counts on branch `provenance-session-tree-storage`, at commit
`68bafa628e4d10e212b089fc73b2e64a12d76dba`. A sixteenth Phase 3D storage
slice added an internal bounded SQLite event-ledger validation read model on
branch `provenance-session-tree-storage`, at commit
`c9078e6eb904d27a1da48db7a5b518aad6c8ab1e`. A seventeenth Phase 3D storage
slice added an internal bounded SQLite projection-count validation read model
on branch `provenance-session-tree-storage`, at commit
`303225390707775863e63821ec50eaf036e3d615`. An eighteenth Phase 3D storage
slice added an internal bounded SQLite projection-key validation read model on
branch `provenance-session-tree-storage`, at commit
`bab8f18abbc79300f52640fea1235fcff2da1f57`. A nineteenth Phase 3D storage
slice added internal bounded SQLite projection-drift repair over complete
projection-key validation on branch `provenance-session-tree-storage`, at commit
`ad94a60bdb8792b4266705579997e9a1f77a25e2`. A twentieth Phase 3D storage
slice added an internal bounded SQLite storage integrity report on branch
`provenance-session-tree-storage`, at commit
`c970310d3852f22dd6b205510967f609a158b3e0`. A twenty-first Phase 3D storage
slice added an internal bounded SQLite storage-integrity repair wrapper that
gates projection repair through the existing integrity report on branch
`provenance-session-tree-storage`, at commit
`1d3bd06aac0fd7e9f63ed18d6b2192a6a75492d9`. A twenty-second Phase 3D storage
slice added internal bounded SQLite storage-repair attempt metadata and bounded
newest-first repair-attempt reads on branch `provenance-session-tree-storage`,
at commit `fb1eda21b5303a9cffdbbbe9696eca25daf9010f`. A twenty-third Phase 3D
storage slice added internal bounded SQLite schema-migration metadata and
bounded newest-first schema-migration reads on branch
`provenance-session-tree-storage`, at commit
`b0cc65f42065b5d8e0ac3be3c45a22ce0d4013d5`. ADR-001 Phase 3D is now closed
for planned internal storage lift work. It covers SQLite connection, statement,
and error support; schema migrations and migration metadata; default storage
location resolution; event ledger append/read paths; projection-backed
contract reads and writes; normalized lifecycle recording; integrity validation
and repair; repair-attempt metadata; and schema-migration metadata. A Phase 4
prerequisite slice added public library product `ProvenanceEngineSDK` and
`ProvenanceEngineClientFactory` for SQLite-backed in-process
`any ProvenanceEngineClient` construction on branch
`provenance-session-tree-storage`, at commit
`b43146d634f7c11f8e14bf95da5418bef502b0de`. No daemon, storage path move,
schema move, data migration, bmux reconnect, retrieval layer, lifecycle policy,
UI, or broad observability expansion has been created. Full ADR-001 Phase 3 is
still not complete.

ADR-001 Phase 4 reconnect is now an active controlled migration tracked in
`docs/context-efficiency/provenance-engine-phase4-reconnect-plan.md` and
`docs/context-efficiency/integration/provenance-engine-adoption.md`. The first
external adapter path, `bmux provenance worktrees list`, is complete against
provenance-engine `0.1.0` at commit
`b73fd1639c1c81230e96215259fc796b517706f6`. The adopted path uses
`ProvenanceEngineClientFactory` plus
`ProvenanceEngineClient.worktrees(ProvenanceWorktreeListRequest(...))` while
preserving existing worktree-list JSON, text, and fallback behavior. Data
migration remains ADR-001 Phase 5. Legacy boundary clarification, the session-tree read migration, and the Slice D file-explanation read adoption are now accepted. Slice D consumes merged Provenance Engine revision `126afde36671f53a137953200e7883e6b4093ac3`; bmux PR 9 merged at `c1c5fce0eb7526d321dbed6c8a6f25f0d9aaf374` on 2026-07-24T21:54:46Z. Slice C and Slice D both accepted explicit GitHub Actions waivers because bmux PR-event CI and Activation performance workflows did not produce usable CI evidence and no failing logs existed. PR #14 later repaired the fork CI baseline enough for current PR jobs to materialize and receive runner assignment, while issue #8 remains open until new pull-request jobs reliably receive runners and complete with usable results.

The ADR-001 Phase 0 migration audit is complete in `docs/context-efficiency/provenance-engine-extraction-phase0-report.md`. The ADR-001 Phase 1 behavior characterization and minimum contract plan is complete in `docs/context-efficiency/provenance-engine-contracts-phase1-plan.md`. The first Phase 2 slice introduced internal protocol/request/response names for append, session-tree, and file-explanation behavior around the current store. The second Phase 2 slice introduced normalized subsession-lifecycle request/response/protocol names around the current lifecycle recorder. The third Phase 2 slice introduced a separate lifecycle-trace query contract around `ProvenanceObservabilityStore`. The fourth Phase 2 slice converted `bmux provenance sessions tree <session-id>` onto `ProvenanceEngineClient.sessionTree(...)` while preserving existing CLI JSON/text/no-database behavior. The fifth Phase 2 slice converted `bmux provenance explain <path>` onto `ProvenanceEngineClient.fileExplanation(...)` while preserving existing CLI JSON/text/no-database/no-worktree/no-file behavior. The sixth Phase 2 slice converted `bmux provenance worktrees list` onto `ProvenanceEngineClient.worktrees(...)` while preserving existing CLI JSON/text/no-database/empty-database behavior and newest-first ordering. The seventh Phase 2 slice converted `bmux provenance context current` onto `ProvenanceEngineClient.currentContext(...)` while preserving existing CLI JSON/text/no-database/no-worktree/empty-section behavior, section bounds, and ordering. No further ADR-001 Phase 2 authoritative provenance CLI conversion is currently identified; pause before starting daemon, further SDK expansion, storage/schema migration, retrieval, lifecycle-policy, UI, or observability expansion.

Observability is not a standalone late milestone. Each provenance milestone should add the relevant traceability, quality, feedback, evaluation, or shadow-comparison requirement while preserving store ownership: `WorkProvenance` is authoritative engineering history, `BmuxContextEfficiency` is read-only imported telemetry/evidence, and `ProvenanceObservability` is future operational and quality telemetry.

## Milestone 1: Discovery and Schemas

Status: completed.

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

Status: closed on 2026-07-17.

Implemented:

- `Packages/macOS/BmuxContextEfficiency`
- Streaming Codex rollout JSONL reader with byte offsets and incomplete-line carryover.
- Defensive rollout telemetry parser for token usage, compactions, tool calls, tool outputs, session metadata, and parser errors.
- SQLite store with schema version 1, import sources, cursors, parser errors, evidence-artifact references, thread projections, model calls, token telemetry, rollout events, tool calls, and tool outputs.
- Duplicate cumulative-token telemetry suppression by thread-local token fingerprint.
- Read-only thread inspection and day summary DTOs for future CLI/UI use.
- Package-local Swift Testing coverage for streaming, parser, duplicate suppression, cursor resume, parser-error recovery, and report reads.
- Workspace package grouping updated via `scripts/check-workspace-package-groups.py --write`.

Implemented by Phase 2 closure:

- Codex `state_N.sqlite` metadata reader.
- App/CLI target integration.
- `bmux context-efficiency ...` command surface.
- Default local storage path.
- Bounded JSON diagnostics and CLI regression coverage.

Still deferred:

- Markdown/CSV export formatting.
- Replacement or removal of the legacy `codex-token-audit` command.

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
- Fixture-based parser tests.
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

## Milestone 3: Command, Reference, and Subsession Lifecycle Attribution

Status: active. Command-attribution, work-item reference fact, command-category count, and repeated-command fact slices are implemented.

Goal:

Connect token/model-call telemetry to command activity and evidence artifacts.

Expected work:

- Index proxy `rawOutputRef` artifacts.
- Evaluate OSC 133 parsing for non-Codex terminal attribution.
- Link evidence-backed reference facts to future provenance work items or delegation inputs.
- Persist command execution candidates if derived reports prove insufficient.

Implemented slices:

- `95e1c0d9 Add context efficiency command attribution` added derived command execution candidates, deterministic command categories, exact tool-call/output links, temporal attribution, and bounded command JSON.
- Work-item reference fact slices added bounded reference records.
- Command-category count slices added count-only thread and day summary aggregates.
- `6279c8abd Add context efficiency repeated command facts` added repeated command, source-search, and file-reading facts.
- Phase B subsession lifecycle slices added WorkProvenance session relationship/external identity projections, then wired `AgentSubsessionLifecycleChange` into persisted `subsession_started` / `subsession_stopped` events through the existing registry lifecycle path.
- A working tree Phase B query-diagnostics slice adds bounded `bmux provenance sessions tree <session-id> --json` output over persisted session relationship and external identity projections; `bmux-cli` builds and the standalone Python CLI regression passes against the built binary.
- A working tree observability query-polish slice adds bounded filters to `bmux provenance traces lifecycle-ingestion`: `--run`, `--parent-session`, `--child-session`, and `--status`, plus JSON counts for resolved, unresolved, and conflicted identity-resolution attempts. This reads existing O1/O2 trace rows only and adds no new capture, schema, policy, or O3+ observability behavior.
- ADR-001 Phase 1 contract characterization added focused tests for event/projection transactionality, reopen/rebuild behavior, append-order replay, unknown event compatibility, and deterministic lifecycle identity/root/depth/timestamp behavior, plus the minimum contract plan for the future engine boundary.
- ADR-001 Phase 2 contract-interface slice added `ProvenanceEngineClient` plus append, session-tree, and file-explanation request/response DTOs over `WorkProvenanceStore`, with protocol-level tests.
- ADR-001 Phase 2 lifecycle-contract slice added normalized subsession-lifecycle request/response/protocol names over `WorkProvenanceSubsessionLifecycleRecorder`, preserving `AgentSubsessionLifecycleChange` as a bmux adapter input.
- ADR-001 Phase 2 lifecycle-trace contract slice added `ProvenanceLifecycleTraceQuerying`.
- ADR-001 Phase 2 worktree-list contract conversion added `ProvenanceWorktreeListRequest`, `ProvenanceWorktreeListEntry`, and `ProvenanceWorktreeListResponse`, then moved `bmux provenance worktrees list` onto `ProvenanceEngineClient.worktrees(...)` while preserving existing CLI output and fallback behavior.
- ADR-001 Phase 2 current-context contract conversion added current-context request/response and bounded row DTOs, then moved `bmux provenance context current` onto `ProvenanceEngineClient.currentContext(...)` while preserving existing CLI output, fallback behavior, section caps, and ordering.
- ADR-001 Phase 3A decision work resolved the independent engine scaffold gate:
  local path `/Users/brianbusby/repos/provenance-engine`, GitHub repository
  `BrianBusby/provenance-engine`, remote URL
  `git@github.com:BrianBusby/provenance-engine.git`, Swift 6 with Swift Package
  Manager, package `ProvenanceEngine`, initial module
  `ProvenanceEngineContracts`, in-process SDK first, new-data storage default
  `~/.local/state/provenance-engine/provenance.sqlite`, and no initial
  observability in the authoritative skeleton.
- ADR-001 Phase 3B created the local independent skeleton at
  `/Users/brianbusby/repos/provenance-engine` with package `ProvenanceEngine`
  and module/product `ProvenanceEngineContracts`.
- ADR-001 Phase 3B remote unblock created GitHub repository
  `BrianBusby/provenance-engine`, set the local engine repo's `origin` to
  `git@github.com:BrianBusby/provenance-engine.git`, and pushed local commit
  `9e8fa620ccd04040968e0afab591feb48c8c11d0` to `origin/main`.
- ADR-001 Phase 3C lifted the initial in-process public contract surface into
  `ProvenanceEngineContracts` at commit
  `0b2529170ef4b0d67f8050f89786d439bbab6d27`.
- ADR-001 Phase 3D initial storage support added internal
  `ProvenanceEngineSQLite` connection, statement, and error support at commit
  `ec8b84bc2f8ac7e98c0e22cac67bf6895e7882ac`, without exporting it as a public
  library product and without changing bmux behavior.
- ADR-001 Phase 3D schema migration scaffolding added internal ordered
  `PRAGMA user_version` migration support at commit
  `9f7333799ef4f036b06b580fcbac3cde9398b306`, still without exporting a public
  storage product and without changing bmux behavior.
- ADR-001 Phase 3D repository skeleton added internal
  `ProvenanceSQLiteRepository` open-and-migrate support at commit
  `dfd57a6441d5090130476893502c3091d2769440`, still without exporting a public
  storage product and without changing bmux behavior.
- ADR-001 Phase 3D event-ledger storage added the first internal
  repository-owned `provenance_events` table plus narrow `ProvenanceEvent`
  append/read support at commit
  `f96858fb8f1a207426ad78c2524ab5b5c9b74121`, still without exporting a public
  storage product and without changing bmux behavior.
- ADR-001 Phase 3D session-projection storage added the first internal
  repository-owned `provenance_sessions` current-state projection table plus
  narrow `ProvenanceSessionRecord` read support at commit
  `ad1eec1dd7a0cabd3e78943ff798f21ee7665fa2`, still without exporting a public
  storage product and without changing bmux behavior.
- ADR-001 Phase 3D worktree projection query storage added internal repository
  and worktree projection tables, projection upserts during event append, and a
  bounded `ProvenanceWorktreeListResponse` read model at commit
  `fe1a4c5712eefc7ab2e2e3b271d0dc1e91a442e1`, still without exporting a public
  storage product and without changing bmux behavior.
- ADR-001 Phase 3D session-tree projection storage added internal
  `provenance_session_relationships` and
  `provenance_session_external_identities` tables, event-payload projection
  upserts, and bounded session-tree/parent/child/external-identity reads at
  commit `aff90f9c28b9a66bbb7014918c9e23338d706c6b` on branch
  `provenance-session-tree-storage`, still without exporting a public storage
  product and without changing bmux behavior.
- ADR-001 Phase 3D file-explanation projection storage added internal
  work-item, contribution, checkpoint, change-set, and file-change projection
  tables, event-payload projection upserts, and a focused file-explanation read
  at commit `1032a752db589e670917b56b5bbbefe6442843bd` on branch
  `provenance-session-tree-storage`, still without exporting a public storage
  product and without changing bmux behavior.
- ADR-001 Phase 3D current-context projection storage added internal
  validation-run projection storage, event-payload projection upserts, and a
  bounded current-context read model over existing storage contracts at commit
  `09628cf4e1ffc0a055dd683cdad5f8da1341a0e2` on branch
  `provenance-session-tree-storage`, still without exporting a public storage
  product and without changing bmux behavior.
- ADR-001 Phase 3D autoreview follow-up bounded session-tree traversal for
  missing-root and exhausted-limit cases at commit
  `bc86510426aba51afd4ed3f1e0fe509ae77f5ec7` on branch
  `provenance-session-tree-storage`, still without exporting a public storage
  product and without changing bmux behavior.
- ADR-001 Phase 3D event-ledger cursor storage added internal append-order
  `ProvenanceEventLedgerEntry` reads over the existing `provenance_events`
  table at commit `4ff1837e40a9dd2c0ad6a9552260cf3afaa9c7d9` on branch
  `provenance-session-tree-storage`, still without exporting a public storage
  product and without changing bmux behavior.
- ADR-001 Phase 3D projection-rebuild storage added internal current-state
  projection rebuild by bounded-batch replay of the immutable event ledger at
  commit `d18d5596c3e0bd4e8e9ffd7680dd6bc6139fc2bb` on branch
  `provenance-session-tree-storage`, still without exporting a public storage
  product and without changing bmux behavior.
- ADR-001 Phase 3D ledger-validation storage added an internal bounded
  event-ledger validation read model at commit
  `c9078e6eb904d27a1da48db7a5b518aad6c8ab1e` on branch
  `provenance-session-tree-storage`, still without exporting a public storage
  product and without changing bmux behavior.
- ADR-001 Phase 3D projection-count validation storage added an internal
  bounded projection-count validation read model at commit
  `303225390707775863e63821ec50eaf036e3d615` on branch
  `provenance-session-tree-storage`, still without exporting a public storage
  product and without changing bmux behavior.
- ADR-001 Phase 3D projection-key validation storage added an internal bounded
  projection-key validation read model at commit
  `bab8f18abbc79300f52640fea1235fcff2da1f57` on branch
  `provenance-session-tree-storage`, still without exporting a public storage
  product and without changing bmux behavior.
- ADR-001 Phase 3D projection repair storage added an internal bounded
  projection-drift repair path over complete projection-key validation at commit
  `ad94a60bdb8792b4266705579997e9a1f77a25e2` on branch
  `provenance-session-tree-storage`, still without exporting a public storage
  product and without changing bmux behavior.
- ADR-001 Phase 3D storage-integrity reporting added an internal bounded
  storage integrity report that composes summary, ledger validation,
  projection-count validation, projection-key validation, and repair guidance
  at commit `c970310d3852f22dd6b205510967f609a158b3e0` on branch
  `provenance-session-tree-storage`, still without exporting a public storage
  product and without changing bmux behavior.
- ADR-001 Phase 3D is closed for planned internal engine-owned SQLite storage
  lift work. Continue Phase 3D only for concrete review or CI fixes, not
  speculative storage expansion.
- Phase 2, Phase 3A, Phase 3B, Phase 3C, and the Phase 3D storage slices have not
  created a daemon, moved storage/schema, added data migration, or added
  daemon/SDK packaging. Four
  read-only authoritative provenance CLI paths
  now consume in-process `ProvenanceEngineClient` contracts instead of their
  direct SQLite reader paths: `bmux provenance sessions tree` uses
  `sessionTree(...)`, `bmux provenance explain` uses `fileExplanation(...)`,
  `bmux provenance worktrees list` uses `worktrees(...)`, and `bmux provenance
  context current` uses `currentContext(...)`.
- ADR-001 Phase 4 reconnect may start only after a scoped reconnect plan names
  the first bmux adapter path to replace, the engine commit or package version
  to consume, the public SDK or API surface for that path, parity coverage for
  existing bmux JSON/text/fallback behavior, and rollback or graceful
  degradation behavior if the engine dependency is unavailable. Data migration
  remains Phase 5 work.

Stop condition:

- Reports must label attribution confidence and distinguish exact tool-call links from temporal candidates.

Subsession/delegation integration:

- `docs/context-efficiency/subsession-delegation-integration-plan.md` is authoritative for this subtrack.
- Phase A is complete in `docs/context-efficiency/subsession-delegation-phase-a-report.md`.
- Phase B store foundation is implemented at `b875eb837 Add provenance session relationship projections`.
- Phase B lifecycle adapter/runtime wiring is implemented; bounded read-only session-tree diagnostics/query coverage is implemented and validated against a rebuilt `bmux-cli`.
- Use `AgentSubsessionLifecycleChange` as the first authoritative lifecycle source.
- `BmuxContextEfficiency` remains read-only telemetry; delegation semantics belong in `WorkProvenance`.

Observability integration:

- Phase O0 architecture investigation is complete in `docs/context-efficiency/provenance-observability-phase-o0-report.md`.
- The first O1 implementation slice traces only `AgentSubsessionLifecycleChange -> WorkProvenance event append -> projection update`.
- The working tree O1 slice adds a separate `ProvenanceObservability.sqlite` store with pipeline run and stage execution records for that lifecycle-ingestion path only.
- O1 observability covers lifecycle ingestion traces, stage duration, bounded failures, and correlation IDs only.
- `6ceb48ccafc698f1ee16984455f26e18c81efe7a` implements the first O2 identity-resolution observability slice for the lifecycle-ingestion path only.
- O2 lifecycle identity records explain bounded native/fallback resolution inputs, selected identity kind/value category, hashed input identity value, confidence, unresolved/fallback state, conflict reason, and correlation to the O1 pipeline run.
- Lifecycle-ingestion trace CLI/query filters are implemented for run ID, parent session, child session, and status; this is read-only query polish over existing trace rows, not a new observability phase.
- `114df3b18 Add lifecycle projection lineage traces` implements the first narrow O3 projection-lineage slice for lifecycle-ingestion projections only.
- O3 lifecycle projection-lineage records explain which authoritative projection rows were derived from a lifecycle event payload, with hashed source payloads and bounded target entity metadata.
- Later O2 attribution explainability and broader O3+ projection/retrieval/feedback/evaluation/UI work remain deferred.
- Observability writes must not block lifecycle event append or projection updates.

## Milestone 4: Efficiency Profiler

Goal:

Compute per-call, per-thread, per-command, and per-work-item metrics from stored facts.

Expected work:

- Cached/new/output totals where available.
- Context utilization and call deltas.
- Compaction effectiveness signals.
- Use repeated command/search/file-read facts in configurable profiler signals.
- Low-information/high-context heuristic signals.
- Possible-loop signal windows.

Rules:

- Heuristics are configurable and versioned.
- High token usage alone must not label a thread stuck.
- Reports show measurements and conditions, not opaque scores.

Observability integration:

- Add telemetry quality and import observability for parser errors, import lag, skipped/dropped events, duplicate suppression, cursor progress, degraded imports, and database lock duration.
- Keep coverage measurements separate from correctness measurements.
- Version profiler signals and report which conditions fired.

## Milestone 5: Project Progress, Delegation, and Semantic Provenance

Superseding engine roadmap:

- `docs/context-efficiency/provenance-engine-semantic-roadmap.md`

Goal:

Integrate useful-work evidence with cost evidence.

For standalone engine work, treat this milestone as split into Phase 5
normalized provenance and Phase 6 structured decisions/project knowledge. Do
not start semantic model calls or context-pack generation from this milestone.

Expected work:

- Decide package/store ownership for `WorkProvenance`.
- Link threads/model calls/commands to worktrees and contributions.
- Add first-class delegation contracts, reconciliation, child completion reports, parent disposition, and contribution links after lifecycle persistence is proven.
- Add first-class semantic records needed by retrieval, including decisions, findings, artifacts, and commits, without treating model-generated summaries as authoritative truth.
- Track decisions, discoveries, failed approaches, invariants, open questions, validations, and milestones.
- Update state incrementally from bounded event batches.

Risk:

- Model-derived summaries can be useful but must remain marked inferred.

Observability integration:

- Add identity and attribution explainability for external thread/session links, child-parent links, command/session links, file/contribution links, validation/contribution links, and commit/contribution links.
- Add derivation records for semantic records, including evidence references, rules applied, generator versions, confidence components, and input/output hashes.
- Support explicit feedback and corrections without silently rewriting authoritative provenance.

## Milestone 5.5: Agent Retrieval and Knowledge Projection

Authoritative plan:

- `docs/context-efficiency/provenance-engine-semantic-roadmap.md`
- `docs/context-efficiency/agent-retrieval-knowledge-projection-plan.md`

Goal:

Build a derived, rebuildable, evidence-linked retrieval layer that can assemble the smallest reliable context package needed for a future agent objective.

For standalone engine work, this maps to Phase 8 agent context retrieval and
depends on Phase 5 normalized provenance, Phase 6 structured decisions/project
knowledge, and Phase 7 semantic processing. The older bmux retrieval plan
remains useful for implementation tactics and evaluation criteria, but the
engine owns the durable semantic model and context-pack API.

Expected work:

- Phase R0 investigation report before code changes.
- Decision and finding semantic records with evidence references, source, confidence, freshness, and supersession.
- Typed provenance edges where retrieval requires richer traversal than existing foreign keys.
- Knowledge records for repository, subsystem, work item, contribution, session, delegation, file, decision, finding, validation, commit, and handoff summaries.
- SQLite FTS5 lexical retrieval with repository/worktree/work-item/kind/freshness/confidence filters.
- Deterministic retrieval ranking and token-budgeted context package assembly.
- Retrieval evaluation fixtures for required-record recall, stale/superseded leakage, omitted counts, source-reference coverage, determinism, and latency.
- After retrieval quality is validated, active session/task registry reads,
  cross-session query APIs, and passive conflict detection backed by structured
  evidence instead of transcripts.

Rules:

- Retrieval records are derived and rebuildable; they never replace provenance facts.
- Retrieval must work without semantic embeddings.
- Do not index raw rollout or terminal output into the primary retrieval surface.
- Do not start context-package generation before semantic records, edges, and lexical retrieval are proven.
- Do not add UI, automatic prompt injection, autonomous orchestration, or assisted handoff behavior in this milestone.
- Do not build a bmux-owned parallel active-work store; bmux should query the
  Provenance Engine and present bounded evidence.

Observability integration:

- Add projection-run, derivation, invalidation, retrieval-run, and retrieval-candidate traces.
- Retrieval traces must explain selected and omitted records with ranking components, freshness/supersession/confidence filtering, token-budget omissions, and source references.
- Evaluation fixtures must measure required-record recall, irrelevant/misleading/stale/superseded leakage, token-budget compliance, source-reference coverage, determinism, and latency.

## Milestone 6: Coordination UI

Goal:

Expose fleet, active-work, conflict, thread-detail, work-item, and
handoff-preview views without crowding the terminal workspace.

Expected work:

- Decide whether the first UI surface is Feed, Session Index detail, custom sidebar, or a new coordination window.
- Display active sessions, active tasks, heartbeat freshness, related work, and
  passive conflict warnings from engine query results.
- Add token timelines and command/evidence drilldown.
- Add explanation UI for passive lifecycle signals.
- Link to raw evidence recovery.

Rules:

- UI warnings must show underlying measurements.
- No automatic interruption.
- bmux owns presentation and workflow only; conflict detection and active-work
  knowledge remain engine-owned.

Observability integration:

- Add UI only after CLI/evaluation quality exists.
- Initial views should show pipeline health, trace exploration, and quality metrics separately for coverage, accuracy, calibration, freshness, retrieval quality, feedback, shadow comparisons, and evaluation regressions.
- Do not present a single opaque provenance quality score as the primary result.

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

Observability integration:

- Add active-versus-candidate shadow comparisons for meaningful algorithm changes.
- Begin with one subsystem, preferably file attribution or retrieval ranking.
- Promotion criteria must be explicit and based on precision, recall, unresolved rate, calibration, fixture regressions, and reviewed disagreements where applicable.

## Milestone 8: Assisted Handoffs and Context Packages

Goal:

Generate bounded structured handoff packages and measure post-handoff outcomes.

Expected work:

- Handoff schema and priority rules.
- Handoff preview/edit UI.
- Retrieval-backed bounded context packages.
- Worktree/path/commit validation.
- New thread launch preparation.
- Post-handoff rediscovery metrics.

Rules:

- User approves transition.
- Raw artifacts remain referenced and recoverable.

Observability integration:

- Add context-package consumption records, supplied-record references, explicit and inferred usage signals, repeated-search detection, missing-context requests, parent feedback, and associated downstream outcome correlations.
- Do not report weak inference as confirmed usage.
- Do not claim causal productivity improvements without controlled comparison.

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

- Whether and when to move `WorkProvenance` out of the app target into a package.
- CLI naming for future provenance/delegation query commands.
- Whether context-efficiency and provenance should ever merge stores after the initial separate-database phase.
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
