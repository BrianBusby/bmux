# Bmux Context Efficiency: Milestones

Status: implementation sequence reconciled on 2026-07-19 after merging the subsession/delegation integration plan, the agent retrieval/knowledge-projection plan, and the provenance observability integration plan into the original context-efficiency roadmap.

Cross-cutting plans:

- `docs/context-efficiency/adr-001-provenance-engine-extraction.md`
- `docs/context-efficiency/provenance-engine-extraction-phase0-report.md`
- `docs/context-efficiency/provenance-engine-contracts-phase1-plan.md`
- `docs/context-efficiency/subsession-delegation-integration-plan.md`
- `docs/context-efficiency/agent-retrieval-knowledge-projection-plan.md`
- `docs/context-efficiency/provenance-observability-integration-plan.md`

ADR-001 is accepted and establishes the Provenance Engine as an independent product. Future provenance milestones should treat bmux as the first client, not as the owner of the engine. Migration work should introduce public SDK/API contracts before moving implementation, keep the engine local-first for V1, and avoid new bmux assumptions in reusable provenance logic.

The ADR-001 Phase 0 migration audit is complete in `docs/context-efficiency/provenance-engine-extraction-phase0-report.md`. The ADR-001 Phase 1 behavior characterization and minimum contract plan is complete in `docs/context-efficiency/provenance-engine-contracts-phase1-plan.md`. The first Phase 2 slice has introduced internal protocol/request/response names for append, session-tree, and file-explanation behavior around the current store. The next extraction slice should add normalized lifecycle and trace query contracts, or convert one CLI path only after its exact JSON/no-database behavior is mapped from the store-backed contract response.

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
- ADR-001 Phase 2 contract-interface slice added `ProvenanceEngineClient` plus append, session-tree, and file-explanation request/response DTOs over `WorkProvenanceStore`, with protocol-level tests. It does not yet move code, create the independent engine repository, or convert CLI direct SQLite readers.

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

Goal:

Integrate useful-work evidence with cost evidence.

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

- `docs/context-efficiency/agent-retrieval-knowledge-projection-plan.md`

Goal:

Build a derived, rebuildable, evidence-linked retrieval layer that can assemble the smallest reliable context package needed for a future agent objective.

Expected work:

- Phase R0 investigation report before code changes.
- Decision and finding semantic records with evidence references, source, confidence, freshness, and supersession.
- Typed provenance edges where retrieval requires richer traversal than existing foreign keys.
- Knowledge records for repository, subsystem, work item, contribution, session, delegation, file, decision, finding, validation, commit, and handoff summaries.
- SQLite FTS5 lexical retrieval with repository/worktree/work-item/kind/freshness/confidence filters.
- Deterministic retrieval ranking and token-budgeted context package assembly.
- Retrieval evaluation fixtures for required-record recall, stale/superseded leakage, omitted counts, source-reference coverage, determinism, and latency.

Rules:

- Retrieval records are derived and rebuildable; they never replace provenance facts.
- Retrieval must work without semantic embeddings.
- Do not index raw rollout or terminal output into the primary retrieval surface.
- Do not start context-package generation before semantic records, edges, and lexical retrieval are proven.
- Do not add UI, automatic prompt injection, autonomous orchestration, or assisted handoff behavior in this milestone.

Observability integration:

- Add projection-run, derivation, invalidation, retrieval-run, and retrieval-candidate traces.
- Retrieval traces must explain selected and omitted records with ranking components, freshness/supersession/confidence filtering, token-budget omissions, and source references.
- Evaluation fixtures must measure required-record recall, irrelevant/misleading/stale/superseded leakage, token-budget compliance, source-reference coverage, determinism, and latency.

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
