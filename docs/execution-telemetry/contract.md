# Telemetry Contract

Status: Slice 11 provider-neutral contract, sidecar fanout seam, first Codex
lifecycle migrations, first narrow Claude lifecycle/identity migration, Plan
Slice 4B live projection sidecar read surface, Plan Slice 4C native read
client, observation diagnostic, and durable execution-evidence policy.

Canonical bmux roadmap reconciliation note: Provenance Engine Slice E is
operationally complete on main, and the active product gate is the Engineering
Observation Period. Execution telemetry Plan Slice 4B is unrelated to
Provenance Engine Slice E numbering.

The sidecar fanout path has been added without persistence, provenance
projection, React behavior changes, or broad provider rewrites. Slices 3 through
11 route Codex prompt submission, provider session linkage, turn lifecycle,
message lifecycle, tool lifecycle, approval lifecycle, and standalone usage
observations plus request-status, send-failure, and app-server exit diagnostics
through the seam. The first Claude migration routes only sidecar prompt
submission, `system/init` provider session identity, Claude `result`
completion/result-error closure, and sidecar process-close failure closure
through the same seam.
Plan Slice 4B attaches an in-memory live projection subscriber to each sidecar
session and exposes a bounded REST read payload without changing React or
WebSocket `AgentEvent` behavior. Plan Slice 4C adds Swift DTOs and an injected
HTTP read client for that existing payload without making Swift the schema
owner.

## Contract Location

The canonical contract lives in `agent-chat/executionTelemetryTypes.ts`.

That module is owned by the agent-chat sidecar package because the sidecar owns
provider process lifecycles, bmux-local session ids, provider session linkage,
event replay order, and future non-UI fanout.

It is deliberately outside `agent-chat/src/session.ts`, which remains the React
projection, and outside `webviews/src/agent-session/shared`, which is a
separate webview package.

`agent-chat/types.ts` remains the current WebSocket UI schema for Slice 11.
`AgentEvent` must not become the canonical telemetry contract and must not be
parsed back into telemetry.

## Ownership Boundaries

- The sidecar session manager owns `eventId`, per-session `sequence`,
  `capturedAtMs`, bmux `sessionId`, replay ordering, and subscriber fanout.
- Provider adapters own provider-specific normalization into the typed event
  payloads, plus bounded provider references such as method, request id, item
  id, turn id, and provider session id.
- React owns only the current `AgentEvent -> Block[]` render projection.
- Native Swift owns future display or notification projections after a bridge is
  added; it does not own this source of truth.
- Provenance Engine owns selected durable evidence and deterministic Current
  State. It is not a high-frequency execution telemetry store and does not
  receive this canonical stream unless a later policy slice selects specific
  execution facts as durable engineering evidence.

The current durable execution-evidence policy selects no automatic telemetry
persistence or provenance writes. Only broad session/provider/lifecycle facts
are eligible for a future explicit projection slice: bmux session id, provider
kind, provider session id when available, repository/worktree association within
the existing provenance boundary, and broad active/running versus inactive/idle
lifecycle presence.

## Envelope Rules

Every future bus publish should wrap one `TelemetryEvent` in a
`TelemetryEventEnvelope`.

- `schema` is currently `bmux.execution-event.v1`.
- `eventId` is an opaque sidecar-assigned id. Consumers must not parse it.
- `sequence` is the authoritative replay order within one bmux session. It is
  sidecar-assigned, starts at the first emitted telemetry event, and increments
  by one for every envelope in that session.
- `capturedAtMs` is wall-clock milliseconds when the sidecar accepted or
  synthesized the event. It is useful for diagnostics but not authoritative for
  ordering.
- `providerSessionId` and `providerTurnId` retain provider identity when the
  provider exposes it. They may be absent for providers or hook paths that do
  not expose stable ids.
- `providerEvent` may retain bounded source references such as app-server
  method, JSON-RPC request id, provider item id, provider turn id, or provider
  sequence. It must not contain the raw provider envelope.
- `metadata` is for small provider-neutral or provider-specific scalar facts
  and scalar lists. It is not a transcript, command-output, diff, nested
  object payload, or raw-envelope escape hatch.

## Sidecar Fanout

`agent-chat/executionTelemetryFanout.ts` owns the first runtime publish seam.
It accepts `TelemetryEventEnvelopeDraft` values, overwrites all sidecar-owned
envelope fields, notifies telemetry subscribers with the assigned envelope, and
projects the envelope to the existing `AgentEvent` UI stream.

`TelemetryEventEnvelopeDraft` is intentionally assignable from a full
`TelemetryEventEnvelope` so future provider adapters or hook paths can pass
envelope-shaped objects, but `schema`, `eventId`, `sessionId`, `sequence`,
`capturedAtMs`, and `provider` are still assigned by the sidecar fanout.

`SessionCtx.emitTelemetry` and `SessionCtx.subscribeTelemetry` are optional
seams for future producers and subscribers. Most adapters and the remaining
non-migrated Codex ignored app-server notification paths still no-op or emit
the current `AgentEvent` stream directly until later slices migrate specific
provider events. The reverse direction remains prohibited: do not reconstruct
canonical telemetry from `AgentEvent`.

`TelemetryPublishProjectionOptions` carries sidecar-local projection details
that must not be copied into canonical envelopes. It preserves private
`done.generation`, Claude display-only `done.stats`, and Claude init `meta`
model projection details while projecting canonical envelopes back to
`AgentEvent`.

## Live Projection Read Surface

`agent-chat/executionTelemetryLiveProjection.ts` owns the renderer-independent
live projection and `LiveSessionProjectionStore`. The store subscribes to
assigned `TelemetryEventEnvelope` values from the session fanout and keeps only
the latest bounded snapshot in memory.

The current sidecar read endpoint is:

```text
GET /api/sessions/:id/execution-telemetry/live
```

It returns `{ sessionId, snapshot }`, with `snapshot: null` until canonical
telemetry exists. This endpoint must not expose raw provider envelopes, raw
errors, command output, transcripts, private reasoning, or changed file paths.

`Packages/Shared/BmuxAgentChat` consumes this payload through
`ExecutionTelemetryLiveProjectionClient`. Swift reads this bounded JSON shape
only; the canonical event union remains in `agent-chat`.

## Minimal Event Set

The Slice 1 union covers the events required to preserve the fields that the
current Codex path drops before non-UI consumers can observe them:

- Session lifecycle: `session.started`, `session.provider-linked`.
- User input: `prompt.submitted`.
- Turn lifecycle: `turn.started`, `turn.completed`, `turn.failed`.
- Text streams: `message.delta`, `message.completed`.
- Tool lifecycle: `tool.started`, `tool.completed`.
- Approval lifecycle: `approval.requested`, `approval.resolved`.
- Usage observations: `usage.updated`.
- File changes: `files.changed` from provider structured events or the current
  Git observer.
- Context lifecycle: `context.compacted`.
- Diagnostics: `diagnostic` for provider warnings, errors, ignored unsupported
  requests, and sidecar status checkpoints.

This set is intentionally smaller than the full Codex app-server schema. Later
slices may add variants when a real producer needs them, but they should not add
catch-all raw-provider variants.

## Swift Sync Policy

This contract is the source of truth until a native subscriber is implemented.
Swift must consume a versioned JSON envelope, not hand-maintain an independent
schema.

When a Swift decoder is added, add fixtures or generated schema checks from
`agent-chat/executionTelemetryTypes.ts` in the same slice so drift is visible in
CI.

## Deferred Work

The first Claude migration does not:

- claim Claude parity with Codex;
- migrate Claude message deltas, thinking deltas, tool use/result blocks,
  slash command lists, option/status control responses, token usage, file
  changes, or raw stream-json envelopes;
- add telemetry persistence;
- write to provenance-engine;
- change React rendering or WebSocket `AgentEvent` payload behavior.

Plan Slice 4B still does not add telemetry persistence, provenance writes,
Swift/native bridge decoding, React rendering changes, WebSocket `AgentEvent`
payload changes, broader Claude provider migration, or automatic diagnostic
checkpoint scheduling.

The durable execution-evidence policy still does not allow message text,
deltas, private reasoning, tool inputs or outputs, command output, raw provider
envelopes, raw errors, changed file paths, approval request payloads, or token
usage details to become durable provenance evidence by default.
