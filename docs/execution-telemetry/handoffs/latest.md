# Execution Telemetry Handoff

## Session identity

- Date: 2026-07-29
- Slice: Slice 10 - Codex send-failure diagnostic telemetry migration
- Branch: `execution-telemetry-slice-1`
- PR: https://github.com/BrianBusby/bmux/pull/12
- Base branch: stacked on PR #11 / `execution-telemetry-slice-0`
- Slice 6 implementation head before Slice 7: `ae19a8d78e2db9445991f89b289720e855d3892e`
- Slice 6 autoreview: clean; Archimedes made no changes and pushed no commits
- Slice 7 implementation head: `8c1405d7fe32c77cc5bddb1604f3be442d32be37`
- Slice 8 implementation head: branch head after the final Slice 8 commit
- Slice 9 implementation head: branch head after the final Slice 9 commit
- Slice 10 implementation head: branch head after the final Slice 10 commit
- Tagged Debug build: `execution-telemetry-slice-10` succeeded
- Tagged Debug app: `/Users/brianbusby/Library/Developer/Xcode/DerivedData/bmux-execution-telemetry-slice-10/Build/Products/Debug/bmux DEV execution-telemetry-slice-10.app`

## Objective completed

Migrated one narrow Codex diagnostic path onto `SessionCtx.emitTelemetry` while preserving the existing React `AgentEvent` stream. Codex send failures now publish bounded `diagnostic` telemetry envelopes when `emitTelemetry` is available, while preserving the existing React `error` projection and direct `done` close-out.

## Work completed

- Routed Codex `send` catch failures through telemetry from `agent-chat/adapters/codex.ts`.
- Preserved the exact existing React `error` message projection.
- Preserved the direct `done` close-out and generation value as current UI projection behavior, not canonical telemetry.
- Preserved bounded provider references for operation method, thread id, and turn id when available.
- Preserved bounded diagnostic level, code, and message only; no raw error object or raw JSON-RPC provider envelope was added to canonical telemetry.
- Extended `agent-chat/test/codex-telemetry-migration.test.ts` proving telemetry subscribers receive the send-failure diagnostic envelope and React receives the same `error` plus `done` events.

## Tests run

- `git diff --check`: passed.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/codex-telemetry-migration.test.ts`: passed.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-fanout.test.ts`: passed.
- `cd agent-chat && PATH="$HOME/.bun/bin:$PATH" bun run check`: passed.
- `./scripts/reload.sh --tag execution-telemetry-slice-10`: passed.

## Known failures or limitations

- Existing non-migrated adapter events still emit `AgentEvent` directly by design.
- Codex app-server process-exit diagnostics and ignored app-server notifications are not migrated in Slice 10.
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

After Slice 10 review, continue only if there is another bounded Codex diagnostic path worth preserving. Keep proving that the existing React `AgentEvent` stream remains equivalent for any migrated path.

## Do not do yet

- Do not add persistence.
- Do not add provenance writes.
- Do not start Claude implementation or structured-source selection.
- Do not change React rendering behavior.
- Do not make Swift the schema owner.
- Do not store raw provider envelopes in canonical telemetry events.
