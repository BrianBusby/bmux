# Execution Telemetry Persistence Policy

Status: current policy after the live projection and narrow lifecycle producer
merged to `main`.

## Current Persistence

There is no durable execution-telemetry store. `agent-chat/server.ts` retains
`Session.events` only in sidecar process memory, capped by
`MAX_SESSION_EVENTS = 5000`, and the live execution telemetry projection is
also an in-memory sidecar snapshot.

The one durable projection now implemented is intentionally narrow:
`ExecutionTelemetryProvenanceProjectionService` records only approved broad
sidecar session/provider/lifecycle presence facts through the existing public
Provenance Engine lifecycle SDK path. That is durable provenance evidence, not
general execution-telemetry persistence.

Adjacent stores are not the execution telemetry store:

- `Session.events`: replayable UI transcript events in memory.
- `~/.bmuxterm/<agent>-hook-sessions.json`: native hook session records.
- `~/.bmuxterm/events.jsonl`: bounded app event log.
- Codex `~/.codex/state_N.sqlite` and rollout JSONL: provider-owned state.
- provenance-engine database: durable engineering provenance and selected
  broad lifecycle facts.

## Initial Retention Categories

- `retain_structured`: typed ids, event types, timestamps, numeric tokens, numeric durations, exit codes, and status enums.
- `retain_bounded`: capped command previews, short errors, and small summaries.
- `retain_hash_only`: large output, large diffs, and repeated command signatures.
- `retain_summary_only`: aggregate counts and checkpoint feature counts.
- `transient_only`: streaming assistant/reasoning deltas and animation state.
- `never_retain`: secrets, credentials, unrestricted transcripts, and private reasoning content beyond explicit supported summaries.

## Provenance Boundary

Do not write every execution event to provenance-engine.

The accepted durable projection is limited to broad session/provider/lifecycle
facts and derived worktree association when available. Raw and high-frequency
telemetry remains bmux-owned runtime state.

Potential future durable projections require a separate policy slice and may
include parent/child relationships, meaningful file-change evidence,
validation results, generated artifacts, explicit decisions, and checkpoint
summaries linked to engineering results.

Telemetry-only by default includes every tool start/end, streaming deltas, token updates, transient status changes, repetitive retries, and raw command output.
