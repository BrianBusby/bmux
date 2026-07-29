# Bmux Context Efficiency: Proposed Integration

Status: proposed integration map after Phase 0 discovery. This is not an implementation plan for all phases; it defines the first safe vertical slices and where they should attach.

## Integration Principles

- Observe before intervening. Milestone 2 stays read-only and does not change live Codex behavior.
- Keep raw evidence recoverable. Reduced output, summaries, and policy labels must point back to raw artifacts or source offsets.
- Keep facts separate from inference. Token counts, timestamps, commands, commits, and file changes are facts; loop/waste labels are versioned inferences.
- Reuse existing identity and storage seams. Do not create a parallel session/workspace model when bmux already has one.
- Prefer supported provider APIs for live provider-owned data. For Codex, app-server should be the primary live thread/session/event source; local rollout/state files remain backfill, recovery, and raw-evidence references.
- Do not put large parsing or disk writes on UI, typing, PTY, or Ghostty hot paths.
- Version every parser, schema, policy, and report format from the beginning.
- Let project knowledge grow without growing default agent context. Future context should be assembled dynamically from hierarchical knowledge and evidence references, with a task-specific reason for each included item.

## Proposed Layering

```text
BmuxContextEfficiencyCore
  Pure value types, IDs, schemas, parser result types, policy-signal types.

BmuxContextEfficiencyStore
  SQLite migrations, import cursors, event/model-call repositories, artifact references.

BmuxContextEfficiencyImport
  Codex app-server live ingestion, rollout/state backfill importers, defensive
  JSONL parsing, duplicate suppression.

BmuxContextEfficiencyReports
  Markdown/JSON/CSV summaries and CLI-facing DTOs.

App integration
  Runtime observer wiring, live event publication, future fleet/thread UI.

CLI integration
  bmux context-efficiency or evolved bmux codex-token-audit commands.

Future context assembly
  Retrieval and context-package APIs that select bounded evidence, facts, and design context by repository, worktree, subsystem, file, work item, session, decision, and source reference.
```

Packaging decision:

- Preferred: add a macOS Swift package under `Packages/macOS/BmuxContextEfficiency` for pure domain, parsing, SQLite storage, and reports, with package-local Swift tests.
- Alternative: promote the current `Sources/WorkProvenance/` code into a package first, then add context-efficiency types there or in a sibling package.
- Avoid: adding the importer and schema directly to `AppDelegate`, `Workspace`, or `TerminalController`.

Why one package first:

- The first Milestone 2 slice is macOS-local and CLI-oriented.
- It needs Foundation and SQLite but not SwiftUI/AppKit/Ghostty.
- A package makes parser/store tests cheap and avoids the bmux app target's large compile surface.

## Existing Components to Extend

| Need | Existing Component | Proposed Use |
| --- | --- | --- |
| Codex live thread/session events | `agent-chat/adapters/codex.ts` and `codex app-server` | Promote app-server from UI-only usage to the primary live Codex ingestion source for supported thread, turn, item, token, tool, process, goal, and metadata events. Persist compact facts through the context-efficiency store rather than keeping token usage only in session memory. |
| Codex thread metadata backfill | `SessionIndexStore+CodexSQL.swift`, `CLI/BMUXCLI+CodexTokenAudit.swift` | Reuse SQL field knowledge and highest-state-DB resolution for historical/offline import, recovery, and source-evidence references. Do not treat Codex SQLite as the preferred live API when app-server exposes the needed field. |
| Codex rollout backfill | `AgentChatTranscriptResolver`, process FD detection in `AgentChatSessionRegistry+ObserveScan.swift` | Use rollout paths as backfill and raw-evidence artifacts. Importer should still accept explicit paths and record source offsets for reproducibility. |
| Live agent identity | `AgentChatSessionRegistry`, hook session store | Link `AgentThreadRecord` to `AgentChatSessionRecord` IDs and bmux surface/workspace IDs. |
| Workspace identity | `TabManager`, `Workspace`, `SessionWorkspaceSnapshot` | Store workspace/window/surface IDs as references; do not persist whole UI snapshots in telemetry rows. |
| Repository/worktree identity | `BmuxGit`, `WorkProvenanceGitInspector`, `WorkProvenanceStableIDFactory` | Reuse Git resolution and stable ID/fingerprint logic. |
| Provenance ledger | `WorkProvenanceStore` | Reuse event-plus-projection design if packaged/reviewed; otherwise keep schema aligned for later merge. |
| Command segmentation | `OSC133CommandParser` | Use for PTY command attribution experiments, not for Milestone 2 token import. |
| Output reduction | `TokenOptimizationLayer`, `CommandOutputOptimizer` | Keep as independent reducer; measure reduction separately from thread handoff savings. |
| Raw output recovery | `ChatRawTerminalOutputRecord`, `ChatRawTerminalOutputFileStore`, `agent-token-output show` | Reuse record shape and reference style. Add artifact index rather than embedding large output in analysis rows. |
| Live UI updates | `BmuxEventBus` | Publish lightweight import/profiler events later. Do not use it as the durable store. |

## Codex Data Source Hierarchy

Use one hierarchy for Codex-owned session data so bmux does not permanently
maintain competing live reads:

```text
codex app-server
        |
        v
primary live ingestion for supported thread/session/turn/item/token/tool events
        |
        +------------------------------+
                                       |
Codex rollout JSONL + state_N.sqlite   |
        |                              |
        v                              v
historical backfill, recovery, raw evidence references, unavailable fields
        |
        v
BmuxContextEfficiency compact facts
        |
        v
Provenance Engine normalized work provenance and lifecycle inputs
```

Rules:

- Use app-server first for live Codex sessions when the needed field is exposed
  by a stable or accepted experimental API.
- Use rollout JSONL and `state_N.sqlite` for historical import, offline reports,
  startup catch-up, recovery from missed live events, source offsets, and fields
  app-server does not expose.
- Keep rollout/state parsing defensive and versioned because those formats are
  local implementation details, not the primary live contract.
- Store compact facts and evidence references in `BmuxContextEfficiency`; store
  causal work relationships and lifecycle/provenance projections in the
  Provenance Engine.
- Do not duplicate complete transcripts, tool outputs, diffs, or other large raw
  payloads in frequently queried SQLite rows.

## Next Codex Live Ingestion Sequence

After the normalization/provenance boundary is accepted for the active slice,
the next Codex-specific implementation sequence is:

1. App-server capability audit.
   Verify which live fields are available and reliable across thread/list,
   thread/read, turn/item pagination, streamed item events, token usage,
   compaction events, process/tool events, goals, metadata, and ID mapping to
   rollout/state records.
2. Live ingestion adapter.
   Persist compact events from the existing `agent-chat/adapters/codex.ts`
   app-server stream into `BmuxContextEfficiency` instead of keeping live token
   and tool telemetry only in session memory.
3. Backfill reconciliation.
   Keep rollout JSONL and `state_N.sqlite` import for startup catch-up,
   historical sessions, missed live events, source offsets, raw-evidence
   recovery, and fields app-server does not expose.
4. Provenance identity linking.
   Map app-server thread, turn, and item IDs to bmux workspace, surface, panel,
   agent-session, repository, and worktree identities, then expose those links
   as normalized provenance inputs rather than duplicating provider records in
   the Provenance Engine.

## What Should Not Be Reused Directly

- `CodexTranscriptParser` should remain chat-display parsing. It intentionally skips token bookkeeping.
- `CLICodexTokenAuditRolloutAnalyzer` should not be the importer because it reads entire rollout files into memory.
- `SessionPersistence.swift` should not become an analytics database.
- `MobileTerminalByteTee` should not be made always-on durable capture without a separate performance design.
- `BmuxEventBus` retained events and rotated JSONL should not be authoritative historical data.

## Data Flow for Milestone 2

Milestone 2 was intentionally read-only and file-backed. That remains the
correct backfill/offline path, but later live ingestion slices should prefer
app-server before expanding direct rollout/state scraping.

```text
Codex state_N.sqlite
        |
        v
Read-only thread metadata snapshot
        |
        +--------------------+
                             |
Codex rollout JSONL          |
        |                    |
        v                    v
Streaming JSONL parser --> normalized telemetry events
        |                    |
        v                    v
Import cursor table      parser error table
        |
        v
SQLite model-call/thread tables
        |
        v
Read-only reports and inspect commands
```

Key behaviors:

- Importer accepts explicit rollout path, Codex home, or discovered state DB.
- It stores source file path, inode/mtime if available, byte offset, line number, parser version, and import time.
- It can resume from the last imported offset and tolerate appended data.
- It records malformed/unknown fields as parser errors without aborting the import.
- It suppresses duplicate cumulative token events where totals have not advanced.
- It never prints or sends raw rollout payloads into Codex context.

## Storage Shape

Recommended local store:

- Path: `~/.local/state/bmux/context-efficiency/bmux-context-efficiency.sqlite`.
- Large artifact root: `~/.local/state/bmux/context-efficiency/artifacts/`.
- Migrations: explicit integer schema version with migration tests.

Why not reuse the current WorkProvenance DB immediately:

- The existing DB is scoped to work provenance and dirty worktree projections.
- Token telemetry will need model-call, parser-cursor, artifact, and lifecycle-policy tables that are not just provenance projections.
- The two stores can share IDs and later merge if the model proves stable.

Why still align with WorkProvenance:

- Use compatible source/confidence fields.
- Reuse repository/worktree stable IDs.
- Allow future contribution rows to link to thread/model-call/command IDs.

## Milestone 2 CLI Surface

The roadmap suggested `bmux-context`. Existing conventions favor adding commands to `bmux` unless a separate executable already exists. Proposed initial commands:

```text
bmux context-efficiency import <rollout-path> [--database <path>]
bmux context-efficiency inspect-thread <thread-id> [--database <path>] [--json]
bmux context-efficiency summarize-day YYYY-MM-DD [--database <path>] [--json]
```

Compatibility options:

- Keep `bmux codex-token-audit` as a compatibility/report command.
- Internally back it with the new importer once available.
- Add `bmux codex token-audit` alias only after the new report shape is stable.

## Smallest Coherent Vertical Slice

The smallest useful slice is read-only Codex telemetry import plus reports:

1. Resolve Codex thread metadata from `state_N.sqlite`.
2. Stream-parse one rollout JSONL path.
3. Persist parsed model-call/token telemetry, source offsets, and parser errors.
4. Produce `inspect-thread` and `summarize-day` reports from the local SQLite store.
5. Add fixtures covering normal, malformed, duplicated, missing, and compaction-like events.

Not included in this slice:

- terminal command capture;
- PTY byte evidence;
- UI fleet view;
- lifecycle warnings;
- handoff generation;
- output filtering changes;
- adaptive policy learning.

## Integration With Work Provenance

Recommended near-term approach:

- Leave `WorkProvenance` observe-only behavior unchanged while Milestone 2 is built.
- Add shared ID fields so context-efficiency rows can reference repository IDs, worktree IDs, workspace IDs, surface IDs, and agent session IDs.
- After Milestone 2, decide whether to:
  - make `WorkProvenanceStore` a lower-level event ledger used by context efficiency; or
  - keep separate SQLite stores linked by IDs and artifact references.

Decision needed:

- Should the untracked `Sources/WorkProvenance/` subsystem be treated as accepted architecture and moved into a package before Milestone 2, or should Milestone 2 create a new package and integrate with WorkProvenance later?

## Integration With Agent Chat

Proposed:

- Keep chat transcript projection unchanged.
- Treat `codex app-server` as the primary live Codex session/event source and
  persist the compact telemetry events already emitted by the agent-chat Codex
  adapter.
- Keep the non-UI Codex JSONL telemetry parser for backfill, recovery, and raw
  evidence references.
- Link imported `AgentThreadRecord.externalThreadID` to `AgentChatSessionRecord.sessionID` when the hook/session registry provides a reliable mapping.
- Do not make AgentChat tailers parse token telemetry for now; they are optimized for UI subscriptions and chat rows.

Future:

- Add an app-server capability/field audit before expanding Codex telemetry
  ingestion, covering thread/list, thread/read, turn/item pagination, streamed
  item events, token usage fields, compaction events, process/tool events, and
  ID mapping to rollout/state records.

## Integration With Output Reduction

Proposed:

- Treat `TokenOptimizationLayer` and `agent-token-proxy` as an already-existing command-output reduction experiment.
- Import reports should measure:
  - raw-output refs observed;
  - optimized-output hints observed;
  - estimated original token counts when the proxy includes them;
  - command families that were proxied.
- Do not label these savings as thread-lifecycle savings.

Future:

- Add an artifact table that can point to proxy raw-output records and transcript raw-output records.
- Add category-specific correctness metrics only after commands can be attributed to model calls.

## Policy and UI Later

Milestone 2 should create enough durable data for later policy evaluation but should not show warnings by default.

Future UI should extend existing surfaces conservatively:

- Session Index can link to per-thread reports.
- Feed can show passive lifecycle markers later.
- A dedicated coordination/fleet window should be considered for the roadmap's full fleet/thread/work-item views.

## User Decisions Needed

1. Package strategy: new `BmuxContextEfficiency` package first, or promote `WorkProvenance` first?
2. CLI naming: `bmux context-efficiency ...`, `bmux context ...`, or evolve `bmux codex-token-audit`?
3. Storage strategy: separate context-efficiency SQLite DB now, or same WorkProvenance DB with new tables?
4. Retention default for raw artifacts once command/evidence capture begins.
5. Whether future lifecycle warnings should initially appear in Feed, Session Index, or a new coordination window.
6. Whether bmux should run one shared app-server process, one per workspace, or attach to an already-running app-server for live Codex ingestion.

## Stop Conditions Before Runtime Changes

- Domain schema reviewed.
- Parser fixture coverage exists.
- SQLite migration tests exist.
- Importer proves it does not load large rollouts into memory.
- App-server field/capability audit proves which live fields can replace rollout/state scraping and which fields still need backfill.
- Reports explain data confidence and unavailable token splits.
- No change to live Codex command execution until read-only telemetry is trustworthy.
