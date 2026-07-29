# Execution Telemetry Handoff

## Session identity

- Date: 2026-07-29
- Slice: Slice 7 - Codex approval lifecycle telemetry migration
- Branch: `execution-telemetry-slice-1`
- PR: https://github.com/BrianBusby/bmux/pull/12
- Base branch: stacked on PR #11 / `execution-telemetry-slice-0`
- Slice 6 implementation head before Slice 7: `ae19a8d78e2db9445991f89b289720e855d3892e`
- Slice 6 autoreview: clean; Archimedes made no changes and pushed no commits
- Slice 7 implementation head: branch head after the final Slice 7 commit
- Tagged Debug build: `execution-telemetry-slice-7` succeeded

## Objective completed

Migrated one narrow Codex approval lifecycle path onto `SessionCtx.emitTelemetry` while preserving the existing React `AgentEvent` stream. Codex JSON-RPC approval requests now publish `approval.requested` and `approval.resolved` telemetry envelopes for approved, denied, and unsupported request outcomes when `emitTelemetry` is available.

## Work completed

- Added Codex approval lifecycle producers in `agent-chat/adapters/codexTelemetry.ts`.
- Routed Codex approval JSON-RPC request handling through telemetry from `agent-chat/adapters/codex.ts`.
- Preserved the existing React behavior: approval events themselves still project no `AgentEvent`, and the existing denial / unsupported-request `status` messages are still emitted directly.
- Preserved bounded provider references for method, request id, thread id, turn id, and operation id when available.
- Preserved bounded approval summaries only; no raw provider request params or response envelopes were added to canonical telemetry.
- Preserved no-op direct fallback for approval producer helpers because `SessionCtx.emitTelemetry` remains optional and approval telemetry has no legacy UI projection.
- Extended `agent-chat/test/codex-telemetry-migration.test.ts` proving telemetry subscribers receive approval lifecycle envelopes and React receives the same projected status behavior for denied and unsupported requests.

## Tests run

- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/codex-telemetry-migration.test.ts`: passed.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-fanout.test.ts`: passed.
- Focused strict TypeScript check from `agent-chat` with Bun types, including `adapters/codex.ts`: passed.

- `agent-chat` package check: passed.
- `git diff --check`: passed.

- `./scripts/reload.sh --tag execution-telemetry-slice-7`: passed.

## Known failures or limitations

- Existing non-migrated adapter events still emit `AgentEvent` directly by design.
- Codex usage updates as standalone telemetry and diagnostics are not migrated in Slice 7.
- No telemetry persistence or provenance projection exists.
- No Swift decoder or native subscriber exists.
- No Claude structured-source work has started.

## Important files for the next session

- `agent-chat/adapters/codexTelemetry.ts`
- `agent-chat/adapters/codex.ts`
- `agent-chat/server.ts`
- `agent-chat/executionTelemetryFanout.ts`
- `agent-chat/executionTelemetryTypes.ts`
- `agent-chat/types.ts`
- `agent-chat/test/codex-telemetry-migration.test.ts`
- `agent-chat/test/execution-telemetry-fanout.test.ts`
- `docs/execution-telemetry/contract.md`
- `docs/execution-telemetry/architecture.md`
- `docs/execution-telemetry/decisions.md`
- `docs/execution-telemetry/implementation-status.md`

## Next slice

After Slice 7 review, continue Codex migration with one narrow path, preferably standalone usage observations or diagnostics. Keep proving that the existing React `AgentEvent` stream remains equivalent for any migrated path.

## Do not do yet

- Do not add persistence.
- Do not add provenance writes.
- Do not start Claude implementation or structured-source selection.
- Do not change React rendering behavior.
- Do not make Swift the schema owner.
- Do not store raw provider envelopes in canonical telemetry events.
