# Execution Telemetry Implementation Status

Last updated: 2026-07-29

## Plan Orientation

| Plan area | Current position | Notes |
| --- | --- | --- |
| Provider-neutral Codex telemetry migration | Slices 0 through 11 completed on the stacked Slice 1 branch history. | Existing React `AgentEvent` projection behavior is preserved. |
| Live session projection foundation | Plan Slice 4A completed on `execution-telemetry-live-projection`. | Adds a renderer-independent replay projection from ordered `TelemetryEventEnvelope` values. |
| Live projection sidecar read surface | Plan Slice 4B completed on `execution-telemetry-live-projection`. | Wires the live projection to the sidecar fanout as an in-memory subscriber and exposes a bounded REST read payload; no React rendering, WebSocket `AgentEvent`, persistence, provenance, or native bridge changes. |

## Active Slice

Plan Slice 4B - live projection sidecar read surface.

Status: completed in branch `execution-telemetry-live-projection`; awaiting review.

## Completed Slices

- Slice 0: current-state audit only. Created the execution telemetry document structure, traced the current Codex app-server path, documented lossy normalization points, recorded provider capability findings, and wrote a handoff for Slice 1.
- Slice 1: validated PR #11 / branch `execution-telemetry-slice-0`, including follow-up commit `6cc83ff8e`; added the canonical provider-neutral telemetry type contract in `agent-chat/executionTelemetryTypes.ts`; hardened metadata in `964e11313` so it cannot carry nested raw-provider payloads; documented sidecar/provider/React/native/provenance ownership boundaries, ordering policy, metadata policy, and Swift sync policy.
- Slice 2: added the sidecar fanout seam in `agent-chat`. Existing adapters and React rendering remain unchanged.
- Slice 3: migrated Codex prompt submission and provider session linkage (`thread/start` and `thread/fork`) through `SessionCtx.emitTelemetry`, with a direct `AgentEvent` fallback while the seam remains optional.
- Slice 4: migrated Codex turn lifecycle (`turn/started`, `turn/completed`, and `turn/failed`) through `SessionCtx.emitTelemetry`, preserving existing React `done` / `error` projection and server-only done generation for file attribution.
- Slice 5: migrated Codex message lifecycle (`item/agentMessage/delta`, reasoning delta variants, and completed non-streamed `agentMessage` items) through `SessionCtx.emitTelemetry`, preserving existing React `delta` / `thinking` / `assistant` projection and streamed-message duplicate suppression.
- Slice 6: migrated Codex tool lifecycle (`item/started` and `item/completed` for command execution, file changes, web search, and MCP tool calls) through `SessionCtx.emitTelemetry`, preserving existing React `tool-start` / `tool-end` projection.
- Slice 7: migrated Codex approval lifecycle (`approval.requested` and `approval.resolved` for approved, denied, and unsupported JSON-RPC approval requests) through `SessionCtx.emitTelemetry`, preserving existing React no-op approval projection plus direct denial / unsupported status messages.
- Slice 8: migrated Codex standalone usage observations (`thread/tokenUsage/updated`) through `SessionCtx.emitTelemetry`, preserving existing React no-op usage projection and matching-turn usage stats on `turn.completed`.
- Slice 9: migrated Codex denial and unsupported request status diagnostics through `SessionCtx.emitTelemetry`, preserving existing React `status` projection while publishing bounded `diagnostic` envelopes.
- Slice 10: migrated Codex send-failure diagnostics through `SessionCtx.emitTelemetry`, preserving existing React `error` projection and direct `done` close-out while publishing bounded `diagnostic` envelopes.
- Slice 11: migrated Codex app-server process-exit mid-turn diagnostics through `SessionCtx.emitTelemetry`, preserving existing React `error` projection and direct `done` close-out while publishing bounded `diagnostic` envelopes.
- Plan Slice 4A: added a renderer-independent live session projection module in `agent-chat` that replays ordered `TelemetryEventEnvelope` values into a small deterministic snapshot with session/provider identity, provider session/turn ids, lifecycle state, active operation count, latest activity timestamp, usage summary, diagnostic summary, approval-blocked state, and files-changed summary. Existing React `AgentEvent` projection behavior and WebSocket payloads remain unchanged.
- Plan Slice 4B: added `LiveSessionProjectionStore`, attached it beside each sidecar `ExecutionTelemetryFanout`, and exposed a bounded REST read payload at `GET /api/sessions/:id/execution-telemetry/live`. The endpoint returns `{ sessionId, snapshot }`, with `snapshot: null` until canonical telemetry exists. Existing React rendering and WebSocket `AgentEvent` payload behavior remain unchanged.

## Current Branch

`execution-telemetry-live-projection`

Starting branch before Slice 0 was `fix-react-submit-bar-photo-drop-v2`, clean at `c19c835e8b58e138aa11d50c6ee9ef75be1cdc7a`. Slice 0 was moved to a scoped branch from `origin/main`.

Starting commit for this branch:

`d346355724b4d85339b0604dcdb6aa559973d4ae`

Slice 0 ending commit after autoreview follow-up:

`6cc83ff8e2cdde480e1a00295e40d0abd51b4cf7`

Slice 1 started from that commit.

Slice 1 handoff head:

`9cb09e138cb6381466489c57b45dd8d39da696b7`

Slice 2 implementation head before autoreview:

`d005aa66f3cdeec11e2a5cbe85782fcc6b39252d`

Slice 3 implementation head:

`d69a8ae3253fd21821a350b946ef04a26f31b324`

Slice 4 implementation head:

`416824d9cb4e6e8b28a8fb32095b88ea56da14e3`

Slice 5 implementation head:

`32e0d07da33f94e868735577cef551fd8b1b9e62`

Slice 5 autoreview result:

No findings. Lagrange reviewed PR #12 at actual head `32e0d07da33f94e868735577cef551fd8b1b9e62`, made no changes, pushed no commits, and reported no GitHub checks on `execution-telemetry-slice-1`.

Slice 6 implementation head:

`ae19a8d78e2db9445991f89b289720e855d3892e`

Slice 6 autoreview result:

No findings. Archimedes reviewed PR #12 at actual head `ae19a8d78e2db9445991f89b289720e855d3892e`, made no changes, pushed no commits, and reported no GitHub comments, reviews, or check rollup findings for that head.

Slice 7 implementation head:

`8c1405d7fe32c77cc5bddb1604f3be442d32be37`

Slice 8 implementation head:

branch head after the final Slice 8 commit

Slice 9 implementation head:

branch head after the final Slice 9 commit

Slice 10 implementation head:

`9fdfef92b85524375144b28157933fba8e03eb0b`

Slice 11 implementation head:

branch head after the final Slice 11 commit

## Tests Currently Passing

No package tests passed in this environment during Slice 0 or Slice 1.

Attempted baseline:

```bash
bun run agent-session-web:test
```

Result: failed before tests ran because `bun` was not on PATH: `zsh:1: command not found: bun`.

Audit support command:

```bash
codex --version
codex app-server generate-json-schema --out /tmp/bmux-codex-schema-1785276507
```

Result: succeeded; local Codex version was `codex-cli 0.144.5`.

Slice 1 validation:

```bash
git diff --check
```

Result: succeeded.

```bash
npm exec --yes --package typescript@5.9.3 -- tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict agent-chat/executionTelemetryTypes.ts
```

Result: succeeded.

Slice 2 validation:

```bash
git diff --check
```

Result: succeeded.

Slice 2 focused TypeScript check, fanout behavior test, and tagged Debug build all succeeded.

Slice 3 validation:

```bash
git diff --check
```

Result: succeeded.

```bash
npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/codex-telemetry-migration.test.ts
```

Result: succeeded.

```bash
npm exec --yes --package typescript@5.9.3 -- tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict agent-chat/executionTelemetryTypes.ts agent-chat/executionTelemetryFanout.ts agent-chat/adapters/codexTelemetry.ts agent-chat/test/codex-telemetry-migration.test.ts
```

Result: succeeded.

```bash
npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-fanout.test.ts
```

Result: succeeded.

```bash
./scripts/reload.sh --tag execution-telemetry-slice-3
```

Result: succeeded.

Slice 4 validation:

- `git diff --check`: succeeded.
- `agent-chat/test/codex-telemetry-migration.test.ts` via `tsx@4.20.5`: succeeded.
- `agent-chat/test/execution-telemetry-fanout.test.ts` via `tsx@4.20.5`: succeeded.
- Focused strict TypeScript check for telemetry contract, fanout, Codex telemetry producers, and the migration test: succeeded.
- `./scripts/reload.sh --tag execution-telemetry-slice-4`: succeeded.

Slice 5 validation:

- `git diff --check`: succeeded.
- `agent-chat/test/codex-telemetry-migration.test.ts` via `tsx@4.20.5`: succeeded.
- `agent-chat/test/execution-telemetry-fanout.test.ts` via `tsx@4.20.5`: succeeded.
- Focused strict TypeScript check from `agent-chat` with Bun types, including `adapters/codex.ts`: succeeded.
- `cd agent-chat && PATH="$HOME/.bun/bin:$PATH" bun run check`: succeeded.
- `./scripts/reload.sh --tag execution-telemetry-slice-5`: succeeded.

Slice 6 validation:

- `git diff --check`: succeeded.
- `agent-chat/test/codex-telemetry-migration.test.ts` via `tsx@4.20.5`: succeeded.
- `agent-chat/test/execution-telemetry-fanout.test.ts` via `tsx@4.20.5`: succeeded.
- Focused strict TypeScript check from `agent-chat` with Bun types, including `adapters/codex.ts`: succeeded.
- `cd agent-chat && PATH="$HOME/.bun/bin:$PATH" bun run check`: succeeded.
- `./scripts/reload.sh --tag execution-telemetry-slice-6`: succeeded.

Slice 7 validation:

- `git diff --check`: succeeded.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/codex-telemetry-migration.test.ts`: succeeded.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-fanout.test.ts`: succeeded.
- `cd agent-chat && PATH="$HOME/.bun/bin:$PATH" bun run check`: succeeded.
- `./scripts/reload.sh --tag execution-telemetry-slice-7`: succeeded.

Slice 8 validation:

- `git diff --check`: succeeded.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/codex-telemetry-migration.test.ts`: succeeded.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-fanout.test.ts`: succeeded.
- `cd agent-chat && PATH="$HOME/.bun/bin:$PATH" bun run check`: succeeded.
- `./scripts/reload.sh --tag execution-telemetry-slice-8`: succeeded.

Slice 9 validation:

- `git diff --check`: succeeded.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/codex-telemetry-migration.test.ts`: succeeded.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-fanout.test.ts`: succeeded.
- `cd agent-chat && PATH="$HOME/.bun/bin:$PATH" bun run check`: succeeded.
- `./scripts/reload.sh --tag execution-telemetry-slice-9`: succeeded.

Slice 10 validation:

- `git diff --check`: succeeded.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/codex-telemetry-migration.test.ts`: succeeded.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-fanout.test.ts`: succeeded.
- `cd agent-chat && PATH="$HOME/.bun/bin:$PATH" bun run check`: succeeded.
- `./scripts/reload.sh --tag execution-telemetry-slice-10`: succeeded.

Slice 11 validation:

- `git diff --check`: succeeded.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/codex-telemetry-migration.test.ts`: succeeded.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-fanout.test.ts`: succeeded.
- `cd agent-chat && PATH="$HOME/.bun/bin:$PATH" bun run check`: succeeded.
- `./scripts/reload.sh --tag execution-telemetry-slice-11`: succeeded.

Plan Slice 4A validation:

- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-live-projection.test.ts`: succeeded.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-fanout.test.ts`: succeeded.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/codex-telemetry-migration.test.ts`: succeeded.
- `cd agent-chat && PATH="$HOME/.bun/bin:$PATH" bun run check`: succeeded.
- `git diff --check`: succeeded.
- `./scripts/reload.sh --tag execution-telemetry-live-projection`: succeeded.

Plan Slice 4B validation:

- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-live-projection.test.ts`: succeeded.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-fanout.test.ts`: succeeded.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/codex-telemetry-migration.test.ts`: succeeded.
- `cd agent-chat && PATH="$HOME/.bun/bin:$PATH" bun run check`: succeeded.
- `git diff --check`: succeeded.
- `./scripts/reload.sh --tag execution-telemetry-live-projection`: succeeded.

## Known Failures

- Running `tsc` from the repo root through transient `npm exec` still does not resolve local Bun and Node ambient types. Run TypeScript checks from `agent-chat` with `PATH="$HOME/.bun/bin:$PATH"` so local package types are used.
- No runtime code changed in Slice 0, so no app build was run.
- No runtime behavior changed in Slice 1; only a type-only contract module and docs were added.

## Next Required Action

Review `execution-telemetry-live-projection`. A later slice can add a native bridge consumer for the bounded live projection or continue provider migration, but should still avoid persistence, provenance writes, Swift schema ownership, React rendering changes, and WebSocket `AgentEvent` payload changes until those are explicitly in scope.

## Blocked Decisions

No current blocked decisions for Plan Slice 4B. Slice 1 decided the canonical contract location, Swift sync policy, event id and ordering policy, provider metadata policy, and raw-envelope exclusion. Plan Slice 4A adds the first live projection replay policy in `docs/execution-telemetry/decisions.md`; Plan Slice 4B adds the in-memory REST-only live read boundary.

## Deviations From Original Plan

- The required docs were created during Slice 0 because they did not already exist.
- Baseline tests were attempted but could not run because `bun` was missing from PATH.
- provenance-engine was inspected read-only; no provenance-engine files were changed.
