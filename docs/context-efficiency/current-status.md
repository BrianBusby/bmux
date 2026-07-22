# Bmux Context Efficiency: Current Status

Last updated: 2026-07-22

This file is the live handoff index for the context-efficiency roadmap. Read it before choosing work, and update it at the end of every context-efficiency slice.

## Read Order

1. `AGENTS.md`
2. `docs/context-efficiency/current-status.md`
3. `docs/context-efficiency/roadmap.md`
4. `docs/context-efficiency/adr-001-provenance-engine-extraction.md`
5. `docs/context-efficiency/provenance-engine-extraction-phase0-report.md`
6. `docs/context-efficiency/provenance-engine-contracts-phase1-plan.md`
7. `docs/context-efficiency/provenance-engine-phase3-plan.md`
8. `docs/context-efficiency/provenance-engine-phase3a-decisions.md`
9. `docs/context-efficiency/subsession-delegation-integration-plan.md`
10. `docs/context-efficiency/agent-retrieval-knowledge-projection-plan.md`
11. `docs/context-efficiency/provenance-observability-integration-plan.md`
12. `docs/context-efficiency/subsession-delegation-phase-a-report.md`
13. `docs/context-efficiency/milestones.md`
14. Relevant bmux skills:
   - `bmux-architecture` before Swift package/API changes.
   - `bmux-dev-workflow` before tagged builds or project wiring.
   - `bmux-testing` before test changes or verification decisions.
   - `bmux-localization` only if changing CLI, UI, docs, help, or other user-facing strings.

## Active Phase

Original roadmap Phase 3 is active: read-only command and output attribution from already-imported telemetry facts. Phase 2 closed on 2026-07-17 with local telemetry ingestion, Codex state metadata, SQLite persistence, bounded JSON diagnostics, and CLI regression coverage.

ADR-001 is accepted and now controls the product boundary for provenance extraction:

- `docs/context-efficiency/adr-001-provenance-engine-extraction.md`
- `docs/context-efficiency/provenance-engine-extraction-phase0-report.md`
- `docs/context-efficiency/provenance-engine-contracts-phase1-plan.md`
- `docs/context-efficiency/provenance-engine-phase3-plan.md`
- `docs/context-efficiency/provenance-engine-phase3a-decisions.md`

Treat the Provenance Engine as an independent local-first product with bmux as its first client. Future provenance implementation should move toward SDK/API boundaries, a local daemon, independent versioning, and no engine dependency on bmux internals. Existing `WorkProvenance`, `BmuxContextEfficiency`, and `ProvenanceObservability` work remains useful migration source material, but new extraction work must not deepen bmux-specific storage or domain coupling.

ADR-001 Phase 3A is complete as a local decision gate only. ADR-001 Phase 3B
has created the minimal independent skeleton locally at
`/Users/brianbusby/repos/provenance-engine`: a Swift 6 SwiftPM package named
`ProvenanceEngine` with initial module `ProvenanceEngineContracts`. The
canonical GitHub repository is now `BrianBusby/provenance-engine` with remote
URL `git@github.com:BrianBusby/provenance-engine.git`. The previous
organization-owned target was an early ownership assumption and is superseded.
The provenance engine is initially owned and maintained under the
`BrianBusby` GitHub account; it may be transferred to a future organization,
for example `manaflow-ai`, once the project matures. Repository ownership is an
implementation detail and must not affect package names, APIs, module
boundaries, documentation, storage defaults, or bmux integration. The
canonical repository now exists as a private GitHub repo, the local engine
repo's `origin` points at the canonical URL, and Phase 3B commit
`9e8fa620ccd04040968e0afab591feb48c8c11d0` is pushed to `origin/main`.
ADR-001 Phase 3C has lifted the initial in-process public contract surface into
`ProvenanceEngineContracts` in the independent engine repo at commit
`0b2529170ef4b0d67f8050f89786d439bbab6d27`.
ADR-001 Phase 3D has started with the smallest storage boundary: internal
engine-owned SQLite connection and statement support in `ProvenanceEngineSQLite`
at commit `ec8b84bc2f8ac7e98c0e22cac67bf6895e7882ac`.
A second Phase 3D storage slice added internal SQLite schema-versioning and
migration scaffolding at commit
`9f7333799ef4f036b06b580fcbac3cde9398b306`. A third Phase 3D storage
slice added a minimal internal SQLite repository actor at commit
`dfd57a6441d5090130476893502c3091d2769440`. A fourth Phase 3D
storage slice added the first internal repository-owned event-ledger table and
narrow append/read path at commit
`f96858fb8f1a207426ad78c2524ab5b5c9b74121`. A fifth Phase 3D storage
slice added the first internal repository-owned session projection table and
narrow read path at commit
`ad1eec1dd7a0cabd3e78943ff798f21ee7665fa2`. A sixth Phase 3D storage
slice added internal repository/worktree projection bootstrap plus a bounded
worktree-list read model at commit
`fe1a4c5712eefc7ab2e2e3b271d0dc1e91a442e1`. A seventh Phase 3D
storage slice added internal session-relationship and external-identity
projection tables plus bounded session-tree reads at commit
`aff90f9c28b9a66bbb7014918c9e23338d706c6b` on branch
`provenance-session-tree-storage`. An eighth Phase 3D storage slice added
internal work-item, contribution, checkpoint, change-set, and file-change
projection tables plus focused file-explanation reads at commit
`1032a752db589e670917b56b5bbbefe6442843bd` on branch
`provenance-session-tree-storage`. A ninth Phase 3D storage slice added
internal validation-run projection storage plus a bounded current-context read
model at commit `09628cf4e1ffc0a055dd683cdad5f8da1341a0e2` on branch
`provenance-session-tree-storage`; draft PR:
https://github.com/BrianBusby/provenance-engine/pull/1.
An autoreview follow-up bounded session-tree traversal at commit
`bc86510426aba51afd4ed3f1e0fe509ae77f5ec7`. A tenth Phase 3D storage
slice added an internal SQLite implementation of the existing normalized
subsession-lifecycle recording contract, deterministic engine-owned stable IDs,
lifecycle event construction, append response handling, and behavior coverage at
commit `94d67f4ee3fe59a7458fc2d1c03793cd67c04466` on branch
`provenance-session-tree-storage`; draft PR:
https://github.com/BrianBusby/provenance-engine/pull/1.
An autoreview follow-up preserved existing child-session start times when
recording stop lifecycle events at commit
`def6a66d6fd9be0bba281cf9edb26319319cd6cb`. An eleventh Phase 3D storage
slice added internal SQLite-backed `ProvenanceEngineClient` conformance,
including health and append request wrappers over the existing internal
storage/query paths, at commit
`29c483078c4637631add212f9c2840b1caf4d328` on branch
`provenance-session-tree-storage`; draft PR:
https://github.com/BrianBusby/provenance-engine/pull/1.
An autoreview follow-up enforced `ProvenanceSessionTreeRequest.limit` as a
combined session-plus-relationship row bound while preserving coherent
parent-child edges at commit `ebf2d437bc48b875c84f5794387e2437dc8b82b4`.
The twelfth Phase 3D storage slice added an internal engine-owned default
SQLite storage-location resolver for
`~/.local/state/provenance-engine/provenance.sqlite` plus repository opening
coverage, without exporting storage or moving bmux data, on branch
`provenance-session-tree-storage`, at commit
`f3767534fbd89a473bd003eb1421ed56acc82827`.
A thirteenth Phase 3D storage slice added bounded internal append-order
event-ledger cursor reads over the existing `provenance_events` table, on
branch `provenance-session-tree-storage`, at commit
`4ff1837e40a9dd2c0ad6a9552260cf3afaa9c7d9`.
A fourteenth Phase 3D storage slice added internal current-state projection
rebuild from immutable event-ledger replay, on branch
`provenance-session-tree-storage`, at commit
`d18d5596c3e0bd4e8e9ffd7680dd6bc6139fc2bb`.
A fifteenth Phase 3D storage slice added an internal repository-owned SQLite
storage summary read model for ledger/projection counts, on branch
`provenance-session-tree-storage`, at commit
`68bafa628e4d10e212b089fc73b2e64a12d76dba`.
A sixteenth Phase 3D storage slice added an internal bounded SQLite
event-ledger validation read model, on branch
`provenance-session-tree-storage`, at commit
`c9078e6eb904d27a1da48db7a5b518aad6c8ab1e`.
A seventeenth Phase 3D storage slice added an internal bounded SQLite
projection-count validation read model, on branch
`provenance-session-tree-storage`, at commit
`303225390707775863e63821ec50eaf036e3d615`.
An eighteenth Phase 3D storage slice added an internal bounded SQLite
projection-key validation read model, on branch
`provenance-session-tree-storage`, at commit
`bab8f18abbc79300f52640fea1235fcff2da1f57`.
The first SDK is still in-process-only while keeping daemon-compatible
contracts; new engine data defaults to
`~/.local/state/provenance-engine/provenance.sqlite`; and observability is
excluded from the initial authoritative skeleton. Full ADR-001 Phase 3 is still
not complete.

Subsession/delegation provenance has been merged into the roadmap as a Phase 3-adjacent provenance integration track with its own authoritative plan:

- `docs/context-efficiency/subsession-delegation-integration-plan.md`

Agent retrieval and knowledge projection has been merged as a Milestone 5.5 track with its own authoritative plan:

- `docs/context-efficiency/agent-retrieval-knowledge-projection-plan.md`

Retrieval must build on reliable lifecycle capture, session/delegation identity, and semantic provenance. Do not start retrieval implementation before Phase R0 investigation and do not let retrieval create parallel stores, task models, child-session records, or raw-evidence copies.

The roadmap now includes Context Assembly as an architectural principle: project knowledge should grow continuously while agent context stays bounded. Future provenance, knowledge projection, retrieval, context-package generation, and project organization work should prefer facts over summaries, evidence over assumptions, references over duplication, and retrieval over preloading. Do not implement anything solely because of this principle; use it to evaluate natural design choices and explain why each context item is included.

Provenance observability has been merged as a cross-cutting roadmap track with its own authoritative plan:

- `docs/context-efficiency/provenance-observability-integration-plan.md`
- `docs/context-efficiency/provenance-observability-phase-o0-report.md`

Observability must not become a parallel provenance system. `WorkProvenance` remains the authoritative semantic history of engineering work, `BmuxContextEfficiency` remains read-only imported telemetry/evidence, and `ProvenanceObservability.sqlite` may hold operational traces, quality telemetry, feedback, evaluation, and shadow-comparison data only as roadmap phases explicitly allow. Phase O0 architecture investigation is complete in `docs/context-efficiency/provenance-observability-phase-o0-report.md`. O1 lifecycle-ingestion tracing, O2 identity-resolution observability, and the first narrow O3 projection-lineage slice are complete only for the existing lifecycle-ingestion path. Do not start broad observability implementation or O4+ work from this slice.

Phase A investigation is complete in `docs/context-efficiency/subsession-delegation-phase-a-report.md`. Phase B read-only subsession lifecycle persistence is now implemented through the WorkProvenance store foundation plus the `AgentSubsessionLifecycleChange` adapter/runtime wiring. Do not treat subsession/delegation as a separate subagent manager; it must extend `WorkProvenance` and link to `BmuxContextEfficiency` telemetry later through stable identities.

Allowed original-plan Phase 3 work:

- Derive command execution candidates from existing Codex rollout tool-call/tool-output facts.
- Classify bounded command summaries into deterministic command categories.
- Attribute tool calls to tool outputs using exact Codex call IDs when present.
- Attribute command outputs to subsequent model calls as temporal candidates.
- Keep command facts bounded and source-referenced.
- Add behavior-level Swift package tests and CLI regression coverage for existing read-only diagnostics.

Allowed subsession/delegation work right now:

- Phase B read-only subsession lifecycle diagnostics and query polish in `WorkProvenance`.
- Use `AgentSubsessionLifecycleChange` as the authoritative lifecycle source.
- Use the existing persisted session, session relationship, and external identity projections before delegation contracts.
- Keep capture/query only; no orchestration, recommendations, or quality scoring.

Allowed observability work right now:

- Phase O0 architecture investigation is complete; keep the report as the O1 gate.
- O1 lifecycle-ingestion pipeline tracing is complete for `AgentSubsessionLifecycleChange -> WorkProvenance event append -> projection update`.
- O2 identity-resolution observability is complete only for the lifecycle-ingestion path.
- O3 projection lineage is complete only for lifecycle-ingestion projection rows derived from `WorkProvenanceEventPayload`.
- Keep observability best-effort, bounded, and separate from authoritative WorkProvenance facts.
- Do not add retrieval traces, feedback, dashboards, quality scoring, shadow evaluation, automatic correction, lifecycle policy, or orchestration in the next slice.

Do not start:

- Lifecycle policy, warnings, handoff recommendations, or intervention logic.
- Output filtering or live Codex execution changes.
- UI changes.
- Automatic compression, omission, or mutation of agent context.
- Delegation contracts, reconciliation tables, parent disposition, completion reports, or telemetry-derived quality metrics before Phase B lifecycle persistence has read-only query coverage.
- Retrieval knowledge projections, FTS, semantic records, provenance edges, context package generation, or semantic-search adapters before the retrieval Phase R0 report is complete and lifecycle/delegation prerequisites are satisfied.
- Observability dashboards, learned quality models, semantic evaluation, outcome claims, broad sampling infrastructure, automatic correction, automatic algorithm promotion, or every proposed observability table before O0/O1 foundations are complete.

Keep all tracks observation-first. Provenance work may capture and query facts, but must not add automatic delegation decisions, task decomposition, prompt mutation, child launch, merge behavior, automatic correction, algorithm promotion, or quality scoring.

## Current Branch State

Current checkout:

- Branch: `provenance-extraction-phase2-contracts`
- This 2026-07-21 slice created the Phase 3B minimal independent skeleton at
  `/Users/brianbusby/repos/provenance-engine` and committed it locally as
  `9e8fa620ccd04040968e0afab591feb48c8c11d0` (`Add Phase 3B contracts
  skeleton`).
- The skeleton package is `ProvenanceEngine`; the initial module and product
  are `ProvenanceEngineContracts`.
- Phase 3B remains intentionally narrow: no bmux imports, AppKit, SwiftUI,
  SQLite implementation, daemon, IPC, launch agent, CLI, storage migration,
  retrieval, lifecycle policy, UI, observability package, or automatic
  orchestration.
- The canonical GitHub repository now exists as private repo
  `BrianBusby/provenance-engine`. The local engine repo's `origin` is
  `git@github.com:BrianBusby/provenance-engine.git`, and commit
  `9e8fa620ccd04040968e0afab591feb48c8c11d0` is pushed to `origin/main`.
- ADR-001 Phase 3D internal SQLite storage support now includes connection,
  statement, error, schema migration scaffolding, a minimal repository actor,
  an internal engine-owned default storage location, an internal event-ledger
  table with narrow append/read support, initial
  session, repository, and worktree projection tables, narrow projection reads,
  a bounded worktree-list read model, internal session relationship/external
  identity projection tables, bounded session-tree/parent/child/identity reads,
  internal file-explanation projection/read support, internal validation-run
  projection storage, bounded current-context projection reads, bounded
  session-tree traversal fixes, internal normalized subsession-lifecycle
  recording support, internal SQLite-backed `ProvenanceEngineClient`
  conformance, bounded append-order event-ledger cursor reads, internal
  projection rebuild from ledger replay, an internal repository-owned SQLite
  storage summary read model, internal bounded event-ledger validation,
  internal bounded projection-count validation, and internal bounded
  projection-key validation in
  `ProvenanceEngineSQLite`. Latest engine commit:
  `bab8f18abbc79300f52640fea1235fcff2da1f57` on
  `origin/provenance-session-tree-storage`; draft PR:
  https://github.com/BrianBusby/provenance-engine/pull/1.
- This 2026-07-21 slice completed ADR-001 Phase 3A decisions in
  `docs/context-efficiency/provenance-engine-phase3a-decisions.md`.
- This 2026-07-21 slice started ADR-001 Phase 3 with a docs-only
  implementation plan and boundary inventory in
  `docs/context-efficiency/provenance-engine-phase3-plan.md`.
- This 2026-07-21 slice converted `bmux provenance context current` to query the in-process `ProvenanceEngineClient.currentContext(...)` contract through `WorkProvenanceStore`.
- This 2026-07-21 slice converted `bmux provenance worktrees list` to query the in-process `ProvenanceEngineClient.worktrees(...)` contract through `WorkProvenanceStore`.
- This 2026-07-20 slice converted `bmux provenance explain <path>` to query the in-process `ProvenanceEngineClient.fileExplanation(...)` contract through `WorkProvenanceStore`.
- The previous Phase 2 CLI slice converted `bmux provenance sessions tree <session-id>` to query `ProvenanceEngineClient.sessionTree(...)`.
- The CLI still owns argument parsing, localized messages, Git target resolution, no-database/no-worktree/no-file fallback construction, snake_case output mapping, and output formatting.
- The context-current JSON/text shape, no-database behavior, no-worktree behavior, empty-section behavior, active-session/dirty-file/unattributed-change/checkpoint/validation/conflict bounds, and section ordering are covered by CLI regression coverage.
- The worktree-list JSON/text shape, no-database behavior, empty-database/no-worktree behavior, newest-first ordering, and existing text-rendering cap of 25 rows were preserved by CLI regression coverage.
- The `explain` JSON/text shape, no-database behavior, no-worktree behavior, no-file behavior, and found-file graph payload were preserved by CLI regression coverage.
- The session-tree JSON/text shape, no-database behavior, missing-session behavior, depth-first ordering, implicit 100 session/relationship bound, and 200 external-identity output cap remain covered by CLI regression coverage.
- The `bmux-cli` target now compiles the portable WorkProvenance store/DTO subset needed for this read-only contract path; bmux-specific runtime, workspace, Git-inspection, and subsession adapter files remain out of the CLI target.
- No daemon, storage move, schema move, data migration, bmux reconnect,
  retrieval layer, lifecycle policy, UI, or observability expansion has
  happened.
- HEAD observed before the Phase 2 CLI contract-conversion slice on 2026-07-20: `7ed3cc7cc`
- Contains the accepted ADR-001 provenance extraction product-boundary documentation, the Phase 0 migration audit report, the Phase 1 contract plan, behavior-characterization tests, the first Phase 2 internal contract seams, and the first CLI consumer conversion.

Active context-efficiency worktree:

- Branch: `context-efficiency-wip-20260715`
- Path: `/private/tmp/context-efficiency-wip-20260715`
- HEAD observed on 2026-07-18: `ca1266ebb`

Latest completed implementation HEAD for original-plan Phase 3:

- `6279c8abdaf2a1d461e86f10a41e1c145229b3d1`

Latest completed implementation HEAD for ADR-001 Phase 2 provenance extraction:

- Current branch tip after the current-context contract-conversion slice. Run `git rev-parse HEAD` when an exact hash is needed.

The current branch tip may include docs-only handoff maintenance commits. Run `git rev-parse HEAD` when an exact checkout hash is needed.

Latest completed implementation slice:

- `6279c8abd Add context efficiency repeated command facts`

Behavior in that slice:

- Thread inspection reports include `repeatedCommandFacts` derived from existing command execution candidates.
- `inspect-thread --json` emits top-level `repeated_command_facts` rows.
- Repeated facts distinguish exact repeated commands, repeated source-search commands, and repeated file-reading commands.
- Repeated facts expose only bounded summaries and stable references: kind, category, normalized executable, representative bounded command summary, normalized command fingerprint, occurrence count, capped sample command execution IDs, and first/last source references.
- No schema migration was added; repeated facts are derived report facts, not persisted rows.
- No lifecycle policy, scoring, warnings, or intervention logic was added.

Files changed in the latest implementation slice:

- `CLI/BMUXCLI+ContextEfficiency.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Model/ContextEfficiencyCommandRepetitionKind.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Model/ContextEfficiencyRepeatedCommandFact.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Reports/ContextEfficiencyRepeatedCommandDetector.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Reports/ContextEfficiencyThreadInspection.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Store/ContextEfficiencyStore.swift`
- `Packages/macOS/BmuxContextEfficiency/Tests/BmuxContextEfficiencyTests/ContextEfficiencyStoreTests.swift`
- `tests/test_context_efficiency_cli.py`

Latest provenance Phase 3D projection-key validation slice:

- External repo path: `/Users/brianbusby/repos/provenance-engine`
- Commit: `bab8f18abbc79300f52640fea1235fcff2da1f57` (`Add SQLite
  projection key validation`)
- Branch: `provenance-session-tree-storage`; draft PR:
  https://github.com/BrianBusby/provenance-engine/pull/1.
- `ProvenanceEngineContracts` remains the only public library product.
- Added internal `ProvenanceSQLiteProjectionKeyValidationReport`,
  `ProvenanceSQLiteProjectionKeyMismatch`, and
  `ProvenanceSQLiteRepository.validateProjectionKeys(limit:mismatchLimit:)`.
- The validation path decodes bounded append-order ledger entries through the
  existing ledger read path, derives expected projection-table keys from
  complete ledger replay, compares them to current SQLite projection-table keys,
  skips comparison when the requested limit truncates the ledger scan, and caps
  reported missing/unexpected key mismatches with an explicit truncation flag.
- Kept the validation read model below the public SDK/product surface; no bmux
  consumer imports or runtime behavior changed.
- Added behavior coverage for clean complete-ledger validation, same-count
  stale projection-key drift, bounded/truncated scans, and bounded mismatch
  reporting.
- No public storage SDK/product, daemon, IPC, launch agent, CLI, retrieval,
  lifecycle policy, UI, observability expansion, bmux storage move, bmux schema
  move, or data migration was added.
- Validation passed with the standalone engine SwiftPM suite and diff checks.
- Localization audit: changed only engine internal Swift package files, package
  README, and bmux internal context-efficiency docs; no bmux CLI/UI/help/
  settings/localized strings changed.
- Next safe target: continue ADR-001 Phase 3D with the next smallest internal
  engine-owned storage boundary over existing contracts. Keep it internal and
  do not start public SDK export, daemon, bmux reconnect, storage migration,
  retrieval, lifecycle policy, UI, or broad observability expansion.

Latest provenance Phase 3D projection-count validation slice:

- External repo path: `/Users/brianbusby/repos/provenance-engine`
- Commit: `303225390707775863e63821ec50eaf036e3d615` (`Add SQLite
  projection count validation`)
- Branch: `provenance-session-tree-storage`; draft PR:
  https://github.com/BrianBusby/provenance-engine/pull/1.
- `ProvenanceEngineContracts` remains the only public library product.
- Added internal `ProvenanceSQLiteProjectionValidationReport`,
  `ProvenanceSQLiteProjectionValidationMismatch`, and
  `ProvenanceSQLiteRepository.validateProjectionCounts(limit:)`.
- The validation path decodes bounded append-order ledger entries through the
  existing ledger read path, derives expected current-state projection counts
  from complete ledger replay, compares them to repository-owned SQLite table
  counts, and skips comparison when the requested bound truncates the ledger
  scan.
- Kept the validation read model below the public SDK/product surface; no bmux
  consumer imports or runtime behavior changed.
- Added behavior coverage for clean complete-ledger validation, stale
  projection-row mismatch reporting, and bounded/truncated scans.
- No public storage SDK/product, daemon, IPC, launch agent, CLI, retrieval,
  lifecycle policy, UI, observability expansion, bmux storage move, bmux schema
  move, or data migration was added.
- Validation passed with the standalone engine SwiftPM suite and diff checks.
- Localization audit: changed only engine internal Swift package files, package
  README, and bmux internal context-efficiency docs; no bmux CLI/UI/help/
  settings/localized strings changed.
- Next safe target: continue ADR-001 Phase 3D with the next smallest internal
  engine-owned storage boundary over existing contracts. Keep it internal and
  do not start public SDK export, daemon, bmux reconnect, storage migration,
  retrieval, lifecycle policy, UI, or broad observability expansion.

Latest provenance Phase 3D ledger-validation slice:

- External repo path: `/Users/brianbusby/repos/provenance-engine`
- Commit: `c9078e6eb904d27a1da48db7a5b518aad6c8ab1e` (`Add SQLite
  ledger validation summary`)
- Branch: `provenance-session-tree-storage`; draft PR:
  https://github.com/BrianBusby/provenance-engine/pull/1.
- `ProvenanceEngineContracts` remains the only public library product.
- Added internal `ProvenanceSQLiteLedgerValidationReport`,
  `ProvenanceSQLiteLedgerValidationIssue`, and
  `ProvenanceSQLiteRepository.validateEventLedger(limit:)`.
- The validation path scans bounded append-order ledger rows through the same
  decoder used by repository ledger reads, reports checked/invalid counts, the
  latest checked append sequence, first invalid row details, and whether the
  scan was truncated by the requested limit.
- Kept the validation read model below the public SDK/product surface; no bmux
  consumer imports or runtime behavior changed.
- Added behavior coverage for clean bounded ledger validation, truncation, and
  zero-limit reporting.
- No public storage SDK/product, daemon, IPC, launch agent, CLI, retrieval,
  lifecycle policy, UI, observability expansion, bmux storage move, bmux schema
  move, or data migration was added.

Previous provenance Phase 3D storage-summary slice:

- External repo path: `/Users/brianbusby/repos/provenance-engine`
- Commit: `68bafa628e4d10e212b089fc73b2e64a12d76dba` (`Add internal
  SQLite storage summary`)
- Branch: `provenance-session-tree-storage`; draft PR:
  https://github.com/BrianBusby/provenance-engine/pull/1.
- `ProvenanceEngineContracts` remains the only public library product.
- Added internal `ProvenanceSQLiteStorageSummary` and
  `ProvenanceSQLiteRepository.storageSummary()` for repository-owned
  ledger/projection row counts and latest append sequence.
- Kept the summary below the public SDK/product surface; no bmux consumer imports
  or runtime behavior changed.
- Added behavior coverage for empty storage, summary counts after append through
  existing contract paths, and projection drift/repair visibility after ledger
  replay.
- No public storage SDK/product, daemon, IPC, launch agent, CLI, retrieval,
  lifecycle policy, UI, observability expansion, bmux storage move, bmux schema
  move, or data migration was added.
- Validation passed with the standalone engine SwiftPM suite and diff checks.
- Localization audit: changed only engine internal Swift package files, package
  README, and bmux internal context-efficiency docs; no bmux CLI/UI/help/
  settings/localized strings changed.
- Next safe target: continue ADR-001 Phase 3D with the next smallest internal
  engine-owned storage boundary over existing contracts. Keep it internal and
  do not start public SDK export, daemon, bmux reconnect, storage migration,
  retrieval, lifecycle policy, UI, or broad observability expansion.

Latest provenance Phase 3D projection rebuild slice:

- External repo path: `/Users/brianbusby/repos/provenance-engine`
- Commit: `d18d5596c3e0bd4e8e9ffd7680dd6bc6139fc2bb` (`Add internal
  projection ledger rebuild`)
- Branch: `provenance-session-tree-storage`; draft PR:
  https://github.com/BrianBusby/provenance-engine/pull/1.
- `ProvenanceEngineContracts` remains the only public library product.
- Added `ProvenanceSQLiteRepository.rebuildProjectionsFromEventLedger(batchSize:)`,
  an internal bounded-batch replay path that clears current-state projection
  tables and reapplies immutable ledger payloads in SQLite append order.
- Refactored append projection updates through a shared private payload
  projection path so direct append and ledger replay use the same upsert logic.
- Preserved the immutable `provenance_events` ledger and kept this out of the
  public SDK/product surface.
- Added behavior coverage for stale projection repair, append-order overwrite
  semantics, non-positive batch coercion, empty-ledger projection clearing, and
  ledger preservation.
- No public storage SDK/product, daemon, IPC, launch agent, CLI, retrieval,
  lifecycle policy, UI, observability expansion, bmux storage move, bmux schema
  move, or data migration was added.
- Validation passed with the standalone engine SwiftPM suite and diff checks.
- Localization audit: changed only engine internal Swift package files, package
  README, and bmux internal context-efficiency docs; no bmux CLI/UI/help/
  settings/localized strings changed.
- Next safe target: continue ADR-001 Phase 3D with the next smallest internal
  engine-owned storage boundary over existing contracts. Keep it internal and
  do not start public SDK export, daemon, bmux reconnect, storage migration,
  retrieval, lifecycle policy, UI, or broad observability expansion.

Latest completed provenance Phase 3B skeleton slice:

- External repo path: `/Users/brianbusby/repos/provenance-engine`
- Local commit: `9e8fa620ccd04040968e0afab591feb48c8c11d0` (`Add Phase 3B
  contracts skeleton`)
- Package: `ProvenanceEngine`
- Initial product/module: `ProvenanceEngineContracts`
- Public surface: Foundation-only health/capability contracts and a
  health-checking protocol.
- Validated with SwiftPM describe.
- Remote push is complete: commit
  `9e8fa620ccd04040968e0afab591feb48c8c11d0` is on canonical
  `origin/main`.
- Localization audit: no bmux CLI/UI/help/settings/localized strings changed.
- Full ADR-001 Phase 3 remains incomplete.

Latest provenance Phase 3B remote unblock slice:

- This 2026-07-21 remote unblock slice created private GitHub repository
  `BrianBusby/provenance-engine` after the canonical repository initially
  returned HTTP 404.
- The canonical remote URL is now
  `git@github.com:BrianBusby/provenance-engine.git`.
- A future organization transfer remains allowed, but it is not the current
  remote gate.
- Commit `9e8fa620ccd04040968e0afab591feb48c8c11d0` is now pushed to the new
  canonical `origin/main`.
- The local `/Users/brianbusby/repos/provenance-engine` git remote now points
  at `git@github.com:BrianBusby/provenance-engine.git` and branch `main`
  tracks `origin/main`.
- `/Users/brianbusby/repos/provenance-engine` remains clean on branch `main` at
  `9e8fa620ccd04040968e0afab591feb48c8c11d0`.
- Phase 3C was not started in this remote-unblock slice.
- Phase 3B remains intentionally narrow: independent skeleton plus canonical
  remote only.
- Validation run:
  - `git status --short --branch`
  - `git rev-parse HEAD`
  - `git -C /Users/brianbusby/repos/provenance-engine status --short --branch`
  - `git -C /Users/brianbusby/repos/provenance-engine rev-parse HEAD`
  - `git -C /Users/brianbusby/repos/provenance-engine remote -v`
  - `gh api /repos/BrianBusby/provenance-engine`
  - `gh api /user`
  - `gh api -X POST /user/repos -f name=provenance-engine -F private=true -f description='Local-first engineering provenance engine' -F has_issues=true -F has_projects=false -F has_wiki=false`
  - `git -C /Users/brianbusby/repos/provenance-engine remote set-url origin git@github.com:BrianBusby/provenance-engine.git`
  - `git -C /Users/brianbusby/repos/provenance-engine ls-remote origin`
  - `git -C /Users/brianbusby/repos/provenance-engine push -u origin main`
  - `git -C /Users/brianbusby/repos/provenance-engine ls-remote origin refs/heads/main`
  - `rg -n "[R]epository not found|[h]as not yet been pushed|[u]npushed|[l]ocal only until|[r]emote gate is still pending|[P]hase 3C remains blocked|[E]xternal push is blocked|[R]emote push is still pending|[C]reate or grant access|[C]reate or gain access" docs/context-efficiency/current-status.md docs/context-efficiency/milestones.md`
  - `git diff --check`
  - `git push`
  - Final clean-state checks for bmux and the engine repo.
- Localization audit: no bmux CLI/UI/help/settings/localized strings changed.
- Full ADR-001 Phase 3 remains incomplete.

Latest provenance Phase 3D current-context projection storage slice:

- External repo path: `/Users/brianbusby/repos/provenance-engine`
- Commit: `09628cf4e1ffc0a055dd683cdad5f8da1341a0e2` (`Add current context storage projections`)
- Pushed to canonical `origin/provenance-session-tree-storage`; draft PR:
  https://github.com/BrianBusby/provenance-engine/pull/1.
- `ProvenanceEngineContracts` remains the only public library product.
- Added the repository-owned V6 migration for internal validation-run
  projection storage plus supporting indexes.
- Updated `appendEvent(_:)` so validation-run payloads project into the
  internal SQLite read model in the same transaction as the event ledger.
- Added an internal `currentContext(_:)` repository actor read backed by
  existing worktree, session, contribution, checkpoint, file-change, and
  validation-run projections.
- No bmux consumer imports or runtime behavior changed.
- No public storage SDK/product, daemon, IPC, launch agent, CLI, retrieval,
  lifecycle policy, UI, observability expansion, bmux storage move, bmux schema
  move, or data migration was added.

- Validation passed.
- Localization audit: no localized user-facing strings changed.
- Next safe target: continue ADR-001 Phase 3D with the next smallest internal
  storage boundary over existing contracts. Keep it engine-owned and internal.
- Background autoreview pushed scoped follow-up commit
  `bc86510426aba51afd4ed3f1e0fe509ae77f5ec7` (`Bound session tree traversal`).
  It prevents `sessionTree` from traversing dangling child relationships for a
  missing root, stops descendant reads once the bounded session limit is
  exhausted, and applies a per-parent child relationship SQL limit during
  bounded tree reads.

Latest provenance Phase 3D file-explanation projection storage slice:

- External repo path: `/Users/brianbusby/repos/provenance-engine`
- Commit: `1032a752db589e670917b56b5bbbefe6442843bd` (`Add file
  explanation projection storage`)
- Pushed to canonical `origin/provenance-session-tree-storage`; draft PR:
  https://github.com/BrianBusby/provenance-engine/pull/1.
- `ProvenanceEngineContracts` remains the only public library product.
- Added the repository-owned V5 migration for internal work item,
  contribution, checkpoint, change-set, and file-change projection tables plus
  supporting indexes.
- Added a narrow internal `fileExplanation(_:)` repository actor read backed by
  those projections.
- Updated the engine README storage-support scope.
- No bmux consumer imports or runtime behavior changed.
- No public storage SDK/product, daemon, IPC, launch agent, CLI, retrieval,
  lifecycle policy, UI, observability expansion, bmux storage move, bmux schema
  move, or data migration was added.
- Validation passed with the standalone engine SwiftPM suite and diff checks.
- Localization audit: changed only engine internal Swift package files, package
  README, and bmux internal context-efficiency docs; no bmux CLI/UI/help/
  settings/localized strings changed.
- Next safe target from this slice was completed by the later current-context
  projection storage slice.

Latest provenance Phase 3D worktree projection query storage slice:

- External repo path: `/Users/brianbusby/repos/provenance-engine`
- Commit: `fe1a4c5712eefc7ab2e2e3b271d0dc1e91a442e1` (`Add worktree projection query storage`)
- Pushed to canonical `origin/main`.
- `ProvenanceEngineContracts` remains the only public library product.
- Added the repository-owned V3 migration for internal repository and worktree
  current-state projection tables plus supporting indexes.
- Updated `appendEvent(_:)` so event-ledger insert plus repository, worktree,
  and session projection upserts happen in one repository-owned SQLite
  transaction when those payload records are present.
- Added narrow internal repository actor methods: `repository(id:)`,
  `worktree(id:)`, and `worktrees(_:)`.

Previous provenance Phase 3D session-projection storage slice:

- External repo path: `/Users/brianbusby/repos/provenance-engine`
- Commit: `ad1eec1dd7a0cabd3e78943ff798f21ee7665fa2` (`Add session
  projection storage`)
- Pushed to canonical `origin/main`.
- `ProvenanceEngineContracts` remains the only public library product.
- Added the repository-owned V2 migration that creates the internal
  `provenance_sessions` current-state projection table and supporting indexes.
- Updated `appendEvent(_:)` so event-ledger insert and session projection
  upsert happen in one repository-owned SQLite transaction when a
  `ProvenanceEventPayload.session` record is present.
- Added a narrow internal repository actor method:
  - `session(id:)`
- Added Swift Testing coverage for default schema bootstrap at version 2,
  session projection upsert/read after repository reopen, missing-session
  reads, and duplicate event ID rejection without replacing the original event
  or original session projection.
- Updated the engine README storage-support scope.
- No bmux consumer imports or runtime behavior changed.
- No daemon, IPC, launch agent, CLI, retrieval, lifecycle policy, UI,
  observability expansion, bmux storage move, bmux schema move, or data
  migration was added.
- Full ADR-001 Phase 3 remains incomplete.
- Validation run:
  - `swift test --package-path /Users/brianbusby/repos/provenance-engine`
  - `git -C /Users/brianbusby/repos/provenance-engine diff --check`
  - `git -C /Users/brianbusby/repos/provenance-engine diff --cached --check`
  - `git -C /Users/brianbusby/repos/provenance-engine rev-parse HEAD`
  - `git -C /Users/brianbusby/repos/provenance-engine ls-remote origin refs/heads/main`
  - `git -C /Users/brianbusby/repos/provenance-engine status --short --branch`
- Localization audit: changed only engine internal Swift package files, package
  README, and bmux internal context-efficiency docs; no bmux CLI/UI/help/
  settings/localized strings changed.
- Next safe target: continue ADR-001 Phase 3D with the next smallest internal
  storage boundary, such as repository/worktree projection bootstrap or a
  bounded session read model over the new session projection. Keep it
  engine-owned and internal.

Previous provenance Phase 3D event-ledger storage slice:

- External repo path: `/Users/brianbusby/repos/provenance-engine`
- Commit: `f96858fb8f1a207426ad78c2524ab5b5c9b74121` (`Add internal
  event ledger storage`)
- Pushed to canonical `origin/main`.
- `ProvenanceEngineContracts` remains the only public library product.
- Added the repository-owned default V1 migration that creates the internal
  `provenance_events` table and supporting indexes.
- Added narrow internal repository actor methods to append one
  `ProvenanceEvent` and read one event by stable ID.
- Added Swift Testing coverage for default schema bootstrap, append/read after
  reopen, missing-event reads, and duplicate-ID rejection without replacing the
  original event.
- Updated the engine README storage-support scope.
- No bmux consumer imports or runtime behavior changed.
- No daemon, IPC, launch agent, CLI, retrieval, lifecycle policy, UI,
  observability expansion, bmux storage move, bmux schema move, or data
  migration was added.
- Full ADR-001 Phase 3 remains incomplete.
- Validation run:
  - `swift test --package-path /Users/brianbusby/repos/provenance-engine`
  - `git -C /Users/brianbusby/repos/provenance-engine diff --check`
  - `git -C /Users/brianbusby/repos/provenance-engine diff --cached --check`
  - `git -C /Users/brianbusby/repos/provenance-engine rev-parse HEAD`
  - `git -C /Users/brianbusby/repos/provenance-engine ls-remote origin refs/heads/main`
  - `git -C /Users/brianbusby/repos/provenance-engine status --short --branch`
- Localization audit: changed only engine internal Swift package files, package
  README, and bmux internal context-efficiency docs; no bmux CLI/UI/help/
  settings/localized strings changed.
- Next safe target: continue ADR-001 Phase 3D with the next smallest internal
  storage boundary, such as a narrow repository-owned projection table
  bootstrap or a bounded read model derived from the new event ledger. Keep it
  engine-owned and internal.

Latest provenance Phase 3D repository skeleton slice:

- External repo path: `/Users/brianbusby/repos/provenance-engine`
- Commit: `dfd57a6441d5090130476893502c3091d2769440` (`Add SQLite
  repository skeleton`)
- Pushed to canonical `origin/main`.
- Added internal `ProvenanceSQLiteRepository` actor that opens an engine-owned
  SQLite database and applies the provided migration plan before returning.
- Exposed only a narrow internal schema-version read for the repository actor;
  no public storage SDK/product was added.
- Added SwiftPM coverage for repository open-and-migrate behavior, already-current
  migration skip behavior, newer-schema rejection, and invalid migration-plan
  rejection before database creation.
- Updated the engine README storage-support scope.
- No bmux consumer imports or runtime behavior changed.
- Full ADR-001 Phase 3 remains incomplete.

Latest provenance Phase 3D schema migration slice:

- External repo path: `/Users/brianbusby/repos/provenance-engine`
- Commit: `9f7333799ef4f036b06b580fcbac3cde9398b306` (`Add SQLite
  migration scaffolding`)
- Pushed to canonical `origin/main`.
- Added internal SQLite migration types for ordered schema upgrades.
- Added storage errors for unsupported schemas and invalid migration plans.
- Added SwiftPM migration behavior coverage.
- Kept `ProvenanceEngineContracts` as the only public library product.
- No bmux consumer imports or runtime behavior changed.
- Full ADR-001 Phase 3 remains incomplete.

Previous provenance Phase 3D storage-support slice:

- External repo path: `/Users/brianbusby/repos/provenance-engine`
- Commit: `ec8b84bc2f8ac7e98c0e22cac67bf6895e7882ac` (`Add initial
  SQLite storage support`)
- Pushed to canonical `origin/main`.
- Added internal `ProvenanceEngineSQLite` target with engine-owned SQLite
  connection, statement, and error support plus SwiftPM behavior tests.
- Kept this Phase 3D storage boundary intentionally below the public SDK:
  `ProvenanceEngineContracts` remains the only library product, and no bmux
  consumer imports or behavior changed.
- Did not move `WorkProvenanceStore`, schemas, migrations, storage paths,
  bmux Git/workspace adapters, CLI formatting/fallback behavior, observability
  storage, daemon, IPC, launch agent, retrieval, lifecycle policy, UI, or
  automatic orchestration.
- Validation run:
  - `swift test --package-path /Users/brianbusby/repos/provenance-engine`
  - `git -C /Users/brianbusby/repos/provenance-engine diff --check`
  - `git -C /Users/brianbusby/repos/provenance-engine diff --cached --check`
  - `git -C /Users/brianbusby/repos/provenance-engine ls-remote origin refs/heads/main`
- Localization audit: changed only engine internal Swift package files,
  package README, and bmux internal context-efficiency docs; no bmux
  CLI/UI/help/settings/localized strings changed.
- Full ADR-001 Phase 3 remains incomplete.

Latest provenance Phase 3C contract-lift slice:

- External repo path: `/Users/brianbusby/repos/provenance-engine`
- Commit: `0b2529170ef4b0d67f8050f89786d439bbab6d27` (`Lift initial
  provenance contracts`)
- Pushed to canonical `origin/main`.
- Lifted Foundation-only public contract values and protocols into
  `ProvenanceEngineContracts` without bmux imports, storage, daemon, CLI,
  migration, reconnect, retrieval, lifecycle policy, UI, or observability.
- Validation run:
  - `swift test --package-path /Users/brianbusby/repos/provenance-engine`
  - `git -C /Users/brianbusby/repos/provenance-engine diff --cached --check`
  - `git -C /Users/brianbusby/repos/provenance-engine ls-remote origin refs/heads/main`
- Localization audit: no bmux CLI/UI/help/settings/localized strings changed.
- Full ADR-001 Phase 3 remains incomplete.

Latest completed provenance planning slice:

- `docs/context-efficiency/provenance-engine-phase3a-decisions.md` completes
  ADR-001 Phase 3A as a local decision gate. It resolves the canonical local
  repo path, GitHub repository owner/name, V1 Swift/SwiftPM implementation choice, first
  artifact type, first package/module names, in-process-first SDK relationship,
  new-data storage default, and initial observability exclusion.
- No scaffold was created in Phase 3A. No daemon, independent repository,
  storage move, schema move, data migration, bmux reconnect, retrieval layer,
  lifecycle policy, UI, broad observability, or automatic orchestration was
  created.
- `docs/context-efficiency/provenance-engine-phase3-plan.md` starts ADR-001
  Phase 3 with an implementation sequence, boundary inventory, no-scaffold
  decision, validation strategy, and next safe Phase 3 gate.
- The Phase 3 plan explicitly does not complete Phase 3.
- It creates no repository/package scaffold, SDK, daemon, storage move, schema
  move, data migration, bmux reconnect, retrieval layer, lifecycle policy, UI,
  or observability expansion.
- `docs/context-efficiency/provenance-engine-extraction-phase0-report.md` completes ADR-001 Phase 0 by auditing current provenance modules, schemas, storage paths, capture paths, CLI/UI consumers, shared types, bmux assumptions, tests, reusable pieces, replacement targets, coupling risks, unknowns, and the proposed change map.
- The report concludes that extraction should center on the existing `WorkProvenance` append-only event/projection model, while bmux keeps capture adapters, UI, workspace/session orchestration, and visualization.
- `docs/context-efficiency/provenance-engine-contracts-phase1-plan.md` completes ADR-001 Phase 1 contract planning by naming current behavior invariants, the first narrow public contract surface, the bmux adapter boundary, and direct SQLite debt to remove later.
- The first Phase 2 interface slice introduces internal protocol/request/response names for event append, session-tree query, and file-explanation query around `WorkProvenanceStore`, without moving implementation or creating the independent engine repository yet.
- The Phase 2 lifecycle-trace interface slice introduces `ProvenanceLifecycleTraceQuerying` plus lifecycle-trace request/response DTOs over `ProvenanceObservabilityStore`, keeping operational telemetry separate from `ProvenanceEngineClient`.
- The first CLI consumer conversion moved `bmux provenance sessions tree` onto `ProvenanceEngineClient.sessionTree(...)` while preserving existing JSON/text/no-database behavior.
- The second CLI consumer conversion moved `bmux provenance explain` onto `ProvenanceEngineClient.fileExplanation(...)` while preserving existing JSON/text/no-database/no-worktree/no-file behavior.
- The third CLI consumer conversion moved `bmux provenance worktrees list` onto `ProvenanceEngineClient.worktrees(...)` while preserving existing JSON/text/no-database/empty-database behavior and newest-first ordering.
- The fourth CLI consumer conversion moved `bmux provenance context current` onto `ProvenanceEngineClient.currentContext(...)` while preserving existing JSON/text/no-database/no-worktree/empty-section behavior, section bounds, and ordering.
- No further ADR-001 Phase 2 authoritative provenance CLI conversion is currently identified. Pause before starting Phase 3: do not create the daemon, SDK, independent repo, storage/schema migration, retrieval layer, lifecycle policy, UI, or observability expansion from this state.

Latest completed provenance Phase 2 current-context CLI contract-conversion slice:

- Branch: `provenance-extraction-phase2-contracts`
- This 2026-07-21 slice added internal current-context request/response DTOs and bounded row DTOs for sessions, file changes, checkpoints, validation runs, and conflict rows.
- `ProvenanceEngineClient` now includes `currentContext(_:)`; `WorkProvenanceStore` backs it with current-state worktree, repository, active session, dirty file, unattributed change, checkpoint, validation-run, and potential conflict projections.
- `bmux provenance context current` now uses the contract client instead of `CLIProvenanceSQLiteReader.context(...)`.
- The CLI still owns Git target resolution, no-database/no-worktree fallback construction, localized messages, snake_case payload keys, summary keys, text output, command syntax, and help text.
- Preserved current bounds and ordering: active sessions 10; dirty files 25; unattributed changes 15; checkpoints 5; validation runs 5; conflicts 10. Existing text output still prints up to five active-session, unattributed-file, and conflict rows.
- No daemon, independent repository, storage move, schema move, data migration, observability change, retrieval work, lifecycle policy, UI, or SDK packaging happened.
- Validation passed: focused `bmux-cli` build, `tests/test_provenance_cli.py` against that CLI, focused `bmux-unit` WorkProvenance/Subsession suites, `./scripts/check-pbxproj.sh`, workspace package grouping check, and `git diff --check`.
- Localization audit: changed no CLI help text, command syntax, UI, settings, shortcut, or localized output strings.

Latest completed provenance Phase 2 worktree-list CLI contract-conversion slice:

- Branch: `provenance-extraction-phase2-contracts`
- This 2026-07-21 slice added the internal `ProvenanceWorktreeListRequest`, `ProvenanceWorktreeListEntry`, and `ProvenanceWorktreeListResponse` contract DTOs.
- `ProvenanceEngineClient` now includes `worktrees(_:)`; `WorkProvenanceStore` backs it with current-state worktree projections plus linked repository records.
- `bmux provenance worktrees list` now uses the contract client instead of `CLIProvenanceSQLiteReader.worktreeList()`.
- The command still performs the no-database guard before store construction, preserving the existing no-database JSON/text output without creating a database.
- The CLI mapper keeps the existing snake_case payload keys and the existing text output; no public command syntax, help text, localized output strings, JSON keys, or text rendering changed.
- The worktree contract supports optional repository filtering and limits for future callers, but the CLI passes no limit to preserve the existing unbounded JSON list behavior; text rendering still displays at most the first 25 rows.
- No daemon, independent repository, storage move, schema move, data migration, observability change, retrieval work, lifecycle policy, UI, or SDK packaging happened.
- Validation passed: focused `bmux-cli` build, provenance Python CLI regression, focused `bmux-unit` WorkProvenance/Subsession suites, pbxproj check, workspace package grouping check, and `git diff --check`.
- Tagged app reload/build was not run; current build policy says not to run full tagged builds as routine validation for this provenance/context-efficiency project.
- Localization audit: changed no CLI help text, command syntax, UI, settings, shortcut, or localized output strings. The command still uses the existing localized no-database and empty-list messages.

Files changed in the Phase 2 worktree-list CLI contract-conversion slice:

- `CLI/BMUXCLI+Provenance.swift`
- `CLI/CLIProvenanceWorktreeList.swift`
- `CLI/CLIProvenanceWorktreeRow.swift`
- `Sources/WorkProvenance/ProvenanceEngineClient.swift`
- `Sources/WorkProvenance/ProvenanceWorktreeListEntry.swift`
- `Sources/WorkProvenance/ProvenanceWorktreeListRequest.swift`
- `Sources/WorkProvenance/ProvenanceWorktreeListResponse.swift`
- `Sources/WorkProvenance/WorkProvenanceStore+ProvenanceEngineClient.swift`
- `Sources/WorkProvenance/WorkProvenanceStore.swift`
- `bmux.xcodeproj/project.pbxproj`
- `bmuxTests/WorkProvenanceStoreTests.swift`
- `tests/test_provenance_cli.py`
- `docs/context-efficiency/current-status.md`
- `docs/context-efficiency/milestones.md`

Latest completed provenance Phase 2 file-explanation CLI contract-conversion slice:

- Branch: `provenance-extraction-phase2-contracts`
- This 2026-07-20 slice converted `bmux provenance explain <path>` from the direct `CLIProvenanceSQLiteReader.explain(...)` path to `ProvenanceEngineClient.fileExplanation(...)` backed by `WorkProvenanceStore`.
- `runProvenanceExplain` still resolves the Git target before opening provenance storage and still returns the existing bounded no-database response without creating a database.
- The CLI now resolves the recorded worktree by Git root path through `WorkProvenanceStore`, preserving the old path-based worktree selection semantics before it calls `fileExplanation(worktreeID:path:)`.
- `CLIProvenanceExplanation` owns the mapper from `ProvenanceFileExplanationResponse` back into the existing snake_case CLI payload keys.
- Public command syntax, help text, localized output strings, JSON keys, and text rendering did not change.
- No daemon, independent repository, storage move, schema move, data migration, or observability change happened.
- Validation passed: focused `bmux-cli` build, provenance Python CLI regression, focused `bmux-unit` WorkProvenance/Subsession suites, pbxproj check, workspace package grouping check, and `git diff --check`.
- Tagged app reload/build was not run; current build policy says not to run full tagged builds as routine validation for this provenance/context-efficiency project.
- Localization audit: changed no CLI help text, command syntax, UI, settings, shortcut, or localized output strings. The command still uses the existing localized no-database, no-worktree, and no-file messages.

Files changed in the Phase 2 file-explanation CLI contract-conversion slice:

- `CLI/BMUXCLI+Provenance.swift`
- `CLI/CLIProvenanceExplanation.swift`
- `Sources/WorkProvenance/WorkProvenanceStore.swift`
- `tests/test_provenance_cli.py`
- `docs/context-efficiency/current-status.md`
- `docs/context-efficiency/milestones.md`

Latest completed provenance Phase 2 CLI contract-conversion slice:

- Branch: `provenance-extraction-phase2-contracts`
- This 2026-07-20 slice converted `bmux provenance sessions tree <session-id>` from the direct `CLIProvenanceSQLiteReader.sessionTree(...)` path to `ProvenanceEngineClient.sessionTree(...)` backed by `WorkProvenanceStore`.
- The command keeps the existing CLI-owned output model in `CLIProvenanceSessionTree`, with a mapper from `ProvenanceSessionTreeResponse` into the previous snake_case payload keys.
- The public command syntax did not change; no `--limit` flag was added.
- The existing implicit bounds are preserved: `limit: 100` for contract session/relationship traversal and `externalIdentityLimit: 200` in the CLI payload mapper.
- The no-database guard still runs before store construction, preserving the existing bounded empty JSON response instead of creating a database.
- The CLI regression fixture now marks its projection database as schema version 3 so the store opens it as existing provenance state rather than a fresh database.
- The `bmux-cli` target now includes the portable WorkProvenance store, contract DTOs, projection records, SQLite helpers, and pure Git snapshot value types required by the store. It does not include `WorkProvenanceRuntime`, `WorkProvenanceWorkspaceSnapshot`, `WorkProvenanceObservationService`, Git command runners/inspectors, or the subsession lifecycle adapter.
- Validation passed:
  - `BMUX_SKIP_ZIG_BUILD=1 xcodebuild build -project bmux.xcodeproj -scheme bmux-cli -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/bmux-provenance-cli-contract-build`
  - `BMUX_BUNDLED_CLI_PATH=/tmp/bmux-provenance-cli-contract-build/Build/Products/Debug/bmux python3 tests/test_provenance_cli.py`
  - `BMUX_SKIP_ZIG_BUILD=1 xcodebuild test -project bmux.xcodeproj -scheme bmux-unit -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/bmux-provenance-cli-contract-test -only-testing:bmuxTests/WorkProvenanceStoreTests -only-testing:bmuxTests/SubsessionProvenanceTests`
  - The focused unit run reported `29 tests in 2 suites passed` and `** TEST SUCCEEDED **`.
  - `python3 scripts/normalize-pbxproj.py`
  - `./scripts/check-pbxproj.sh`
  - `python3 scripts/check-workspace-package-groups.py --check`
  - `git diff --check`
- Additional attempted verification: `BMUX_SKIP_ZIG_BUILD=1 ./scripts/reload.sh --tag provenance-cli-contract` was stopped after about 308 seconds because it looped waiting on a stale GhosttyKit cache lock and never reached the app build.
- Localization audit: changed no CLI help text, command syntax, UI, settings, shortcut, or localized output strings. The command still uses the existing localized no-database and no-session messages.

Files changed in the Phase 2 CLI contract-conversion slice:

- `CLI/BMUXCLI+Provenance.swift`
- `CLI/CLIProvenanceSessionTree.swift`
- `CLI/bmux.swift`
- `bmux.xcodeproj/project.pbxproj`
- `tests/test_provenance_cli.py`
- `docs/context-efficiency/current-status.md`
- `docs/context-efficiency/milestones.md`

Latest completed provenance Phase 2 lifecycle-trace contract slice:

- Branch: `provenance-extraction-phase2-contracts`
- This 2026-07-20 slice added `ProvenanceLifecycleTraceQuerying`.
- `ProvenanceObservabilityStore` conforms to the trace-query protocol.
- The response is bounded operational telemetry, separate from `ProvenanceEngineClient`.
- No CLI command, daemon, repository split, or schema move was added.
- Validation passed: focused `bmux-unit` trace/store suites and project hygiene checks.
- Localization audit: no user-facing strings changed.

Files changed in the Phase 2 lifecycle-trace contract slice:

- `Sources/WorkProvenance/ProvenanceLifecycleTraceListRequest.swift`
- `Sources/WorkProvenance/ProvenanceLifecycleTraceListResponse.swift`
- `Sources/WorkProvenance/ProvenanceLifecycleTraceQuerying.swift`
- `Sources/WorkProvenance/ProvenanceObservabilityStore+ProvenanceLifecycleTraceQuerying.swift`
- `Sources/WorkProvenance/ProvenanceIdentityResolutionRecord.swift`
- `Sources/WorkProvenance/ProvenancePipelineRunRecord.swift`
- `Sources/WorkProvenance/ProvenancePipelineStageExecutionRecord.swift`
- `Sources/WorkProvenance/ProvenanceProjectionLineageRecord.swift`
- `bmux.xcodeproj/project.pbxproj`
- `bmuxTests/SubsessionProvenanceTests.swift`
- `docs/context-efficiency/current-status.md`
- `docs/context-efficiency/milestones.md`

Latest completed provenance Phase 2 lifecycle-contract slice:

- Branch: `provenance-extraction-phase2-contracts`
- This 2026-07-20 slice added internal lifecycle contracts in `Sources/WorkProvenance`.
- `WorkProvenanceSubsessionLifecycleRecorder` now records through normalized lifecycle requests.
- The existing `AgentSubsessionLifecycleChange` path is preserved as a bmux adapter.
- Contract tests cover the normalized recorder, response metadata, session tree projections, deterministic event building, and stable fallback identity behavior.
- A read-only subsession inspected the lifecycle-trace query seam and recommended keeping it separate from `ProvenanceEngineClient`; that seam is deferred to a separate mapping slice.
- The slice intentionally did not convert CLI commands, move code into an independent repository, create the daemon, or change database schemas.
- Validation passed:
  - `BMUX_SKIP_ZIG_BUILD=1 xcodebuild test -project bmux.xcodeproj -scheme bmux-unit -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/bmux-provenance-phase2-lifecycle-test -only-testing:bmuxTests/WorkProvenanceStoreTests -only-testing:bmuxTests/SubsessionProvenanceTests`
  - The focused run reported `28 tests in 2 suites passed` and `** TEST SUCCEEDED **`.
  - `./scripts/check-pbxproj.sh`
  - `python3 scripts/check-workspace-package-groups.py --check`
  - `git diff --check`
- Localization audit: changed only internal Swift contracts, internal tests, project wiring, and context-efficiency documentation; no UI, CLI help/output, settings, shortcut, or localized user-facing strings changed.

Files changed in the Phase 2 lifecycle-contract slice:

- `Sources/WorkProvenance/ProvenanceSubsessionLifecyclePhase.swift`
- `Sources/WorkProvenance/ProvenanceSubsessionLifecycleRecording.swift`
- `Sources/WorkProvenance/ProvenanceSubsessionLifecycleRequest.swift`
- `Sources/WorkProvenance/ProvenanceSubsessionLifecycleResponse.swift`
- `Sources/WorkProvenance/WorkProvenanceSubsessionLifecycleRecorder.swift`
- `bmux.xcodeproj/project.pbxproj`
- `bmuxTests/SubsessionProvenanceTests.swift`
- `docs/context-efficiency/current-status.md`
- `docs/context-efficiency/milestones.md`

Latest completed provenance Phase 2 contract-interface slice:

- Branch: `provenance-extraction-phase2-contracts`
- This 2026-07-20 slice added an internal `ProvenanceEngineClient` seam in `Sources/WorkProvenance` with request/response DTOs for `appendEvent`, `sessionTree`, and `fileExplanation`.
- `WorkProvenanceStore` now conforms to that seam through `WorkProvenanceStore+ProvenanceEngineClient.swift`; implementation still lives in bmux and still uses the existing SQLite store.
- `WorkProvenanceStore.sessionTree(rootSessionID:limit:)` now walks child relationships recursively from the requested root with a depth bound and cycle guard, which better matches the future CLI replacement target than the older root-ID projection scan.
- Contract-level tests exercise the store through `any ProvenanceEngineClient` for append/file explanation, duplicate event rollback, session-tree external identities, and replay consistency.
- The slice intentionally did not convert `bmux provenance sessions tree` yet. A read-only subsession flagged that the CLI path has exact JSON/no-database/limit semantics that should be mapped in a separate CLI regression slice.
- Validation passed:
  - `BMUX_SKIP_ZIG_BUILD=1 xcodebuild test -project bmux.xcodeproj -scheme bmux-unit -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/bmux-provenance-phase2-test -only-testing:bmuxTests/WorkProvenanceStoreTests -only-testing:bmuxTests/SubsessionProvenanceTests`
  - The focused run reported `26 tests in 2 suites passed` and `** TEST SUCCEEDED **`.
  - `./scripts/check-pbxproj.sh`
  - `python3 scripts/check-workspace-package-groups.py --check`
  - `git diff --check`
- Localization audit: changed only internal Swift contracts, internal tests, project wiring, and context-efficiency documentation; no UI, CLI help/output, settings, shortcut, or localized user-facing strings changed.

Files changed in the Phase 2 contract-interface slice:

- `Sources/WorkProvenance/ProvenanceAppendEventRequest.swift`
- `Sources/WorkProvenance/ProvenanceAppendEventResponse.swift`
- `Sources/WorkProvenance/ProvenanceEngineClient.swift`
- `Sources/WorkProvenance/ProvenanceFileExplanationRequest.swift`
- `Sources/WorkProvenance/ProvenanceFileExplanationResponse.swift`
- `Sources/WorkProvenance/ProvenanceSessionTreeRequest.swift`
- `Sources/WorkProvenance/ProvenanceSessionTreeResponse.swift`
- `Sources/WorkProvenance/WorkProvenanceStore+ProvenanceEngineClient.swift`
- `Sources/WorkProvenance/WorkProvenanceFileExplanation.swift`
- `Sources/WorkProvenance/WorkProvenanceStore.swift`
- `bmux.xcodeproj/project.pbxproj`
- `bmuxTests/WorkProvenanceStoreTests.swift`
- `docs/context-efficiency/current-status.md`
- `docs/context-efficiency/milestones.md`

Latest completed provenance Phase 1 characterization slice:

- Branch: `provenance-extraction-phase1-contracts`
- This 2026-07-20 slice added contract-style tests for the existing `WorkProvenance` behavior before extraction.
- Store invariants now covered: events remain readable in append order after reopening; projections still answer file-explanation queries after reopening and rebuilding; duplicate event IDs roll back projection changes; projection failures after event insert roll back the whole append transaction; replay uses append order rather than event timestamp order; unknown future event type names remain readable.
- Subsession lifecycle invariants now covered: identical normalized lifecycle input produces deterministic event/session/relationship/external-identity IDs; missing or blank subsession identifiers use the same stable low-confidence fallback identity; missing parent relationships root the child under the named parent at depth one; start followed by stop preserves the start timestamp and updates completion.
- The slice intentionally changed no runtime paths, no schema, no CLI output, no UI, and no daemon/repository layout.
- Validation passed:
  - `BMUX_SKIP_ZIG_BUILD=1 xcodebuild test -project bmux.xcodeproj -scheme bmux-unit -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/bmux-provenance-phase1-test -only-testing:bmuxTests/WorkProvenanceStoreTests -only-testing:bmuxTests/SubsessionProvenanceTests`
  - The focused run reported `23 tests in 2 suites passed` and `** TEST SUCCEEDED **`.
  - `git diff --check`
- Localization audit: changed only internal tests and context-efficiency documentation; no UI, CLI help/output, settings, shortcut, or localized user-facing strings changed.

Files changed in the Phase 1 characterization slice:

- `bmuxTests/WorkProvenanceStoreTests.swift`
- `bmuxTests/SubsessionProvenanceTests.swift`
- `docs/context-efficiency/provenance-engine-contracts-phase1-plan.md`
- `docs/context-efficiency/current-status.md`
- `docs/context-efficiency/milestones.md`

Latest completed provenance implementation slice:

- Working tree slice on 2026-07-19 adds bounded read-only `bmux provenance sessions tree <session-id> --json` diagnostics over the existing `sessions`, `session_relationships`, and `session_external_identities` projections. It keeps `WorkProvenance` as the authoritative store and adds no orchestration, policy, delegation contracts, observability schema, UI, or lifecycle mutation. `bmux-cli` built successfully and `tests/test_provenance_cli.py` passed against that built binary. The full `bmux-unit` app-target test run was attempted but blocked before tests by an unrelated Ghostty CLI helper Zig link failure.

Latest completed observability planning slice:

- `docs/context-efficiency/provenance-observability-phase-o0-report.md` completes Phase O0 investigation and documents the narrow O1 lifecycle-ingestion trace design. No observability schema or runtime code was added.

Latest completed observability implementation slice:

- `114df3b18 Add lifecycle projection lineage traces`
- This 2026-07-20 slice migrates `ProvenanceObservability.sqlite` to schema version 3 with bounded `projection_lineage` rows.
- Lifecycle-ingestion traces now record which authoritative projection rows were derived from the lifecycle event payload during `work_provenance_projection_update`.
- Projection lineage records include pipeline run ID, stage name, projection kind, source event ID/type/schema version, hashed source payload, target table, target entity kind/ID, operation, generator version, confidence, timestamps, and duration.
- `bmux provenance traces lifecycle-ingestion --json` now includes top-level `projection_lineage` rows and `summary.projection_lineage_count`. Older observability databases without the table still return an empty lineage array.
- The projection stage version is now `o3`; lifecycle-ingestion run implementation version is now `o3`.
- Failed WorkProvenance append/projection attempts do not emit projection-lineage rows, preserving the distinction between attempted identity resolution and successful projection derivation.
- This remains scoped to the existing lifecycle-ingestion path only. It adds no retrieval traces, semantic projection, feedback, dashboard, quality scoring, shadow evaluation, automatic correction, lifecycle policy, orchestration, UI, or parallel provenance source.
- Validation passed:
  - Focused `SubsessionProvenanceTests` with `BMUX_SKIP_ZIG_BUILD=1`.
  - `bmux-cli` Debug build at `/tmp/bmux-context-o3-projection-lineage-cli`.
  - `tests/test_provenance_cli.py` against that built CLI.
  - `scripts/check-pbxproj.sh`, workspace package grouping check, and `git diff --check`.

Files changed in the latest observability projection-lineage slice:

- `CLI/BMUXCLI+Provenance.swift`
- `CLI/CLIProvenanceLifecycleTraceList.swift`
- `CLI/CLIProvenanceObservabilitySQLiteReader.swift`
- `Sources/WorkProvenance/ProvenanceObservabilityStore.swift`
- `Sources/WorkProvenance/ProvenanceProjectionLineageRecord.swift`
- `Sources/WorkProvenance/WorkProvenanceStore.swift`
- `Sources/WorkProvenance/WorkProvenanceSubsessionLifecycleRecorder.swift`
- `bmux.xcodeproj/project.pbxproj`
- `bmuxTests/SubsessionProvenanceTests.swift`
- `tests/test_provenance_cli.py`

Previous completed observability implementation slice:

- `4ff2e661a Add lifecycle trace filters`
- This 2026-07-20 slice adds bounded read-only filters to `bmux provenance traces lifecycle-ingestion` and to `ProvenanceObservabilityStore.lifecycleIngestionRuns(...)`.
- New CLI filters: `--run <pipeline-run-id>`, `--parent-session <session-id>`, `--child-session <session-id>`, and `--status <status>`, all still capped by `--limit`.
- The trace JSON summary now includes `resolved_identity_resolution_count`, `unresolved_identity_resolution_count`, and `conflicted_identity_resolution_count` in addition to run/stage/identity counts.
- The Python CLI fixture now includes two lifecycle parents so filter regressions prove unrelated lifecycle traces are excluded, not only non-lifecycle rows.
- This is query polish over existing O1/O2 rows only. It adds no schema migration, capture source, projection lineage, retrieval, feedback, dashboard, quality scoring, shadow evaluation, automatic correction, lifecycle policy, orchestration, or parallel provenance source.
- Validation: focused `SubsessionProvenanceTests` passed with `BMUX_SKIP_ZIG_BUILD=1`; `./scripts/reload.sh --tag provenance-trace-filters` succeeded; `tests/test_provenance_cli.py` passed against the tagged app's bundled CLI; `git diff --check` passed; `Resources/Localizable.xcstrings` parsed as JSON and the changed `en`/`ja` keys were verified.

Files changed in the latest observability query-polish slice:

- `CLI/BMUXCLI+Provenance.swift`
- `CLI/CLIProvenanceLifecycleTraceList.swift`
- `CLI/CLIProvenanceObservabilitySQLiteReader.swift`
- `Resources/Localizable.xcstrings`
- `Sources/WorkProvenance/ProvenanceObservabilityStore.swift`
- `bmuxTests/SubsessionProvenanceTests.swift`
- `tests/test_provenance_cli.py`

Previous completed observability implementation slice:

- `6ceb48ccafc698f1ee16984455f26e18c81efe7a Add lifecycle identity observability traces`
- This O2 slice adds `identity_resolution_attempts` to the separate `ProvenanceObservability.sqlite` store, migrating the observability schema to version 2 while keeping `WorkProvenance` authoritative.
- It records identity-resolution attempts only for the lifecycle-ingestion path and correlates each attempt to the O1 `pipeline_run_id`.
- It explains how `AgentSubsessionLifecycleChange` was resolved into child session ID, lifecycle event ID, relationship session ID, and external identity ID.
- It stores bounded inputs and outcomes only: phase, agent kind, parent session ID, presence flags for optional lifecycle fields, selected identity kind/value category, hashed input identity value, candidate count, confidence, fallback/unresolved state, unresolved reason, conflict reason, selected authoritative IDs, timestamps, and resolver version.
- Native subsession IDs record high-confidence resolved identity; missing native identifiers record low-confidence fallback-unresolved identity; duplicate append conflicts record a bounded conflict reason without blocking provenance persistence.
- The existing `bmux provenance traces lifecycle-ingestion --json` output now includes bounded `identity_resolutions` rows and `identity_resolution_count`. Text output is unchanged.
- Observability writes remain best-effort/non-blocking and separate from authoritative WorkProvenance writes.
- It does not add O3+ projection lineage, retrieval, delegation contracts, feedback, dashboards, quality scoring, shadow evaluation, automatic correction, lifecycle policy, orchestration, or a parallel semantic provenance source.
- Validation: focused `SubsessionProvenanceTests` passed with `BMUX_SKIP_ZIG_BUILD=1`; `bmux-cli` built successfully; `tests/test_provenance_cli.py`, `scripts/check-pbxproj.sh`, `python3 scripts/check-workspace-package-groups.py --check`, and `git diff --check` passed.

Files changed in the working tree slice:

- `CLI/BMUXCLI+Provenance.swift`
- `CLI/CLIProvenanceLifecycleTraceList.swift`
- `CLI/CLIProvenanceObservabilitySQLiteReader.swift`
- `Sources/WorkProvenance/ProvenanceIdentityResolutionRecord.swift`
- `Sources/WorkProvenance/ProvenanceObservabilityStore.swift`
- `Sources/WorkProvenance/WorkProvenanceSubsessionLifecycleRecorder.swift`
- `bmux.xcodeproj/project.pbxproj`
- `bmuxTests/SubsessionProvenanceTests.swift`
- `tests/test_provenance_cli.py`

Previous completed provenance implementation slice:

- `Add provenance subsession lifecycle recorder`

Behavior in that slice:

- `WorkProvenanceSubsessionLifecycleRecorder` converts `AgentSubsessionLifecycleChange` into append-only `subsession_started` / `subsession_stopped` events.
- Child session IDs, external identity IDs, and lifecycle event IDs are deterministic through `WorkProvenanceStableIDFactory`.
- Runtime wiring records lifecycle changes from the existing `registry.onSubsessionLifecycleChanged` path while preserving ephemeral child workspace behavior.
- Existing `WorkProvenanceRuntime.live()` now shares one store between workspace Git observation and subsession lifecycle persistence.
- Swift Testing coverage verifies start/stop projection replay, nested root/depth derivation, missing-identifier fallback confidence, and stop-before-start persistence.
- No CLI, UI, lifecycle policy, delegation contracts, reconciliation, parent disposition, quality scoring, or observability schema was added.

Files changed in that slice:

- `Sources/WorkProvenance/WorkProvenanceSubsessionLifecycleRecorder.swift`
- `Sources/WorkProvenance/WorkProvenanceStableIDFactory.swift`
- `Sources/WorkProvenance/WorkProvenanceRuntime.swift`
- `Sources/Mobile/AgentChat/AgentChatTranscriptService.swift`
- `Sources/AppDelegate.swift`
- `Sources/bmuxApp.swift`
- `bmuxTests/SubsessionProvenanceTests.swift`
- `bmux.xcodeproj/project.pbxproj`

Previous provenance implementation slice:

- `b875eb837 Add provenance session relationship projections`

Behavior in that slice:

- `WorkProvenanceStore` schema version is now 3.
- New projection tables record session parent/root relationships and session external identities.
- Event payload replay/upsert/query support now covers parent lookup, direct children, external identities, and bounded session trees.
- Store tests cover relationship and identity replay/idempotency.
- No adapter, runtime wiring, CLI, UI, lifecycle policy, warnings, delegation contracts, or parent disposition was added.

Files changed in that slice:

- `Sources/WorkProvenance/WorkProvenanceExternalIdentityRecord.swift`
- `Sources/WorkProvenance/WorkProvenanceSessionRelationshipRecord.swift`
- `Sources/WorkProvenance/WorkProvenanceSessionTree.swift`
- `Sources/WorkProvenance/WorkProvenanceEventPayload.swift`
- `Sources/WorkProvenance/WorkProvenanceEventType.swift`
- `Sources/WorkProvenance/WorkProvenanceStore.swift`
- `bmuxTests/WorkProvenanceStoreTests.swift`
- `bmux.xcodeproj/project.pbxproj`

## Phase 2 Closure Note

- `b194b8b1 Add missing timestamp rollout regression`
- `f90790b0 Report missing rollout timestamps`

That closure slice kept missing-timestamp facts importable, reported bounded `missing rollout event timestamp` parser diagnostics, and kept unknown scalar payload imports non-fatal.

## Good Next Targets

Stay narrow and read-only. Prefer package-level Swift tests unless a CLI regression is specifically exercising the built binary.

ADR-001 Phase 3 target:

1. Phase 3C contract lift is complete: commit
   `0b2529170ef4b0d67f8050f89786d439bbab6d27` is pushed to
   `BrianBusby/provenance-engine` on `origin/main`.
2. Phase 3D storage support has progressed through initial SQLite support,
   schema migration scaffolding, a minimal repository actor, event-ledger
   storage, session projection storage, repository/worktree projection storage,
   session-tree projection storage, file-explanation projections,
   current-context projections, normalized lifecycle recording,
   SQLite-backed `ProvenanceEngineClient` conformance, default storage-location
   resolution, bounded internal event-ledger cursor reads, internal projection
   rebuild from ledger replay, internal storage summary reads, and internal
   event-ledger validation. Latest storage slice is
   `c9078e6eb904d27a1da48db7a5b518aad6c8ab1e` on
   `origin/provenance-session-tree-storage` with draft PR
   https://github.com/BrianBusby/provenance-engine/pull/1.
3. The next implementation target can continue Phase 3D only after deciding the
   next smallest internal engine-owned storage boundary over existing contracts,
   still without lifting `WorkProvenanceStore` wholesale and without bmux
   consumer imports or behavior changes.
4. Do not start Phase 4 reconnect, Phase 5 migration, retrieval, lifecycle
   policy, UI, broad observability, or automatic orchestration.

Original-plan Phase 3 targets:

1. Link `work_item_references` to future `WorkProvenance` work items or delegation inputs through stable IDs instead of copying telemetry rows.
2. Evaluate OSC 133 parsing for non-Codex terminal attribution in a separate capture slice.
3. Persist command execution candidates only if derived reports prove insufficient.

Subsession/delegation provenance target:

1. Phase B read-only lifecycle persistence and session-tree query coverage are proven against a narrow rebuilt `bmux-cli`; do not expand into delegation contracts until a separate Phase C/D slice.
2. Keep `AgentSubsessionLifecycleChange` as the authoritative lifecycle source; use `BmuxContextEfficiency` only later for telemetry identity links.
3. Do not start delegation contracts, reconciliation, child reports, parent disposition, UI, or lifecycle policy until read-only lifecycle persistence and query coverage are proven.

Retrieval/knowledge-projection target:

1. Keep retrieval as planning/investigation only until subsession lifecycle persistence and the next semantic provenance prerequisites are proven.
2. When explicitly starting retrieval work, begin with Phase R0 from `agent-retrieval-knowledge-projection-plan.md`: current stores, projection/migration patterns, retrieval capabilities, FTS support, schemas, invalidation design, roadmap insertion points, first migration, and first fixture.
3. Do not start embeddings, context-package generation, UI, automatic prompt injection, or orchestration in the first retrieval slice.

Observability target:

1. Use `provenance-observability-phase-o0-report.md` as the completed O0 gate.
2. Treat O1 lifecycle-ingestion traces and O2 lifecycle identity-resolution traces as complete for the current narrow path.
3. Treat the first O3 projection-lineage slice as complete only for lifecycle-ingestion projections.
4. The next observability implementation, if explicitly requested, should either continue O3 for another already-authoritative projection path or begin the next explicitly approved observability phase with the same bounded/read-only constraints.
5. Do not add broad observability tables, retrieval traces, dashboards, feedback, quality scoring, shadow evaluation, automatic correction, lifecycle policy, warnings, intervention logic, prompt mutation, or orchestration.

Avoid broad CLI/app integration unless the slice is explicitly scoped to read-only diagnostics and includes localization work for any new command/help/error text.

## Verification For The Next Slice

For docs-only context-efficiency roadmap updates, run:

```bash
git diff --check
```

After context-efficiency package or CLI report changes, run:

```bash
swift test --package-path /private/tmp/context-efficiency-wip-20260715/Packages/macOS/BmuxContextEfficiency
python3 scripts/check-workspace-package-groups.py --check
scripts/check-pbxproj.sh
git diff --check
./scripts/reload.sh --tag context-efficiency
```

Then run the context-efficiency CLI regression against the rebuilt tagged CLI if the slice touches CLI behavior or report output.

After WorkProvenance/subsession Phase B code changes, run the relevant Swift Testing/Xcode unit coverage for `WorkProvenanceStore`, `AgentChatSessionRegistryLifecycleTests`, and any new lifecycle adapter tests, then run `scripts/check-pbxproj.sh`, `python3 scripts/check-workspace-package-groups.py --check`, `git diff --check`, and a tagged reload if app runtime wiring changed.

Build policy update from 2026-07-19: do not run full tagged builds as routine validation for this provenance/context-efficiency project. Build again only for a compiler-level reason or when the user explicitly asks.

Latest Phase B query-diagnostics validation on 2026-07-19:

- `xcodebuild -project bmux.xcodeproj -scheme bmux-cli -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/bmux-context-eff-phase-b-cli build` passed.
- `BMUX_BUNDLED_CLI_PATH=/tmp/bmux-context-eff-phase-b-cli/Build/Products/Debug/bmux python3 tests/test_provenance_cli.py` passed.
- `scripts/check-pbxproj.sh`, `python3 scripts/check-workspace-package-groups.py --check`, and `git diff --check` passed.
- Focused `bmux-unit` testing was attempted with `SubsessionProvenanceTests`, `AgentChatSessionRegistryLifecycleTests`, and `WorkProvenanceStoreTests`, but the app-target build failed before tests in the Ghostty CLI helper Zig build script with undefined symbols such as `__availability_version_check`; this was outside the Phase B Swift/CLI changes.

Latest Phase 3 salvage validation on 2026-07-19:

- `swift test --package-path /private/tmp/context-efficiency-phase3-salvage/Packages/macOS/BmuxContextEfficiency` passed 26 Swift Testing tests.
- `xcodebuild -project bmux.xcodeproj -scheme bmux-cli -configuration Debug -destination platform=macOS -derivedDataPath /tmp/bmux-context-eff-phase3-salvage-cli build` passed.
- `BMUX_BUNDLED_CLI_PATH=/tmp/bmux-context-eff-phase3-salvage-cli/Build/Products/Debug/bmux python3 tests/test_context_efficiency_cli.py` passed.
- `scripts/check-pbxproj.sh`, `python3 scripts/check-workspace-package-groups.py --check`, and `git diff --check` passed.

Latest Phase B foundation validation on 2026-07-18:

- `scripts/check-pbxproj.sh` passed.
- `python3 scripts/check-workspace-package-groups.py --check` passed.
- `git diff --check` passed.
- `./scripts/reload.sh --tag context-eff-phase-b` passed and built `bmux DEV context-eff-phase-b.app`.
- Focused `xcodebuild test -only-testing:bmuxTests/WorkProvenanceStoreTests/persistsSessionRelationshipsAndExternalIdentitiesAcrossReplay` reached compilation of the new WorkProvenance files, then failed later with the known local Zig/Ghostty undefined-symbol linker issue before running tests.

Latest Phase B lifecycle adapter validation on 2026-07-19:

- `scripts/check-pbxproj.sh` passed.
- `python3 scripts/check-workspace-package-groups.py --check` passed.
- `git diff --check` passed.
- `xcodebuild test -project bmux.xcodeproj -scheme bmux-unit -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/bmux-context-provenance-test -only-testing:bmuxTests/SubsessionProvenanceTests` initially failed at the known local Ghostty CLI helper Zig link step before test execution.
- `BMUX_SKIP_ZIG_BUILD=1 xcodebuild test -project bmux.xcodeproj -scheme bmux-unit -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/bmux-context-provenance-test -only-testing:bmuxTests/SubsessionProvenanceTests` passed 4 Swift Testing tests.
- `./scripts/reload.sh --tag context-provenance` passed and built `bmux DEV context-provenance.app`.

Current tagged app path pattern:

```text
/Users/brianbusby/Library/Developer/Xcode/DerivedData/bmux-context-efficiency/Build/Products/Debug/bmux DEV context-efficiency.app
```

Use the bundled CLI from that rebuilt app:

```text
/Users/brianbusby/Library/Developer/Xcode/DerivedData/bmux-context-efficiency/Build/Products/Debug/bmux DEV context-efficiency.app/Contents/Resources/bin/bmux
```

## Known Local Quirks

- The active WIP may be in a separate worktree outside `/Users/brianbusby/repos/bmux`. Confirm with `git branch --show-current` and the handoff context before editing.
- Worktree git metadata may live under `/Users/brianbusby/repos/bmux/.git/worktrees/`, outside some writable sandboxes.
- `git status --short` may be less useful in that setup. Prefer `git diff --name-status`, `git diff --stat`, `git branch --show-current`, and `git rev-parse HEAD`.
- `apply_patch` may default to `/Users/brianbusby/repos/bmux`. Use absolute paths when patching a `/private/tmp/...` worktree.
- `tests/test_context_efficiency_cli.py` has shown local-disk sensitivity. If needed, materialize the indexed test blob into a temporary file and run that copy against the rebuilt bundled CLI.

## Handoff Update Rules

At the end of every context-efficiency slice:

1. Update `Latest completed implementation HEAD` when the slice changes implementation behavior.
2. Record the completed commit or commits.
3. Summarize behavior changes in facts, not intentions.
4. List changed files.
5. Update phase status and next targets if priorities changed.
6. Update verification commands or known quirks if they changed.
7. State whether localization was needed.

Do not let one-off chat handoffs become the only record of current status.

## Localization

The O3 projection-lineage implementation changed provenance trace JSON fields only (`projection_lineage_count` and `projection_lineage`) and did not add or edit CLI help, CLI text output, UI strings, command text, error text, or localized user-facing prose. No `Resources/Localizable.xcstrings` update was needed.

This file and the other `docs/context-efficiency/*` planning files are internal development documentation and are not mirrored into localized docs. If a future slice adds or edits CLI/UI/user-facing strings, use `bmux-localization` and update every supported locale.
