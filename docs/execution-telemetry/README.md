# Execution Telemetry

This directory tracks the provider-neutral execution telemetry effort.

Execution telemetry is the high-frequency lifecycle record of an agent session: session and turn boundaries, tool activity, approvals, usage observations, provider errors, file-change summaries, and diagnostic checkpoints. It is operational evidence for live state, diagnostics, replay, and analytics.

Provenance is narrower. Provenance records durable engineering facts and evidence, such as a session contributing to a work item, a meaningful file-change attribution, a validation result, a generated artifact, or a selected lifecycle summary. Most execution events should never be written directly to provenance-engine.

## Documents

- `architecture.md`: current and target ownership boundaries.
- `event-inventory.md`: current Codex event mappings, lost fields, and persistence/provenance decisions.
- `provider-capabilities.md`: provider capability matrix.
- `persistence-policy.md`: initial retention categories and separation from provenance.
- `implementation-status.md`: active slice status and validation notes.
- `decisions.md`: short architecture decision records.
- `handoffs/latest.md`: required entry point for the next Codex session.

## Current State

Slice 0 is complete as a current-state audit only. No runtime extraction, event bus, persistence, or React behavior change has been implemented.

The structured Codex path currently enters bmux through `agent-chat/adapters/codex.ts`, which talks to `codex app-server` over JSON-RPC/NDJSON. That adapter converts app-server notifications directly into display-oriented `AgentEvent` values from `agent-chat/types.ts`. The server in `agent-chat/server.ts` owns session identity, status, bounded event replay, and WebSocket/REST fanout. React in `agent-chat/src/session.ts` consumes those events and folds them into renderable blocks.

The current structured app-server path does not write to provenance-engine. Existing provenance writes found in this audit are driven by native Swift/CLI hook and provenance paths, especially `CLI/bmux.swift`, `CLI/BMUXCLI+AgentHookCatalog.swift`, `CLI/BMUXCLI+CodexFireAndForgetHooks.swift`, `CLI/BMUXCLI+Provenance.swift`, and `bmuxTests/SubsessionProvenanceTests.swift`.
