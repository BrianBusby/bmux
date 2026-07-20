# Bmux Provenance Project State and Integration Handoff

## 1. Executive Summary

- [planned] The provenance system is intended to make bmux a local, evidence-backed profiler and lifecycle manager for long-running agent work. It should explain what work happened, where it happened, what evidence supports it, how much context/token cost it carried, and when a structured handoff would be cheaper and safer.
- [implemented] Two related implementations exist:
  - `WorkProvenance` in `/Users/brianbusby/repos/bmux/Sources/WorkProvenance`: an app-target SQLite event/projection store for observed Git worktree state and dirty-file provenance.
  - `BmuxContextEfficiency` in `/Users/brianbusby/repos/bmux/Packages/macOS/BmuxContextEfficiency`: a package-backed Codex rollout/state importer and report layer for token telemetry, tool-call/tool-output facts, parser diagnostics, and JSON CLI diagnostics.
- [implemented in separate worktree] The freshest context-efficiency branch at `/private/tmp/context-efficiency-wip-20260715` is at `57244d6b1` and documents Phase 3 as active. Commit `95e1c0d9f Add context efficiency command attribution` adds derived command execution candidates from rollout tool facts.
- [partially implemented] Work provenance has schemas for sessions, work items, contributions, checkpoints, validation runs, change sets, and file changes, but the live observer currently records only repository/worktree/change-set/file-change facts from Git status snapshots.
- [partially implemented] Token telemetry is persistent in the `BmuxContextEfficiency` SQLite store. It is not yet merged into `WorkProvenance`; the two stores are separate.
- [in progress] The context-efficiency worktree has uncommitted work-item reference extraction files and a schema v2 draft for `work_item_references`. Treat that as active local WIP, not committed architecture.
- [not started] No lifecycle warnings, handoff recommendations, intervention policy engine, dedicated provenance UI, output filtering, live PTY command interception, or automatic context mutation is implemented.
- [next planned milestone] Phase 3 continues with read-only command/output attribution: aggregate command categories, repeated command/search/file-read facts, PR/ticket/work-item references, and possibly OSC 133 evaluation. Subsession/delegation provenance should integrate at this boundary, before lifecycle policy and handoff automation.

## 2. Product Intent

- [planned] The product intent is to let users and agents answer: “What happened in this work?”, “Which session did it?”, “Which files/commits/tests are tied to it?”, “What evidence supports that?”, and “Can a new thread resume this safely?”
- [planned] Main problems: long Codex threads carry huge cached contexts; agents rediscover prior work; concurrent sessions can duplicate or conflict; raw terminal/tool output can be too large for context but must remain recoverable.
- [planned] Intended users: the bmux user supervising multiple local agent sessions; agent threads that need compact historical context; future planning/coordinator agents that need evidence-backed state.
- [planned] Codex relationship: a logical Codex thread should be independent from a terminal tab. Codex `state_N.sqlite` and rollout JSONL provide authoritative/imported telemetry and metadata. bmux surface/workspace IDs are references for UI binding, not logical thread identity.
- [implemented] Repository/worktree/file relationship: `WorkProvenanceGitInspector` observes Git repository root, common dir, remote slug, branch, HEAD, dirty flag, and porcelain status entries. `WorkProvenanceObservationService` stores observed dirty files as unattributed low-confidence file changes.
- [planned] Task/work-item relationship: `WorkProvenanceWorkItemRecord` and `WorkProvenanceContributionRecord` exist, but no live task assignment pipeline populates them yet. The context-efficiency WIP branch is beginning evidence-backed PR/ticket/branch/reference extraction.
- [planned] Separate provenance/work-management window: Roadmap Milestone 6 calls for a coordination UI with fleet/thread/work-item/handoff-preview views. No dedicated window exists today. Existing candidate surfaces are Feed, Session Index, custom/sidebar surfaces, or a new coordination window.
- [planned] Expected historical use: search historical Codex sessions; find work by file, worktree, branch, PR, ticket, command category, or token pressure; drill from summary to source path/line/byte offset or raw-output reference; generate bounded handoff packages with links to recoverable evidence.

## 3. Current Architecture

| Component | Path | Responsibility | Dependencies | Status |
| --- | --- | --- | --- | --- |
| `WorkProvenanceStore` | `/Users/brianbusby/repos/bmux/Sources/WorkProvenance/WorkProvenanceStore.swift` | Actor-owned SQLite event ledger and projection store. | `WorkProvenanceSQLiteDatabase`, JSON encoder/decoder. | [implemented, partial domain coverage] |
| `WorkProvenanceRuntime` | `/Users/brianbusby/repos/bmux/Sources/WorkProvenance/WorkProvenanceRuntime.swift` | App composition wrapper that starts observe-only workspace provenance. | `TabManager`, `WorkProvenanceObservationService`. | [implemented] |
| `WorkProvenanceObservationService` | `/Users/brianbusby/repos/bmux/Sources/WorkProvenance/WorkProvenanceObservationService.swift` | Observes workspace snapshots and appends Git worktree observations when fingerprint changes. | `WorkProvenanceStore`, `WorkProvenanceGitInspecting`. | [implemented] |
| `WorkProvenanceGitInspector` | `/Users/brianbusby/repos/bmux/Sources/WorkProvenance/WorkProvenanceGitInspector.swift` | Runs Git probes and converts porcelain status to provenance snapshots. | `BmuxGit`, `/usr/bin/git` through runner. | [implemented] |
| `WorkProvenance*Record` types | `/Users/brianbusby/repos/bmux/Sources/WorkProvenance` | Repository, worktree, session, work item, contribution, checkpoint, change set, file change, validation projections. | Foundation. | [implemented as internal app-target types] |
| `bmux provenance ...` CLI | `/Users/brianbusby/repos/bmux/CLI/BMUXCLI+Provenance.swift` | Read-only CLI queries: explain file, current context, worktree list. | `CLIProvenanceSQLiteReader`, Git resolver. | [implemented] |
| `CLIProvenanceSQLiteReader` | `/Users/brianbusby/repos/bmux/CLI/CLIProvenanceSQLiteReader.swift` | Direct read-only SQLite queries over work-provenance DB. | SQLite3. | [implemented] |
| `BmuxContextEfficiency` package | `/Users/brianbusby/repos/bmux/Packages/macOS/BmuxContextEfficiency/Package.swift` | Swift package for Codex telemetry import, storage, reports. | Foundation, SQLite3. | [implemented] |
| `ContextEfficiencyStore` | `/Users/brianbusby/repos/bmux/Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Store/ContextEfficiencyStore.swift` | Incremental rollout import, dedupe, source refs, thread inspection, day summary. | SQLite wrapper, parser, stable ID factory. | [implemented] |
| `ContextEfficiencySQLiteMigration` | `/Users/brianbusby/repos/bmux/Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Store/ContextEfficiencySQLiteMigration.swift` | Context-efficiency schema v1. | SQLite wrapper. | [implemented; v2 WIP exists in other worktree] |
| `CodexRolloutTelemetryParser` | `/Users/brianbusby/repos/bmux/Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Import/CodexRolloutTelemetryParser.swift` | Defensive parser for Codex rollout JSONL lines. | `CodexTokenUsageExtractor`, command summary helper. | [implemented] |
| `CodexStateMetadataReader` | `/Users/brianbusby/repos/bmux/Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/CodexState/CodexStateMetadataReader.swift` | Reads Codex state DB from snapshot copy. | `CodexStateSQLiteReader`. | [implemented] |
| `bmux context-efficiency ...` CLI | `/Users/brianbusby/repos/bmux/CLI/BMUXCLI+ContextEfficiency.swift` | Import, inspect-thread, summarize-day JSON/text diagnostics. | `BmuxContextEfficiency`. | [implemented] |
| `ContextEfficiencyCommandAttributor` | `/private/tmp/context-efficiency-wip-20260715/.../Reports/ContextEfficiencyCommandAttributor.swift` | Derives command execution candidates from tool facts. | Tool-call/output/model-call records. | [implemented in context branch, not current main checkout] |
| `ContextEfficiencyWorkItemReferenceExtractor` | `/private/tmp/context-efficiency-wip-20260715/.../Reports/ContextEfficiencyWorkItemReferenceExtractor.swift` | Extracts PR/ticket/branch/repo references. | Rollout/metadata strings. | [in progress, uncommitted] |
| `SessionIndexStore+CodexSQL` | `/Users/brianbusby/repos/bmux/Sources/SessionIndexStore+CodexSQL.swift` | Historical Codex session search from Codex state DB plus rollout content. | SQLite3, ripgrep/file scan. | [implemented, separate from provenance store] |
| Raw output store | `/Users/brianbusby/repos/bmux/Packages/Shared/BmuxAgentChat/Sources/BmuxAgentChat/Store/ChatRawTerminalOutputFileStore.swift` | Stores complete raw terminal outputs by `rawOutputRef`. | Filesystem JSON. | [implemented] |
| Output optimizer | `/Users/brianbusby/repos/bmux/Packages/Shared/BmuxAgentChat/Sources/BmuxAgentChat/Parsing/TokenOptimizationLayer.swift` | Produces optimized output plus raw-output side-channel record. | `CommandOutputOptimizer`. | [implemented, separate from provenance] |
| OSC 133 parser | `/Users/brianbusby/repos/bmux/Packages/Shared/BmuxAgentChat/Sources/BmuxAgentChat/Parsing/OSC133CommandParser.swift` | Segments PTY stream into command blocks. | Terminal escape parsing. | [implemented, not integrated into provenance] |
| Dedicated provenance UI | N/A | Fleet/thread/work-item/handoff UI. | TBD. | [planned] |
| Lifecycle policy engine | N/A | Shadow warnings, handoff recommendations. | Telemetry/provenance facts. | [not started] |

Coverage notes: session discovery/identity exists in `AgentChatSessionRegistry`, `SessionIndexStore`, Codex state readers, and hook/process observation. Workspace/worktree identity exists in `Workspace`, `TabManager`, session snapshots, and `WorkProvenanceStableIDFactory`. Command capture exists only as Codex rollout tool-call/tool-output facts and derived candidates in the Phase 3 context worktree. File-change capture exists from Git status, not from per-command file write attribution. Commit capture records current HEAD in worktree snapshots; no commit table or commit-to-session attribution exists. Token telemetry exists in `BmuxContextEfficiency`, not `WorkProvenance`.

## 4. Data Model

### Implemented WorkProvenance Schema

[implemented] `WorkProvenanceStore` schema version is `2`, stored via `PRAGMA user_version = 2`.

| Entity/table | Purpose | Primary key | Key fields | Foreign keys by convention | Indexes | Source of truth |
| --- | --- | --- | --- | --- | --- | --- |
| `events` | Immutable provenance ledger. | `id` | `schema_version`, `event_type`, `timestamp`, `repository_id`, `worktree_id`, `session_id`, `contribution_id`, `source`, `confidence`, `payload_json` | repository/worktree/session/contribution IDs | `events_worktree_idx`, `events_contribution_idx`, `events_type_timestamp_idx`, `events_worktree_type_timestamp_idx` | SQLite event table |
| `repositories` | Current repository projection. | `id` | `path`, `common_directory`, `remote_slug`, timestamps | none | none | Projection from events |
| `worktrees` | Current worktree projection. | `id` | `repository_id`, `path`, `branch`, `base_commit`, `current_head`, `is_dirty`, `status` | `repository_id` | none | Projection from Git observations/events |
| `sessions` | Current agent session projection. | `id` | `agent_kind`, `workspace_id`, `surface_id`, `worktree_id`, `cwd`, `status` | `worktree_id` | none | Planned event payloads; not live-populated by observer |
| `work_items` | Durable work item projection. | `id` | `title`, `status`, timestamps | none | none | Planned/declared events |
| `work_contributions` | Session contribution to work item. | `id` | `session_id`, `worktree_id`, `work_item_id`, `declared_intent`, `expected_scope_json`, `status`, `assignment_confidence` | session/worktree/work_item IDs | none | Planned/declared events |
| `checkpoints` | Contribution progress checkpoint. | `id` | `contribution_id`, `sequence`, `git_head`, `diff_fingerprint`, `summary`, `status`, `validation_state`, `semantic_confidence`, `freshness` | `contribution_id` | none | Planned/declared events |
| `change_sets` | Coherent file-change batch. | `id` | `checkpoint_id`, `contribution_id`, `worktree_id`, `summary`, `diff_fingerprint` | checkpoint/contribution/worktree IDs | `change_sets_worktree_created_idx` | Git observation or checkpoint event |
| `file_changes` | File-level current provenance. | `id` | `change_set_id`, `repository_id`, `worktree_id`, `path`, `status`, `before_hash`, `after_hash`, `attribution_source`, `attribution_confidence` | change_set/repository/worktree IDs | `file_changes_worktree_path_idx`, `file_changes_source_updated_idx` | Projection from Git/status events |
| `validation_runs` | Validation command/check result. | `id` | `checkpoint_id`, `contribution_id`, `command`, `status`, `summary`, times | checkpoint/contribution IDs | none | Planned event payloads |

Representative type names: `WorkProvenanceEvent`, `WorkProvenanceEventPayload`, `WorkProvenanceRepositoryRecord`, `WorkProvenanceWorktreeRecord`, `WorkProvenanceSessionRecord`, `WorkProvenanceWorkItemRecord`, `WorkProvenanceContributionRecord`, `WorkProvenanceCheckpointRecord`, `WorkProvenanceChangeSetRecord`, `WorkProvenanceFileChangeRecord`, `WorkProvenanceValidationRunRecord`.

Status values are stringly typed in code. Documented examples include `active`, `paused`, `completed`, `missing`, `interrupted`, `proposed`, `superseded`, `in_progress`, `passed`, `failed`, `stale`, `fresh`.

### Implemented ContextEfficiency Schema

[implemented] `ContextEfficiencySQLiteMigration` schema v1 tables: `schema_migrations`, `import_sources`, `import_cursors`, `evidence_artifacts`, `agent_threads`, `rollout_events`, `parser_errors`, `token_telemetry_events`, `model_calls`, `tool_calls`, and `tool_outputs`.

[implemented in context branch] Phase 3 derives `ContextEfficiencyCommandExecutionRecord` in reports but does not persist a `command_executions` table.

[in progress in context branch] Schema v2 draft adds `work_item_references` with fields: `id`, `thread_id`, `kind`, `reference`, `repository_slug`, `number`, `url_string`, `branch_name`, `ticket_key`, `source_kind`, `confidence`, source path/offset/line/parser, `observed_at`, `imported_at`.

Relationships:

```text
[implemented] WorkProvenance:
repository 1 -> many worktrees
worktree 1 -> many sessions
worktree 1 -> many change_sets
change_set 1 -> many file_changes
session 1 -> many work_contributions
work_item 1 -> many work_contributions
contribution 1 -> many checkpoints
checkpoint/contribution -> validation_runs

[implemented] ContextEfficiency:
agent_thread 1 -> many rollout_events
agent_thread 1 -> many token_telemetry_events
agent_thread 1 -> many model_calls
agent_thread 1 -> many tool_calls
agent_thread 1 -> many tool_outputs
import_source 1 -> one import_cursor
rollout/tool/model facts -> source path + byte offset + line number

[planned] Unified model:
workspace -> terminal session(s) -> agent thread(s)
repository -> worktree(s) -> contributions
contribution -> files, commits, commands, validations, decisions, summaries
handoff links source agent thread -> destination agent thread
```

Missing concepts: no first-class commit entity/table; no decision/discovery/failed-approach/invariant/open-question tables; no terminal session table in either concrete SQLite schema; no persisted model-call-to-work-contribution relationship; no durable handoff entity; no subsession/delegation entity.

## 5. Session and Worktree Organization

- [implemented] Agent session identity exists in `AgentChatSessionRegistry` as `AgentChatSessionRecord.sessionID`, with agent kind, workspace ID, surface ID, working directory, transcript path, PID, state, and activity timestamps.
- [implemented] Codex historical session identity exists in Codex `threads.id` and rollout paths. `ContextEfficiencyStableIDFactory` normalizes thread IDs as `codex:<external-id>`.
- [implemented] Worktree identity in `WorkProvenanceStableIDFactory.worktreeID(repositoryRoot:)` is a SHA-256-based stable ID over normalized repository root path.
- [implemented] Repository identity is similarly path-derived by `repositoryID(repositoryRoot:)`.
- [partial] Sessions are associated with worktrees only if a `WorkProvenanceSessionRecord` event exists. The live Git observer does not currently populate sessions or contributions.
- [implemented] Concurrent dirty worktrees are represented as separate `worktrees` rows keyed by root path. Concurrent sessions are representable in the schema but not populated by current observer.
- [partial] Separate sessions’ changes are distinguishable only when attributed events include session/contribution IDs. Current observed dirty file changes are `unattributed`/low confidence.
- [unknown] A session moving between worktrees is representable by updating `sessions.worktree_id`, but no concrete reconciliation behavior was found.
- [partial] Branch changes update the worktree projection on the next Git snapshot. Rebases/squashes update `current_head`; no commit lineage history is preserved except through event snapshots.
- [partial] Deleted/missing worktrees are representable via `status = "missing"` but no observer was found that marks missing worktrees.
- [known ambiguity] Dirty-file observation can say “this worktree has this dirty path,” not “this session wrote this path.” Attribution requires future command/file write/contribution evidence.

## 6. Event and Capture Pipeline

Current WorkProvenance pipeline:

```text
Workspace list/current-directory change
-> WorkProvenanceWorkspaceSnapshot
-> WorkProvenanceGitInspector.snapshot()
-> WorkProvenanceObservationService fingerprint dedupe
-> WorkProvenanceEvent(event_type: worktree_observed)
-> WorkProvenanceStore.append()
-> projections: repositories/worktrees/change_sets/file_changes
-> CLIProvenanceSQLiteReader
-> bmux provenance explain/context/worktrees
```

Current ContextEfficiency pipeline:

```text
Codex state_N.sqlite
-> CodexStateMetadataReader snapshot copy
-> CodexStateThreadMetadata

Codex rollout JSONL
-> CodexRolloutJSONLStreamReader
-> CodexRolloutTelemetryParser
-> ContextEfficiencyStore transaction
-> import_sources/import_cursors/evidence_artifacts/agent_threads/model_calls/tool facts/errors
-> inspectThread/summarizeDay
-> bmux context-efficiency JSON/text output
```

Important properties: Git and Codex local files are the authoritative structured sources. Dirty-file attribution is heuristic/unattributed. Context importer preserves source byte offsets and line numbers. Duplicate cumulative telemetry is skipped by thread-local fingerprint. Imports resume from byte offsets and reset on source shrink. Parser version and SQLite schema version are persisted. Fragile assumptions include Codex rollout schema stability, available cached-token splits, and path-derived worktree identity.

## 7. Existing UI Plan and Implementation

- [implemented] No dedicated provenance UI exists.
- [implemented] Existing UI-adjacent surfaces: Session Index can search historical sessions; Feed exists but provenance/lifecycle signals are not wired there; sidebar metadata and work-context WIP exist on current dirty branch under `Packages/macOS/BmuxSidebar/Sources/BmuxSidebar/WorkContext`.
- [planned] Milestone 6 UI should expose fleet, thread detail, work item, and handoff preview.
- [planned] Expected views include token timelines, command/evidence drilldown, worktree/session relationships, raw evidence recovery, and passive lifecycle explanations.
- [not implemented] No tables, timelines, graph views, filters, or drill-down panels for provenance have been built beyond CLI reports and existing Session Index search.

## 8. Query and Retrieval Capabilities

| Capability | Existing symbol/path | Status |
| --- | --- | --- |
| Find provenance for a file | `WorkProvenanceStore.fileExplanation`, `bmux provenance explain <path>` | [implemented for file_changes; often unattributed] |
| Find sessions in a worktree | `CLIProvenanceSQLiteReader.activeSessionRows` | [partial; only useful if sessions populated] |
| List known worktrees | `bmux provenance worktrees list` | [implemented] |
| Find unfinished work | `CLIProvenanceSQLiteReader.context`, active sessions/contributions filters | [partial; data not live-populated except dirty files] |
| Find origin of a change | `CLIProvenanceSQLiteReader.explain` | [partial; source/confidence reported, but current observer says unattributed] |
| Retrieve session summaries | Session Index and agent transcript views | [partial; not provenance summaries] |
| Search historical Codex sessions | `SessionIndexStore+CodexSQL.loadCodexEntriesViaSQL` | [implemented outside provenance store] |
| Retrieve relevant past context for current agent | None | [planned] |
| Trace why a decision was made | No `DecisionRecord` table | [planned] |
| Compare token usage across sessions | `bmux codex-token-audit`; `bmux context-efficiency summarize-day`; `inspect-thread` | [implemented/partial] |
| Import Codex rollout telemetry | `ContextEfficiencyStore.importRollout` | [implemented] |
| Inspect one thread telemetry | `ContextEfficiencyStore.inspectThread`, `bmux context-efficiency inspect-thread` | [implemented] |
| Derive command executions | `ContextEfficiencyCommandAttributor` in context worktree | [implemented in context branch] |
| Extract PR/ticket references | `ContextEfficiencyWorkItemReferenceExtractor` in context worktree | [in progress] |

## 9. Token and Context Telemetry

- [implemented] Legacy analyzer: `/Users/brianbusby/repos/bmux/CLI/BMUXCLI+CodexTokenAudit.swift`. It reads Codex state DB thread rows and rollout files into memory, then reports totals, largest sessions, day/model/cwd totals, rough rollout/tool-output pressure, repeated commands, and raw-output refs. Covered by `/Users/brianbusby/repos/bmux/tests/test_codex_token_audit.py`. It is useful as a report prototype but not the durable importer.
- [implemented] Durable telemetry package: `BmuxContextEfficiency`. It reads Codex `state_N.sqlite` and rollout JSONL, stores exact cached/non-cached/output fields when exposed, suppresses duplicate cumulative fingerprints, imports compaction events, normalizes thread IDs as `codex:<id>`, and exposes bounded JSON/text reports without raw rollout/tool output.
- [implemented in context branch] Command attribution adds derived `command_executions` to `inspect-thread --json`.
- [not implemented] Token data is not stored in `WorkProvenance`; it is stored in the separate context-efficiency SQLite DB.
- [planned] Integration with provenance should link model calls/commands/token pressure to worktrees, contributions, files, tests, artifacts, and decisions.

Relevant commands:

```bash
bmux context-efficiency import <rollout-path> [--database <path>] [--codex-home <path>] [--json]
bmux context-efficiency inspect-thread <thread-id> [--database <path>] [--json]
bmux context-efficiency summarize-day YYYY-MM-DD [--database <path>] [--json]
bmux codex-token-audit [--database <path>] [--codex-home <path>] [--json]
```

## 10. Previous Decisions

| Decision | Rationale | Alternatives | Status | Evidence |
| --- | --- | --- | --- | --- |
| Use local SQLite for telemetry/provenance facts. | Need migrations, indexes, durable local queries. | EventBus JSONL or session snapshots. | [locked for current slices] | `WorkProvenanceStore`, `ContextEfficiencyStore` |
| Keep raw evidence recoverable but out of hot/query rows. | Avoid context leakage and large SQLite rows. | Store raw rollout/tool output inline. | [locked] | `ContextEfficiencyStore`, `ChatRawTerminalOutputFileStore` |
| Observation before intervention. | Need trustworthy telemetry before warnings/handoffs. | Start with lifecycle automation. | [locked] | `docs/context-efficiency/roadmap.md` |
| Separate facts from inference. | Avoid overwriting user decisions with model guesses. | Store opaque scores/summaries as truth. | [locked] | `docs/context-efficiency/domain-model.md` |
| Build `BmuxContextEfficiency` as a package. | Testable parser/store without app compile surface. | Put importer in app target or WorkProvenance first. | [implemented] | `fee11f639`, package files |
| Keep `WorkProvenance` and context-efficiency stores separate for now. | Token tables differ from worktree projections; model still stabilizing. | One combined DB now. | [tentative] | `docs/context-efficiency/proposed-integration.md` |
| `codex-token-audit` stays legacy. | Avoid breaking existing report while new importer stabilizes. | Replace immediately. | [tentative] | context worktree `current-status.md` |
| Phase 3 begins with rollout tool facts, not live PTY capture. | Lower risk, read-only, already imported facts. | OSC 133/live terminal interception first. | [locked for next slice] | context worktree `current-status.md` |
| Dedicated coordination UI deferred. | Need data/policy first. | Build UI early. | [locked until Milestone 6] | `docs/context-efficiency/milestones.md` |
| PR/ticket detection should be evidence-backed references, not a single scalar. | Stacks/multiple related refs can occur. | Store one current PR number. | [tentative/in progress] | context worktree `current-status.md` and WIP files |

## 11. Open Questions and Risks

Architecture questions: should `WorkProvenance` move into a package, merge with `BmuxContextEfficiency`, or remain app-target-local; should there be one SQLite DB or linked DBs; what is the canonical `Session` entity once subsessions/delegations exist.

Codex integration questions: Codex rollout schemas may change; mapping among Codex thread ID, rollout filename UUID, hook session ID, app-server thread ID, and bmux surface ID is not fully settled; state DB reader handles schema variation but still assumes a `threads` table.

Attribution/reconciliation risks: dirty files are observed, not attributed; Phase 3 command attribution is candidate/exact by call ID or temporal order, not proof of causality; rebases/squashes/deleted worktrees need explicit reconciliation rules.

Schema risks: `WorkProvenance` uses string status values without closed enums; schema v2 `work_item_references` is uncommitted WIP and may change.

UI risks: coordination UI could become noisy without mature confidence/explanation signals; first surface choice remains unresolved.

Performance risks: context importer streams JSONL, but live PTY capture could affect typing/output paths if added without gating; Session Index/ripgrep historical search can be expensive over large Codex session trees.

Privacy risks: context-efficiency avoids raw payload leakage; future extraction must avoid storing secrets and raw logs in `payload_json`.

Migration risks: existing local DBs may need v1->v2 migrations; moving app-target `WorkProvenance` to a package requires Xcode project wiring and API visibility cleanup.

Testing gaps: no end-to-end UI tests for provenance; no multi-session attribution tests; no deleted/rebased worktree tests.

Product-scope risks: combining provenance, token efficiency, subsession management, and handoff automation can blur scope. Keep phases read-only until policy quality is measurable.

## 12. Current Roadmap

1. [implemented] Milestone 1: Discovery and schemas. Deliverables: architecture inventory, proposed integration, domain model, milestones, roadmap. No runtime behavior changes.
2. [implemented] Milestone 2: Read-only Codex telemetry. Deliverables: streaming rollout parser, Codex state reader, SQLite store, cursors, parser errors, duplicate suppression, CLI JSON diagnostics, tests. No live Codex changes.
3. [active/partial] Milestone 3: Command and output attribution. Deliverables: command candidates from tool facts, category classifier, exact/temporal confidence labels, repeated command facts, PR/ticket/work-item references. Subsession/delegation provenance should integrate here by adding parent/child session/work-item/delegation facts to the read-only event model before policy/UI phases.
4. [planned] Milestone 4: Efficiency profiler. Compute per-call/thread/command/work-item metrics and loop/repetition signals.
5. [planned] Milestone 5: Project progress and provenance. Link threads/model calls/commands to worktrees/contributions; track decisions, discoveries, validations, failed approaches.
6. [planned] Milestone 6: Coordination UI. Fleet, thread, work-item, handoff-preview views with raw evidence drilldown.
7. [planned] Milestone 7: Shadow lifecycle engine. Versioned policies, shadow intervention logs, explanations.
8. [planned] Milestone 8: Assisted handoffs. Bounded handoff packages, preview/edit, validation, new thread prep.
9. [planned] Milestone 9: Output reduction experiment. Measure native/RTK-style command reduction separately.
10. [planned] Milestone 10: Adaptive calibration. Replay framework and versioned policy evaluation.

## 13. Repository Evidence

| Path | What it contains | Current status | Why it matters |
| --- | --- | --- | --- |
| `/Users/brianbusby/repos/bmux/docs/context-efficiency/roadmap.md` | Original roadmap and principles. | [planned] | Defines mission and invariants. |
| `/Users/brianbusby/repos/bmux/docs/context-efficiency/current-architecture.md` | Discovery inventory. | [implemented doc; slightly stale vs context worktree] | Maps reuse/replacement. |
| `/Users/brianbusby/repos/bmux/docs/context-efficiency/domain-model.md` | Planned canonical vocabulary. | [planned] | Guides future schema. |
| `/Users/brianbusby/repos/bmux/docs/context-efficiency/milestones.md` | Implementation phases. | [stale in main checkout; current in context worktree] | Roadmap source. |
| `/Users/brianbusby/repos/bmux/docs/context-efficiency/current-status.md` | Live handoff index. | [stale in main checkout; current in context worktree] | Must be checked before work. |
| `/Users/brianbusby/repos/bmux/Sources/WorkProvenance` | Work-provenance store, records, Git observer. | [implemented/partial] | Current provenance core. |
| `/Users/brianbusby/repos/bmux/CLI/BMUXCLI+Provenance.swift` | CLI provenance commands. | [implemented] | Current query surface. |
| `/Users/brianbusby/repos/bmux/Packages/macOS/BmuxContextEfficiency` | Telemetry package. | [implemented] | Token/context foundation. |
| `/Users/brianbusby/repos/bmux/CLI/BMUXCLI+ContextEfficiency.swift` | CLI telemetry diagnostics. | [implemented] | User/agent report API. |
| `/Users/brianbusby/repos/bmux/CLI/BMUXCLI+CodexTokenAudit.swift` | Legacy token audit. | [implemented/legacy] | Baseline analysis output. |
| `/Users/brianbusby/repos/bmux/Sources/SessionIndexStore+CodexSQL.swift` | Codex historical search. | [implemented] | Retrieval precedent. |
| `/Users/brianbusby/repos/bmux/Packages/Shared/BmuxAgentChat/Sources/BmuxAgentChat/Store/ChatRawTerminalOutputFileStore.swift` | Raw output store. | [implemented] | Raw evidence recovery. |
| `/Users/brianbusby/repos/bmux/Packages/Shared/BmuxAgentChat/Sources/BmuxAgentChat/Parsing/OSC133CommandParser.swift` | PTY command segmentation. | [implemented, not wired] | Future non-Codex command capture. |
| `/Users/brianbusby/repos/bmux/bmuxTests/WorkProvenanceStoreTests.swift` | Store/replay/prune/file explanation tests. | [implemented] | Regression coverage. |
| `/Users/brianbusby/repos/bmux/bmuxTests/WorkProvenanceObserverTests.swift` | Git observation/dedupe tests. | [implemented] | Observer coverage. |
| `/Users/brianbusby/repos/bmux/tests/test_context_efficiency_cli.py` | CLI telemetry regression. | [implemented] | Validates no raw leaks, cursors, JSON shape. |
| `/Users/brianbusby/repos/bmux/AGENTS.md` | Agent instructions. | [implemented guidance] | Defines phase guardrails and handoff rules. |

## 14. Git and Worktree State

- [implemented/current checkout] Repository: `/Users/brianbusby/repos/bmux`.
- [implemented/current checkout] Current branch: `subagent-workspace-tabs`.
- [implemented/current checkout] Current HEAD: `fee11f639f6c7d2f51b6dc3cb34fe3a169afd2d2`, also `origin/main`, merge commit `Merge branch 'context-efficiency-wip-20260715'`.
- [implemented/current checkout] Dirty state: dirty. Modified files include `CLI/bmux.swift`, `Sources/Mobile/AgentChat/*`, `Sources/Workspace.swift`, sidebar files, localization, and context-efficiency docs. Untracked files include `Packages/macOS/BmuxSidebar/Sources/BmuxSidebar/WorkContext/*` and `WorkspaceWorkContextTests.swift`.
- [implemented] Relevant committed provenance commits: `e472d537f Add agent audit and token tooling`; `c4361544c Add work provenance runtime`; `fee11f639 Merge branch 'context-efficiency-wip-20260715'`.
- [implemented/separate worktree] Active context-efficiency worktree: `/private/tmp/context-efficiency-wip-20260715`, branch `context-efficiency-wip-20260715`, HEAD `57244d6b1473f931c9f7d93329775850db4f2c77`. Latest committed implementation there: `95e1c0d9f Add context efficiency command attribution`. Dirty WIP: work-item reference extraction and schema v2 changes.
- [implemented/other] Another worktree exists at `/private/tmp/publish-local-worktree` on `agent/publish-local-work`; no provenance relevance found from inspected state.
- [important discrepancy] Main checkout docs still say Phase 2 only in places; context-efficiency worktree docs say Phase 2 closed and Phase 3 active. Treat the context-efficiency worktree as the fresher provenance-project state.

No tests were run for this handoff; inspection was read-only.

## 15. Recommended Integration Points for Subsessions

Straightforward extensions:

- [straightforward] Represent the parent Codex session/thread with `ContextEfficiencyAgentThreadRecord` for telemetry and `WorkProvenanceSessionRecord` for work provenance.
- [straightforward] Represent delegated objective as either an extension of `WorkProvenanceWorkItemRecord` or a new child work item linked to a parent work item. Existing `work_contributions` can represent “child session contributed to delegated work.”
- [straightforward] Store parent-child relationships in provenance events first, then projections. Add event types such as `delegation_started`, `subsession_started`, `subsession_completed`, `delegation_accepted`, `delegation_rejected`.
- [straightforward] Lifecycle events should enter through the same event ledger pattern as `WorkProvenanceEvent` and through the context-efficiency importer when Codex rollout/hook events expose subagent start/stop.
- [straightforward] Child results should attach through existing IDs: files via `file_changes`, commands via Phase 3 `command_executions`, tests via `validation_runs`, commits via a new commit entity, summaries via artifact/summary records, token usage via `model_calls`.
- [straightforward] Parent acceptance/rejection should be a semantic event with `source = declared` or `userAuthored` equivalent and high confidence.

Requires architecture decisions:

- [decision needed] Whether to add a first-class `SubsessionRecord`/`DelegationRecord` or model delegation as `WorkItem + WorkContribution + parentSessionID`.
- [decision needed] Where delegation contracts live: `WorkProvenance` DB, context-efficiency DB, or a unified package/store.
- [decision needed] Whether subsession IDs are agent-native, bmux-minted, or composite `(parentSessionID, subagentID/requestID)`.
- [decision needed] Whether child sessions can share a worktree with parent or should get explicit worktree scopes/contracts.
- [decision needed] How to handle child sessions that produce no commits but return analysis.

Current related dirty work:

- [in progress/current checkout] `AgentSubsessionLifecycleChange` is being added in `AgentChatSessionRegistry+Lifecycle.swift`.
- [in progress/current checkout] `AgentChatTranscriptService` creates ephemeral workspaces for subagent start/stop and marks them non-restorable.
- [in progress/current checkout] Feed hook enrichment captures subagent scalar metadata in `CLI/bmux.swift`.
- [in progress/current checkout] These changes are not persisted into `WorkProvenance` yet.

Likely migration concerns: add parent-child fields without duplicating existing `session_id`/`work_item_id`; preserve existing DBs with migration tests; keep raw child output external; maintain status/confidence/source conventions.

## 16. Proposed Merge Constraints

- [constraint] Do not duplicate `WorkProvenanceSessionRecord` or `ContextEfficiencyAgentThreadRecord`; extend or link them.
- [constraint] Do not create a second unrelated work-item model if `WorkProvenanceWorkItemRecord` can carry the objective with parent links/migrations.
- [constraint] Preserve event-plus-projection pattern for durable provenance.
- [constraint] Preserve source/confidence labeling. Exact facts, declarations, and inferences must remain distinguishable.
- [constraint] Do not store raw rollout/tool/terminal output in frequently queried SQLite rows.
- [constraint] Keep `BmuxContextEfficiency` read-only until lifecycle phases explicitly open.
- [constraint] Do not add lifecycle warnings or handoff automation during command/reference attribution work.
- [constraint] Keep CLI JSON reports bounded and raw-payload-safe.
- [constraint] Use package-local Swift tests for package changes and app tests for app-target `WorkProvenance`.
- [constraint] If adding user-facing CLI/UI strings, update `Resources/Localizable.xcstrings`.
- [constraint] Do not reopen the “observation before intervention” decision without strong evidence.
- [constraint] Do not rely on terminal title or mtime heuristics for session binding when surface/hook/process identity exists.

## 17. Final Readiness Assessment

Solid enough to build on now:

- [implemented] `WorkProvenanceStore` event/projection pattern.
- [implemented] Git worktree/file dirty-state observation.
- [implemented] Context-efficiency streaming import, SQLite storage, source references, parser diagnostics, duplicate suppression.
- [implemented] Codex state snapshot reader and CLI diagnostics.
- [implemented in context branch] Derived command execution candidates and confidence labels.

Must be verified first:

- [unknown] Whether the context-efficiency worktree WIP should be merged before subsession design work.
- [unknown] Whether `WorkProvenance` should move to a package before adding delegation entities.
- [unknown] Exact current Codex subagent/subsession hook/rollout event shapes.

Likely to change:

- [likely] Work-item/reference schema.
- [likely] Storage ownership between `WorkProvenance` and `BmuxContextEfficiency`.
- [likely] Session/subsession identity mapping once delegation is first-class.

Three highest-risk integration points:

1. [risk] Parent/child identity: avoiding duplicate “session,” “thread,” and “subsession” concepts.
2. [risk] Attribution: proving which child produced which files/commands/commits without overclaiming.
3. [risk] Store ownership/migrations: merging work provenance and telemetry without schema churn or broken local DBs.

Recommended first implementation slice for subsession provenance:

- [recommended] Add read-only semantic event ingestion for subagent/subsession lifecycle into `WorkProvenanceStore`, using existing `AgentSubsessionLifecycleChange` as the app-side signal.
- [recommended] Persist parent session ID, child/subsession ID, agent kind, workspace ID, surface ID, cwd, display name, started/stopped timestamps, source, and confidence.
- [recommended] Do not add UI, handoff policy, or automatic delegation judgment in that slice.
- [recommended] Add tests that prove parent state is unchanged, child lifecycle events are persisted idempotently, and future file/command/test facts can link to the child contribution.
