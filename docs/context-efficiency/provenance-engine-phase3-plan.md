# Provenance Engine Extraction: Phase 3 Plan

Status: drafted on 2026-07-21 for ADR-001 Phase 3 entry; updated on
2026-07-22 after ADR-001 Phase 3D closeout.

Inputs:

- `docs/context-efficiency/adr-001-provenance-engine-extraction.md`
- `docs/context-efficiency/provenance-engine-extraction-phase0-report.md`
- `docs/context-efficiency/provenance-engine-contracts-phase1-plan.md`
- `docs/context-efficiency/provenance-engine-semantic-roadmap.md`
- ADR-001 Phase 2 in-bmux contracts and CLI consumer conversions on branch
  `provenance-extraction-phase2-contracts`

## Purpose

Phase 3 starts the independent Provenance Engine product boundary without
changing bmux runtime behavior. This document records the original Phase 3
entry plan and the current Phase 3D closeout state.

This plan does not complete all of ADR-001 Phase 3. The independent engine
exists, the initial contracts are lifted, and the planned internal SQLite
storage lift is closed. Public SDK export, daemon, CLI, and bmux reconnect work
remain gated by explicit follow-up plans.

## Scaffold Decision

Historical decision for the original 2026-07-21 docs-only entry slice: no
scaffold was created until Phase 3A made the missing product decisions explicit.
That gate is now complete, and the independent scaffold exists at
`/Users/brianbusby/repos/provenance-engine`.

Reasons:

- ADR-001 says the engine should live as an independent product.
  It should have its own repository and release lifecycle.
- ADR-001 suggests a repository layout but leaves implementation details open.
- Phase 0 still lists the V1 language, daemon/SDK ownership, storage location,
  migration path, workspace metadata shape, and observability move as unknowns.
- An in-repo package would bias the decision toward bmux package mechanics before
  the independent product boundary is explicit.

Scaffolding was allowed only after local docs named the canonical repo path and
GitHub repository owner/name, V1 implementation language and package manager,
first artifact shape, SDK/daemon relationship, engine-owned new-data storage
path, and initial package/module names.

## Boundary Inventory

Portable source material:

- Contract DTOs and protocols in `Sources/WorkProvenance/Provenance*Request.swift`,
  `Provenance*Response.swift`, `BmuxLegacyProvenanceClient.swift`, and normalized
  lifecycle contract files.
- Event/domain values in `WorkProvenanceEvent*.swift`,
  `WorkProvenanceSource.swift`, `WorkProvenanceConfidence.swift`, and the
  `WorkProvenance*Record.swift` projection DTOs.
- Store implementation source in `WorkProvenanceStore.swift`,
  `WorkProvenanceStore+BmuxLegacyProvenanceClient.swift`,
  `WorkProvenanceSQLiteDatabase.swift`, `WorkProvenanceSQLiteStatement.swift`,
  `WorkProvenanceStoreError.swift`, `WorkProvenanceStableIDFactory.swift`,
  `WorkProvenanceRetentionPolicy.swift`, and `WorkProvenancePruneResult.swift`.
  SQLite table shape remains internal.

bmux adapter material:

- `WorkProvenanceRuntime.swift` stays in bmux because it owns `TabManager`,
  `Workspace`, app notifications, bmux storage wiring, and runtime degradation.
- `WorkProvenanceWorkspaceSnapshot.swift`, `WorkProvenanceObservationService.swift`,
  `WorkProvenanceGitInspector.swift`, and `WorkProvenanceProcessGitCommandRunner.swift`
  remain capture adapters until normalized engine observation requests exist.
- `WorkProvenanceSubsessionLifecycleRecorder.swift` must split later: bmux maps
  `AgentSubsessionLifecycleChange`; the engine records normalized lifecycle input.
- `CLI/BMUXCLI+Provenance.swift` and `CLI/CLIProvenance*.swift` remain bmux
  adapters for command syntax, Git target resolution, localized output,
  snake_case JSON compatibility, text rendering, and no-database fallbacks.

Do not move next:

- `CLIProvenanceSQLiteReader.swift` and `CLIProvenanceObservabilitySQLiteReader.swift`;
  replacing them is Phase 4 reconnect.
- `WorkProvenanceStorageLocation.swift`; changing defaults starts storage move
  and Phase 5 migration concerns.
- `ProvenanceObservabilityStore*`, lifecycle trace query DTOs, pipeline/identity/
  projection-lineage records, and trace CLI files; observability remains separate.
- `Packages/macOS/BmuxContextEfficiency`, retrieval, lifecycle policy, UI,
  warnings, handoffs, context packages, migration, daemon reconnect, and
  automatic orchestration.

## Smallest Engine-Facing Shape

If Swift is selected for V1, the smallest first package should be a pure
`ProvenanceContracts`-style package. Keep it Foundation-only and limited to
`Codable`, `Equatable`, and `Sendable` values plus protocol surfaces.

Suggested folders inside that package:

- `Domain`: event, source, confidence, and projection/read-model DTOs.
- `Requests` and `Responses`: append, session tree, file explanation, worktrees,
  current context, and normalized lifecycle DTOs.
- `Client`: `ProvenanceEngineClient` plus health/capability contracts.
- `Observability`: lifecycle trace DTOs/protocol only if explicitly included,
  still separate from authoritative provenance.

The first authoritative contract surface should include only health/capabilities,
`appendEvent`, normalized subsession lifecycle recording, `sessionTree`,
`fileExplanation`, `worktrees`, and `currentContext`.

## Adapter Metadata

Preserve these as optional client metadata or external identities, not required
core engine fields:

- `workspaceID`, `surfaceID`, `displayName`, and bmux workspace titles;
- `agentKind` when it describes a bmux runtime adapter rather than an engine
  session taxonomy;
- `workingDirectory` when it is client runtime state rather than a repository or
  worktree fact;
- bmux storage defaults under `~/.local/state/bmux/work-provenance`;
- CLI fallback labels such as `no_database` and localized output strings;
- observability storage fields such as `targetTable` or input-presence flags.

## Implementation Sequence

### Phase 3A: Decision Gate

Produce or update a local decision document with the missing scaffold inputs.
This is the next safe Phase 3 slice and is not a code migration.

Done when the repo path, implementation language, first artifact type,
SDK/daemon relationship, engine storage default, and public module names are
explicit.

Status: completed in
`docs/context-efficiency/provenance-engine-phase3a-decisions.md`.

### Phase 3B: Minimal Independent Skeleton

Create the independent repo/package skeleton only after Phase 3A is complete.

Allowed content is minimal.
Keep bmux unmodified.

Status: completed in `/Users/brianbusby/repos/provenance-engine` with Swift 6
SwiftPM package `ProvenanceEngine`, initial module/product
`ProvenanceEngineContracts`, and canonical GitHub repository
`BrianBusby/provenance-engine`.

### Phase 3C: Contract Lift

Lift the Phase 2 DTO/protocol names behind the independent contract boundary.
Do not change bmux CLI behavior or storage paths.

Status: completed in `ProvenanceEngineContracts` at commit
`0b2529170ef4b0d67f8050f89786d439bbab6d27`.

### Phase 3D: Storage Lift

Move reusable store logic after contracts build independently.

Status: closed for planned internal storage lift work at engine commit
`b0cc65f42065b5d8e0ac3be3c45a22ce0d4013d5` on branch
`provenance-session-tree-storage`. Phase 3D now covers SQLite connection,
statement, and error support; schema migrations and migration metadata; default
storage location resolution; event ledger append/read paths; projections for
the existing contract reads; normalized lifecycle recording; storage integrity
validation and repair; repair-attempt metadata; and schema-migration metadata.
It remains internal to `ProvenanceEngineSQLite`; no public storage product,
daemon, bmux reconnect, storage migration, retrieval, lifecycle policy, UI, or
broad observability expansion was created.

## Semantic Compatibility Notes

Phase 3 should preserve forward compatibility for the semantic roadmap without
implementing it. Keep the ledger append-only, keep projection rebuilds
deterministic, and avoid public contracts that treat all durable knowledge as
observed fact.

The current open string event types and JSON payload storage are compatible with
later evidence-origin and processor metadata. The known gap is semantic
authority: `ProvenanceSource.declared` is too broad for the future split between
orchestrator-declared and agent-declared meaning.

Before adding new event producers or semantic APIs, design explicit
source-event links, parent-event links where needed, numeric confidence for
inference, and semantic model cost/token telemetry.

## Validation Strategy

For this docs-only slice:

```bash
git diff --check
```

For a later skeleton, validate that skeleton independently before bmux imports it.

## Phase 3 Non-Completion Statement

This plan starts Phase 3 but does not complete every ADR-001 extraction
requirement. Phase 3A through Phase 3D have established the independent repo,
initial contracts, and internal storage lift, but no bmux behavior, bmux storage
path, bmux data migration, daemon, SDK transport, CLI reconnect, retrieval
layer, lifecycle policy, UI, or observability expansion is included here.

## Phase 4 Entry Criteria

Do not start Phase 4 reconnect implementation until a scoped reconnect plan
names the first bmux adapter path to replace.

The reconnect plan must also name the exact engine commit or package version to
consume.
It must identify the public SDK or API surface the adapter path will call.
It must preserve parity for existing bmux JSON, text, and fallback behavior.
It must define rollback or graceful degradation when the engine dependency is
unavailable.

Phase 4 must not include bmux data migration. Migration belongs to ADR-001
Phase 5. Do not use Phase 4 as a reason to add retrieval, lifecycle policy, UI,
broad observability, or speculative storage expansion.
