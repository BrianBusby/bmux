# Subsession Delegation Phase A Report

Date: 2026-07-18

Status: Phase A architecture investigation complete. This report unlocks the next narrow implementation slice: read-only subsession lifecycle persistence in `WorkProvenance`.

## Relevant Modules

- `Sources/WorkProvenance`: existing append-only event ledger plus current-state projections. The store owns repository, worktree, session, work item, contribution, checkpoint, change-set, file-change, and validation-run records.
- `Sources/WorkProvenance/WorkProvenanceRuntime.swift`: app runtime wiring for observe-only Git/workspace provenance.
- `Sources/WorkProvenance/WorkProvenanceObservationService.swift`: actor that observes workspace Git snapshots and appends `worktree_observed` events.
- `Sources/Mobile/AgentChat/AgentChatSessionRegistry.swift`: main-actor agent session registry that folds hook and process observations into `AgentChatSessionRecord`.
- `Sources/Mobile/AgentChat/AgentChatSessionRegistry+Lifecycle.swift`: derives `AgentSubsessionLifecycleChange` from `SubagentStart` and `SubagentStop` hook events.
- `Sources/Mobile/AgentChat/AgentChatTranscriptService.swift`: currently consumes subsession lifecycle changes to show/remove ephemeral child workspaces.
- `Packages/macOS/BMUXAgentLaunch/Sources/BMUXAgentLaunch/Workstream/WorkstreamEvent.swift`: hook/feed wire event model. Unknown keys are preserved in `extraFieldsJSON`.
- `CLI/bmux.swift`: hook feed path for Codex and other agents. It enriches subagent feed events with scalar native metadata before sending `feed.push`.
- `/private/tmp/context-efficiency-wip-20260715/Packages/macOS/BmuxContextEfficiency`: fresher Phase 3 telemetry package with thread, model-call, tool-call, tool-output, command-execution, source-reference, and work-item-reference facts.
- `CLI/BMUXCLI+Provenance.swift`: existing read-only provenance CLI commands: `explain`, `context current`, and `worktrees list`.
- `CLI/BMUXCLI+ContextEfficiency.swift`: existing read-only context-efficiency CLI commands: `import`, `inspect-thread`, and `summarize-day`.

## Current Data Flow

Existing WorkProvenance flow:

```text
Workspace/current-directory observation
-> WorkProvenanceObservationService
-> WorkProvenanceEvent(event_type: worktree_observed)
-> WorkProvenanceStore.append()
-> events row + projection upserts
-> CLI provenance queries
```

Existing subsession UI flow:

```text
Agent hook stdin
-> CLI feed.push WorkstreamEvent
-> TerminalController v2FeedPush
-> AgentChatTranscriptService.noteHookEvent()
-> AgentChatSessionRegistry.noteHookEvent()
-> AgentSubsessionLifecycleChange
-> AgentChatTranscriptService.show/removeSubsessionWorkspace()
```

Target Phase B provenance flow:

```text
AgentSubsessionLifecycleChange
-> WorkProvenance subsession lifecycle adapter
-> WorkProvenanceEvent(event_type: subsession_started|subsession_stopped)
-> sessions + session_relationships + session_external_identities projections
-> bounded CLI session-tree query
```

This should extend the current event-plus-projection model. It should not create a separate subagent manager, a second child-session table, or live delegation orchestration.

## Available Identifiers

Authoritative from `AgentSubsessionLifecycleChange`:

- `parentSessionID`: current `AgentChatSessionRecord.sessionID`; strongest current parent identifier.
- `agentKind`: `ChatAgentKind`; maps to persisted `WorkProvenanceSessionRecord.agentKind`.
- `workspaceID`: bmux workspace UUID string when hook or record provides it.
- `surfaceID`: bmux surface UUID string when hook or record provides it.
- `workingDirectory`: hook/record cwd.
- `subsessionID`: native child/subagent identifier when present; falls back to hook request ID.
- `displayName`: bounded scalar display/name/role/task text from hook metadata.
- `phase`: started or stopped.

Available on `WorkstreamEvent` before conversion:

- `session_id`: hook session ID, prefixed by the CLI feed path as `<source>-<session>`.
- `_source`: agent source such as `codex` or `claude`.
- `_opencode_request_id`: hook request/tool-use ID or generated fallback.
- `_ppid`: agent process PID when wrapper environment or parent process is available.
- `workspace_id`, `surface_id`, `transcript_path`, `cwd`, `tool_name`, `tool_input`, `context`.
- `extraFieldsJSON`: arbitrary forward-compatible scalar fields, including subagent keys.

Subagent scalar keys currently preserved by the CLI feed path:

- IDs: `subagent_id`, `subagentId`, `subsession_id`, `subsessionId`, `agent_id`, `agentId`, `task_id`, `taskId`, `id`.
- Names/objectives: `subagent_name`, `subagentName`, `agent_name`, `agentName`, `name`, `title`, `role`, `description`, `task`.

Context-efficiency linkable identifiers:

- `ContextEfficiencyAgentThreadRecord.id`: normalized `codex:<external>` thread ID.
- `ContextEfficiencyAgentThreadRecord.externalThreadID`: external Codex thread or rollout identifier.
- `ContextEfficiencySourceReference`: rollout path, byte offset, line number, parser version.
- `ContextEfficiencyToolCallRecord.callID`: Codex call ID when present.
- `ContextEfficiencyCommandExecutionRecord.id`: stable derived command candidate ID.
- `ContextEfficiencyWorkItemReferenceRecord.reference`: normalized PR, issue, ticket, branch, or repository reference.

Missing or weak identifiers today:

- No persisted `WorkProvenanceSessionRecord` parent/root relationship.
- No external identity link table.
- No stable `childSessionID` in `AgentSubsessionLifecycleChange`; Phase B must derive one deterministically from source, parent session, and native subsession/request ID.
- No first-class delegation ID, objective, permissions, expected outputs, completion report, or parent disposition.
- No confirmed Codex rollout subagent lifecycle schema from the current parser. Local rollout inspection was noisy and did not produce a reliable structured subagent event shape separate from prompt or instruction text.
- No proof that a dirty file was written by a child session from Git observation alone.

## Authoritative Lifecycle Source

Use `AgentSubsessionLifecycleChange` as the first authoritative lifecycle source.

Rationale:

- It is already derived from structured hook events at the app boundary.
- It carries the parent session ID before the UI creates any ephemeral workspace.
- It normalizes native child identifiers and display names from known scalar keys.
- It is emitted from the central `AgentChatSessionRegistry` write path, after session canonicalization and workspace/surface backfill.
- Existing tests already cover start/stop emission, parent-state preservation, late-start suppression, and stop handling.

Do not use ephemeral child workspace creation as the source of truth. It is a UI projection and can fail or be skipped when workspace IDs are missing.

## Fallback Signals

Use these only for enrichment or reconciliation, not as the first Phase B source:

- `WorkstreamEvent` raw hook payload keys in `extraFieldsJSON`.
- Hook request ID when native subsession ID is missing.
- Bmux workspace and surface IDs.
- Agent process PID and transcript path.
- `AgentChatSessionRegistry.applyObservedSessions(_:)` process-table observations.
- Context-efficiency Codex thread metadata and rollout source references.
- Context-efficiency command/tool-call facts after a stable provenance-session-to-thread identity link exists.

Do not infer parent/child topology from terminal titles, file modification times, or Git dirty state.

## Proposed Schema Changes

Phase B only:

- Bump `WorkProvenanceStore.schemaVersion` from `2` to `3`.
- Add `session_relationships` with `session_id`, `parent_session_id`, `root_session_id`, optional `inbound_delegation_id`, `depth`, `source`, `confidence`, `created_at`, and `updated_at`.
- Add `session_external_identities` with `id`, `session_id`, `system`, `kind`, `external_id`, `source`, `confidence`, `created_at`, and `updated_at`.
- Add a unique index on `(system, kind, external_id)` for external identities.
- Add event types `subsession_started` and `subsession_stopped`; reserve `subsession_discovered` for later fallback capture.
- Add projection payload records for session relationship and external identity links.

Do not add `delegations`, `delegation_integrations`, or reconciliation tables in Phase B. They belong to Phase C/D after lifecycle persistence is stable.

## Migration Strategy

- Keep version 0 creation path creating the full current schema plus v2 and v3 indexes/tables.
- Add `schemaV3SQL` with `CREATE TABLE IF NOT EXISTS` and `CREATE INDEX IF NOT EXISTS`.
- For `version < 3`, execute `schemaV3SQL` and set `PRAGMA user_version = 3`.
- Update `clearProjectionTables()` to clear new projection tables before `sessions` during rebuild.
- Preserve existing event rows and existing projection semantics.
- Do not rewrite existing `sessions` rows or infer parent relationships for historical sessions in the migration.

## First Test Fixture

Add a Swift Testing package/app test around the store-level ingestion path, not a grep-style source test.

Minimum fixture:

```swift
let parentSession = WorkProvenanceSessionRecord(
    id: "codex-parent",
    agentKind: "codex",
    workspaceID: "workspace-1",
    surfaceID: "surface-1",
    cwd: "/repo",
    status: "active",
    startedAt: Date(timeIntervalSince1970: 100),
    updatedAt: Date(timeIntervalSince1970: 100)
)

let lifecycleChange = AgentSubsessionLifecycleChange(
    phase: .started,
    parentSessionID: "codex-parent",
    agentKind: .codex,
    workspaceID: "workspace-1",
    surfaceID: "surface-1",
    workingDirectory: "/repo",
    subsessionID: "subagent-1",
    displayName: "Reviewer"
)
```

Expected assertions:

- parent session remains active and unchanged except for any explicitly appended parent event.
- child session ID is deterministic.
- duplicate start replays do not create duplicate child session or identity rows.
- stop updates child status and timestamp.
- parent/root/depth query returns `codex-parent -> child`.
- missing native subsession ID uses request ID or records an unknown identity without guessing.
- rebuild from events reproduces the relationship projections.

## Implementation Map

1. Add WorkProvenance value types: `WorkProvenanceSessionRelationshipRecord`, `WorkProvenanceExternalIdentityRecord`, and `WorkProvenanceSessionTree`.
2. Extend `WorkProvenanceEventPayload` with optional `sessionRelationship` and `[externalIdentity]` projections.
3. Extend `WorkProvenanceStore` with v3 migration, projection upserts, and read queries: `parentSession(for:)`, `childSessions(for:)`, `sessionTree(rootSessionID:)`, and optionally `externalIdentities(sessionID:)`.
4. Add a small adapter that converts `AgentSubsessionLifecycleChange` into append-only events with a deterministic child session ID from `agentKind.sourceName`, `parentSessionID`, and native subsession/request ID or a stable unresolved fallback.
5. Use `source: .observed` and `confidence: .high` when native ID or request ID is present; downgrade confidence when identifiers are missing.
6. Wire the adapter from the same place that currently handles `registry.onSubsessionLifecycleChanged`, while preserving existing ephemeral workspace behavior.
7. Add bounded `bmux provenance sessions tree <session-id> --json`.
8. Add Swift Testing coverage for lifecycle replay, stop-before-start, missing IDs, nested roots, migration from schema v2, and projection rebuild.
9. Run `swift test` or the relevant Xcode unit target plus `scripts/check-pbxproj.sh`, `python3 scripts/check-workspace-package-groups.py --check`, `git diff --check`, and a tagged `reload.sh` only after code changes.

## Risks and Open Questions

- `AgentSubsessionLifecycleChange` currently lacks timestamps. The adapter should receive the event time from the hook path or inject a date provider; do not use `Date()` hidden inside tests.
- Child session ID derivation must be idempotent for replay. If neither native ID nor request ID exists, record low-confidence unresolved evidence rather than creating many guessed child rows.
- Nested subsessions need root calculation from existing relationships. A child may become a parent later.
- `WorkProvenanceSource` currently has coarse source values. Phase B can use `.observed` now and add finer-grained source categories later only if reporting needs them.
- Existing `WorkProvenanceConfidence` is coarse string labels, not numeric confidence. Keep it for Phase B instead of introducing numeric confidence prematurely.
- WorkProvenance is still app-target code, not a package. Keep Phase B localized unless a package extraction is explicitly opened.
- The current main checkout contains unrelated dirty subsession/workspace-tab work. Implementation should either use this branch deliberately or move to a clean worktree before code changes.

## Decision

Phase B should begin with read-only lifecycle persistence in `WorkProvenance` using `AgentSubsessionLifecycleChange` as the authoritative source. Delegation contracts remain out of scope until the lifecycle, identity-link, and tree query path is proven with migration and replay tests.
