# Execution Telemetry Handoff

## Session identity

- Date: 2026-07-31
- Slice: Claude lifecycle telemetry pending review on draft PR #13
- Main evidence baseline: `c616bcfbb4dc222a1d4c3c99ab3a933383714cab`
- Historical implementation branch: `execution-telemetry-live-projection`

## Objective completed

Implemented the narrow durable producer for broad sidecar
session/provider/lifecycle facts. Supported live sidecar sessions with a
bounded live projection now produce enough Provenance Engine lifecycle evidence
for the existing read-only diagnostic to match Current State.

The diagnostic remains observational and read-only.

This implementation is now contained in `main`. Do not treat the historical
branch as an active implementation branch unless new work is explicitly
selected.

## Implementation completed

- Added a native `AgentChatSessionListClient` and bounded
  `AgentChatSessionSummary` DTO for the existing `GET /api/sessions` sidecar
  endpoint.
- Added `ExecutionTelemetryProvenanceProjectionService`, a native app-side
  observer that polls the sidecar session list, reads each bounded live
  projection, and records only idle/running lifecycle presence.
- Reused the existing public Provenance Engine SDK write path through
  `WorkProvenanceSessionLifecycleRecorder`.
- Recorded only the allowed durable facts: bmux sidecar session id, provider
  kind, provider session id when available, and a derived worktree id.
- Did not persist working-directory paths in the new sidecar lifecycle request;
  the cwd is used only to derive the worktree id.
- Dedupe is in memory per sidecar session/provider/provider-session identity.
- The observer starts for the default sidecar URL at runtime and switches to a
  configured Agent Chat URL when the Agent Chat action uses one.
- XCTest app bootstraps skip the sidecar poller to avoid unit-test network
  noise.

## Preserved boundaries

- No telemetry persistence.
- No raw provider envelopes.
- No raw errors, command output, transcripts, private reasoning, changed file
  paths, approval payloads, or token usage details are written to provenance.
- No React rendering changes.
- No WebSocket `AgentEvent` changes.
- No Swift ownership of the canonical telemetry schema.
- No Claude structured-source work.
- No automatic diagnostic checkpoint scheduling.

## Dogfood completed

- Built tagged Debug app with `./scripts/reload.sh --tag
  execution-telemetry-live-projection`, build 293.
- Launched the tagged app from the exact DerivedData app path.
- Started `agent-chat` on `127.0.0.1:7739`.
- Created Codex sidecar session `79a4701f` in `/Users/brianbusby/repos/bmux`.
- Live projection settled to provider `codex`, provider session id
  `019fb1bd-bc6b-7141-8926-df2554f0c5e4`, lifecycle `idle`.
- The tagged CLI diagnostic text mode reported:
  `No execution telemetry observation mismatches for 79a4701f.`
- The tagged CLI diagnostic JSON mode reported `status: matched`,
  `mismatch_count: 0`, and an empty `mismatches` array.

## Validation

- Focused `BmuxAgentChat` `ChatMessageCodableTests`: passed.
- Full `BmuxAgentChat` package suite with `--no-parallel`: passed.
- Focused `bmux-unit` `SessionProvenanceTests`: passed.
- Focused `bmux-unit` `WorkProvenanceObserverTests`: passed.
- `git diff --check`: passed.
- Tagged reload passed with local build number 293.

## Next slice

The first non-Codex provider migration, Claude lifecycle telemetry, is
implemented on draft PR #13 at
`5a4a463f17e07a1c5e2a037f07bfe4f743f839c5` and is pending review. No
subsequent execution telemetry implementation slice is selected.

Explicitly selectable later work:

- live-dogfood Claude Agent Chat sessions after PR #13 review;
- decide whether to migrate a bounded Claude tool lifecycle source;
- dogfood with a configured non-default Agent Chat URL;
- decide whether sidecar session disappearance should record a stopped
  lifecycle fact;
- design automatic 5/10/15/20/25-minute diagnostic checkpoint policy and then
  implement it;
- continue provider migration after the Claude lifecycle PR is accepted or
  closed.

Keep telemetry persistence, broad provenance writes, React rendering changes,
WebSocket payload changes, Swift schema ownership, raw Claude stream-json
envelopes, transcript/tool output capture, token usage assumptions,
changed-file paths, and automatic diagnostic checkpoint scheduling out of scope
unless a later policy slice selects them.
