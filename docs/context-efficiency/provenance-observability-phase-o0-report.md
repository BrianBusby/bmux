# Provenance Observability Phase O0 Report

Date: 2026-07-19

Status: O0 architecture investigation complete. This report does not add observability schema or runtime code. It unlocks only the smallest O1 pipeline-tracing design for a later implementation slice.

## Scope Inspected

- `Sources/WorkProvenance`: append-only event ledger, schema migration, replay, projection tables, session relationships, external identities, lifecycle recorder, and runtime wiring.
- `Sources/Mobile/AgentChat`: `AgentSubsessionLifecycleChange` derivation from hook lifecycle events and transcript-service lifecycle callbacks.
- `Sources/bmuxApp.swift` and `Sources/AppDelegate.swift`: app composition root wiring for a shared `WorkProvenanceRuntime`.
- `CLI/BMUXCLI+Provenance.swift` and `CLI/CLIProvenanceSQLiteReader.swift`: read-only provenance diagnostics and direct SQLite reader patterns.
- `Packages/macOS/BmuxContextEfficiency`: rollout import, parser diagnostics, cursor persistence, command/reference derived reports, and bounded CLI report conventions.
- Roadmap plans for subsession/delegation, retrieval/knowledge projection, and provenance observability.
- Existing debug/diagnostic surfaces: DEBUG event log, startup breadcrumbs, CLI JSON diagnostics, Swift tests, and Python CLI regressions.

## Current Authoritative Stores

`WorkProvenance` is the authoritative semantic work history. Its model is:

```text
observed or declared fact
-> WorkProvenanceEvent
-> WorkProvenanceStore.append()
-> projection upserts
-> read-only CLI/query surfaces
```

The store is currently app-target code, not a Swift package. Schema version 3 owns `events`, repository/worktree/session projections, session parent/root/depth relationships, and external identity links. Projection rebuild replays the immutable event table after clearing projection tables. This is the right source of domain identifiers for observability correlation.

`BmuxContextEfficiency` is a separate read-only telemetry/evidence store. It owns imported Codex rollout facts, model calls, token telemetry, tool calls/outputs, parser errors, source references, command candidates, repeated-command facts, and bounded report DTOs. It should not own lifecycle semantics or observability traces for WorkProvenance.

A future `ProvenanceObservability.sqlite` should remain operational telemetry only: pipeline runs, stages, durations, bounded errors, and later derivation/retrieval/evaluation traces. It must not duplicate WorkProvenance events, ContextEfficiency rollout payloads, transcripts, command output, or diffs.

## Phase B Lifecycle Flow

Phase B now has a complete read-only lifecycle persistence and query path:

```text
WorkstreamEvent subagentStart/subagentStop
-> AgentChatSessionRegistry.subsessionLifecycleChange(for:record:)
-> AgentChatTranscriptService.handleSubsessionLifecycleChange
-> WorkProvenanceRuntime.recordSubsessionLifecycleChange
-> WorkProvenanceSubsessionLifecycleRecorder
-> WorkProvenanceStore.append(subsession_started/subsession_stopped)
-> sessions + session_relationships + session_external_identities projections
-> bmux provenance sessions tree <session-id> --json
```

The lifecycle recorder derives deterministic child session IDs and external identity IDs through `WorkProvenanceStableIDFactory`. Native subsession/request identifiers record high confidence; missing identifiers use a stable low-confidence unresolved identity. Stop-before-start still records a completed child relationship instead of dropping the fact. Nested subsessions derive root and depth from existing parent relationships.

The app composition root creates one shared `WorkProvenanceStore` through `WorkProvenanceRuntime.live()` and shares it between Git/workspace observation and subsession lifecycle persistence. `AppDelegate.configure(...)` injects that runtime into `AgentChatTranscriptService` before the service starts.

## Existing Diagnostics And Gaps

Current diagnostics are useful but not trace-correlated:

- `bmux provenance sessions tree <session-id> --json` proves current projections are queryable and bounded, but it does not explain which append/projection stage produced each row.
- `WorkProvenanceSubsessionLifecycleRecorder.lastErrorDescription` retains only the latest best-effort persistence error and is not queryable as a durable trace.
- `WorkProvenanceStore.append()` performs event insert and projection updates inside one transaction, but stage timing/failure details are not recorded.
- `ContextEfficiencyStore` records parser errors, import cursors, source references, and bounded report facts, but those are separate imported telemetry diagnostics and should not be repurposed as provenance pipeline traces.
- DEBUG event logs and startup breadcrumbs are good app-debug tools, but they are not durable, scoped, queryable observability records.

## O1 Smallest Trace Design

The smallest useful O1 slice is clear and should trace only one flow:

```text
AgentSubsessionLifecycleChange
-> lifecycle event construction
-> WorkProvenanceStore.append()
-> projection update
```

Recommended O1 entities:

- `ProvenancePipelineRunRecord`: one lifecycle ingestion attempt, with `pipeline_run_id`, `pipeline_kind = lifecycle_ingestion`, trigger/source, optional session scope, status, started/ended timestamps, input/output/error counts, bounded error summary, and implementation version.
- `ProvenancePipelineStageExecutionRecord`: three stage rows for `lifecycle_change_received`, `work_provenance_event_append`, and `work_provenance_projection_update`, with stage version, status, counts, started/ended timestamps, duration, and bounded error fields.

Recommended correlation strategy:

- Generate `pipeline_run_id` outside `WorkProvenanceStore.append()` in the lifecycle recorder or a small adapter wrapper.
- Reuse authoritative domain IDs: parent session ID, child session ID, lifecycle event ID, relationship session ID, and external identity ID.
- Keep observability writes best-effort and non-blocking. Failure to write a trace must not block `WorkProvenanceStore.append()` or projection updates.
- Keep trace rows bounded; store IDs, counts, durations, statuses, versions, hashes if needed, and short error summaries only.

Recommended implementation boundary:

- Add a new small observability store/type rather than adding trace tables to `WorkProvenanceStore`.
- Inject an optional lifecycle trace recorder into `WorkProvenanceSubsessionLifecycleRecorder` or `WorkProvenanceRuntime`. Default/no-op keeps current runtime behavior unchanged.
- Avoid changing `BmuxContextEfficiency` in O1. It may later link through stable external identities and source references.

## O1 Non-Goals

Do not add dashboards, quality scoring, retrieval traces, feedback, shadow comparisons, semantic derivations, automatic correction, lifecycle policy, handoff recommendations, or broad sampling in O1. Do not copy raw transcripts, rollout payloads, command output, diffs, or model/tool payloads into observability rows.

## Acceptance For Later O1

A later O1 implementation is sufficient when one subsession lifecycle event can be traced end to end; success and failure are distinguishable; stage duration is visible; lifecycle event/projection IDs are correlated; trace writes are best-effort; CLI trace JSON is bounded; and existing WorkProvenance lifecycle tests and provenance CLI regression remain green.

## Stop Line

O0 is complete. No O1 schema or code was added in this slice. The smallest O1 trace design is clear enough for the next explicitly approved implementation slice.
