# Execution Telemetry

This directory tracks the provider-neutral execution telemetry effort.

Execution telemetry is the high-frequency lifecycle record of an agent session: session and turn boundaries, tool activity, approvals, usage observations, provider errors, file-change summaries, and diagnostic checkpoints. It is operational evidence for live state, diagnostics, replay, and analytics.

Provenance is narrower. Provenance records durable engineering facts and evidence, such as a session contributing to a work item, a meaningful file-change attribution, a validation result, a generated artifact, or a selected lifecycle summary. Most execution events should never be written directly to provenance-engine.

## Documents

- `architecture.md`: current and target ownership boundaries.
- `contract.md`: Slice 1 provider-neutral telemetry contract and ownership policy.
- `event-inventory.md`: current Codex event mappings, lost fields, and persistence/provenance decisions.
- `provider-capabilities.md`: provider capability matrix.
- `persistence-policy.md`: initial retention categories and separation from provenance.
- `implementation-status.md`: active slice status and validation notes.
- `decisions.md`: short architecture decision records.
- `handoffs/latest.md`: required entry point for the next Codex session.

## Current Generated Status

Current execution-telemetry capability state and the active bmux-local slice are
generated from `project/repo-status.yaml`:

- [Repository status](../generated/repository-status.md)
- [Project status](../generated/project-status.md)
- [Ownership boundary](../generated/ownership-boundary.md)

Do not update this README with active gates, PR state, or current slice status.
