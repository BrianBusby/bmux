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

## Current Ownership Boundaries

`agent-chat/server.ts` owns the current agent-chat session object: bmux-local session id, provider id, cwd, title, auto-approve flag, status, adapter-private state, sockets, created-at timestamp, and replayable `events`.

`agent-chat/adapters/codex.ts` owns Codex app-server process state: one shared `codex app-server` process per sidecar, JSON-RPC request ids, pending requests, `sessionsByThread` keyed by Codex `threadId`, and per-session Codex state in `sess.internal.codex`.

React does not own provider session identity or app-server lifecycle. React owns only a browser-side projection: `agent-chat/src/session.ts` duplicates the `AgentEvent` union and `foldEvent()` maps events into renderable `Block` values.

Native Swift does not currently subscribe to the TypeScript `AgentEvent` stream. `Sources/AppDelegate+AgentChat.swift` only starts or opens the sidecar URL in a browser surface. The shared Swift package `Packages/Shared/BmuxAgentChat` models native chat transcripts and hook-derived agent kinds, but this audit did not find a bridge from TypeScript `AgentEvent` to that package.

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

Existing provider adapters still call `SessionCtx.emit(AgentEvent)` directly,
so React WebSocket payloads and `foldEvent()` behavior are unchanged in Slice
2. Later slices should migrate provider events by publishing
`TelemetryEventEnvelopeDraft` values first and treating `AgentEvent` as the
fanout projection only.

## Current Lossy Boundary

The lossy boundary is inside `agent-chat/adapters/codex.ts`, primarily `handleServerMessage()`, `itemStarted()`, and `itemCompleted()`. Raw Codex notifications are reduced directly into `AgentEvent`, whose schema is display-oriented.

Important reductions:

- `turn/completed` token usage and duration become a display string in `done.stats`.
- `thread/tokenUsage/updated` stores only `tokenUsage.total` in `sess.internal.lastUsage`; `tokenUsage.last`, cached-input tokens, reasoning-output tokens, total tokens, model context window, and `turnId` do not reach `AgentEvent`.
- Tool events drop provider turn id, timestamps, cwd, process id, numeric duration, command actions, source, MCP server/plugin details, structured results, and several item variants.
- Approval requests are answered immediately and reduced to status text only when denied or unsupported.
- Reasoning and assistant deltas drop item id, turn id, index, and ordering metadata.
- App-server errors, compaction, hooks, model reroutes, warnings, guardian review, process output/exit, realtime, thread status/name/goal, and several other notifications are currently ignored.

## Provenance Boundary Today

The app-server path does not currently call provenance-engine. Searches for `ProvenanceEngineContracts`, `ProvenanceEngineSDK`, `WorkProvenanceStore`, and subsession lifecycle paths led to Swift/CLI code rather than `agent-chat`.

Current provenance-related code includes `CLI/BMUXCLI+Provenance.swift`, `CLI/CLIProvenanceContext.swift`, `CLI/bmux.swift`, `bmuxTests/SubsessionProvenanceTests.swift`, and `provenance-engine/Sources/ProvenanceEngineContracts`.

This means Codex app-server lifecycle telemetry currently reaches the React agent-chat UI, but not provenance-engine.

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
        +--> future selected provenance projection
```

The reverse direction should remain prohibited: raw provider event -> AgentEvent/status string -> reconstructed execution telemetry.

## Slice 1 Ownership Boundary

The sidecar owns the canonical envelope fields: bmux session id, event id,
per-session sequence, captured timestamp, provider id, provider session id, and
provider turn id. Provider adapters own bounded normalization from provider
messages into typed event payloads. React owns only the current render
projection. Native Swift can consume a future JSON bridge but should not define
an independent schema. provenance-engine remains a later selected projection,
not the owner of high-frequency telemetry.
