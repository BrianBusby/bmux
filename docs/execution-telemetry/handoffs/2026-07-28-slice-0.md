# Execution Telemetry Handoff

## Session identity

- Date: 2026-07-28
- Slice: Slice 0 - Repository audit and event-flow inventory
- Branch: `execution-telemetry-slice-0`
- Starting commit: `d346355724b4d85339b0604dcdb6aa559973d4ae`
- Slice 0 audit commit: `703c11782b9ef440762c1e28f9cd6ba73326dd74`
- Working tree status: documentation changes only at handoff creation time

## Objective completed

Audit the current structured Codex lifecycle path without refactoring it: Codex app-server input, provider adapter normalization, sidecar session ownership, `AgentEvent` replay/fanout, React consumption, native bridge, and provenance boundaries.

## Work completed

- Created `docs/execution-telemetry/` document structure.
- Documented current architecture in `architecture.md`.
- Documented raw Codex app-server mappings and lossy fields in `event-inventory.md`.
- Added initial provider capability matrix in `provider-capabilities.md`.
- Added initial persistence/provenance separation in `persistence-policy.md`.
- Added status and decisions documents.
- Generated local Codex app-server schema under `/tmp` for audit evidence.

No production code, tests, migrations, or provenance-engine files were changed.

## Architecture findings

- `agent-chat/adapters/codex.ts` starts one shared `codex app-server` process and maps notifications directly to display-oriented `AgentEvent` values.
- `agent-chat/server.ts` owns sidecar sessions, status, replay, WebSocket subscribers, and REST session creation.
- React consumes history/live events and folds `AgentEvent` into `Block` rows; it is not required for sidecar session ownership.
- `POST /api/sessions` can start a session without a React subscriber.
- Multiple WebSocket consumers can subscribe to one sidecar session, but there is no provider-neutral non-UI event bus.
- Current app-server normalization loses structured Codex fields before any native, analytics, persistence, or provenance consumer can see them.
- No Codex app-server lifecycle events were found reaching provenance-engine. Existing provenance paths are Swift/CLI hook-driven and separate from agent-chat sidecar events.

## Decisions made

See `../decisions.md`:

- `2026-07-28 - Slice 0 Is Audit-Only`
- `2026-07-28 - Treat AgentEvent As Current UI Projection`
- `2026-07-28 - Keep Provenance Projection Separate`

## Tests run

```bash
bun run agent-session-web:test
```

Result: failed before tests ran because `bun` was not on PATH: `zsh:1: command not found: bun`.

```bash
codex --version
codex app-server generate-json-schema --out /tmp/bmux-codex-schema-1785276507
```

Result: passed. Codex version was `codex-cli 0.144.5`; schema files were generated under `/tmp`.

## Known failures or limitations

Pre-existing failures:

- `bun` unavailable on PATH in this shell, preventing the targeted agent-session web test from running.

Failures introduced by this slice:

- None known. Documentation-only changes.

Intentionally deferred behavior:

- No provider-neutral contract.
- No execution-event bus.
- No dual-publish path.
- No telemetry persistence.
- No provenance projection.
- No Claude structured-source audit beyond noting current code boundaries.

## Important files for the next session

- `docs/execution-telemetry/architecture.md`
- `docs/execution-telemetry/event-inventory.md`
- `docs/execution-telemetry/provider-capabilities.md`
- `docs/execution-telemetry/decisions.md`
- `agent-chat/types.ts`
- `agent-chat/server.ts`
- `agent-chat/adapters/codex.ts`
- `agent-chat/src/session.ts`
- `Sources/AppDelegate+AgentChat.swift`
- `CLI/bmux.swift`
- `CLI/BMUXCLI+AgentHookCatalog.swift`
- `CLI/BMUXCLI+CodexFireAndForgetHooks.swift`
- `/Users/brianbusby/repos/provenance-engine/Sources/ProvenanceEngineContracts/ProvenanceSessionLifecycleRequest.swift`

## Next slice

Slice 1 - Define ownership boundaries and provider-neutral contract.

## First action for the next agent

Choose the contract module location by inspecting existing TypeScript build and test boundaries around `agent-chat/types.ts`, `agent-chat/server.ts`, and `webviews/src/agent-session/shared`.

## Do not do yet

- Do not implement the execution-event bus; that is Slice 2.
- Do not change React rendering.
- Do not add telemetry persistence.
- Do not add provenance writes.
- Do not start Claude implementation or source selection.
- Do not use `AgentEvent` as the canonical contract.

## Review notes

- The strongest Slice 1 risk is TypeScript/Swift contract drift. The final contract location and generation/synchronization policy must be explicit.
- The local Codex schema is from `codex-cli 0.144.5`; regenerate if the local CLI changes.
- Current `AgentEvent.done.stats` is a display string and must not be parsed back into telemetry.
- Approval handling currently auto-responds inside `handleServerMessage()`; a future contract must model request and resolution separately.
