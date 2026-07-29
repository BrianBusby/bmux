# Execution Telemetry Handoff

## Session identity

- Date: 2026-07-29
- Slice: Slice 5 - Codex message lifecycle telemetry migration
- Branch: `execution-telemetry-slice-1`
- PR: https://github.com/BrianBusby/bmux/pull/12
- Base branch: stacked on PR #11 / `execution-telemetry-slice-0`
- Slice 4 review-fix head before Slice 5: `416824d9cb4e6e8b28a8fb32095b88ea56da14e3`
- Slice 5 implementation head: branch head after the final Slice 5 commit
- Tagged Debug build: `execution-telemetry-slice-5` succeeded

## Objective completed

Migrated one narrow Codex message lifecycle path onto `SessionCtx.emitTelemetry` while preserving the existing React `AgentEvent` stream. Codex assistant deltas, reasoning deltas, and completed non-streamed assistant messages now publish telemetry envelopes first and rely on the fanout projection for the UI path when `emitTelemetry` is available.

## Work completed

- Added Codex message lifecycle producers in `agent-chat/adapters/codexTelemetry.ts`.
- Routed Codex `item/agentMessage/delta`, reasoning delta variants, and completed non-streamed `agentMessage` items through telemetry from `agent-chat/adapters/codex.ts`.
- Preserved the existing streamed-message duplicate suppression: a streamed assistant message still does not emit a second completed assistant block.
- Preserved bounded provider references for method, thread id, turn id, and item id.
- Preserved a direct `AgentEvent` fallback because `SessionCtx.emitTelemetry` remains optional.
- Extended `agent-chat/test/codex-telemetry-migration.test.ts` proving telemetry subscribers receive message lifecycle envelopes and React receives the same projected `delta` / `thinking` / `assistant` events.

## Tests run

- `git diff --check`: passed.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/codex-telemetry-migration.test.ts`: passed.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-fanout.test.ts`: passed.
- Focused strict TypeScript check from `agent-chat` with Bun types, including `adapters/codex.ts`: passed.
- `cd agent-chat && PATH="$HOME/.bun/bin:$PATH" bun run check`: passed.
- `./scripts/reload.sh --tag execution-telemetry-slice-5`: passed.

## Known failures or limitations

- Existing non-migrated adapter events still emit `AgentEvent` directly by design.
- Codex tool lifecycle, approval lifecycle, usage updates as standalone telemetry, diagnostics, and unsupported request status messages are not migrated in Slice 5.
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

After Slice 5 review, continue Codex migration with one narrow path, preferably tool lifecycle or approval lifecycle. Keep proving that the existing React `AgentEvent` stream remains equivalent for the migrated path.

## Do not do yet

- Do not add persistence.
- Do not add provenance writes.
- Do not start Claude implementation or structured-source selection.
- Do not change React rendering behavior.
- Do not make Swift the schema owner.
- Do not store raw provider envelopes in canonical telemetry events.
