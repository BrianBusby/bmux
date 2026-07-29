# Telemetry Contract

Status: Slice 7 provider-neutral contract, sidecar fanout seam, and first Codex lifecycle migrations.

The sidecar fanout path has been added without persistence, provenance
projection, React behavior changes, or broad provider rewrites. Slices 3 through
7 route Codex prompt submission, provider session linkage, turn lifecycle,
message lifecycle, tool lifecycle, and approval lifecycle through the seam.

## Contract Location

The canonical contract lives in `agent-chat/executionTelemetryTypes.ts`.

That module is owned by the agent-chat sidecar package because the sidecar owns
provider process lifecycles, bmux-local session ids, provider session linkage,
event replay order, and future non-UI fanout.

It is deliberately outside `agent-chat/src/session.ts`, which remains the React
projection, and outside `webviews/src/agent-session/shared`, which is a
separate webview package.

`agent-chat/types.ts` remains the current WebSocket UI schema for Slice 7.
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
- provenance-engine owns durable engineering provenance only. It is not an
  execution telemetry store and does not receive this stream in Slice 1.

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
non-migrated Codex usage and diagnostic events still emit the current
`AgentEvent` stream directly until later slices migrate specific provider
events. The reverse direction remains prohibited: do not reconstruct canonical
telemetry from `AgentEvent`.

`TelemetryPublishProjectionOptions` carries sidecar-local projection details
that must not be copied into canonical envelopes. Slice 4 uses this only to
preserve the private `done.generation` value required by current server
file-change attribution while projecting Codex `turn.completed` and
`turn.failed` events back to `AgentEvent`.

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

Slice 7 does not:

- broadly migrate provider events beyond Codex prompt/linkage, turn lifecycle,
  message lifecycle, tool lifecycle, and approval lifecycle;
- add telemetry persistence;
- write to provenance-engine;
- choose or implement a Claude structured event source.
