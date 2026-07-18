# Bmux Context Efficiency: Proposed Integration

Status: proposed integration map after Phase 0 discovery. This is not an implementation plan for all phases; it defines the first safe vertical slices and where they should attach.

## Integration Principles

- Observe before intervening. Milestone 2 stays read-only and does not change live Codex behavior.
- Keep raw evidence recoverable. Reduced output, summaries, and policy labels must point back to raw artifacts or source offsets.
- Keep facts separate from inference. Token counts, timestamps, commands, commits, and file changes are facts; loop/waste labels are versioned inferences.
- Reuse existing identity and storage seams. Do not create a parallel session/workspace model when bmux already has one.
- Do not put large parsing or disk writes on UI, typing, PTY, or Ghostty hot paths.
- Version every parser, schema, policy, and report format from the beginning.

## Proposed Layering

```text
BmuxContextEfficiencyCore
  Pure value types, IDs, schemas, parser result types, policy-signal types.

BmuxContextEfficiencyStore
  SQLite migrations, import cursors, event/model-call repositories, artifact references.

BmuxContextEfficiencyImport
  Codex rollout/state importers, defensive JSONL parsing, duplicate suppression.

BmuxContextEfficiencyReports
  Markdown/JSON/CSV summaries and CLI-facing DTOs.

App integration
  Runtime observer wiring, live event publication, future fleet/thread UI.

CLI integration
  bmux context-efficiency or evolved bmux codex-token-audit commands.
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
| Codex thread metadata | `SessionIndexStore+CodexSQL.swift`, `CLI/BMUXCLI+CodexTokenAudit.swift` | Reuse SQL field knowledge and highest-state-DB resolution. Move durable import logic into new package. |
| Codex rollout path | `AgentChatTranscriptResolver`, process FD detection in `AgentChatSessionRegistry+ObserveScan.swift` | Use as live identity hints; importer should still accept explicit paths. |
| Live agent identity | `AgentChatSessionRegistry`, hook session store | Link `AgentThreadRecord` to `AgentChatSessionRecord` IDs and bmux surface/workspace IDs. |
| Workspace identity | `TabManager`, `Workspace`, `SessionWorkspaceSnapshot` | Store workspace/window/surface IDs as references; do not persist whole UI snapshots in telemetry rows. |
| Repository/worktree identity | `BmuxGit`, `WorkProvenanceGitInspector`, `WorkProvenanceStableIDFactory` | Reuse Git resolution and stable ID/fingerprint logic. |
| Provenance ledger | `WorkProvenanceStore` | Reuse event-plus-projection design if packaged/reviewed; otherwise keep schema aligned for later merge. |
| Command segmentation | `OSC133CommandParser` | Use for PTY command attribution experiments, not for Milestone 2 token import. |
| Output reduction | `TokenOptimizationLayer`, `CommandOutputOptimizer` | Keep as independent reducer; measure reduction separately from thread handoff savings. |
| Raw output recovery | `ChatRawTerminalOutputRecord`, `ChatRawTerminalOutputFileStore`, `agent-token-output show` | Reuse record shape and reference style. Add artifact index rather than embedding large output in analysis rows. |
| Live UI updates | `BmuxEventBus` | Publish lightweight import/profiler events later. Do not use it as the durable store. |

## What Should Not Be Reused Directly

- `CodexTranscriptParser` should remain chat-display parsing. It intentionally skips token bookkeeping.
- `CLICodexTokenAuditRolloutAnalyzer` should not be the importer because it reads entire rollout files into memory.
- `SessionPersistence.swift` should not become an analytics database.
- `MobileTerminalByteTee` should not be made always-on durable capture without a separate performance design.
- `BmuxEventBus` retained events and rotated JSONL should not be authoritative historical data.

## Data Flow for Milestone 2

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
- Add a non-UI telemetry parser for Codex JSONL.
- Link imported `AgentThreadRecord.externalThreadID` to `AgentChatSessionRecord.sessionID` when the hook/session registry provides a reliable mapping.
- Do not make AgentChat tailers parse token telemetry for now; they are optimized for UI subscriptions and chat rows.

Future:

- Live app-server token usage events can feed the same telemetry store after the read-only importer proves the schema.

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

## Stop Conditions Before Runtime Changes

- Domain schema reviewed.
- Parser fixture coverage exists.
- SQLite migration tests exist.
- Importer proves it does not load large rollouts into memory.
- Reports explain data confidence and unavailable token splits.
- No change to live Codex command execution until read-only telemetry is trustworthy.
