# Execution Telemetry Handoff

## Session identity

- Date: 2026-07-29
- Slice: Read-only observation diagnostic after Plan Slice 4C
- Branch: `execution-telemetry-live-projection`
- Starting commit: `f54175830070dddea7260b0fd10a97a8c12c42d7`

## Objective completed

Implemented a bounded read-only diagnostic comparing bmux's live execution
telemetry projection with Provenance Engine Current State.

Execution telemetry remains bmux-owned high-frequency runtime state.
Provenance Engine remains authoritative for selected durable evidence and
deterministic Current State.

## Work completed

- Added `ExecutionTelemetryObservationDiagnostic` to `BmuxAgentChat`.
- Added bounded Current State session and mismatch value types for the
  diagnostic comparison.
- Added package tests covering matched state and broad provider/lifecycle
  mismatch reporting.
- Added `bmux provenance diagnostics execution-telemetry-live <session-id>`.
- The CLI reads live telemetry through
  `ExecutionTelemetryLiveProjectionClient.read(sessionID:)`.
- The CLI reads Current State through the existing public Provenance Engine
  current-context path.
- The CLI reports mismatch rows only and supports `--agent-chat-url`,
  `--repository`, `--database`, and `--json`.
- Updated localized CLI usage/error/output strings in English and Japanese.

## Preserved boundaries

- No telemetry persistence.
- No provenance append/write path.
- No raw provider envelopes.
- No raw errors, command output, transcripts, private reasoning, or changed
  file paths in diagnostic payloads.
- No React rendering changes.
- No WebSocket `AgentEvent` payload changes.
- No Swift ownership of the canonical telemetry schema.
- No automatic diagnostic checkpoint scheduling.
- No durable execution-evidence policy decision in code.

## Validation

- `python3 -m json.tool Resources/Localizable.xcstrings >/dev/null`: passed.
- `git diff --check`: passed.
- `swift test --package-path Packages/Shared/BmuxAgentChat --filter ChatMessageCodableTests`: passed 13 Swift Testing cases.
- `swift test --package-path Packages/Shared/BmuxAgentChat --no-parallel`: passed 203 Swift Testing cases.
- `BMUX_SKIP_ZIG_BUILD=1 xcodebuild test -project bmux.xcodeproj -scheme bmux-unit -destination 'platform=macOS' -derivedDataPath /tmp/bmux-execution-telemetry-live-projection -only-testing:bmuxTests/WorkProvenanceObserverTests`: passed 3 Swift Testing cases.
- `./scripts/reload.sh --tag execution-telemetry-live-projection`: passed, local build number 292.

Observed local quirk: `swift test --package-path Packages/Shared/BmuxAgentChat`
without `--no-parallel` aborted once with `freed pointer was not the last
allocation`; the same full package suite passed serialized.

## Next slice

No next execution telemetry implementation slice is selected.

Later work can wire an app/native consumer to the package client, continue
provider migration, or explicitly decide durable execution-evidence policy.
Keep telemetry persistence, broad provenance writes, React rendering changes,
WebSocket payload changes, Swift schema ownership, Claude structured-source
work, and automatic diagnostic checkpoint scheduling out of scope unless a
later policy slice selects them.
