# Bmux Context Efficiency: Current Architecture

Status: Phase 0 discovery. This document records repository evidence before any broad implementation of the context-efficiency roadmap.

## Scope

The requested system should observe agent work, preserve raw evidence, explain token/context cost, detect inefficient thread lifecycle points, and support structured handoffs. The current bmux repository already contains several adjacent systems:

- agent session detection and transcript viewing;
- Codex wrapper and hook injection;
- native command-output token optimization;
- live event streaming;
- workspace/window/tab/session persistence;
- session index/search;
- a partial work-provenance SQLite subsystem in the current working tree;
- a Codex token-audit CLI prototype in the current working tree.

It does not yet contain a canonical model-call telemetry store, a streaming rollout-token parser, a lifecycle policy engine, or a structured handoff engine.

## Repository Shape

Confirmed high-level structure:

- App target and composition root: `Sources/`, with large AppKit/SwiftUI composition files such as `Sources/AppDelegate.swift`, `Sources/Workspace.swift`, `Sources/TabManager.swift`, `Sources/TerminalController.swift`, and `Sources/GhosttyTerminalView.swift`.
- CLI: `CLI/`, with dispatch in `CLI/bmux.swift` and feature extensions such as `CLI/BMUXCLI+CodexFireAndForgetHooks.swift`, `CLI/BMUXCLI+Provenance.swift`, and `CLI/BMUXCLI+CodexTokenAudit.swift`.
- Shared Swift packages: `Packages/Shared/`.
- macOS Swift packages: `Packages/macOS/`.
- iOS packages and app: `Packages/iOS/` and `ios/`.
- Web/backend code: `web/` and `agent-chat/`.
- Tests: `bmuxTests/`, `bmuxUITests/`, package-local tests, and Python CLI tests in `tests/`.
- Planning docs: `docs/`, `docs/superpowers/`, and now `docs/context-efficiency/`.

Important current-working-tree note:

- `Sources/WorkProvenance/`, `CLI/BMUXCLI+Provenance.swift`, `CLI/CLIProvenance*.swift`, `CLI/BMUXCLI+CodexTokenAudit.swift`, `bmuxTests/WorkProvenance*.swift`, and `tests/test_codex_token_audit.py` are present in this checkout but are currently untracked or otherwise part of a dirty worktree. Treat them as repository evidence for this branch, but do not assume they are merged baseline.

## Swift Packages and Major Modules

Confirmed relevant packages:

| Area | Location | Current Role | Reuse for Roadmap |
| --- | --- | --- | --- |
| Agent chat model/parsing | `Packages/Shared/BmuxAgentChat` | Shared chat messages, transcript parsers, terminal command rows, token optimization, raw-output file store. | Reuse parser utilities, raw-output metadata conventions, `OSC133CommandParser`, `TokenOptimizationLayer`. Do not overload chat parser with telemetry ingestion. |
| Terminal runtime | `Packages/macOS/BmuxTerminal` | Ghostty surface creation, spawn environment, terminal surface lifecycle, terminal runtime seams. | Reuse surface/workspace env identity and PTY seams. Avoid hot-path durable capture without gating. |
| Terminal core/GhosttyKit | `Packages/macOS/BmuxTerminalCore` | Ghostty interop and terminal core types. | Reuse only through existing package seams. |
| Control socket | `Packages/macOS/BmuxControlSocket` | Socket protocol, command dispatch/coordinator, worker-lane policy. | Reuse for diagnostic/lifecycle commands and UI query endpoints. |
| Workspaces | `Packages/macOS/BmuxWorkspaces` | Workspace list model, session snapshot repository, restore policy seams. | Reuse workspace/window/session snapshot identity. Do not use session snapshots as evidence storage. |
| Git metadata | `Packages/macOS/BmuxGit` | Git repository resolution, branch/PR metadata, worktree-aware path resolution. | Reuse repository/worktree identity and dirty-state snapshots. |
| Agent launch | `Packages/macOS/BMUXAgentLaunch` | Agent launch definitions, workstream events, sanitizer policies. | Reuse agent kind definitions and hook event model. |
| Settings | `Packages/macOS/BmuxSettings`, `Packages/macOS/BmuxSettingsUI` | Typed config and settings UI, including `terminal.agentTokenOptimization.mode`. | Reuse typed settings for future policy modes/thresholds. |
| Notifications/feed | `Packages/macOS/BmuxNotifications`, `Sources/Feed/` | User-facing feed and coordination-style UI. | Candidate for lifecycle warnings, but not a dedicated context-efficiency window yet. |

Architecture risk:

- The partial `WorkProvenance` implementation currently lives in the app target under `Sources/WorkProvenance/`, while the roadmap needs reusable, testable domain/storage code. Milestone 2 should decide whether to promote it into a package or create a package that can absorb it cleanly.

## Application Entry Points

Confirmed:

- `Sources/bmuxApp.swift` and `Sources/AppDelegate.swift` are the macOS app entry/composition root.
- `Sources/AppDelegate.swift` owns `MainWindowContext`, `mainWindowContexts`, active `TabManager` routing, session restore, window creation, and command palette/action routing.
- `CLI/bmux.swift` is the CLI dispatch root.
- `agent-chat/server.ts` and `agent-chat/adapters/codex.ts` implement a separate Bun-powered agent chat UI/server path.

Relevant constraints:

- `AppDelegate` is already a large composition root. New lifecycle services should be injected through a small runtime object, not by adding large analysis logic directly to `AppDelegate`.
- CLI diagnostics should follow existing `BMUXCLI` extension style if they stay in the monolithic CLI.

## Window, Workspace, Tab, and Panel Architecture

Confirmed:

- `AppDelegate.MainWindowContext` contains a `windowId`, `TabManager`, sidebar state, file explorer state, optional `NSWindow`, and per-window dock.
- `TabManager` owns a `WorkspacesModel<Workspace>`, exposes `tabs`, and has one `workProvenanceRuntime` slot in the current working tree.
- `Workspace` is the logical workspace/tab model. It owns panel IDs, current directory, stable workspace ID, group ID, focused panel ID, workspace environment, sidebar metadata, per-panel Git branches, and restored agent snapshots.
- Panels include terminal, browser, markdown, file preview, project, agent-session, and other panel types.
- `SessionWorkspaceSnapshot`, `SessionPanelSnapshot`, `SessionWindowSnapshot`, and `AppSessionSnapshot` in `Sources/SessionPersistence.swift` persist window/workspace/panel restore state.

Reuse:

- Workspace ID, stable workspace ID, window ID, surface/panel ID, and current directory should be foreign keys or references in the context-efficiency model.
- Session snapshots are useful for restore/handoff verification context.

Do not reuse as-is:

- Session persistence is bounded restore state. It caps windows, workspaces, panels, and terminal scrollback. It is not a forensic or analytics store.

## Terminal, Ghostty, PTY, and Process Integration

Confirmed:

- Terminal surface creation is in `Packages/macOS/BmuxTerminal/Sources/BmuxTerminal/Surface/TerminalSurface+RuntimeSurfaceCreation.swift`.
- Spawn environment assembly is in `Packages/macOS/BmuxTerminal/Sources/BmuxTerminal/Spawn/TerminalSurface+StartupEnvironment.swift`.
- The terminal spawn environment injects protected identity keys:
  - `BMUX_SURFACE_ID`
  - `BMUX_WORKSPACE_ID`
  - `BMUX_PANEL_ID`
  - `BMUX_TAB_ID`
  - `BMUX_SOCKET_PATH`
- Runtime surface creation also injects `BMUX_BUNDLED_CLI_PATH`, `BMUX_BUNDLE_ID`, port ranges, hook-disable flags, and per-surface CLI shim paths.
- A per-surface shim directory under `/tmp/bmux-cli-shims/<surface-id>/` can contain `claude` and `codex` wrappers.
- `TerminalByteTeeBinding` and `MobileTerminalByteTee` install a Ghostty PTY tee callback for mobile clients. It is hot-path gated on mobile event subscribers and keeps a bounded per-surface replay buffer.
- `TerminalController.readTerminalTextForSnapshot` and related helpers can read terminal text/scrollback snapshots, with work routed away from the main actor where practical.

Reuse:

- Surface/workspace env identity is the strongest local binding between terminal activity and bmux UI identity.
- The existing byte tee proves bmux can observe raw PTY bytes, but future durable capture must be opt-in/gated and avoid typing/output latency.
- `surface.read_text` worker-lane policy is a good pattern for expensive reads.

Unknown:

- Whether OSC 133 marks are emitted reliably for every supported shell and every agent command execution path.
- Whether raw PTY bytes are the right durable command evidence source, or whether hook/tool-result boundaries are sufficient for Codex first.

## Codex Integration and Session Handling

Confirmed:

- `docs/codex-agent-detection-plan.md` describes an implemented Codex wrapper/shim plan.
- `CLI/BMUXCLI+CodexFireAndForgetHooks.swift` emits per-invocation Codex hook configuration for:
  - `SessionStart`
  - `UserPromptSubmit`
  - `Stop`
  - `PreToolUse`
  - `PostToolUse`
  - `PermissionRequest`
- `runCodexOptimizePreToolUseHook()` can rewrite eligible command tool input to run through `agent-token-proxy` when hooks are enabled and token optimization is not off.
- `AgentChatSessionRegistry` tracks live agent sessions from hooks, hook-store files, process observation, and process-exit watchers.
- `AgentChatTranscriptResolver` resolves Codex rollout JSONL paths from hook-recorded paths or by scanning `~/.codex/sessions/**/rollout-*.jsonl`.
- `AgentChatSessionRegistry+ObserveScan.swift` can discover Codex processes under bmux surfaces and find open Codex rollout files via process file descriptors.
- `agent-chat/adapters/codex.ts` uses `codex app-server`, starts/forks threads, observes `thread/tokenUsage/updated`, and displays turn completion token stats.
- `SessionIndexStore+CodexSQL.swift` reads Codex `~/.codex/state_5.sqlite` `threads` rows for session index/search and copies SQLite sidecars to a temp snapshot before querying.

Partial:

- Existing Codex transcript parsing is UI-oriented. `CodexTranscriptParser` explicitly skips `event_msg`, `turn_context`, and token bookkeeping.
- `agent-chat/adapters/codex.ts` records live token usage only in session memory for display; it does not persist model-call telemetry.
- The current Codex token-audit prototype reads Codex state and rollout files for reports, but it is not an incremental telemetry ingestion system.

Unknown:

- The exact current Codex rollout JSONL token event shape and whether it includes cached-input, uncached-input, output, and reasoning-token splits.
- Whether Codex app-server `thread/tokenUsage/updated` exposes enough detail for cached-token attribution in all modes.
- Whether Codex state DB version has advanced beyond `state_5.sqlite` in all local installs. The token-audit prototype handles `state_N.sqlite`; the session index currently names `state_5.sqlite` by default.

## Transcript, Terminal Output, and Compression

Confirmed:

- `Packages/Shared/BmuxAgentChat/Sources/BmuxAgentChat/Parsing/TokenOptimizationLayer.swift` is the shared native command-output optimization entry point.
- `CommandOutputOptimizer` classifies and reduces git status, test output, TypeScript diagnostics, package install output, build output, search output, and generic output.
- `ChatRawTerminalOutputFileStore` stores complete raw terminal-output records as JSON by `rawOutputRef`.
- `AgentChatTranscriptTailer` tails transcript JSONL incrementally after initial load and persists raw output records produced by transcript parsing.
- `OSC133CommandParser` incrementally segments PTY streams into `TerminalCommandBlock` values using OSC 133 semantic prompt marks.
- `bmux agent-token-output show <raw-output-ref>` can recover proxy raw output stored under the CLI raw-output path.
- `docs/agent-token-optimization.md` states the design invariant: optimized text can be shown/supplied while raw output remains locally recoverable.

Partial:

- Native command-output optimization exists, but RTK-specific integration was not found in code.
- Current optimization can reduce command output before Codex sees it only when hooks rewrite eligible tool input to `agent-token-proxy`; it is not a general post-tool-output interceptor.
- UI transcript optimization and Codex model-context reduction are related but not identical paths.

Reuse:

- Preserve `rawOutputRef` style and raw-output side-channel semantics.
- Keep command-output reduction as a separate layer from lifecycle/handoff policy.

## Persistence and Storage

Confirmed existing stores:

- Session restore snapshots: `SessionSnapshotRepository`/`SessionPersistenceStore` paths via `Sources/SessionPersistence.swift` and `Packages/macOS/BmuxWorkspaces/Sources/BmuxWorkspaces/Session/`.
- Live/catch-up events: `BmuxEventBus` and `BmuxEventLogWriter`, writing `~/.bmuxterm/events.jsonl` with rotation and byte caps.
- Hook sessions: `~/.bmuxterm/<agent>-hook-sessions.json`.
- Agent raw output cache: `~/Library/Caches/.../bmux/agent-raw-output` for app transcript raw records.
- CLI token proxy raw output: `~/.local/state/bmux/agent-raw-output` via `CLI/BMUXCLI+CodexFireAndForgetHooks.swift`.
- Codex state: `~/.codex/state_N.sqlite`, with `threads` rows.
- Codex rollout JSONL: `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`.
- Partial work provenance: `~/.local/state/bmux/work-provenance/bmux-work-provenance.sqlite`.

Partial `WorkProvenance` schema:

- Immutable `events` table with `schema_version`, `event_type`, timestamps, repository/worktree/session/contribution IDs, source, confidence, and JSON payload.
- Projection tables: `repositories`, `worktrees`, `sessions`, `work_items`, `work_contributions`, `checkpoints`, `change_sets`, `file_changes`, `validation_runs`.
- Retention policy preserves semantic events while pruning high-volume observed history.

Do not reuse as-is:

- `BmuxEventBus` is capped and backpressure tolerant; it should not be the authoritative durable telemetry ledger.
- Session snapshots are bounded restore state.
- Raw multi-megabyte evidence should not be stored inline in frequently queried rows.

## Reports, Analytics, and Search

Confirmed:

- `CLI/BMUXCLI+CodexTokenAudit.swift` provides a Codex token-audit report over Codex state DB rows and local rollout JSONL.
- `tests/test_codex_token_audit.py` covers the current token-audit report behavior.
- `SessionIndexStore` and `SessionIndexView` support old session indexing/search across agents; Codex support can use SQL metadata and ripgrep rollout content matching.
- iOS analytics packages and web analytics services exist, but they are product analytics, not local context-efficiency telemetry.

Limitations:

- `CLICodexTokenAuditRolloutAnalyzer` currently reads a rollout file into memory. This violates the roadmap requirement to stream-parse large JSONL files.
- The prototype report uses aggregate `threads.tokens_used` and estimates tool-output pressure; it does not reconstruct per-model-call cached/new/output splits.

## Provenance and Work Contribution

Confirmed in current working tree:

- `WorkProvenanceStore` is an actor-backed SQLite event store with projection rebuild.
- `WorkProvenanceObservationService` observes workspaces and records Git worktree state when changed.
- `WorkProvenanceGitInspector` uses `BmuxGit` and git commands to collect repository root, common directory, remote slug, branch, HEAD, dirty state, and status entries.
- `CLI/BMUXCLI+Provenance.swift` exposes `bmux provenance explain`, `bmux provenance context current`, and `bmux provenance worktrees list`.
- Tests cover append/replay/explain, pruning, dirty workspace observation, and duplicate observation suppression.

Partial:

- It records observed dirty files and can represent sessions/contributions/work items, but it does not yet ingest agent thread/model-call/command evidence.
- Session/contribution/work-item records are simple current-state projections, not the full lifecycle model from the roadmap.

Reuse:

- The event-plus-projection shape is the closest existing architecture to the requested causal ledger.
- The schema already distinguishes source and confidence, which maps to fact-vs-inference requirements.

Risk:

- It is currently app-target code. Milestone 2 should decide whether to package it or to create a context-efficiency package that can use it through protocols.

## Existing Planning Documents

Relevant docs found:

- `docs/context-efficiency/roadmap.md`: full requested roadmap, stored for future sessions.
- `docs/agent-token-optimization.md`: native token-output optimization and raw-output recovery.
- `docs/agent-session-tracking-spec.md`: agent session identity single-source-of-truth plan.
- `docs/codex-agent-detection-plan.md`: Codex wrapper/shim/hook implementation plan.
- `docs/agent-hooks.md`: hook setup and hook session stores.
- `docs/events.md`: event stream and event log behavior.
- `docs/workspace-auto-naming.md`: transcript-driven workspace naming.
- `docs/streaming-agent-updates.md`: transcript JSONL streaming limitations and Ghostty-render-grid fallback.
- `docs/workspace-groups.md`: workspace grouping and session persistence.
- `docs/superpowers/specs/2026-07-08-claude-token-optimization-design.md`: Claude token optimization design.
- `docs/superpowers/plans/2026-07-08-claude-token-optimization.md`: Claude token optimization implementation plan.

## Dependency Map

The new system should extend existing components in this order:

```text
TerminalSurface spawn env and Codex wrapper hooks
        |
        v
AgentChatSessionRegistry / hook stores / process observation
        |
        +----> Codex state DB + rollout JSONL importer
        |
        +----> SessionIndex Codex SQL metadata loader
        |
        v
Context-efficiency domain records and telemetry store
        |
        +----> WorkProvenance repository/worktree/contribution projections
        |
        +----> BmuxAgentChat raw-output refs and command-output optimizer
        |
        +----> BmuxEventBus live UI/update notifications
        |
        v
Reports, fleet/thread UI, lifecycle shadow policy, handoff preview
```

Expected extension points:

- Codex session metadata: reuse `SessionIndexStore+CodexSQL.swift` query ideas and `AgentChatTranscriptResolver`.
- Live session identity: link to `AgentChatSessionRecord` and hook-store session IDs.
- Repository/worktree state: reuse `BmuxGit` and `WorkProvenanceGitInspector`.
- Raw command output: reuse `ChatRawTerminalOutputRecord` conventions and artifact references.
- Live UI updates: publish summaries through `BmuxEventBus`, but persist authoritative state in SQLite.
- CLI diagnostics: follow `BMUXCLI` extension style, initially replacing or evolving `codex-token-audit`.

## Unknowns Requiring Experiments

- Exact Codex rollout token telemetry fields in the currently installed Codex version.
- Whether local rollout JSONL alone can identify model calls and cached-input deltas reliably, or whether app-server live events must also be captured.
- Whether compaction calls are consistently represented across Codex CLI versions.
- Best ID mapping between Codex `thread.id`, rollout filename UUID, hook `session_id`, app-server thread ID, and `AgentChatSessionRecord.sessionID`.
- Whether `PreToolUse` token proxy coverage is enough for command-output reduction evaluation or whether a deeper Codex tool-result interception point exists.
- Whether OSC 133 command marks are always present in bmux-launched shells, especially after user shell customizations.
- Where to store large durable artifacts so raw evidence is recoverable without filling SQLite rows.
- Whether the partial `WorkProvenance` code should be moved into a Swift package before Milestone 2 or left app-target-local until the model stabilizes.
- How the separate coordination UI should relate to existing Feed, Session Index, Agent Session, and custom sidebar surfaces.

## Replacement and Reuse Decisions

Reuse:

- `AgentChatSessionRegistry` for live agent identity.
- `AgentChatTranscriptResolver` for transcript path resolution.
- `SessionIndexStore+CodexSQL` query pattern for Codex state DB metadata.
- `TokenOptimizationLayer`, `CommandOutputOptimizer`, and raw-output record conventions.
- `OSC133CommandParser` where PTY semantic command attribution is needed.
- `BmuxGit` and `WorkProvenanceGitInspector` for repository/worktree facts.
- `WorkProvenanceStore` event/projection design if it survives packaging review.

Replace or reshape:

- Replace the full-file rollout read in `CLICodexTokenAuditRolloutAnalyzer` with a streaming, offset-aware importer.
- Do not use `CodexTranscriptParser` for token telemetry; create a sibling telemetry parser.
- Do not rely on `BmuxEventBus` JSONL as durable analytics storage.
- Do not use session restore snapshots as lifecycle/provenance storage.

Important coupling risks:

- App-target `WorkProvenance` code may be hard to reuse in CLI/package tests.
- `AppDelegate` and `Workspace` are large and main-actor heavy; telemetry ingestion should avoid these paths.
- Terminal byte tee is output hot path; durable capture must be gated and measured.
- Codex-local schemas are not stable API; parsers must be defensive and versioned.
- User-authored decisions can appear in chat/prose, docs, and git commits; inferred summaries must not overwrite them.
