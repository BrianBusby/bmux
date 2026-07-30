# Execution Telemetry Handoff

## Session identity

- Date: 2026-07-30
- Slice: Durable execution-evidence policy after diagnostic dogfood
- Branch: `execution-telemetry-live-projection`
- Starting commit: `027917a12cc13da963de62b655cf652c751fae55`

## Objective completed

Dogfooded the read-only execution telemetry diagnostic against a real live
Codex sidecar session and recorded the durable execution-evidence policy.

Execution telemetry remains bmux-owned high-frequency runtime state. It is not
durable provenance evidence by default.

## Dogfood completed

- Launched the existing tagged Debug app for
  `execution-telemetry-live-projection`.
- Verified the tag-bound CLI helper talked to the tagged socket.
- Started `agent-chat` on `127.0.0.1:7739`.
- Created Codex session `05384b5e` with a harmless prompt.
- Confirmed the live projection settled to provider `codex`, provider session
  id `019fb0b3-ca8f-7cb1-88b0-31412a83a332`, lifecycle `idle`, no active
  operations, and a bounded usage summary.
- Ran the diagnostic through `scripts/bmux-debug-cli.sh` in text mode.
- Ran the same diagnostic with `--json`.

Both diagnostic modes reported exactly one bounded mismatch:
`current_state_session_missing`. This matches the expected boundary that a live
sidecar session does not automatically create durable Provenance Engine Current
State lifecycle evidence.

## Policy completed

Eligible future durable projection facts are limited to broad
session/provider/lifecycle facts:

- bmux session id and provider kind;
- provider session id when available;
- repository or worktree association when bmux can derive it within the
  existing provenance boundary;
- broad lifecycle presence such as active/running versus inactive/idle.

Everything else remains out of durable provenance scope by default, including
message text and deltas, private reasoning, tool inputs and outputs, command
output, raw provider envelopes, raw errors, changed file paths, approval request
payloads, and token usage details.

## Preserved boundaries

- No telemetry persistence.
- No provenance append/write path.
- No raw provider envelopes.
- No raw errors, command output, transcripts, private reasoning, or changed
  file paths.
- No React rendering changes.
- No WebSocket `AgentEvent` payload changes.
- No Swift ownership of the canonical telemetry schema.
- No automatic diagnostic checkpoint scheduling.

## Validation

- Diagnostic text mode against live session `05384b5e`: passed with the
  expected bounded mismatch.
- Diagnostic JSON mode against live session `05384b5e`: passed with
  `status: mismatched`, `mismatch_count: 1`, and no sensitive payload fields.
- `git diff --check`: passed.

## Next slice

No next execution telemetry implementation slice is selected.

Reasonable later work:

- implement a narrow durable producer for broad session/provider/lifecycle facts
  only;
- wire an app/native consumer to the existing package client;
- continue provider migration.

Keep telemetry persistence, broad provenance writes, React rendering changes,
WebSocket payload changes, Swift schema ownership, Claude structured-source
work, and automatic diagnostic checkpoint scheduling out of scope unless a
later policy slice selects them.
