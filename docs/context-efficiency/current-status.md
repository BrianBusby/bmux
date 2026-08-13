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
the public SDK.

Workspace Display Durable Context and Reconciliation is the latest implemented
slice. PE workspace-display Current State now reduces accepted evidence field by
field: missing observations preserve known facts, explicit clears are represented
as evidence, and field-level metadata records source/origin/event/freshness.
bmux remains the observer/refresh owner and renders the built-in workspace row
from PE Current State once the relevant fact is populated.

Verification for this slice:

- PE: `swift test`
- PE docs: `./scripts/project-docs validate && ./scripts/project-docs generate && ./scripts/project-docs check`
- bmux focused test: `BMUX_SKIP_ZIG_BUILD=1 xcodebuild test -project bmux.xcodeproj -scheme bmux-unit -destination 'platform=macOS' -derivedDataPath /tmp/bmux-workspace-display-durable-context-tests -only-testing:bmuxTests/WorkProvenanceObserverTests COMPILER_INDEX_STORE_ENABLE=NO`
- bmux docs: `./scripts/project-docs validate && ./scripts/project-docs generate && ./scripts/project-docs check`

Known local quirk: the normal Xcode app build script can fail while building the
Ghostty CLI helper with Zig unresolved macOS symbols on this machine. The focused
test used the repo-supported `BMUX_SKIP_ZIG_BUILD=1` stub path. A production
tagged reload still needs a successful non-stub helper build or the local Zig
toolchain issue resolved.

## Current Handoffs

- Project Truth: `docs/handoffs/latest.md`
- Execution telemetry: `docs/execution-telemetry/handoffs/latest.md`

## Historical Evidence

Historical slice details remain in:

- `docs/context-efficiency/integration/provenance-engine-adoption-history.md`
- `docs/context-efficiency/integration/provenance-engine-adoption.md`
- `docs/execution-telemetry/implementation-status.md`
- `docs/execution-telemetry/handoffs/`
