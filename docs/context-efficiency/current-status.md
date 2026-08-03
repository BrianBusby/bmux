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

## Current Handoffs

- Project Truth: `docs/handoffs/latest.md`
- Execution telemetry: `docs/execution-telemetry/handoffs/latest.md`

## Historical Evidence

Historical slice details remain in:

- `docs/context-efficiency/integration/provenance-engine-adoption-history.md`
- `docs/context-efficiency/integration/provenance-engine-adoption.md`
- `docs/execution-telemetry/implementation-status.md`
- `docs/execution-telemetry/handoffs/`
