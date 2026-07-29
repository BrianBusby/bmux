# Execution Telemetry Handoff

## Session identity

- Date: 2026-07-28
- Slice: Slice 4 - Codex turn lifecycle telemetry migration
- Branch: `execution-telemetry-slice-1`
- PR: https://github.com/BrianBusby/bmux/pull/12
- Base branch: stacked on PR #11 / `execution-telemetry-slice-0`
- Slice 3 head before Slice 4: `d69a8ae3253fd21821a350b946ef04a26f31b324`
- Slice 4 implementation head: branch head after the final Slice 4 commit
- Tagged Debug build: `execution-telemetry-slice-4` succeeded

## Objective completed

Migrated one narrow Codex lifecycle path onto `SessionCtx.emitTelemetry` while preserving the existing React `AgentEvent` stream. Codex `turn/started`, `turn/completed`, and `turn/failed` notifications now publish telemetry envelopes first and rely on the fanout projection for the UI path when `emitTelemetry` is available.

## Work completed

- Added Codex turn lifecycle producers in `agent-chat/adapters/codexTelemetry.ts`.
- Routed Codex `turn/started`, `turn/completed`, and `turn/failed` notifications through telemetry from `agent-chat/adapters/codex.ts`.
- Preserved Codex `done.generation` for server-side file-change attribution as a projection-only option; it is not stored on canonical telemetry envelopes.
- Preserved bounded provider references for method, thread id, and turn id, plus bounded model/effort, duration, token usage, and error facts.
- Preserved a direct `AgentEvent` fallback because `SessionCtx.emitTelemetry` remains optional.
- Extended `agent-chat/test/codex-telemetry-migration.test.ts` proving telemetry subscribers receive turn lifecycle envelopes and React receives the same projected `done` / `error` events.

## Tests run

- `git diff --check`: passed.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/codex-telemetry-migration.test.ts`: passed.
- `npm exec --yes --package typescript@5.9.3 -- tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict agent-chat/executionTelemetryTypes.ts agent-chat/executionTelemetryFanout.ts agent-chat/adapters/codexTelemetry.ts agent-chat/test/codex-telemetry-migration.test.ts`: passed.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-fanout.test.ts`: passed.
- Broader focused `tsc` including `agent-chat/server.ts` and `agent-chat/adapters/codex.ts`: blocked before useful source checking because Bun and Node type definitions could not be resolved in this shell, matching the existing `bun` limitation.
- `./scripts/reload.sh --tag execution-telemetry-slice-4`: passed.

## Known failures or limitations

- `bun` is unavailable on PATH in this shell.
- Full `agent-chat` tsconfig/package checks remain blocked by missing Bun and Node type resolution in this shell.
- Existing non-migrated adapter events still emit `AgentEvent` directly by design.
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

After Slice 4 review, continue Codex migration with one narrow path, preferably message/tool lifecycle or approval/usage lifecycle. Keep proving that the existing React `AgentEvent` stream remains equivalent for the migrated path.

## Do not do yet

- Do not add persistence.
- Do not add provenance writes.
- Do not start Claude implementation or structured-source selection.
- Do not change React rendering behavior.
- Do not make Swift the schema owner.
- Do not store raw provider envelopes in canonical telemetry events.
