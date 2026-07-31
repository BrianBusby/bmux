# Execution Telemetry Architecture

## Current-State Diagram

```text
Codex app-server
  JSON-RPC over NDJSON stdio
        |
        v
agent-chat/adapters/codex.ts
  ensureServer()
  handleServerMessage()
  itemStarted()
  itemCompleted()
        |
        v
Session.emit(AgentEvent)
  agent-chat/server.ts
  Session.events[] replay buffer
  Session.status
  sessionSummary()
        |
        +--> WebSocket /ws history and event messages
        |       |
        |       v
        |   React useSession()
        |   agent-chat/src/session.ts
        |   foldEvent() -> Block[]
        |
        +--> REST /api/sessions start/list

Native terminal and hook path
        |
        v
Codex/Claude/other agent hooks
  CLI/BMUXCLI+AgentHookCatalog.swift
  CLI/BMUXCLI+CodexFireAndForgetHooks.swift
  CLI/bmux.swift ClaudeHookSessionStore
        |
        +--> hook session JSON under ~/.bmuxterm
        +--> socket status/notification/autonaming mutations
        +--> selected work provenance paths

provenance-engine
  consumed through ProvenanceEngineContracts and ProvenanceEngineSDK
  for selected durable provenance queries and lifecycle records
```

Mainline reconciliation note: current bmux main has accepted Provenance Engine
Slice E. The active product gate is the Engineering Observation Period. This
execution telemetry plan's Plan Slice 4B numbering is unrelated to Provenance
Engine Slice E.

## Current Ownership Boundaries

`agent-chat/server.ts` owns the current agent-chat session object: bmux-local session id, provider id, cwd, title, auto-approve flag, status, adapter-private state, sockets, created-at timestamp, and replayable `events`.

`agent-chat/adapters/codex.ts` owns Codex app-server process state: one shared `codex app-server` process per sidecar, JSON-RPC request ids, pending requests, `sessionsByThread` keyed by Codex `threadId`, and per-session Codex state in `sess.internal.codex`.

React does not own provider session identity or app-server lifecycle. React owns only a browser-side projection: `agent-chat/src/session.ts` duplicates the `AgentEvent` union and `foldEvent()` maps events into renderable `Block` values.

Native Swift does not subscribe to the TypeScript `AgentEvent` UI stream. The
shared Swift package `Packages/Shared/BmuxAgentChat` now reads the bounded live
projection REST payload through `ExecutionTelemetryLiveProjectionClient` and
uses shared fixtures to catch payload drift. Swift consumes that read payload;
it does not own the canonical telemetry schema or reconstruct telemetry from
React events.

## Renderer Independence Today

React is not required for lifecycle capture once a session exists. `POST /api/sessions` in `agent-chat/server.ts` creates a session and calls `sendPrompt(sess, prompt)` without a React WebSocket subscriber, and Codex app-server notifications still reach `handleServerMessage()` and `sess.emit()`.

React is not required for session ownership. The `sessions` map and `Session.events` replay buffer are process memory in `agent-chat/server.ts`; React reconnects and receives history from that owner.

Multiple React/WebSocket consumers can subscribe to the same session. Each `Session` has a `sockets` set, `subscribe()` adds a socket, and `broadcastSessionEvent()` sends each event to all subscribed sockets. This multiple-consumer support is UI-only; before Slice 2 there was no renderer-independent execution-event fanout, native subscriber API, or provider-neutral event contract.

## Slice 2 Fanout Seam

`agent-chat/executionTelemetryFanout.ts` now provides the first
renderer-independent sidecar fanout path. A per-session
`ExecutionTelemetryFanout` assigns `eventId`, `sequence`, `capturedAtMs`,
`sessionId`, and `provider` in one place, notifies telemetry subscribers, and
projects each envelope to the existing `AgentEvent` stream through
`SessionCtx.emitTelemetry`.

Most provider adapter events still call `SessionCtx.emit(AgentEvent)` directly.
Slices 3 through 11 migrate Codex prompt submission, provider session linkage,
turn lifecycle, message lifecycle, tool lifecycle, approval lifecycle,
standalone usage observations, and request-status diagnostics through
`SessionCtx.emitTelemetry`; those envelopes project back to the same
`AgentEvent` stream, so React WebSocket payloads and `foldEvent()` behavior are
unchanged. Later slices should migrate more provider events by publishing
`TelemetryEventEnvelopeDraft` values first and treating `AgentEvent` as the
fanout projection only.

The first non-Codex provider migration applies that same seam to a narrow
Claude lifecycle/identity subset only: sidecar prompt submission, Claude
stream-json `system/init` provider session identity, Claude stream-json
`result` completion/result-error closure, and sidecar process-close failure
closure for active turns. Claude message, thinking, tool, command-list,
control/status, token usage, file-change, and raw stream-json payloads remain
outside canonical telemetry until a later source-selection slice.

## Plan Slice 4B Live Projection Read Surface

Each `agent-chat/server.ts` session now attaches a
`LiveSessionProjectionStore` beside its `ExecutionTelemetryFanout`. The store
subscribes to assigned canonical envelopes and keeps only the latest bounded
`LiveSessionProjectionSnapshot` in sidecar process memory.

The read surface is REST-only:

```text
GET /api/sessions/:id/execution-telemetry/live
  -> { sessionId, snapshot }
```

`snapshot` is `null` until the session has emitted canonical telemetry. This
does not append projection state to `Session.events`, broadcast new WebSocket
messages, change React rendering, persist telemetry, or write provenance
records. Plan Slice 4C later added the native read client for this existing
REST payload.

## Plan Slice 4C Native Read Client

`Packages/Shared/BmuxAgentChat` now has a Swift read client for the existing
live projection REST payload. Swift consumes the bounded JSON shape only.

## Current Lossy Boundary

The lossy boundary is inside `agent-chat/adapters/codex.ts`, primarily `handleServerMessage()`, `itemStarted()`, and `itemCompleted()`. Raw Codex notifications are reduced directly into `AgentEvent`, whose schema is display-oriented.

Important reductions:

- `turn/completed` token usage and duration become a display string in `done.stats`.
- `thread/tokenUsage/updated` stores only `tokenUsage.total` in `sess.internal.lastUsage`; `tokenUsage.last`, cached-input tokens, reasoning-output tokens, total tokens, model context window, and `turnId` do not reach `AgentEvent`.
- Remaining non-migrated tool details still drop process id, command actions, source, MCP server/plugin details, structured results, and several item variants. Slice 6 preserves provider turn id, item id, tool kind, bounded summaries, exit code, duration when present, and provider item/status scalar metadata for migrated Codex tool events.
- Approval requests are answered immediately; denied and unsupported request status text now also publishes bounded diagnostic telemetry.
- Reasoning and assistant deltas drop item id, turn id, index, and ordering metadata.
- App-server errors, compaction, hooks, model reroutes, warnings, guardian review, process output/exit, realtime, thread status/name/goal, and several other notifications are currently ignored.

## Provenance Boundary Today

Execution telemetry remains bmux-owned high-frequency runtime state. The
agent-chat app-server path does not write canonical telemetry to Provenance
Engine, and the live projection is not durable.

After accepted Provenance Engine Slice E, bmux production provenance defaults
use the engine-owned store for selected durable evidence, lifecycle writes,
worktree observation writes, schema identity, and deterministic Current State.
Those durable evidence paths stay separate from the high-frequency execution
telemetry stream. The current app-side projection records only broad sidecar
session/provider/lifecycle presence facts through the public
`recordSessionLifecycle(...)` SDK path.

## Durable Execution Evidence Policy

The first dogfood pass of the read-only diagnostic confirmed that a real live
Codex sidecar session can have provider identity and an idle live projection
while Provenance Engine Current State has no matching active lifecycle
evidence. That was an expected boundary mismatch before a durable lifecycle
producer was selected. Supported lifecycle-backed live sessions can now match
Current State because the narrow producer records only broad lifecycle facts.

Execution telemetry is therefore still not durable provenance evidence by
default. The implemented explicit producer projects only broad
session/provider/lifecycle facts into Provenance Engine:

- bmux session id and provider kind;
- provider session id when available;
- repository or worktree association when bmux can derive it within the
  existing provenance boundary;
- broad lifecycle presence such as active/running versus inactive/idle.

The following remain outside durable provenance by default: message text and
deltas, private reasoning, tool inputs and outputs, command output, raw provider
envelopes, raw errors, changed file paths, approval request payloads, and token
usage details.

## Target Direction For Later Slices

Slice 1 defines the common telemetry contract in
`agent-chat/executionTelemetryTypes.ts`, outside React component code and
outside the current `AgentEvent` UI schema. Slice 2 introduced the first
sidecar-owned fanout/projection seam so this direction is possible:

```text
Raw Codex app-server notification
        |
        v
ExecutionEventEnvelope
        |
        +--> AgentEvent UI projection
        +--> live bmux/native projection
        +--> future bounded telemetry store
        +--> current narrow lifecycle provenance projection
        +--> future selected durable projections
```

The reverse direction should remain prohibited: raw provider event -> AgentEvent/status string -> reconstructed execution telemetry.

## Slice 1 Ownership Boundary

The sidecar owns the canonical envelope fields: bmux session id, event id,
per-session sequence, captured timestamp, provider id, provider session id, and
provider turn id. Provider adapters own bounded normalization from provider
messages into typed event payloads. React owns only the current render
projection. Native Swift consumes the bounded live projection JSON payload but
should not define an independent schema. Provenance Engine owns only explicitly
selected durable evidence written through the public SDK, not high-frequency
telemetry.
