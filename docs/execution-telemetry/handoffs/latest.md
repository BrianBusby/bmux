# Execution Telemetry Handoff

## Session identity

- Date: 2026-07-29
- Slice: Slice 8 - Codex standalone usage telemetry migration
- Branch: `execution-telemetry-slice-1`
- PR: https://github.com/BrianBusby/bmux/pull/12
- Base branch: stacked on PR #11 / `execution-telemetry-slice-0`
- Slice 6 implementation head before Slice 7: `ae19a8d78e2db9445991f89b289720e855d3892e`
- Slice 6 autoreview: clean; Archimedes made no changes and pushed no commits
- Slice 7 implementation head: `8c1405d7fe32c77cc5bddb1604f3be442d32be37`
- Slice 8 implementation head: branch head after the final Slice 8 commit
- Tagged Debug build: `execution-telemetry-slice-8` succeeded

## Objective completed

Migrated one narrow Codex standalone usage observation path onto `SessionCtx.emitTelemetry` while preserving the existing React `AgentEvent` stream. Codex `thread/tokenUsage/updated` notifications now publish bounded `usage.updated` telemetry envelopes when `emitTelemetry` is available.

## Work completed

- Added Codex standalone usage producer support in `agent-chat/adapters/codexTelemetry.ts`.
- Routed Codex `thread/tokenUsage/updated` notifications through telemetry from `agent-chat/adapters/codex.ts`.
- Preserved the existing buffered usage path that attaches matching usage to `turn.completed` for current React `done.stats`.
- Preserved existing React behavior: standalone usage updates project no `AgentEvent`.
- Preserved bounded provider references for method, thread id, and turn id when available.
- Preserved bounded usage fields only; no raw provider `tokenUsage` envelope was added to canonical telemetry.
- Preserved no-op direct fallback for standalone usage because `SessionCtx.emitTelemetry` remains optional and usage telemetry has no legacy UI projection.
- Extended `agent-chat/test/codex-telemetry-migration.test.ts` proving telemetry subscribers receive standalone usage envelopes and React receives the same projected turn completion stats.

## Tests run

- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/codex-telemetry-migration.test.ts`: passed.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-fanout.test.ts`: passed.
- Focused strict TypeScript check from `agent-chat` with Bun types, including `adapters/codex.ts`: passed.

- `agent-chat` package check: passed.
- `git diff --check`: passed.

- `./scripts/reload.sh --tag execution-telemetry-slice-8`: passed.

## Known failures or limitations

- Existing non-migrated adapter events still emit `AgentEvent` directly by design.
- Codex diagnostics are not migrated in Slice 8.
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

After Slice 8 review, continue Codex migration with one narrow path, preferably diagnostics. Keep proving that the existing React `AgentEvent` stream remains equivalent for any migrated path.

## Do not do yet

- Do not add persistence.
- Do not add provenance writes.
- Do not start Claude implementation or structured-source selection.
- Do not change React rendering behavior.
- Do not make Swift the schema owner.
- Do not store raw provider envelopes in canonical telemetry events.
