# Execution Telemetry Handoff

## Session identity

- Date: 2026-07-30
- Slice: Narrow durable lifecycle producer for live execution telemetry
- Branch: `execution-telemetry-live-projection`
- Starting commit: `036693febe00cc620aeb149595e0339e45b9307a`

## Objective completed

Implemented the narrow durable producer for broad sidecar
session/provider/lifecycle facts. Supported live sidecar sessions with a
bounded live projection now produce enough Provenance Engine lifecycle evidence
for the existing read-only diagnostic to match Current State.

The diagnostic remains observational and read-only.

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

No next execution telemetry implementation slice is selected.

Reasonable later work:

- dogfood with a configured non-default Agent Chat URL;
- decide whether sidecar session disappearance should record a stopped
  lifecycle fact;
- continue provider migration.

Keep telemetry persistence, broad provenance writes, React rendering changes,
WebSocket payload changes, Swift schema ownership, Claude structured-source
work, and automatic diagnostic checkpoint scheduling out of scope unless a
later policy slice selects them.
