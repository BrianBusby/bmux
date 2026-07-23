# bmux Integration Roadmap

This is the canonical shared roadmap for work that crosses the bmux and provenance-engine repository boundary. It is not a combined product roadmap. provenance-engine owns reusable provenance capabilities and public contracts. bmux owns product behavior, UI, CLI presentation, orchestration, capture adapters, and rollout decisions.

Detailed technical contract rules remain in `docs/integration-contract.md`. The provenance-engine product roadmap is `docs/roadmap.md`. The bmux product roadmap should link here instead of duplicating these milestones.

## Current Priority

V1 adoption is a controlled migration. The first external bmux path, `bmux provenance worktrees list`, is complete. The next active milestone is session-tree read migration.

Do not begin file explanations, current context, lifecycle writes, storage migration, daemon transport, retrieval, GitHub ingestion, or Knowledge Compiler implementation before the current path is validated.

Planned order after the active session-tree milestone: file explanations, current context, lifecycle recording, worktree observation capture, storage ownership migration, daemon or service transport, then shared evidence and Knowledge Compiler adoption.

## Milestone: bmux Worktree Reads

Capability owner: provenance-engine

Adopter: bmux

Required contract: `ProvenanceEngineClient.worktrees(ProvenanceWorktreeListRequest())`

Provenance-engine work:
- Release `0.1.0` with public contracts and `ProvenanceEngineClientFactory`.
- Own SQLite-backed worktree and repository projections.

bmux work:
- Use the SDK factory to create a SQLite-backed engine client.
- Preserve CLI JSON, text, fallback, ordering, and limit behavior.

Dependencies: provenance-engine `0.1.0`.

Acceptance criteria: existing command behavior is preserved. No direct SQLite read remains for this path.

Compatibility expectations: bmux owns output compatibility. provenance-engine owns DTO semantics and query ordering.

Rollback strategy: scoped bmux revert restoring the previous adapter without changing the engine ledger schema.

Migration or cleanup: local worktree-list DTO duplication and direct SQLite reader are removed.

Status: Complete.

## Milestone: bmux Session-Tree Reads

Capability owner: provenance-engine

Adopter: bmux

Required contract: `ProvenanceEngineClient.sessionTree(ProvenanceSessionTreeRequest())`

Provenance-engine work: preserve the accepted V1 session-tree contract.

bmux work: migrate only the provenance session-tree CLI command to the external SQLite-backed engine client.

Dependencies: worktree-read adoption complete. bmux legacy boundary clarified as `BmuxLegacyProvenanceClient`.

Acceptance criteria: existing session-tree CLI behavior is preserved. bmux does not use bmux-local session-tree query SQL for this path. No file-explanation, current-context, lifecycle-write, capture, observability, data-migration, daemon, UI, or retrieval work is started.

Compatibility expectations: existing bmux CLI output remains stable. Engine contract changes, if needed, remain source-compatible unless explicitly versioned.

Rollback strategy: scoped bmux revert restoring the legacy adapter. Do not alter provenance-engine schema as rollback.

Migration or cleanup: remove the local session-tree legacy seam and session-tree-only query helpers only when unused.

Status: Active next milestone.

## Milestone: bmux File or Artifact Explanations

Capability owner: provenance-engine. Adopter: bmux.

Required contract: `ProvenanceEngineClient.fileExplanation(ProvenanceFileExplanationRequest())`.

Provenance-engine work: preserve file-explanation DTOs and projection semantics.

bmux work: migrate only the file-explanation CLI path. Keep Git target resolution, fallback text, command parsing, and output rendering in bmux.

Dependencies: session-tree read migration accepted. Integration findings report completed.

Acceptance criteria: existing command output and fallback behavior are preserved. bmux does not keep a permanent dual-read implementation. Deletable legacy file-explanation query code is removed after migration.

Compatibility expectations: engine returns domain records. bmux maps them to existing presentation payloads.

Rollback strategy: scoped bmux revert to the previous local adapter.

Migration or cleanup: remove file-explanation-only local query helpers once unused.

Status: Planned after session-tree reads.

## Milestone: bmux Current Session and Task Context

Capability owner: provenance-engine. Adopter: bmux.

Required contract: `ProvenanceEngineClient.currentContext(ProvenanceCurrentContextRequest())`.

Provenance-engine work: preserve bounded current-context projection reads. Keep retrieval and semantic expansion out of this V1 command migration unless explicitly approved later.

bmux work: migrate only the current-context CLI path. Keep current directory resolution, default section limits, command parsing, fallback text, and rendering in bmux.

Dependencies: file or artifact explanation migration accepted. Integration findings report completed.

Acceptance criteria: existing current-context JSON, text, and empty-section behavior are preserved. No semantic retrieval, prompt assembly, lifecycle policy, UI, or observability expansion is introduced.

Compatibility expectations: section limits and output compatibility remain bmux responsibilities.

Rollback strategy: scoped bmux revert to the local current-context adapter.

Migration or cleanup: remove current-context-only local SQL helpers when unused.

Status: Planned.

## Milestone: Storage Ownership Leaves bmux

Capability owner: provenance-engine. Adopter: bmux.

Required contract: versioned storage location, migration, backup, validation, and compatibility policy.

Provenance-engine work: define migration tooling and compatibility expectations for engine-owned storage. Preserve validation and repair reports.

bmux work: stop treating bmux-local provenance SQLite as authoritative durable storage. Keep bmux-owned runtime wiring and user-facing fallback behavior.

Dependencies: all accepted runtime read/write paths stop depending on bmux-local store internals. Explicit migration design approved.

Acceptance criteria: existing users retain access to prior durable provenance data or receive an explicit documented migration path. Rollout and rollback are documented before implementation.

Compatibility expectations: no silent data loss. no unversioned schema movement.

Rollback strategy: restore previous bmux storage adapter only through a documented migration or backup strategy.

Migration or cleanup: remove legacy bmux-local durable provenance storage after migration is verified.

Status: Gated post-read/write adoption.

## Milestone: Daemon or Service Transport

Capability owner: provenance-engine. Adopter: bmux.

Required contract: versioned daemon or service API, local authorization model, health checks, and compatibility policy.

Provenance-engine work: design and implement daemon or service transport only after in-process V1 adoption proves the API surface.

bmux work: replace in-process SDK usage only if the daemon or service path is accepted. Preserve product behavior and user-facing failure modes.

Dependencies: local V1 adoption accepted. Storage ownership and rollout strategy understood.

Acceptance criteria: in-process behavior has an equivalent service-backed path. Released-version compatibility and rollback are documented.

Compatibility expectations: do not break existing in-process adopters without a versioned transition.

Rollback strategy: fall back to the in-process SDK path for affected bmux releases.

Migration or cleanup: remove daemon-specific compatibility shims only after released-version support windows close.

Status: Exploratory post-V1.

## Milestone: Shared Evidence and Knowledge Compiler Adoption

Capability owner: provenance-engine. Adopter: bmux and future clients.

Required contract: shared evidence-store APIs, authorization boundaries, evidence-backed retrieval APIs, compiler artifact versioning, and compatibility policy.

Provenance-engine work: validate the external evidence model, design shared evidence-store scopes, run a raw GitHub ingestion spike, and implement the first Knowledge Compiler artifact only after ingestion shape is validated.

bmux work: adopt evidence-backed retrieval only after the engine proves usefulness and product fit. Keep prompt assembly, UI, workflow policy, and user-facing reports in bmux.

Dependencies: V1 local bmux adoption accepted. GitHub ingestion spike approved. Retrieval quality evaluation designed.

Acceptance criteria: shared repository evidence is not duplicated per engineer. Derived knowledge artifacts cite supporting evidence. Retrieval returns bounded context rather than raw bulk history.

Compatibility expectations: personal, project, and organization evidence scopes remain distinct. Authorization boundaries are explicit before organization-scale use.

Rollback strategy: disable shared retrieval adoption while preserving immutable evidence.

Migration or cleanup: remove any temporary spike-only schemas or adapters after the first accepted schema extension.

Status: Post-V1, planned and gated.

## Milestone: bmux Session Lifecycle Recording

Capability owner: provenance-engine. Adopter: bmux.

Required contract: `ProvenanceEngineClient.recordSubsessionLifecycle(...)` or `appendEvent(...)`.

Provenance-engine work: preserve normalized lifecycle recording behavior and deterministic identity handling.

bmux work: keep hook handling, transcript observation, runtime degradation, and product policy in bmux. Send lifecycle facts through the public engine contract instead of direct bmux-local store writes.

Dependencies: durable read paths prove contract compatibility. Explicit integration findings report for write-path readiness.

Acceptance criteria: existing lifecycle capture behavior is preserved. Engine owns durable lifecycle evidence persistence. bmux-owned observability trace behavior is not silently moved or expanded.

Compatibility expectations: lifecycle writes remain local-first in V1. Any contract changes must be versioned or source-compatible.

Rollback strategy: scoped bmux revert to local lifecycle recording.

Migration or cleanup: remove direct lifecycle append coupling to bmux-local provenance storage when unused.

Status: Planned after read-path migrations.

## Milestone: bmux Worktree Observation Capture

Capability owner: provenance-engine for durable append and projection ownership. bmux owns Git observation policy.

Adopter: bmux.

Required contract: `ProvenanceEngineClient.appendEvent(...)`.

Provenance-engine work: own persistence and projection updates for accepted worktree observation events.

bmux work: keep Git snapshot scheduling, duplicate-fingerprint suppression, capture timing, and runtime degradation policy in bmux. Append durable facts through the public engine contract.

Dependencies: lifecycle write migration accepted or a focused append-adapter slice approved.

Acceptance criteria: runtime capture behavior remains unchanged for users. bmux no longer writes durable worktree observation facts through bmux-local provenance storage.

Compatibility expectations: capture adapters remain bmux-owned even after storage moves.

Rollback strategy: scoped bmux revert to local append adapter.

Migration or cleanup: remove direct local store append and retention SQL only after replacement is accepted.

Status: Planned.
