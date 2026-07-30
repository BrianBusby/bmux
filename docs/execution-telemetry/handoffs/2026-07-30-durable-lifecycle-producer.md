# Execution Telemetry Handoff

## Session identity

- Date: 2026-07-30
- Slice: Narrow durable lifecycle producer for live execution telemetry
- Branch: `execution-telemetry-live-projection`
- Starting commit: `036693febe00cc620aeb149595e0339e45b9307a`

## Completed

Implemented the narrow durable producer for broad live sidecar
session/provider/lifecycle facts. Supported live sidecar sessions now record a
Provenance Engine lifecycle-start fact with bmux session id, provider kind,
provider session id when available, and a derived worktree id.

The existing diagnostic remains read-only. Dogfood session `79a4701f` reached
provider `codex`, provider session
`019fb1bd-bc6b-7141-8926-df2554f0c5e4`, lifecycle `idle`, and both text and
JSON diagnostics reported zero mismatches.

## Boundaries

No telemetry persistence, raw provider envelopes, raw errors, command output,
transcripts, private reasoning, changed file paths, approval payloads, token
usage details, React rendering changes, WebSocket `AgentEvent` changes, Swift
schema ownership, Claude structured-source work, or automatic diagnostic
checkpoint scheduling were added.

## Validation

- Focused `BmuxAgentChat` `ChatMessageCodableTests`: passed.
- Full `BmuxAgentChat` package suite with `--no-parallel`: passed.
- Focused `bmux-unit` `SessionProvenanceTests`: passed.
- Focused `bmux-unit` `WorkProvenanceObserverTests`: passed.
- `git diff --check`: passed.
- Tagged reload passed, build 293.

## Next

No next execution telemetry implementation slice is selected. Reasonable later
work: dogfood a configured non-default Agent Chat URL, decide whether sidecar
session disappearance should record a stopped lifecycle fact, or continue
provider migration.
