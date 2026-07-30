# Bmux Context Efficiency: Current Status

Last updated: 2026-07-30

This file is the live handoff index for context-efficiency, provenance, and handoff work. Keep it concise; move slice history and detailed findings into topic documents.

## Read Order

1. `AGENTS.md`
2. `docs/roadmap.md`
3. `docs/provenance-integration.md`
4. `docs/context-efficiency/current-status.md`
5. `docs/context-efficiency/roadmap.md`
6. `docs/context-efficiency/milestones.md`
7. `docs/context-efficiency/adr-001-provenance-engine-extraction.md`
8. `docs/context-efficiency/provenance-engine-phase3-plan.md`
9. `docs/context-efficiency/provenance-engine-phase4-reconnect-plan.md`
10. `docs/context-efficiency/integration/provenance-engine-adoption.md`
11. Relevant bmux skills for Swift/package/build/test/localization work.

## Active State

Operational V1 integration is complete with named caveats. Slice E, the
operational Provenance Engine V1 runtime cutover, is now the accepted
provenance state for the bmux mainline.

bmux now pins Provenance Engine revision `18f5511a7c836b3f12f3fa0fbe3aefe42efd3f03`, which contains the finalized V1 public contract and producer-neutral lifecycle API. The Xcode project links only the public engine products `ProvenanceEngineContracts` and `ProvenanceEngineSDK`.

Adopted read paths use public Current State/query APIs:

- `bmux provenance worktrees list` calls `client.worktrees(...)`.
- `bmux provenance sessions tree <session-id>` calls `client.sessionTree(...)`.
- `bmux provenance explain <path>` calls `client.fileExplanation(...)`.
- `bmux provenance context current` calls `client.currentContext(...)`.

Adopted write paths use public SDK APIs:

- Agent lifecycle capture calls `client.recordSessionLifecycle(...)` with `ProvenanceSessionLifecycleRequest`.
- Supported live sidecar execution telemetry sessions project only broad
  session/provider/lifecycle facts through `client.recordSessionLifecycle(...)`.
- Git/worktree observation capture calls `client.appendEvent(...)` with public `ProvenanceEvent` contracts.

bmux owns observation, stable producer identity assignment where available, retry/error policy, command parsing, Git path normalization, UI/workflow orchestration, and presentation. Provenance Engine owns evidence, deterministic Current State, provenance interpretation, and bounded provenance queries.

Planning clarification on 2026-07-29: Codex app-server should be the primary
live source for supported Codex-owned session/thread/event data in future
context-efficiency slices. Codex rollout JSONL and `state_N.sqlite` remain
historical backfill, recovery, unavailable-field, and raw-evidence sources.
The Provenance Engine remains the durable normalized provenance and lifecycle
query boundary; bmux remains responsible for capture orchestration,
presentation, fallback behavior, and workflow policy.
The explicit four-step Codex live ingestion sequence is recorded in
`docs/context-efficiency/proposed-integration.md`.

## Current Boundary

Do not add new provenance consumer behavior to bmux-local direct SQLite readers, `WorkProvenanceStore`, or `BmuxLegacyProvenanceClient`. Those remain only for legacy support, tests, and lifecycle trace presentation until a separate cleanup slice removes or replaces them.

The CLI trace path `bmux provenance traces lifecycle-ingestion` still reads bmux-local observability SQLite because V1 has no public observability trace API. This is not an adopted Current State path.

Historical slice details live in `docs/context-efficiency/integration/provenance-engine-adoption-history.md`. Current Slice E adoption details live in `docs/context-efficiency/integration/provenance-engine-adoption.md`.

## Next Target

Active milestone after Slice E: Engineering Observation Period, plus cleanup of named legacy surfaces.

Execution telemetry observation diagnostic completed on 2026-07-29 in branch
`execution-telemetry-live-projection`: `bmux provenance diagnostics
execution-telemetry-live <session-id>` compares the live projection with
Provenance Engine Current State read-only and reports bounded mismatch rows
only.

Execution telemetry diagnostic dogfood and durable evidence policy completed
on 2026-07-30 in the same branch. Dogfood against live Codex sidecar session
`05384b5e` reported the expected bounded mismatch
`current_state_session_missing`. Policy now records that execution telemetry is
not durable provenance evidence by default; only broad
session/provider/lifecycle facts are eligible for a future explicit projection
slice.

The narrow durable lifecycle producer completed on 2026-07-30 in the same
branch. Dogfood against live Codex sidecar session `79a4701f` reached provider
`codex`, provider session `019fb1bd-bc6b-7141-8926-df2554f0c5e4`, lifecycle
`idle`, and the read-only diagnostic reported zero mismatches in text and JSON
modes.

Potential follow-up work:

- Remove or retire `WorkProvenanceStore` and `BmuxLegacyProvenanceClient` after all remaining legacy tests and observability support have replacement contracts or are declared obsolete.
- Decide whether lifecycle observability traces need a public engine API or should remain bmux-local diagnostics.
- Cut a tagged Provenance Engine release so bmux can depend on a version tag rather than a revision pin.
- Dogfood a configured non-default Agent Chat URL, decide whether sidecar
  session disappearance should record stopped lifecycle facts, or continue
  provider migration. Keep telemetry persistence, raw provider data,
  transcript/tool/usage details, React/WebSocket changes, Swift schema
  ownership, and automatic diagnostic scheduling out of scope unless a later
  policy slice selects them.

## Canonical Details

bmux product roadmap: `docs/roadmap.md`.

bmux-local provenance integration notes: `docs/provenance-integration.md`.

Canonical shared integration roadmap: `https://github.com/BrianBusby/provenance-engine/blob/main/docs/bmux-integration-roadmap.md`.

Migration state and plan: `docs/context-efficiency/integration/provenance-engine-adoption.md`.

Slice history: `docs/context-efficiency/integration/provenance-engine-adoption-history.md`.

Findings template: `docs/context-efficiency/integration/provenance-engine-integration-findings-template.md`.

Durable roadmap: `docs/context-efficiency/roadmap.md`.

Phase 4 migration plan: `docs/context-efficiency/provenance-engine-phase4-reconnect-plan.md`.

## Validation Notes

Runtime cutover validation completed locally on 2026-07-26:

- Provenance Engine `swift build --package-path /Users/brianbusby/repos/provenance-engine`: passed.
- Provenance Engine `swift test --package-path /Users/brianbusby/repos/provenance-engine`: passed 93 tests.
- Provenance Engine `git -C /Users/brianbusby/repos/provenance-engine diff --check`: passed.
- Provenance Engine schema identity commit `18f5511a7c836b3f12f3fa0fbe3aefe42efd3f03` was pushed to `origin/main`.
- bmux `xcodebuild -resolvePackageDependencies -project bmux.xcodeproj -scheme bmux -derivedDataPath /Users/brianbusby/Library/Developer/Xcode/DerivedData/bmux-slice-e-v1`: passed.
- bmux focused provenance tests (`SessionProvenanceTests`, `WorkProvenanceObserverTests`) with `BMUX_SKIP_ZIG_BUILD=1`: passed 6 tests.
- bmux provenance CLI integration tests with `BMUX_BUNDLED_CLI_PATH` pointing at the tagged bundled CLI: passed after default bootstrap and incompatible-store coverage.
- bmux `./scripts/reload.sh --tag slice-e-v1 --launch`: passed for build 248. Local `--launch` exited after startup in this environment, so build 248 was manually opened from the exact `App path:` for live validation.
- Live canonical store: `~/.local/state/provenance-engine/provenance.sqlite`; schema tables and `provenance_metadata` identity rows were present.
- Live event count increased from 0 before app activity to 22 after restored worktree observation, fresh workspace/command activity, and hook-derived Codex lifecycle events.
- Public CLI reads verified: `provenance worktrees list`, `provenance context current`, `provenance explain provenance-live-validation.txt`, and `provenance sessions tree session-fec80075f92fc25a2978d2c1`.
- Current State showed one active Codex session attached to the bmux worktree after lifecycle writes included `worktreeID`.
- Legacy database `~/.local/state/bmux/work-provenance/bmux-work-provenance.sqlite` was left intact and is no longer opened by default.
- Remaining caveat: opening an agent-session surface alone does not create lifecycle evidence; supported hook/feed events must reach bmux.
