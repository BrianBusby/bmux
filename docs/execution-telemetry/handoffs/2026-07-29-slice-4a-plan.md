# Execution Telemetry Handoff

## Session identity

- Date: 2026-07-29
- Slice: Planning handoff after merged Slice 11; next target is Plan Slice 4A
- Branch: `execution-telemetry-live-projection-plan`
- Starting commit: `c32ed93989c8ed8531d9b573bb34b36149461475`
- Previous implementation PR: https://github.com/BrianBusby/bmux/pull/12
- Merged base branch: `execution-telemetry-slice-0`

## Objective completed

Recorded that PR #12 / Slice 11 is merged and selected the next execution
telemetry target: Plan Slice 4A, a live session projection foundation.

## Work completed

- Updated status to point future work at `execution-telemetry-slice-0`.
- Marked the Codex telemetry migration phase as complete enough to stop broad
  Codex migration work.
- Chose live session projection before telemetry persistence, provenance
  projection, Claude structured-source work, diagnostic checkpoint scheduling,
  or broad native UI integration.

## Architecture findings

The migrated Codex app-server paths now publish canonical telemetry envelopes
before projecting to the existing React `AgentEvent` stream. There is still no
telemetry persistence, provenance projection, Swift decoder/native subscriber,
diagnostic checkpoint scheduler, or Claude structured source selection. Ignored
Codex app-server notifications remain deferred unless a specific need appears.

## Decisions made

See `docs/execution-telemetry/decisions.md` entry:
`2026-07-29 - Build Live Projection Before Persistence Or Claude`.

## Tests run

`git diff --check`: passed.

## Known failures or limitations

- No telemetry persistence exists.
- No provenance projection exists.
- No Swift/native subscriber exists.
- No Claude structured-source audit or adapter exists.
- No automatic 5/10/15/20/25 minute diagnostic checkpoints exist.

## Important files for the next session

- `docs/execution-telemetry/implementation-status.md`
- `docs/execution-telemetry/architecture.md`
- `docs/execution-telemetry/decisions.md`
- `docs/execution-telemetry/contract.md`
- `agent-chat/executionTelemetryTypes.ts`
- `agent-chat/executionTelemetryFanout.ts`
- `agent-chat/server.ts`
- `agent-chat/test/execution-telemetry-fanout.test.ts`
- `agent-chat/test/codex-telemetry-migration.test.ts`

## Next slice

Plan Slice 4A - live session projection foundation.

Recommended scope: add an `agent-chat` projection module that consumes ordered `TelemetryEventEnvelope` values and returns a renderer-independent live session state snapshot. Keep the initial state small: session id, provider, provider session id, current provider turn id, lifecycle state, active operation count, latest activity timestamp, latest usage summary, latest diagnostic, approval-blocked state when derivable, and files-changed indicator/count when present. Add focused replay tests and preserve existing React projection behavior.

## First action for the next agent

```bash
git fetch origin
git checkout execution-telemetry-slice-0
git pull --ff-only origin execution-telemetry-slice-0
git checkout -b execution-telemetry-live-projection
```

Then inspect `agent-chat/executionTelemetryTypes.ts`, `agent-chat/executionTelemetryFanout.ts`, and existing fanout tests before creating the projection module.

## Do not do yet

- Do not add telemetry persistence.
- Do not add provenance writes.
- Do not start Claude structured-source selection or implementation.
- Do not add automatic diagnostic checkpoint scheduling.
- Do not make Swift the telemetry schema owner.
- Do not change React rendering or WebSocket `AgentEvent` payload behavior.
- Do not migrate ignored Codex app-server notifications without a concrete reason.
- Do not store raw provider envelopes, raw errors, command output, transcripts, or private reasoning in canonical telemetry.

## Review notes

The projection should be replayable and deterministic. If out-of-order, duplicate, or missing events need policy decisions, keep the first slice conservative and document the behavior in `decisions.md` before expanding scope.
