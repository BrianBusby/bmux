# bmux Integration Roadmap

This is the canonical shared roadmap for work that crosses the bmux and provenance-engine repository boundary. It is not a combined product roadmap and it does not replace the platform reference architecture in `docs/reference-architecture.md`. provenance-engine owns reusable provenance capabilities and public contracts. bmux owns product behavior, UI, CLI presentation, orchestration, capture adapters, and rollout decisions.

Detailed technical contract rules remain in `docs/integration-contract.md`. The provenance-engine product roadmap is `docs/roadmap.md`. The bmux product roadmap should link here instead of duplicating these milestones.

## Current Project Status

The authoritative generated status is:

- [Project status](generated/project-status.md)
- [Ownership boundary](generated/ownership-boundary.md)
- [Repository status](generated/repository-status.md)

This roadmap defines cross-repository sequencing, ownership rationale,
acceptance criteria, compatibility expectations, and rollback strategy. It must
not independently maintain the active gate, milestone state, evidence commits,
current caveat status, or telemetry persistence policy.

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

Provenance-engine readiness: SDK-level coverage confirms that an adopter can seed session projections through `appendEvent` and read them through `ProvenanceEngineClientFactory` plus `ProvenanceEngineClient.sessionTree(...)`, without importing or querying SQLite internals.

Acceptance criteria: existing session-tree CLI behavior is preserved. bmux does not use bmux-local session-tree query SQL for this path. No file-explanation, current-context, lifecycle-write, capture, observability, data-migration, daemon, UI, or retrieval work is started.

Compatibility expectations: existing bmux CLI output remains stable. Engine contract changes, if needed, remain source-compatible unless explicitly versioned.

Rollback strategy: scoped bmux revert restoring the legacy adapter. Do not alter provenance-engine schema as rollback.

Migration or cleanup: bmux removed the direct CLI session-tree SQLite reader, legacy local client method, duplicate local CLI DTOs, and raw SQLite CLI fixture seeding for this path. bmux intentionally retained local store relationship/session-tree helpers for lifecycle and capture projection tests until later migration slices.

Integration finding: the session-tree request limit is an engine row budget,
not a presentation cap. The current engine applies it across the combined
session and relationship rows needed for traversal. bmux preserves its legacy
100-session presentation cap by adapting the request limit at its CLI boundary.
The engine returns relationships only for child sessions that fit within the
limit, then returns external identities for included sessions.

Dependency result: engine-side Slice C was accepted against provenance-engine commit
`dbdc4b7e8b33bc0dc9c160d0f23501d2062e213e`; bmux now pins the
merged default-branch revision `2026914454a00ccc6c45d686ea741111b0a01229`. Downstream consumers should use a
merged default-branch revision or later release/tag containing that commit
rather than relying indefinitely on the temporary feature-branch commit.

Status: Accepted.

## Milestone: bmux File or Artifact Explanations

Capability owner: provenance-engine. Adopter: bmux.

Required contract: `ProvenanceEngineClient.fileExplanation(ProvenanceFileExplanationRequest())`.

Provenance-engine work: preserve file-explanation DTOs and projection semantics.
Readiness assessment: accepted. Engine-side SDK coverage and bmux PR 9 adoption
prove adopters can seed file-change evidence through public `appendEvent` calls,
construct a client through `ProvenanceEngineClientFactory`, resolve worktrees
through `ProvenanceEngineClient.worktrees(...)`, and read file explanations
through `ProvenanceEngineClient.fileExplanation(...)` without importing SQLite
internals. V1 path identity is exact worktree-scoped repository-relative path
identity; consumers own Git path resolution and normalization.

bmux work: migrate only the file-explanation CLI path. Keep Git target resolution, fallback text, command parsing, and output rendering in bmux.

Dependencies: session-tree read migration accepted. Integration findings report completed.

Acceptance criteria: existing command output and fallback behavior are preserved. bmux does not keep a permanent dual-read implementation. Deletable legacy file-explanation query code is removed after migration.

Compatibility expectations: engine returns domain records. bmux maps them to existing presentation payloads.

Rollback strategy: scoped bmux revert to the previous local adapter.

Migration or cleanup: remove file-explanation-only local query helpers once unused.
The precise bmux adoption handoff is recorded in
`docs/file-explanation-readiness-slice-completion.md`.

Status: Accepted. Engine readiness merged in PR 5 at `126afde36671f53a137953200e7883e6b4093ac3`; bmux adoption merged in PR 9 at `c1c5fce0eb7526d321dbed6c8a6f25f0d9aaf374`.

## Milestone: bmux Current Session and Task Context

Capability owner: provenance-engine. Adopter: bmux.

Required contract: `ProvenanceEngineClient.currentContext(ProvenanceCurrentContextRequest())`.

Provenance-engine work: preserve bounded current-context projection reads. Engine readiness is complete and recorded in `docs/current-context-readiness-slice-completion.md`. Keep retrieval and semantic expansion out of this V1 command migration unless explicitly approved later.

bmux work: migrate only the current-context CLI path. Keep current directory resolution, default section limits, command parsing, fallback text, and rendering in bmux.

Dependencies: file or artifact explanation migration accepted. Integration findings report completed.

Acceptance criteria: existing current-context JSON, text, and empty-section behavior are preserved. No semantic retrieval, prompt assembly, lifecycle policy, UI, or observability expansion is introduced.

Compatibility expectations: section limits and output compatibility remain bmux responsibilities.

Rollback strategy: scoped bmux revert to the local current-context adapter.

Migration or cleanup: remove current-context-only local SQL helpers when unused.

Status: Accepted in Slice E; bmux adoption merge commit `3cbacd150`.

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

Status: Operational default cutover accepted in Slice E. Broad legacy data
migration and cleanup remain gated by explicit design and observation evidence.

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

Required contract: `ProvenanceEngineClient.recordSessionLifecycle(...)` or `appendEvent(...)`.

Provenance-engine work: preserve normalized lifecycle recording behavior and deterministic identity handling.

bmux work: keep hook handling, transcript observation, runtime degradation, and product policy in bmux. Send lifecycle facts through the public engine contract instead of direct bmux-local store writes.

Dependencies: durable read paths prove contract compatibility. Explicit integration findings report for write-path readiness.

Acceptance criteria: existing lifecycle capture behavior is preserved. Engine owns durable lifecycle evidence persistence. bmux-owned observability trace behavior is not silently moved or expanded.

Compatibility expectations: lifecycle writes remain local-first in V1. Any contract changes must be versioned or source-compatible.

Rollback strategy: scoped bmux revert to local lifecycle recording.

Migration or cleanup: remove direct lifecycle append coupling to bmux-local provenance storage when unused.

Status: Accepted in Slice E for supported hook/feed lifecycle events. Opening
an agent-session surface alone does not create lifecycle evidence.

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

Status: Accepted in Slice E for bmux-owned Git/worktree observation capture.

## Milestone: bmux Workspace Display Current State Projection

Capability owner: provenance-engine for durable evidence contracts, projection
semantics, and Current State APIs. bmux owns observation adapters, display
rendering, optimistic UI, fallback behavior, and rollout decisions.

Adopter: bmux.

Required contract: existing public SDK writes where sufficient, plus new public
workspace-display event/domain contracts and Current State read contracts if the
existing V1 API surface cannot represent the accepted facts.

Provenance-engine work: accept deterministic workspace-display facts, persist
durable evidence, and derive Current State for workspace display metadata. The
projection should cover workspace display title, title source, repository and
worktree identity, branch, accepted dirty state if already part of worktree
observation, PR number/status/url/branch/staleness, and projection
revision/cursor/timestamp.

bmux work: observe workspace created/selected/renamed events, tab rename events,
worktree branch and repository HEAD changes, PR metadata found/changed/cleared
events, PR state changes (`open`, `merged`, `closed`), and auto-name
applied/suppressed/cleared events. Append accepted facts through the public
engine contract, then render workspace tabs, sidebar rows, and custom sidebar
fields such as `workspace.branch`, `workspace.pr`, and `workspace.prs` from PE
Current State.

Dependencies: accepted worktree observation capture and an explicit diagnostic
slice selection. This milestone is not active until selected through the project
manifest.

Acceptance criteria: bmux display reads PE Current State for workspace title,
branch, and PR metadata after the slice is implemented. Live session data is not
the durable or steady-state display source of truth for those fields. Any
optimistic bmux-local display state is temporary, request-scoped, reconciled
from PE Current State, and rolled back or surfaced as an error when PE rejects a
write.

Diagnostics requirements: provide read-only diagnostics that compare observed
bmux UI/model display, PE Current State, and the latest accepted evidence for a
workspace. Diagnostics must measure correctness, stale/cleared PR state, and
latency for branch changes, PR mapping, PR state changes, leaving a PR-backed
branch, leaving a Git worktree, and workspace rename triggers.

Suggested diagnostic commands:

```bash
bmux provenance diagnostics workspace-display --workspace <id> --json
bmux provenance diagnostics workspace-display --workspace <id> --watch --json
bmux provenance diagnostics workspace-rename --workspace <id> --json
```

Diagnostic output should compare:

```text
observed bmux UI/model display
vs
PE Current State
vs
latest accepted evidence
```

The diagnostic should record workspace id; tab or surface id when applicable;
repository root; branch before/after; PR before/after; PR status before/after;
evidence accepted timestamp; PE Current State projection timestamp, revision,
or cursor; display observed timestamp; expected and observed display values;
latency in milliseconds; pass/fail; and stale/cleared-state correctness. Rename
diagnostics should additionally record old title, new title or a
privacy-preserving hash, title source, user-set state, auto-name suppression
state, request timestamp, rollback/error state if the write failed, and later
overwrite or revert detection.

Compatibility expectations: bmux keeps UI presentation, CLI formatting, custom
sidebar field compatibility, and local fallback behavior. Provenance Engine owns
deterministic projection semantics and API compatibility.

Rollback strategy: scoped bmux revert to the existing bmux-local/live display
metadata path while preserving already accepted PE evidence. Engine schema or
contract rollback requires explicit compatibility handling.

Implementation boundary: do not include broad GitHub ingestion, Knowledge
Compiler work, semantic or AI interpretation of PRs, raw execution telemetry
persistence, raw live session event storage, transcript storage, broad UI
rewrite, automatic workspace naming redesign, or GitHub write synchronization.

Status: Planned and gated.
