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
