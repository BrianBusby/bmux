# Execution Telemetry

This directory tracks the provider-neutral execution telemetry effort.

Execution telemetry is the high-frequency lifecycle record of an agent session: session and turn boundaries, tool activity, approvals, usage observations, provider errors, file-change summaries, and diagnostic checkpoints. It is operational evidence for live state, diagnostics, replay, and analytics.

Provenance is narrower. Provenance records durable engineering facts and evidence, such as a session contributing to a work item, a meaningful file-change attribution, a validation result, a generated artifact, or a selected lifecycle summary. Most execution events should never be written directly to provenance-engine.

## Documents

- `architecture.md`: current and target ownership boundaries.
- `contract.md`: Slice 1 provider-neutral telemetry contract and ownership policy.
- `event-inventory.md`: current Codex event mappings, lost fields, and persistence/provenance decisions.
- `provider-capabilities.md`: provider capability matrix.
- `persistence-policy.md`: current retention categories and separation from provenance.
- `implementation-status.md`: merged implementation status, active gate, and validation notes.
- `decisions.md`: short architecture decision records.
- `handoffs/latest.md`: required entry point for the next Codex session.

## Current State

The canonical provider-neutral telemetry contract lives in
`agent-chat/executionTelemetryTypes.ts`. The sidecar-owned fanout seam in
`agent-chat/executionTelemetryFanout.ts` assigns telemetry identity and ordering
in one place, supports sidecar telemetry subscribers, and projects canonical
telemetry envelopes back to the existing React `AgentEvent` UI stream.

Completed Codex migrations publish prompt submission, provider session linkage,
turn lifecycle, message lifecycle, tool lifecycle, approval lifecycle,
standalone usage observations, request-status diagnostics, send-failure
diagnostics, and app-server exit diagnostics through that seam. React rendering
behavior and WebSocket `AgentEvent` payloads remain compatibility projections,
not the canonical telemetry contract.

The renderer-independent live projection in
`agent-chat/executionTelemetryLiveProjection.ts` replays ordered
`TelemetryEventEnvelope` values into a bounded in-memory snapshot. The sidecar
exposes that snapshot through the REST-only read surface
`GET /api/sessions/:id/execution-telemetry/live`. The live projection itself is
not persisted and is not appended to `Session.events`.

`Packages/Shared/BmuxAgentChat` contains the native Swift read client and wire
DTOs for the live projection payload. Shared JSON fixture coverage protects
the TypeScript-to-Swift payload shape from drift while leaving the TypeScript
contract as the schema owner.

`bmux provenance diagnostics execution-telemetry-live <session-id>` is a
read-only observation diagnostic. It compares bounded live projection facts
with Provenance Engine Current State and reports mismatches; it does not write
telemetry or provenance records.

The durable execution-evidence policy is intentionally narrow. Execution
telemetry remains bmux-owned, high-frequency runtime state and is not durable
provenance by default. The implemented durable projection is limited to
approved broad sidecar session/provider/lifecycle facts and derived worktree
association when available. The app-side
`ExecutionTelemetryProvenanceProjectionService` records that narrow subset
through the existing public Provenance Engine SDK lifecycle path. Supported
lifecycle-backed sessions can therefore match Provenance Engine Current State
in the diagnostic.

Raw and high-frequency telemetry remains ephemeral. Message text, reasoning,
command output, raw errors, provider envelopes, changed-file paths, approval
payloads, token details, and the live projection snapshot are not made durable
by this work. Automatic checkpoint scheduling has not been implemented.

## Current Gate

The implemented telemetry foundation is available for observation and dogfood
on `main`. The first non-Codex provider migration, Claude lifecycle telemetry,
is implemented on draft PR #13 and is pending review. No subsequent
execution-telemetry implementation slice is selected. Automatic
5/10/15/20/25-minute diagnostics require a separate explicit policy and
implementation slice.
