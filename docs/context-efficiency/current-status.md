# Bmux Context Efficiency: Current Status

This file is the live handoff index for context-efficiency, provenance, and
handoff work. Volatile project-state facts are generated from manifests and must
not be maintained here.

## Current Generated Truth

- [Project status](../generated/project-status.md)
- [Ownership boundary](../generated/ownership-boundary.md)
- [Repository status](../generated/repository-status.md)

Update `project/repo-status.yaml` for bmux-local slice, release, capability, or
caveat changes. Shared milestone, gate, ownership, and policy changes belong in
`BrianBusby/provenance-engine:project/project-state.yaml`.

## Read Order

1. `AGENTS.md`
2. `docs/README.md`
3. `docs/generated/project-status.md`
4. `docs/generated/ownership-boundary.md`
5. `docs/generated/repository-status.md`
6. `docs/roadmap.md`
7. `docs/provenance-integration.md`
8. `docs/context-efficiency/roadmap.md`
9. `docs/context-efficiency/milestones.md`
10. `docs/context-efficiency/adr-001-provenance-engine-extraction.md`
11. Relevant bmux skills for Swift/package/build/test/localization work.

## Current Boundary

Do not add new provenance consumer behavior to bmux-local direct SQLite readers,
`WorkProvenanceStore`, or `BmuxLegacyProvenanceClient`. Those remain only for
legacy support, tests, and lifecycle trace presentation until a separate cleanup
slice removes or replaces them.

Execution telemetry remains bmux-owned high-frequency runtime state. Provenance
Engine receives only explicitly approved durable engineering evidence through
the public SDK. The accepted next direction is more precise: raw provider
streams and deltas stay live/ephemeral in bmux, while selected completed or
meaningful evidence units may become durable PE evidence once explicit
contracts, retention policy, and privacy review exist.

Richer Session Evidence Foundation is the latest implemented slice. bmux now
forwards selected completed Codex evidence units through the existing
provider-neutral execution telemetry path to Provenance Engine public append
contracts. PE records provider thread/turn identity, submitted prompt, plan
updates, completed command facts, visible reasoning summaries, and file-change
attribution as durable observable evidence below the semantic layer.

Next planning target: PE owns the future `SessionWorkModel` projection for one
coding-agent session. bmux should consume that revisioned authoritative snapshot
for human-readable live work views and should not build a parallel semantic
milestone/architecture model. Current implemented behavior remains lower-level
evidence modeling and deterministic projection; SessionWorkModel, inference,
milestone synthesis, and architecture projection are not implemented.

Verification for this slice:

- PE: `swift test`
- PE docs: `./scripts/project-docs validate && ./scripts/project-docs generate && ./scripts/project-docs check`
- bmux sidecar test: `cd agent-chat && bun test/codex-telemetry-migration.test.ts`
- bmux Swift package test: `cd Packages/Shared/BmuxAgentChat && swift test --filter executionTelemetryEventClientReadsBoundedCursorEndpoint`
- bmux focused test: `BMUX_SKIP_ZIG_BUILD=1 xcodebuild test -project bmux.xcodeproj -scheme bmux-unit -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/bmux-richer-session-evidence-foundation -only-testing:bmuxTests/SessionProvenanceTests`
- bmux docs: `./scripts/project-docs validate && ./scripts/project-docs generate && ./scripts/project-docs check`
- bmux tagged reload: `./scripts/reload.sh --tag richer-session-evidence-foundation`

Known local quirk: the normal Xcode app build script can fail while building the
Ghostty CLI helper with Zig unresolved macOS symbols on this machine. The focused
test used the repo-supported `BMUX_SKIP_ZIG_BUILD=1` stub path. The tagged
reload succeeded through `reload.sh`, which automatically skipped the local
Ghostty CLI helper build for this macOS SDK/Zig combination.
Additional local quirk: `cd agent-chat && bun x tsc --noEmit` currently fails
on `adapters/lines.ts` because `ReadableStream<Uint8Array<ArrayBufferLike>>`
lacks an async iterator in the active TypeScript library environment. The
focused Codex telemetry test still passes.

## Current Handoffs

- Project Truth: `docs/handoffs/latest.md`
- Execution telemetry: `docs/execution-telemetry/handoffs/latest.md`

## Historical Evidence

Historical slice details remain in:

- `docs/context-efficiency/integration/provenance-engine-adoption-history.md`
- `docs/context-efficiency/integration/provenance-engine-adoption.md`
- `docs/execution-telemetry/implementation-status.md`
- `docs/execution-telemetry/handoffs/`
