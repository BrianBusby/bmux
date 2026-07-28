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
