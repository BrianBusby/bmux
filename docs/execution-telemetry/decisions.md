# Execution Telemetry Decisions

## 2026-07-28 - Slice 0 Is Audit-Only

Decision: Slice 0 records current behavior and does not introduce production runtime code, event contracts, persistence, or UI behavior changes.

Rationale: The requested plan has an explicit review gate after Slice 0. The repository first needs an accurate map of the existing structured Codex path and its lossy boundaries.

Alternatives rejected: start implementing an event bus immediately; patch the current `AgentEvent` union to carry more fields.

Consequences: Slice 1 starts from documented evidence rather than chat history, and the React experience remains unchanged.

## 2026-07-28 - Treat AgentEvent As Current UI Projection

Decision: The Slice 0 audit classifies `AgentEvent` as the current UI/replay projection, not as a suitable canonical execution telemetry contract.

Rationale: `AgentEvent` drops provider turn identity, numeric usage fields, operation timestamps, structured approval lifecycle, and provider metadata. React also duplicates the type in `agent-chat/src/session.ts`, confirming it is coupled to rendering.

Alternatives rejected: promote `AgentEvent` directly to the provider-neutral contract.

Consequences: Slice 1 should define a separate contract outside React component code. Slice 2 should project from execution events into `AgentEvent`, not the reverse.

## 2026-07-28 - Keep Provenance Projection Separate

Decision: The audit documents the current absence of app-server-to-provenance writes and keeps future provenance projection as a later policy boundary.

Rationale: Existing provenance-engine contracts are durable engineering records, while Codex app-server emits high-frequency operational lifecycle data. Directly dumping provider events into provenance-engine would violate the storage boundary and privacy goals.

Alternatives rejected: add provenance writes during the audit.

Consequences: Slice 5 should define bounded operational telemetry persistence first. Slice 7 can then choose selected durable projections.

## 2026-07-28 - Canonical Contract Lives In agent-chat

Decision: The provider-neutral telemetry contract lives in `agent-chat/executionTelemetryTypes.ts`.

Rationale: `agent-chat/server.ts` owns sidecar sessions, replay ordering, provider process lifecycles, and future non-UI fanout. React and `webviews/src/agent-session/shared` are projections or separate packages, not owners of sidecar execution state.

Alternatives rejected: put the canonical contract in React session state; put it in webview shared code; keep the contract docs-only.

Consequences: Slice 2 can add a sidecar-owned bus without importing React. `AgentEvent` remains the current UI projection.

## 2026-07-28 - Sidecar Owns Event Identity And Ordering

Decision: The sidecar assigns opaque `eventId` values, per-session numeric `sequence` values, and `capturedAtMs` timestamps in `TelemetryEventEnvelope`.

Rationale: Provider protocols expose inconsistent ids and timestamps. A bmux-local sequence is the only stable replay order across provider, sidecar, Git observer, and future native-hook sources.

Alternatives rejected: rely on provider timestamps for ordering; require every provider event to expose a provider sequence; parse structure out of `eventId`.

Consequences: Consumers order by `(sessionId, sequence)`. `capturedAtMs` is diagnostic metadata, not the ordering source.

## 2026-07-28 - Retain Bounded Provider References, Not Raw Envelopes

Decision: The telemetry envelope may keep bounded provider references in `providerEvent` and small scalar facts in `metadata`, but it must not carry raw provider envelopes.

Rationale: Raw provider envelopes can include unrestricted transcript, tool output, diffs, paths, or policy-sensitive fields. The contract should preserve ids and numeric lifecycle facts without creating an unbounded persistence or privacy path.

Alternatives rejected: add `raw` or `providerPayload` to every event; drop all provider references.

Consequences: Later slices may keep temporary private debug logs or fixtures outside the canonical stream, but the canonical event contract stays bounded.

## 2026-07-28 - Swift Consumes Versioned JSON, Not A Parallel Schema

Decision: The `agent-chat` type module remains the source of truth until a native subscriber exists. Swift should consume the versioned JSON envelope and add drift checks or fixtures in the same slice that adds the decoder.

Rationale: Hand-maintained Swift and sidecar event unions would drift before the native bridge exists.

Alternatives rejected: add Swift mirror types in Slice 1; move the canonical contract to Swift first.

Consequences: Slice 1 changes no Swift code. A future native bridge must include schema drift validation.

## 2026-07-28 - Fanout Publishes Telemetry Before UI Projection

Decision: Slice 2 introduces `ExecutionTelemetryFanout` as a per-session
sidecar object that assigns canonical envelope fields, notifies telemetry
subscribers, and projects envelopes to the existing `AgentEvent` stream.

Rationale: Identity and replay ordering must have one sidecar owner before
providers are migrated. Keeping `AgentEvent` as the final projection preserves
React behavior while giving future non-UI subscribers a typed event path.

Alternatives rejected: reconstruct telemetry from `AgentEvent`; rewrite Codex
normalization in the same slice; add persistence or provenance writes now.

Consequences: Provider adapters can migrate incrementally to
`SessionCtx.emitTelemetry`. Until they do, existing `SessionCtx.emit` events
remain the UI path only and are not treated as canonical telemetry.

## 2026-07-28 - Migrate Codex Prompt And Linkage First

Decision: Slice 3 migrates only Codex prompt submission and provider session
linkage (`thread/start` and `thread/fork`) to `SessionCtx.emitTelemetry`.
Non-Codex prompt echoes and the rest of the Codex adapter continue using the
existing `AgentEvent` path until later narrow slices.

Rationale: These events are small, deterministic, and already project to simple
`user` and `meta` UI events. They prove provider-owned telemetry can fan out
before React projection without changing rendering, WebSocket payload shape,
persistence, provenance, Swift ownership, or Claude source selection.

Alternatives rejected: migrate all Codex adapter events in one slice; migrate
all providers' prompt echoes through telemetry; introduce persistence while
moving the first provider events.

Consequences: The telemetry fanout now has its first production Codex producer
path, but high-volume turn, message, tool, approval, usage, and diagnostic
Codex events still need future focused migrations.

## 2026-07-28 - Migrate Codex Turn Lifecycle With Projection-Only Generation

Decision: Slice 4 migrates Codex `turn/started`, `turn/completed`, and
`turn/failed` notifications to `SessionCtx.emitTelemetry`. The server-only
`done.generation` field used for file-change attribution is carried as a
projection option, not as canonical telemetry envelope data.

Rationale: Turn lifecycle events preserve bounded provider facts such as method,
thread id, turn id, duration, token totals, model/effort, and error code/message.
The existing React `AgentEvent` stream still needs the private generation value
to defer file-change events into the correct turn, but that value is an
implementation detail of the current UI projection rather than provider-neutral
execution telemetry.

Alternatives rejected: store `generation` in envelope metadata; drop generation
from projected `done` events; keep Codex turn lifecycle on direct `AgentEvent`
emits until a broader server attribution rewrite.

Consequences: Codex turn lifecycle now has a canonical producer path without
changing React rendering, WebSocket payload shape, persistence, provenance,
Swift ownership, Claude source selection, or non-Codex behavior. Message, tool,
approval, usage, and diagnostic Codex events still need future narrow migrations.

## 2026-07-29 - Migrate Codex Message Lifecycle Without Tool Changes

Decision: Slice 5 migrates Codex assistant text deltas, reasoning deltas, and
completed non-streamed assistant messages to `SessionCtx.emitTelemetry`. Codex
tool lifecycle, approval lifecycle, standalone usage observations, diagnostics,
and unsupported request status messages remain on their existing paths.

Rationale: Message events already have a provider-neutral contract and fanout
projection to the existing `delta`, `thinking`, and `assistant` UI events. This
is a narrow producer migration that preserves the duplicate-suppression behavior
for streamed assistant messages before touching tool or approval semantics.

Alternatives rejected: migrate message and tool lifecycle together; emit
completed assistant telemetry for streamed messages that the UI currently
suppresses; add persistence while migrating transcript events.

Consequences: Codex text message lifecycle now has a canonical producer path
without changing React rendering, WebSocket payload shape, persistence,
provenance, Swift ownership, Claude source selection, or non-Codex behavior.
Tool, approval, usage, and diagnostic Codex events still need future narrow
migrations.

## 2026-07-29 - Migrate Codex Tool Lifecycle With Legacy UI Projection

Decision: Slice 6 migrates Codex `item/started` and `item/completed` tool
lifecycle notifications to `SessionCtx.emitTelemetry` for command execution,
file changes, web search, and MCP tool calls. The existing `tool-start` /
`tool-end` React projection remains unchanged, including current names,
summaries, and success calculation.

Rationale: Tool lifecycle events already have a provider-neutral contract and
are the next bounded Codex path after message lifecycle. Preserving the legacy
projection keeps React/WebSocket behavior stable while capturing provider
session id, turn id, item id, tool kind, bounded input/output summaries,
exit code, duration when present, and provider item/status scalar metadata for
non-UI consumers.

Alternatives rejected: migrate approval requests together with tool lifecycle;
store raw provider items in telemetry metadata; change the UI success behavior
for provider statuses that were previously treated as successful by the
display-oriented `AgentEvent` projection.

Consequences: Codex tool lifecycle now has a canonical producer path without
changing React rendering, WebSocket payload shape, persistence, provenance,
Swift ownership, Claude source selection, or non-Codex behavior. Approval,
standalone usage, diagnostic, and unsupported request status Codex events still
need future narrow migrations.

## 2026-07-29 - Migrate Codex Approval Lifecycle Without UI Projection Changes

Decision: Slice 7 migrates Codex JSON-RPC approval requests to
`SessionCtx.emitTelemetry` by publishing `approval.requested` and
`approval.resolved` envelopes for approved, denied, and unsupported request
outcomes. Approval telemetry keeps bounded provider references and summaries,
while existing denial and unsupported-request `status` messages remain direct
`AgentEvent` emits.

Rationale: Approval requests are the next bounded Codex lifecycle path after
tool events and already have provider-neutral contract variants. The current
React projection intentionally has no approval block, so keeping approval
telemetry projection-free preserves rendering while making request id, method,
approval kind, operation id, summary, decision, and reason observable to future
non-UI consumers.

Alternatives rejected: project approval lifecycle into new React events; store
raw JSON-RPC request params or response envelopes in canonical telemetry; fold
unsupported request status messages into diagnostics in the same slice.

Consequences: Codex approval lifecycle now has a canonical producer path
without changing React rendering, WebSocket payload shape, persistence,
provenance, Swift ownership, Claude source selection, or non-Codex behavior.
Standalone usage and diagnostic Codex events still need future narrow
migrations.

## 2026-07-29 - Migrate Codex Standalone Usage Without UI Projection Changes

Decision: Slice 8 migrates Codex `thread/tokenUsage/updated` notifications to
`SessionCtx.emitTelemetry` by publishing bounded `usage.updated` envelopes,
while preserving the existing buffered usage path that attaches matching usage
to `turn.completed` for current React `done.stats`.

Rationale: Usage observations are bounded numeric provider facts that already
fit the provider-neutral contract and currently have no standalone React UI
projection. Publishing them directly lets future non-UI consumers observe token
updates before turn completion without changing WebSocket rendering behavior.

Alternatives rejected: store the raw provider `tokenUsage` envelope; move
completion stats exclusively to standalone usage telemetry; migrate diagnostics
in the same slice.

Consequences: Codex standalone usage observations now have a canonical producer
path without changing React rendering, WebSocket payload shape, persistence,
provenance, Swift ownership, Claude source selection, or non-Codex behavior.
Diagnostic Codex events still need a future narrow migration.

## 2026-07-29 - Migrate Codex Request-Status Diagnostics With Legacy Projection

Decision: Slice 9 migrates the Codex denied-approval and unsupported-request
status messages to `SessionCtx.emitTelemetry` by publishing bounded
`diagnostic` envelopes. The existing React `status` projection keeps the same
message text.

Rationale: These messages are the first narrow diagnostic path that already has
clear provider request identity and bounded display text. Keeping the current
UI projection stable avoids rendering or WebSocket schema changes while making
request id, method, provider session id, level, code, and message observable to
future non-UI consumers.

Alternatives rejected: migrate transport/send failures in the same slice; emit
raw JSON-RPC request or response envelopes; introduce new React diagnostic
blocks.

Consequences: Codex request-status diagnostics now have a canonical producer
path without changing React rendering, WebSocket payload shape, persistence,
provenance, Swift ownership, Claude source selection, or non-Codex behavior.
Broader Codex transport failure diagnostics and ignored app-server
notifications remain deferred.

## 2026-07-29 - Migrate Codex Send-Failure Diagnostics With Done Close-Out

Decision: Slice 10 migrates the Codex `send` catch path to
`SessionCtx.emitTelemetry` by publishing a bounded `diagnostic` envelope for the
failed send operation. The existing React `error` projection keeps the same
message text, and the existing direct `done` close-out is preserved as
projection-only UI behavior.

Rationale: Send failures from app-server startup, thread creation, turn start,
or steering already collapse to a bounded error message and a current operation
label. Publishing that diagnostic preserves useful provider/turn references for
non-UI consumers without storing raw errors, JSON-RPC envelopes, provider
params, or changing the UI turn-closing contract.

Alternatives rejected: migrate app-server process-exit diagnostics in the same
slice; store raw thrown errors in telemetry metadata; change diagnostic
projection so it also synthesizes `done` events.

Consequences: Codex send-failure diagnostics now have a canonical producer path
without changing React rendering, WebSocket payload shape, persistence,
provenance, Swift ownership, Claude source selection, or non-Codex behavior.
App-server process-exit diagnostics and ignored app-server notifications remain
deferred.

## 2026-07-29 - Migrate Codex App-Server Exit Diagnostics With Done Close-Out

Decision: Slice 11 migrates the Codex app-server stdout-close mid-turn path to
`SessionCtx.emitTelemetry` by publishing a bounded `diagnostic` envelope for
the process-exit condition. The existing React `error` projection keeps the
same message text, and the existing direct `done` close-out is preserved as
projection-only UI behavior.

Rationale: A Codex app-server exit during an active turn already collapses to a
bounded, display-oriented error message plus a current thread and turn id when
available. Publishing that diagnostic preserves useful provider/turn references
for non-UI consumers without storing process handles, raw errors, JSON-RPC
envelopes, provider params, or changing the UI turn-closing contract.

Alternatives rejected: migrate ignored app-server notifications in the same
slice; store raw process state in telemetry metadata; change diagnostic
projection so it also synthesizes `done` events.

Consequences: Codex app-server exit diagnostics now have a canonical producer
path without changing React rendering, WebSocket payload shape, persistence,
provenance, Swift ownership, Claude source selection, or non-Codex behavior.
Ignored app-server notifications remain deferred.

## 2026-07-29 - Live Session Projection Replays One Ordered Telemetry Stream

Decision: Plan Slice 4A adds a renderer-independent live session projection in
`agent-chat` that consumes ordered `TelemetryEventEnvelope` values for exactly
one bmux session/provider stream and rejects mixed-session or mixed-provider
replay input.

Rationale: The sidecar already owns canonical event identity and per-session
sequence ordering. A live projection should trust that ordered canonical stream
directly, rather than reconstructing state from React `AgentEvent` history or
provider-specific raw envelopes.

Alternatives rejected: parse existing React history back into lifecycle state;
accept mixed-session replay and silently pick the latest identity; introduce
server persistence or a native bridge in the same slice.

Consequences: `LiveSessionProjection` can deterministically derive a small
snapshot with session/provider identity, provider session/turn ids, lifecycle
state, active tool-operation count, latest activity timestamp from the most
recently applied envelope, latest usage and diagnostic summaries, pending
approval-blocked state, and a unique files-changed count. React rendering and
WebSocket `AgentEvent` payload behavior remain unchanged.

## 2026-07-29 - Live Projection Read Surface Is In-Memory And REST-Only

Decision: Plan Slice 4B wires `LiveSessionProjectionStore` to each sidecar
session's `ExecutionTelemetryFanout` as an in-memory subscriber and exposes the
latest bounded projection through `GET /api/sessions/:id/execution-telemetry/live`.

Rationale: The live projection needs a sidecar-owned read surface before a
native bridge or persistence layer can consume it. Keeping the surface in
process memory and REST-only proves the subscriber/read boundary without
changing React rendering, WebSocket `AgentEvent` payloads, replay history,
persistence, provenance writes, or Swift schema ownership.

Alternatives rejected: publish live projection updates over the existing
WebSocket stream; append projection snapshots to `Session.events`; persist
projection snapshots; add the native bridge in the same slice.

Consequences: Consumers can poll a small `{ sessionId, snapshot }` payload,
where `snapshot` is `null` until canonical telemetry exists. The snapshot is
derived only from assigned `TelemetryEventEnvelope` values and remains bounded;
it does not expose raw provider envelopes, raw errors, command output,
transcripts, private reasoning, or changed file paths.

## 2026-07-29 - Native Client Consumes Live Projection JSON Only

Decision: Plan Slice 4C adds a Swift REST read client for the bounded live projection payload without making Swift the canonical telemetry schema owner.

## 2026-07-29 - Reconcile With Provenance Slice E Boundary

Decision: Execution telemetry remains bmux-owned high-frequency runtime state
after reconciling with the Slice E mainline baseline. Provenance Engine Slice E
is complete and owns selected durable evidence plus deterministic Current
State.

Consequence: compare live telemetry with Current State only as a bounded
observation diagnostic unless a later policy slice selects durable execution
facts for provenance writes.

## 2026-07-30 - Durable Execution Evidence Remains Opt-In

Decision: The live execution telemetry stream is not durable provenance
evidence by default. After dogfooding the observation diagnostic, the only
execution telemetry facts eligible for a future durable provenance projection
are broad session/provider/lifecycle facts:

- bmux session id and provider kind;
- provider session id when the provider exposes one;
- repository or worktree association when bmux can determine it without raw
  path leakage beyond the existing provenance boundary;
- broad lifecycle presence such as active/running versus inactive/idle.

All other execution telemetry remains out of durable provenance scope unless a
later policy slice explicitly selects it. That includes message text and
deltas, private reasoning, tool inputs and outputs, command output, raw
provider envelopes, raw errors, changed file paths, approval request payloads,
and token usage details.

Rationale: Local dogfood of
`bmux provenance diagnostics execution-telemetry-live 05384b5e` reported one
bounded mismatch, `current_state_session_missing`, for a real Codex sidecar
session that had live provider identity and an idle projection but no durable
Current State lifecycle evidence. That mismatch is useful observation data, not
a reason to dump the telemetry stream into Provenance Engine.

Alternatives rejected: write every live session snapshot to Provenance Engine;
persist the canonical telemetry stream first and decide policy later; treat
usage, transcript, tool, approval, or diagnostic details as durable engineering
evidence by default.

Consequences: A future implementation slice may add a narrow producer that
records only the eligible broad session/provider/lifecycle facts through public
Provenance Engine APIs. That slice must still avoid telemetry persistence,
broad provenance writes, raw provider data, React rendering changes, WebSocket
payload changes, Swift schema ownership, and automatic diagnostic checkpoint
scheduling unless those are separately selected.

## 2026-07-30 - Migrate Only Claude Lifecycle And Identity Facts

Decision: The first non-Codex provider migration selects only Claude sidecar
prompt submission, stream-json `system/init` provider session identity, Claude
stream-json `result` completion/result-error closure, and sidecar
process-close failure closure for canonical telemetry.

Rationale: `agent-chat/adapters/claude.ts` has structured stream-json events,
but they do not expose Codex-parity turn ids, token usage, structured changed
files, or a selected safe tool lifecycle source. The audited authoritative
facts are enough to make the live projection lifecycle/provider identity useful
for Claude sessions without widening the privacy or provenance boundary.

Alternatives rejected: migrate Claude message deltas, thinking deltas,
tool-use/tool-result blocks, command lists, status/control responses, cost
display stats, raw stream-json envelopes, or token usage assumptions in the
same slice; synthesize provider turn ids for Claude.

Consequences: Claude live telemetry can report sidecar session id, provider
kind, provider session id when `system/init` arrives, and broad running versus
idle/failed lifecycle. React `AgentEvent` behavior remains unchanged, and
Claude message/tool/content events remain direct UI projection until a later
bounded source-selection slice.
