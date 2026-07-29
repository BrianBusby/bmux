# Execution Telemetry Handoff

## Session identity

- Date: 2026-07-29
- Slice: Slice 9 - Codex request-status diagnostic telemetry migration
- Branch: `execution-telemetry-slice-1`
- PR: https://github.com/BrianBusby/bmux/pull/12
- Base branch: stacked on PR #11 / `execution-telemetry-slice-0`
- Slice 6 implementation head before Slice 7: `ae19a8d78e2db9445991f89b289720e855d3892e`
- Slice 6 autoreview: clean; Archimedes made no changes and pushed no commits
- Slice 7 implementation head: `8c1405d7fe32c77cc5bddb1604f3be442d32be37`
- Slice 8 implementation head: branch head after the final Slice 8 commit
- Slice 9 implementation head: branch head after the final Slice 9 commit
- Tagged Debug build: `execution-telemetry-slice-9` succeeded
- Tagged Debug app: `/Users/brianbusby/Library/Developer/Xcode/DerivedData/bmux-execution-telemetry-slice-9/Build/Products/Debug/bmux DEV execution-telemetry-slice-9.app`

## Objective completed

Migrated one narrow Codex diagnostic path onto `SessionCtx.emitTelemetry` while preserving the existing React `AgentEvent` stream. Codex denied-approval and unsupported-request status messages now publish bounded `diagnostic` telemetry envelopes when `emitTelemetry` is available.

## Work completed

- Added Codex diagnostic producer support in `agent-chat/adapters/codexTelemetry.ts`.
- Routed denied approval status messages through telemetry from `agent-chat/adapters/codex.ts`.
- Routed unsupported JSON-RPC request status messages through telemetry from `agent-chat/adapters/codex.ts`.
- Preserved the exact existing React `status` message projection for both paths.
- Preserved bounded provider references for method, request id, thread id, and turn id when available.
- Preserved bounded diagnostic level, code, and message only; no raw JSON-RPC request or response envelope was added to canonical telemetry.
- Extended `agent-chat/test/codex-telemetry-migration.test.ts` proving telemetry subscribers receive diagnostic envelopes and React receives the same status messages.
- Extended `agent-chat/test/execution-telemetry-fanout.test.ts` proving diagnostic envelopes project to the existing status event.

## Tests run

- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/codex-telemetry-migration.test.ts`: passed.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-fanout.test.ts`: passed.
- Focused strict TypeScript check from `agent-chat` with Bun types, including `adapters/codex.ts`: passed.

- `agent-chat` package check: passed.
- `git diff --check`: passed.

- `./scripts/reload.sh --tag execution-telemetry-slice-9`: passed.

## Known failures or limitations

- Existing non-migrated adapter events still emit `AgentEvent` directly by design.
- Broader Codex transport failure diagnostics and ignored app-server notifications are not migrated in Slice 9.
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

After Slice 9 review, continue only if there is another bounded Codex diagnostic path worth preserving. Keep proving that the existing React `AgentEvent` stream remains equivalent for any migrated path.

## Do not do yet

- Do not add persistence.
- Do not add provenance writes.
- Do not start Claude implementation or structured-source selection.
- Do not change React rendering behavior.
- Do not make Swift the schema owner.
- Do not store raw provider envelopes in canonical telemetry events.
