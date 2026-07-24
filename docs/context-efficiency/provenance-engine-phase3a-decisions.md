# Provenance Engine Extraction: Phase 3A Decisions

Status: completed on 2026-07-21 for ADR-001 Phase 3A.

Inputs:

- `docs/context-efficiency/adr-001-provenance-engine-extraction.md`
- `docs/context-efficiency/provenance-engine-extraction-phase0-report.md`
- `docs/context-efficiency/provenance-engine-contracts-phase1-plan.md`
- `docs/context-efficiency/provenance-engine-phase3-plan.md`

## Purpose

Phase 3A resolves the scaffold-blocking product and repository decisions for
the independent Provenance Engine before any files are created outside bmux.

This document does not create the engine repository, package skeleton, SDK,
daemon, storage migration, bmux reconnect, retrieval layer, lifecycle policy,
UI, or observability expansion.

## Decisions

| Topic | Decision |
| --- | --- |
| Canonical local repository path | `/Users/brianbusby/repos/provenance-engine` |
| Canonical GitHub repository | `BrianBusby/provenance-engine` |
| Canonical remote URL | `git@github.com:BrianBusby/provenance-engine.git` |
| V1 implementation language | Swift 6 |
| V1 package manager | Swift Package Manager |
| First artifact type | Standalone SwiftPM library package |
| First package name | `ProvenanceEngine` |
| First module name | `ProvenanceEngineContracts` |
| First SDK relationship | In-process-only SDK contracts first; daemon-backed transport comes later |
| Engine-owned default storage path for new data | `~/.local/state/provenance-engine/provenance.sqlite` |
| Initial observability scope | Excluded from the initial authoritative engine skeleton |

## Ownership Strategy

The provenance engine is initially owned and maintained under the `BrianBusby`
GitHub account. The repository may be transferred to a future organization, for
example `manaflow-ai`, once the project matures.

Repository ownership is an implementation detail. It must not affect package
names, APIs, module boundaries, documentation structure, storage defaults, or
integration with bmux.

## Initial Package And Module Names

The Phase 3B skeleton should create a standalone SwiftPM package at:

```text
/Users/brianbusby/repos/provenance-engine
```

Initial package:

```text
ProvenanceEngine
```

Initial module:

```text
ProvenanceEngineContracts
```

The first module should be Foundation-only and limited to public contract
values and protocols that can compile without bmux, AppKit, SwiftUI, SQLite, or
daemon transport. It should include health/capability contracts and the narrow
Phase 2 request/response vocabulary needed for bmux as the first client.

Reserved later module names:

- `ProvenanceEngineCore` for domain values that are not merely client contracts.
- `ProvenanceEngineSQLite` for the engine-owned SQLite repository/storage layer.
- `ProvenanceEngineClient` for transport-backed client code once the daemon API
  exists.

Reserved later executable names:

- `provenance-engine-daemon`
- `provenance`

Do not create reserved later modules or executables in Phase 3B unless the
Phase 3B task explicitly expands scope.

## SDK And Daemon Relationship

The first SDK is in-process-only.

Reasoning:

- The reusable implementation is currently Swift and already exercised through
  in-process contract seams in bmux.
- An in-process contracts package lets bmux adopt the independent product
  boundary without inventing daemon lifecycle, IPC, launch, and degradation
  behavior prematurely.
- The public contracts should remain daemon-compatible so a later daemon-backed
  SDK can implement the same surface without changing bmux-owned adapter code.

Phase 3B may create only the contract library. It must not add a daemon, IPC
protocol, launch agent, background process lifecycle, automatic orchestration,
or bmux reconnect.

## Storage Default

For new engine-owned data, the default SQLite path is:

```text
~/.local/state/provenance-engine/provenance.sqlite
```

This is a new-data default only. Phase 3A and Phase 3B must not move, rename,
copy, delete, or migrate existing bmux provenance data at:

```text
~/.local/state/bmux/work-provenance/bmux-work-provenance.sqlite
```

Migration from bmux-owned paths remains Phase 5 work and must be idempotent,
resumable, validated, and reversible during development.

SQLite table shape remains internal engine implementation detail and is not
public API.

## Observability Boundary

`ProvenanceObservabilityStore` remains separate from authoritative provenance
APIs.

The initial Phase 3B authoritative engine skeleton excludes observability:

- no observability package;
- no observability schema;
- no trace storage move;
- no lifecycle trace query lift;
- no quality, feedback, evaluation, dashboard, or shadow-comparison surface.

Lifecycle trace contracts may be revisited later as an operational telemetry
surface, but they must remain separate from authoritative provenance contracts.

## Phase 3B Scaffold Gate

Phase 3B may scaffold the independent repository only if it follows these
decisions exactly:

1. Use `/Users/brianbusby/repos/provenance-engine` as the local repository path.
2. Use `BrianBusby/provenance-engine` as the initial GitHub repository.
3. Use Swift 6 and Swift Package Manager.
4. Create a standalone SwiftPM package named `ProvenanceEngine`.
5. Create only the initial `ProvenanceEngineContracts` module unless explicitly
   scoped otherwise.
6. Keep the first SDK in-process-only and daemon-compatible.
7. Treat `~/.local/state/provenance-engine/provenance.sqlite` as the future
   default for new engine data, without moving existing bmux data.
8. Exclude observability from the initial authoritative skeleton.

Phase 3B must still avoid Phase 4 reconnect, Phase 5 migration, retrieval,
lifecycle policy, UI, broad observability, and automatic orchestration.

## Non-Completion Statement

Phase 3A resolves the decision gate only. Full ADR-001 Phase 3 is still not
complete.

No independent repository/package scaffold, SDK implementation, daemon, storage
move, schema move, data migration, bmux reconnect, retrieval layer, lifecycle
policy, UI, broad observability, or automatic orchestration was created in this
slice.
