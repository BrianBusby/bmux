# Provenance Engine Extraction: Phase 3 Plan

Status: drafted on 2026-07-21 for ADR-001 Phase 3 entry.

Inputs:

- `docs/context-efficiency/adr-001-provenance-engine-extraction.md`
- `docs/context-efficiency/provenance-engine-extraction-phase0-report.md`
- `docs/context-efficiency/provenance-engine-contracts-phase1-plan.md`
- ADR-001 Phase 2 in-bmux contracts and CLI consumer conversions on branch
  `provenance-extraction-phase2-contracts`

## Purpose

Phase 3 starts the independent Provenance Engine product boundary without
changing bmux runtime behavior. The largest safe slice right now is to lock the
extraction plan, boundary inventory, and first scaffold gate. It is not safe to
create a speculative local package or repository skeleton in this slice because
local docs still leave the V1 implementation choice unresolved.

This plan does not complete Phase 3. ADR-001 Phase 3 still requires creating
the independent engine, moving reusable logic, removing bmux assumptions, and
building SDK, daemon, and CLI surfaces after the open product/repo/scope
decisions are explicit.

## Scaffold Decision

No scaffold is created in this slice.

Reasons:

- ADR-001 says the engine should live as an independent product.
  It should have its own repository and release lifecycle.
- ADR-001 suggests a repository layout but leaves implementation details open.
- Phase 0 still lists the V1 language, daemon/SDK ownership, storage location,
  migration path, workspace metadata shape, and observability move as unknowns.
- An in-repo package would bias the decision toward bmux package mechanics before
  the independent product boundary is explicit.

Scaffolding is allowed only after local docs name the canonical repo path and
GitHub repository owner/name, V1 implementation language and package manager, first
artifact shape, SDK/daemon relationship, engine-owned new-data storage path, and
initial package/module names.

## Boundary Inventory

Portable source material:

- Contract DTOs and protocols in `Sources/WorkProvenance/Provenance*Request.swift`,
  `Provenance*Response.swift`, `ProvenanceEngineClient.swift`, and normalized
  lifecycle contract files.
- Event/domain values in `WorkProvenanceEvent*.swift`,
  `WorkProvenanceSource.swift`, `WorkProvenanceConfidence.swift`, and the
  `WorkProvenance*Record.swift` projection DTOs.
- Store implementation source in `WorkProvenanceStore.swift`,
  `WorkProvenanceStore+ProvenanceEngineClient.swift`,
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

### Phase 3C: Contract Lift

Lift the Phase 2 DTO/protocol names behind the independent contract boundary.
Do not change bmux CLI behavior or storage paths.

### Phase 3D: Storage Lift

Move reusable store logic after contracts build independently.

## Validation Strategy

For this docs-only slice:

```bash
git diff --check
```

For a later skeleton, validate that skeleton independently before bmux imports it.

## Phase 3 Non-Completion Statement

This plan starts Phase 3 but does not complete it. No bmux behavior, storage
path, migration, daemon, SDK transport, CLI reconnect, retrieval layer,
lifecycle policy, UI, or observability expansion is included here.

## Next Safe Phase 3 Slice

Create the Phase 3B minimal independent skeleton only if the slice follows
`docs/context-efficiency/provenance-engine-phase3a-decisions.md` exactly. The
skeleton should live at `/Users/brianbusby/repos/provenance-engine`, use Swift
6 and Swift Package Manager, create package `ProvenanceEngine`, and start with
module `ProvenanceEngineContracts`.

Keep the first skeleton in-process-only and daemon-compatible. Do not add the
daemon, bmux reconnect, storage migration, retrieval, lifecycle policy, UI,
broad observability, or automatic orchestration in Phase 3B.
