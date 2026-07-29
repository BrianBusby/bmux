# Execution Telemetry Handoff

## Session identity

- Date: 2026-07-29
- Slice: Plan Slice 4A - live session projection foundation
- Branch: `execution-telemetry-live-projection`
- Base branch: `execution-telemetry-slice-0`
- Starting commit: `c32ed93989c8ed8531d9b573bb34b36149461475`
- Implementation head: branch head after the final Slice 4A commit
- Tagged Debug build: `execution-telemetry-live-projection` succeeded
- Tagged Debug app: `/Users/brianbusby/Library/Developer/Xcode/DerivedData/bmux-execution-telemetry-live-projection/Build/Products/Debug/bmux DEV execution-telemetry-live-projection.app`

## Objective completed

Added a renderer-independent live session projection foundation in
`agent-chat`. The projection consumes ordered `TelemetryEventEnvelope` values
and derives a deterministic bounded snapshot without using React lifecycle
state, changing React rendering, or changing WebSocket `AgentEvent` payload
behavior.

## Work completed

- Added `agent-chat/executionTelemetryLiveProjection.ts`.
- Added `LiveSessionProjection` for incremental envelope application.
- Added `replayLiveSessionProjection()` for deterministic ordered replay.
- Snapshot fields cover bmux session id, provider, provider session id, current provider turn id, lifecycle state, active operation count, latest activity timestamp, latest usage summary, latest diagnostic, approval-blocked state, and files-changed summary.
- Added focused replay tests with synthetic telemetry envelopes.
- Preserved the existing `ExecutionTelemetryFanout` and React `AgentEvent` projection behavior.

## Replay policy

- Replay input is one ordered telemetry stream for exactly one bmux session and provider.
- Mixed session ids or mixed providers are rejected instead of silently merged.
- `latestActivityAtMs` is the `capturedAtMs` from the most recently applied envelope in replay order.
- Active operation count is derived from unresolved `tool.started` / `tool.completed` operation ids.
- Approval-blocked state is derived from unresolved `approval.requested` / `approval.resolved` ids.
- Files-changed count is a unique count of paths reported by canonical `files.changed` telemetry; paths are not exposed in the snapshot.

## Tests run

- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-live-projection.test.ts`: passed.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-fanout.test.ts`: passed.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/codex-telemetry-migration.test.ts`: passed.
- `cd agent-chat && PATH="$HOME/.bun/bin:$PATH" bun run check`: passed.
- `./scripts/reload.sh --tag execution-telemetry-live-projection`: passed.
- `git diff --check`: passed.

## Known failures or limitations

- The projection is module-only in this slice; it is not wired into `server.ts`, a subscriber API, React, native Swift, persistence, or provenance.
- Existing non-migrated adapter events still emit `AgentEvent` directly by design.
- No telemetry persistence or provenance projection exists.
- No Swift decoder or native subscriber exists.
- No Claude structured-source work has started.

## Important files for the next session

- `agent-chat/executionTelemetryLiveProjection.ts`
- `agent-chat/test/execution-telemetry-live-projection.test.ts`
- `agent-chat/executionTelemetryTypes.ts`
- `agent-chat/executionTelemetryFanout.ts`
- `agent-chat/server.ts`
- `agent-chat/test/execution-telemetry-fanout.test.ts`
- `agent-chat/test/codex-telemetry-migration.test.ts`
- `docs/execution-telemetry/implementation-status.md`
- `docs/execution-telemetry/decisions.md`
- `docs/execution-telemetry/architecture.md`
- `docs/execution-telemetry/contract.md`

## Next slice

After review, the next slice can wire this projection to a sidecar subscriber
or native bridge if that is the selected plan target. Keep it bounded: do not
add persistence, provenance writes, Swift schema ownership, React rendering
changes, WebSocket `AgentEvent` payload changes, Claude structured-source
selection, or automatic diagnostic checkpoint scheduling unless explicitly in
scope.

## Do not do yet

- Do not add telemetry persistence.
- Do not add provenance writes.
- Do not start Claude structured-source selection or implementation.
- Do not add automatic diagnostic checkpoint scheduling.
- Do not make Swift the telemetry schema owner.
- Do not change React rendering or WebSocket `AgentEvent` payload behavior.
- Do not migrate ignored Codex app-server notifications without a concrete reason.
- Do not store raw provider envelopes, raw errors, command output, transcripts, or private reasoning in canonical telemetry.
