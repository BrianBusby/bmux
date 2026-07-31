# Execution Telemetry Implementation Status

Last updated: 2026-07-30

## Plan Orientation

Canonical bmux roadmap reconciliation completed on 2026-07-29 by merging
`origin/main` into this branch. Current main defines Provenance Engine Slice E
as operationally complete and sets the active product gate to the Engineering
Observation Period.

Execution telemetry is bmux-owned high-frequency runtime state. Provenance
Engine owns selected durable evidence and deterministic Current State. The
execution telemetry plan's "Plan Slice 4B" numbering is unrelated to Provenance
Engine Slice E.

| Plan area | Current position | Notes |
| --- | --- | --- |
| Provider-neutral Codex telemetry migration | Slices 0 through 11 completed on the stacked Slice 1 branch history. | Existing React `AgentEvent` projection behavior is preserved. |
| Live session projection foundation | Plan Slice 4A completed on `execution-telemetry-live-projection`. | Adds a renderer-independent replay projection from ordered `TelemetryEventEnvelope` values. |
| Live projection sidecar read surface | Plan Slice 4B completed on `execution-telemetry-live-projection`. | Wires the live projection to the sidecar fanout as an in-memory subscriber and exposes a bounded REST read payload; no React rendering, WebSocket `AgentEvent`, persistence, or provenance changes. |
| Native live projection read client | Plan Slice 4C completed on `execution-telemetry-live-projection`. | Adds Swift DTOs and an injected HTTP read client in `BmuxAgentChat` for the existing REST payload, plus a shared JSON fixture drift check; no rendering, WebSocket, persistence, provenance, or Swift schema ownership changes. |
| Read-only observation diagnostic | Completed on `execution-telemetry-live-projection`. | Adds a provider-neutral package comparison value and `bmux provenance diagnostics execution-telemetry-live <session-id>` CLI report. It compares only session presence, provider identity, and broad lifecycle presence between the live projection and Provenance Engine Current State; no persistence, provenance writes, React rendering changes, WebSocket changes, or automatic scheduling. |
| Durable execution-evidence policy | Completed on `execution-telemetry-live-projection`. | Dogfooded the diagnostic against a real live Codex sidecar session and recorded the policy that execution telemetry is not durable provenance evidence by default. Only broad session/provider/lifecycle facts are eligible for a future explicit projection slice. |
| Narrow durable lifecycle producer | Completed on `execution-telemetry-live-projection`. | Adds an app-side producer for broad live sidecar session/provider/lifecycle facts only. The existing diagnostic remains read-only and now matches supported lifecycle-backed live sessions. |
| First non-Codex provider migration | Completed on `execution-telemetry-provider-migration-next`. | Audited Claude stream-json support and migrated only prompt submission, provider session identity, coarse result lifecycle, and sidecar process-close failure through the existing telemetry fanout. |

## Active Slice

First non-Codex provider migration.

Status: completed in branch `execution-telemetry-provider-migration-next`;
started from current `origin/main` after the live projection/provenance
lifecycle work merged at `9d7fefacb`.

The selected slice audited `agent-chat/adapters/claude.ts` and found only a
narrow authoritative source set: sidecar prompt dispatch, Claude stream-json
`system/init` provider session identity, Claude stream-json `result`
completion/result-error closure, and sidecar process-close failure for active
turns. It does not claim Claude parity with Codex.

Recent implementation validation: focused Claude active-turn telemetry test,
execution telemetry fanout test, Codex telemetry migration test, and full
`agent-chat` package check passed before the final reload build.

Latest dogfood: no live Claude dogfood session was run in this slice. The
implementation is covered by handler-level tests against the audited Claude
stream-json `system/init` and `result` events plus sidecar process-close
failure behavior.

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
- Plan Slice 4C: added the native live projection read client and shared fixture drift check.
- Observation diagnostic: added `ExecutionTelemetryObservationDiagnostic` in `BmuxAgentChat` and a read-only CLI surface at `bmux provenance diagnostics execution-telemetry-live <session-id>`. The CLI reads the live projection through `ExecutionTelemetryLiveProjectionClient.read(sessionID:)`, reads Provenance Engine Current State through the existing public client/current-context path, and reports mismatch rows only. It does not store raw provider envelopes, raw errors, command output, transcripts, private reasoning, changed file paths, telemetry state, or provenance events.
- Durable execution-evidence policy: dogfooded the observation diagnostic
  against live Codex session `05384b5e` and decided that execution telemetry is
  not durable provenance evidence by default. Only broad
  session/provider/lifecycle facts are eligible for a future explicit
  projection slice.
- Narrow durable lifecycle producer: added an app-side producer that reads the
  existing sidecar session list and bounded live projection, then records only
  broad session/provider/lifecycle facts through the public Provenance Engine
  lifecycle API. Dogfood against live Codex session `79a4701f` reported zero
  diagnostic mismatches.
- First non-Codex provider migration: added Claude telemetry helper producers
  and routed sidecar prompt submission, `system/init` provider session linking,
  `result` completion/result-error closure, and sidecar process-close active
  turn failure through `ExecutionTelemetryFanout`. Existing React `AgentEvent`
  behavior is preserved; Claude message/tool streams, raw stream-json
  envelopes, token usage assumptions, changed files, telemetry persistence,
  provenance writes, WebSocket changes, and React rendering changes remain out
  of scope.

## Current Branch

`execution-telemetry-provider-migration-next`

Started from `main` at `9d7fefacbb40` after `git fetch origin`,
`git checkout main`, `git pull --ff-only origin main`, and `git checkout -b
execution-telemetry-provider-migration-next`.

Scoped implementation head is this branch's pushed head commit for the first
non-Codex provider migration.

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
- `./scripts/reload.sh --tag execution-telemetry-provider-migration-next`: succeeded, local build number 294.
- `git diff --check`: succeeded.
- `./scripts/reload.sh --tag execution-telemetry-live-projection`: succeeded.

Plan Slice 4B validation:

- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-live-projection.test.ts`: succeeded.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-fanout.test.ts`: succeeded.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/codex-telemetry-migration.test.ts`: succeeded.
- `cd agent-chat && PATH="$HOME/.bun/bin:$PATH" bun run check`: succeeded.
- `git diff --check`: succeeded.
- `./scripts/reload.sh --tag execution-telemetry-live-projection`: succeeded.

Plan Slice 4C validation: succeeded.

Observation diagnostic validation:

- `python3 -m json.tool Resources/Localizable.xcstrings >/dev/null`: succeeded.
- `git diff --check`: succeeded.
- `swift test --package-path Packages/Shared/BmuxAgentChat --filter ChatMessageCodableTests`: succeeded with 13 Swift Testing cases, including the new observation diagnostic coverage.
- `swift test --package-path Packages/Shared/BmuxAgentChat --no-parallel`: succeeded with 203 Swift Testing cases.
- `BMUX_SKIP_ZIG_BUILD=1 xcodebuild test -project bmux.xcodeproj -scheme bmux-unit -destination 'platform=macOS' -derivedDataPath /tmp/bmux-execution-telemetry-live-projection -only-testing:bmuxTests/WorkProvenanceObserverTests`: succeeded with 3 Swift Testing cases.
- `./scripts/reload.sh --tag execution-telemetry-live-projection`: succeeded, local build number 292.

Durable execution-evidence policy dogfood:

- Existing tagged Debug app launched from the tag-specific DerivedData app path.
- The tag-bound CLI helper succeeded against the tagged socket.
- `PATH="$HOME/.bun/bin:$PATH" bun server.ts` from `agent-chat`: started the sidecar on `127.0.0.1:7739`.
- `POST /api/sessions` created Codex session `05384b5e`.
- The live projection for `05384b5e` returned provider `codex`, provider session id `019fb0b3-ca8f-7cb1-88b0-31412a83a332`, lifecycle `idle`, a usage summary, and no active operations.
- Diagnostic text mode reported one bounded mismatch, `current_state_session_missing`.
- Diagnostic JSON mode returned `status: mismatched`, `mismatch_count: 1`, and only the mismatch code plus broad live/current-state presence values.

First non-Codex provider migration validation:

- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/claude-active-turn.test.ts`: succeeded.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-fanout.test.ts`: succeeded.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/codex-telemetry-migration.test.ts`: succeeded.
- `cd agent-chat && PATH="$HOME/.bun/bin:$PATH" bun run check`: succeeded.
- `git diff --check`: succeeded.
- `./scripts/reload.sh --tag execution-telemetry-provider-migration-next`: succeeded, local build number 294.

## Known Failures

- Running `tsc` from the repo root through transient `npm exec` still does not resolve local Bun and Node ambient types. Run TypeScript checks from `agent-chat` with `PATH="$HOME/.bun/bin:$PATH"` so local package types are used.
- `swift test --package-path Packages/Shared/BmuxAgentChat` without `--no-parallel` aborted once with `freed pointer was not the last allocation`; the same full package suite passed with `--no-parallel`.
- No runtime code changed in Slice 0, so no app build was run.
- No runtime behavior changed in Slice 1; only a type-only contract module and docs were added.

## Next Required Action

The first non-Codex provider migration is implemented and covered by focused
handler-level tests. No next execution telemetry implementation slice is
selected. A later slice can live-dogfood Claude Agent Chat sessions, decide
whether to migrate a bounded Claude tool lifecycle source, dogfood configured
non-default Agent Chat URLs, decide whether sidecar session disappearance
should record stopped lifecycle facts, or wire more app/native consumers to the
package client. Do not add telemetry persistence, broad provenance writes,
React rendering changes, WebSocket payload changes, Swift schema ownership, raw
Claude stream-json envelopes, transcript/tool output capture, token usage
assumptions, changed-file paths, or automatic diagnostic scheduling without an
explicit policy slice.

## Observation Diagnostic Evaluation

The bounded diagnostic is implemented as a read-only comparison between
`ExecutionTelemetryLiveProjectionClient.read(sessionID:)` and the existing
Provenance Engine Current State client path.

Keep the diagnostic observational:

- compare session/provider/turn presence and lifecycle broad state only;
- report mismatches without writing telemetry or provenance records;
- treat Provenance Engine Current State as authoritative durable evidence;
- treat the live projection as ephemeral runtime state;
- avoid command output, transcripts, changed file paths, raw errors, and raw
  provider envelopes.

## Durable Execution Evidence Policy

Execution telemetry remains bmux-owned high-frequency runtime state and is not
durable provenance evidence by default.

Eligible future durable projection facts are limited to broad
session/provider/lifecycle facts: bmux session id, provider kind, provider
session id when available, repository/worktree association when bmux can derive
it within the existing provenance boundary, and broad lifecycle presence such
as active/running versus inactive/idle.

Message text, deltas, private reasoning, tool inputs or outputs, command
output, raw provider envelopes, raw errors, changed file paths, approval request
payloads, and token usage details remain out of durable provenance scope unless
a later policy slice explicitly selects them.

## Blocked Decisions

No current blocked decisions for durable execution-evidence policy. Slice 1
decided the canonical contract location, Swift sync policy, event id and
ordering policy, provider metadata policy, and raw-envelope exclusion. Plan
Slice 4A adds the first live projection replay policy in
`docs/execution-telemetry/decisions.md`; Plan Slice 4B adds the in-memory
REST-only live read boundary; Plan Slice 4C adds the native read-client
boundary and shared fixture drift check. The durable execution-evidence policy
records that execution telemetry is not durable provenance evidence by default.

## Deviations From Original Plan

- The required docs were created during Slice 0 because they did not already exist.
- Baseline tests were attempted but could not run because `bun` was missing from PATH.
- provenance-engine was inspected read-only; no provenance-engine files were changed.
