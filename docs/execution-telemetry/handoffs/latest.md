# Execution Telemetry Handoff

## Session identity

- Date: 2026-07-29
- Slice: Slice 6 - Codex tool lifecycle telemetry migration
- Branch: `execution-telemetry-slice-1`
- PR: https://github.com/BrianBusby/bmux/pull/12
- Base branch: stacked on PR #11 / `execution-telemetry-slice-0`
- Slice 5 implementation head before Slice 6: `32e0d07da33f94e868735577cef551fd8b1b9e62`
- Slice 5 autoreview: clean; Lagrange made no changes and pushed no commits
- Slice 6 implementation head: branch head after the final Slice 6 commit
- Tagged Debug build: `execution-telemetry-slice-6` succeeded

## Objective completed

Migrated one narrow Codex tool lifecycle path onto `SessionCtx.emitTelemetry` while preserving the existing React `AgentEvent` stream. Codex `item/started` and `item/completed` notifications for command execution, file changes, web search, and MCP tool calls now publish telemetry envelopes first and rely on the fanout projection for the UI path when `emitTelemetry` is available.

## Work completed

- Added Codex tool lifecycle producers in `agent-chat/adapters/codexTelemetry.ts`.
- Routed Codex command execution, file change / patch apply, web search, and MCP tool item starts and completions through telemetry from `agent-chat/adapters/codex.ts`.
- Preserved the existing `tool-start` / `tool-end` React projection, including current names, summaries, omitted names/details for completed web/MCP events, and success calculation.
- Preserved bounded provider references for method, thread id, turn id, and item id.
- Preserved bounded scalar metadata for provider item type and provider status.
- Preserved a direct `AgentEvent` fallback because `SessionCtx.emitTelemetry` remains optional.
- Extended `agent-chat/test/codex-telemetry-migration.test.ts` proving telemetry subscribers receive tool lifecycle envelopes and React receives the same projected tool events.

## Tests run

- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/codex-telemetry-migration.test.ts`: passed.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-fanout.test.ts`: passed.
- Focused strict TypeScript check from `agent-chat` with Bun types, including `adapters/codex.ts`: passed.

- `agent-chat` package check: passed.

- `./scripts/reload.sh --tag execution-telemetry-slice-6`: passed.

## Known failures or limitations

- Existing non-migrated adapter events still emit `AgentEvent` directly by design.
- Codex approval lifecycle, usage updates as standalone telemetry, diagnostics, and unsupported request status messages are not migrated in Slice 6.
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

After Slice 6 review, continue Codex migration with one narrow path, preferably approval lifecycle, standalone usage observations, or diagnostics. Keep proving that the existing React `AgentEvent` stream remains equivalent for any migrated path.

## Do not do yet

- Do not add persistence.
- Do not add provenance writes.
- Do not start Claude implementation or structured-source selection.
- Do not change React rendering behavior.
- Do not make Swift the schema owner.
- Do not store raw provider envelopes in canonical telemetry events.
