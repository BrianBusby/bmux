# Execution Telemetry Handoff

## Project Truth Note

Before changing execution-telemetry milestone, slice, persistence-policy, release,
or caveat state, update `project/repo-status.yaml` or the shared manifest in
`provenance-engine/project/project-state.yaml`, then run project-docs validation
and generation. Current generated status lives in:

- `docs/generated/project-status.md`
- `docs/generated/ownership-boundary.md`
- `docs/generated/repository-status.md`

Generated files must not be edited manually.

## Session identity

- Date: 2026-07-31
- Slice: First non-Codex provider migration merged via PR #13
- Historical branch: `execution-telemetry-provider-migration-next`
- Starting commit: `9d7fefacbb40`
- Implementation head: `010ea333b24ccca71b6cea4c1bad19642ffaa6c8`
- Merge commit: `3f49c5d5abbe3a4ed2cc8edfb8b81b003ceb0ed9`

## Objective completed

Audited Claude support in `agent-chat/adapters/claude.ts` and migrated only the
narrow lifecycle/identity facts that have an authoritative source in the
current stream-json path.

This does not claim Claude parity with Codex.

This implementation is now contained in `main`. Do not treat the historical
branch as an active implementation branch unless new work is explicitly
selected.

## Implementation completed

- Added `agent-chat/adapters/claudeTelemetry.ts` with bounded Claude producers
  for prompt submission, provider session linking, turn completion, and turn
  failure.
- Routed Claude sidecar prompt submission through the existing shared
  `server.ts` prompt hook and `ExecutionTelemetryFanout`.
- Routed Claude stream-json `system/init` provider session identity through
  `session.provider-linked` telemetry while preserving the existing single
  React `meta` event with `model` and `providerSessionId`.
- Routed Claude stream-json `result` success/error closure through
  `turn.completed` / `turn.failed` telemetry while keeping Claude cost,
  duration, turn-count display stats projection-only.
- Routed sidecar process-close failure for unfinished Claude turns through
  bounded `turn.failed` telemetry so live lifecycle state does not remain
  running after a mid-turn process exit.
- Extended the projection-only options with `doneStats` and
  `providerLinkedModel`; these values are not canonical envelope data.

## Preserved boundaries

- No telemetry persistence.
- No provenance writes or broad durable evidence expansion.
- No raw Claude stream-json envelopes.
- No raw errors, command output, transcripts, private reasoning, changed file
  paths, approval payloads, or token usage details.
- No Claude message, thinking, tool-use/tool-result, command-list,
  control/status, token usage, or changed-file migration.
- No React rendering changes.
- No WebSocket `AgentEvent` schema changes.
- No Swift ownership of the canonical telemetry schema.

## Validation

- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/claude-active-turn.test.ts`: passed.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/execution-telemetry-fanout.test.ts`: passed.
- `npm exec --yes --package tsx@4.20.5 -- tsx agent-chat/test/codex-telemetry-migration.test.ts`: passed.
- `cd agent-chat && PATH="$HOME/.bun/bin:$PATH" bun run check`: passed.
- `git diff --check`: passed.
- `./scripts/reload.sh --tag execution-telemetry-provider-migration-next`: passed, local build number 294.

## Dogfood

No live Claude dogfood session was run in this slice. The selected behavior is
covered by handler-level tests against the audited Claude stream-json
`system/init` and `result` events plus sidecar process-close failure behavior.

## Next slice

The first non-Codex provider migration, Claude lifecycle telemetry, is
implemented and merged to `main` via PR #13. No subsequent execution telemetry
implementation slice is selected.

Reasonable later work:

- live-dogfood Claude Agent Chat sessions against the sidecar live projection;
- decide whether a bounded Claude tool lifecycle source is safe to migrate;
- dogfood configured non-default Agent Chat URLs;
- decide whether sidecar session disappearance should record stopped lifecycle
  facts;
- design automatic 5/10/15/20/25-minute diagnostic checkpoint policy and then
  implement it;
- wire more app/native consumers to the package client.

Keep telemetry persistence, broad provenance writes, React rendering changes,
WebSocket payload changes, Swift schema ownership, raw provider envelopes,
transcripts, tool output, token usage assumptions, changed-file paths, and
automatic diagnostic checkpoint scheduling out of scope unless a later policy
slice selects them.

## Next Project Truth Slice

Add required `project-truth` CI validation, cross-repository invariant checking, GitHub PR/issue state verification, and drift detection. Do not select GitHub App synchronization before the read-only CI checks have been proven.
