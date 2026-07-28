# Execution Telemetry Persistence Policy

Status: initial Slice 0 policy. No telemetry persistence has been implemented.

## Current Persistence

The app-server agent-chat path currently persists no durable execution telemetry. `agent-chat/server.ts` retains `Session.events` only in sidecar process memory, capped by `MAX_SESSION_EVENTS = 5000`.

Adjacent stores are not the execution telemetry store:

- `Session.events`: replayable UI transcript events in memory.
- `~/.bmuxterm/<agent>-hook-sessions.json`: native hook session records.
- `~/.bmuxterm/events.jsonl`: bounded app event log.
- Codex `~/.codex/state_N.sqlite` and rollout JSONL: provider-owned state.
- provenance-engine database: durable engineering provenance.

## Initial Retention Categories

- `retain_structured`: typed ids, event types, timestamps, numeric tokens, numeric durations, exit codes, and status enums.
- `retain_bounded`: capped command previews, short errors, and small summaries.
- `retain_hash_only`: large output, large diffs, and repeated command signatures.
- `retain_summary_only`: aggregate counts and checkpoint feature counts.
- `transient_only`: streaming assistant/reasoning deltas and animation state.
- `never_retain`: secrets, credentials, unrestricted transcripts, and private reasoning content beyond explicit supported summaries.

## Provenance Boundary

Do not write every execution event to provenance-engine.

Potential future durable projections include session lifecycle summaries, provider external identity when meaningful, parent/child relationships, meaningful file-change evidence, validation results, generated artifacts, explicit decisions, and checkpoint summaries linked to engineering results.

Telemetry-only by default includes every tool start/end, streaming deltas, token updates, transient status changes, repetitive retries, and raw command output.
