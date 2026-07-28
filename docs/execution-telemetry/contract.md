# Telemetry Contract

Status: Slice 1 provider-neutral contract. This defines ownership and the
minimal event shape only.

No bus, persistence, provenance projection, or React behavior change has been
implemented.

## Contract Location

The canonical contract lives in `agent-chat/executionTelemetryTypes.ts`.

That module is owned by the agent-chat sidecar package because the sidecar owns
provider process lifecycles, bmux-local session ids, provider session linkage,
event replay order, and future non-UI fanout.

It is deliberately outside `agent-chat/src/session.ts`, which remains the React
projection, and outside `webviews/src/agent-session/shared`, which is a
separate webview package.

`agent-chat/types.ts` remains the current WebSocket UI schema for Slice 1.
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

Slice 1 does not:

- create the bus;
- dual-publish from providers;
- project telemetry into `AgentEvent`;
- add telemetry persistence;
- write to provenance-engine;
- choose or implement a Claude structured event source.
