# Execution Telemetry Handoff

## Session identity

- Date: 2026-07-29
- Slice: Plan Slice 4B - live projection sidecar read surface
- Branch: `execution-telemetry-live-projection`
- Base branch: `execution-telemetry-slice-0`
- Starting commit: `d750bf4b4158202ab59f8039ee7d864788eaa403`
- Implementation head: branch head after the final Slice 4B commit
- Tagged Debug build: `execution-telemetry-live-projection` succeeded
- Tagged Debug app: `/Users/brianbusby/Library/Developer/Xcode/DerivedData/bmux-execution-telemetry-live-projection/Build/Products/Debug/bmux DEV execution-telemetry-live-projection.app`

## Objective completed

Wired the renderer-independent live session projection to the sidecar as an
in-memory subscriber/read surface. The sidecar now keeps a bounded latest
projection per session and exposes it over REST without changing React
rendering, WebSocket `AgentEvent` payload behavior, persistence, provenance, or
native bridge behavior.

## Work completed

Test coverage added.

- Added `LiveSessionProjectionStore` in `agent-chat/executionTelemetryLiveProjection.ts`.
- Added defensive snapshot reads so callers cannot mutate the store internals.
- Added `liveSessionProjectionPayload()` returning `{ sessionId, snapshot }`, with `snapshot: null` until canonical telemetry exists.
- Attached a `LiveSessionProjectionStore` beside the per-session `ExecutionTelemetryFanout` in `agent-chat/server.ts`.
- Added `GET /api/sessions/:id/execution-telemetry/live` as a bounded REST read surface for the latest projection.

## Read surface policy

- The live projection is process-memory only.
- The read surface is REST-only.
- It does not broadcast WebSocket messages.
- The endpoint returns only the bounded projection snapshot and session id.
- `snapshot` is `null` before the first canonical telemetry envelope.
- The snapshot excludes raw provider data, raw errors, command output, transcripts, private reasoning, and changed file paths.

## Validation

All focused validation passed.

Build passed.

## Known failures or limitations

- The live projection is still in-memory only.
- No persistence was added.
- No provenance writes were added.
- No native bridge was added.
- No React rendering changes or WebSocket `AgentEvent` payload changes were made.
- Existing non-migrated adapter events still emit `AgentEvent` directly by design.
- No Claude structured-source work has started.

## Important files for the next session

- `agent-chat/executionTelemetryLiveProjection.ts`
- `agent-chat/server.ts`
- `agent-chat/test/execution-telemetry-live-projection.test.ts`
- `agent-chat/executionTelemetryTypes.ts`
- `agent-chat/executionTelemetryFanout.ts`
- `agent-chat/test/execution-telemetry-fanout.test.ts`
- `agent-chat/test/codex-telemetry-migration.test.ts`
- `docs/execution-telemetry/implementation-status.md`
- `docs/execution-telemetry/decisions.md`
- `docs/execution-telemetry/architecture.md`
- `docs/execution-telemetry/contract.md`

## Next slice

After review, a later slice can add a native bridge consumer for the bounded
live projection or continue provider telemetry migration.

Keep the next slice bounded: avoid persistence, provenance writes, Swift schema
ownership, React rendering changes, WebSocket `AgentEvent` payload changes,
Claude structured-source selection, and automatic diagnostic checkpoint
scheduling unless explicitly in scope.

## Do not do yet

- Do not add telemetry persistence.
- Do not add provenance writes.
- Do not start Claude structured-source selection or implementation.
- Do not add automatic diagnostic checkpoint scheduling.
- Do not make Swift the telemetry schema owner.
- Do not change React rendering or WebSocket `AgentEvent` payload behavior.
- Do not migrate ignored Codex app-server notifications without a concrete reason.
- Do not store raw provider envelopes, raw errors, command output, transcripts, or private reasoning in canonical telemetry.
