# Provenance Engine Current Status

This document records the accepted baseline and active integration gate. The complete platform north star is `docs/reference-architecture.md`; the currently implemented architecture and active design boundaries are in `docs/architecture.md`.

Accepted baseline: `main` at
`0ed9f68b66126ce50ec0f0ce7f7f6569b02a9dbc`, which includes Provenance Engine
V1, bmux Slice E operational acceptance, and schema identity hardening.

Current cross-repository gate: Engineering Observation Period after Slice E.

The accepted engine is an independent Swift package with three modules:

- `ProvenanceEngineContracts`
- `ProvenanceEngineSDK`
- `ProvenanceEngineSQLite`

The supported client entrypoint is `ProvenanceEngineClientFactory`, which creates an in-process SQLite-backed `any ProvenanceEngineClient`. The current storage backend owns SQLite schema creation, event ledger persistence, worktree/session/file/current-context projections, validation summaries, repair reports, default storage path resolution, and schema identity validation.

bmux now consumes the public SDK for adopted V1 reads and bounded writes:

- `bmux provenance worktrees list` calls `ProvenanceEngineClient.worktrees(...)`.
- `bmux provenance sessions tree <session-id>` calls `ProvenanceEngineClient.sessionTree(...)`.
- `bmux provenance explain <path>` calls `ProvenanceEngineClient.fileExplanation(...)`.
- `bmux provenance context current` calls `ProvenanceEngineClient.currentContext(...)`.
- supported lifecycle facts are recorded with `ProvenanceEngineClient.recordSessionLifecycle(...)`.
- accepted Git/worktree observations are recorded with `ProvenanceEngineClient.appendEvent(...)`.

Slice E is operationally accepted. bmux merged the runtime cutover at
`3cbacd1501768f79ea377eb2d6aea9113f199d1b`; this repository accepted the shared
roadmap update at `0ed9f68b66126ce50ec0f0ce7f7f6569b02a9dbc`; and schema
identity hardening landed at `18f5511a7c836b3f12f3fa0fbe3aefe42efd3f03`.

Production default storage now resolves to the engine-owned store at
`~/.local/state/provenance-engine/provenance.sqlite`, and incompatible stores
are rejected by engine schema identity validation. The prior bmux-local
database is not the canonical V1 Current State store.

Slice C consumer adoption merged in bmux PR 7 at
`08763dd0d3256989180dcc04f426da1f24369175` on 2026-07-24T17:20:04Z with an
explicit GitHub Actions waiver for unavailable Blacksmith runner evidence. Slice
C accepted the second bmux adoption path, `bmux provenance sessions tree
<session-id>`, through `ProvenanceEngineClientFactory` and
`ProvenanceEngineClient.sessionTree(ProvenanceSessionTreeRequest(rootSessionID:limit:))`.
SDK-level tests cover a client created by `ProvenanceEngineClientFactory`, seeded
through public `appendEvent` calls, and queried through `sessionTree` without
direct SQLite access.

Slice D is fully accepted. Engine-side readiness is recorded in
`docs/file-explanation-readiness-slice-completion.md`; real bmux adoption
validated the existing `fileExplanation` public contract, required no new public
API, and did not cross the storage boundary. bmux PR 9 merged at
`c1c5fce0eb7526d321dbed6c8a6f25f0d9aaf374` on 2026-07-24T21:54:46Z with final
head `ea72bfd7dc28cd60b093b5a4d0bebc5853c32f59`. bmux repinned to merged engine
revision `126afde36671f53a137953200e7883e6b4093ac3` and removed the temporary
feature-branch dependency pin everywhere.

Slice E validated the existing `currentContext` public contract, lifecycle
recording, accepted Git/worktree observation append path, engine-owned
production default storage, and schema identity hardening. Provenance Engine did
not take ownership of bmux UI, orchestration, capture policy, observability
trace presentation, or execution telemetry.

Current caveats and gates:

- Broad migration or removal of legacy bmux-local provenance data remains a
  separate, explicitly gated cleanup/migration decision.
- The current observability trace path remains bmux-local because V1 has no
  public observability trace API.
- Opening an agent-session UI surface alone does not necessarily create durable
  lifecycle evidence; supported hooks, feeds, or approved lifecycle producers
  must emit facts to bmux first.
- Daemon/service transport, GitHub ingestion, retrieval, Knowledge Compiler
  work, shared evidence deployment, execution analytics, and automatic
  diagnostic checkpoint scheduling remain unimplemented and gated.

Long-term architecture note: shared repository evidence and Knowledge Compiler work are accepted as post-V1 planning targets only. The current package preserves optional event evidence-origin and evidence-scope metadata, but GitHub ingestion, shared evidence-store deployment, retrieval, and compiler implementation remain frozen until the Engineering Observation Period produces an explicit next-slice decision.

Required verification for this repository baseline:

```bash
swift test
```

Last local verification for Slice D readiness on 2026-07-24:

- `swift test --package-path /Users/brianbusby/repos/provenance-engine --filter ProvenanceEngineFileExplanationSDKTests`: 7 tests passed.
- `swift test --package-path /Users/brianbusby/repos/provenance-engine`: passed before PR 5 merge.
- Package product verification confirmed only `ProvenanceEngineContracts` and `ProvenanceEngineSDK` public products.
- `git diff --check`: passed.
- Markdown link scan over `README.md` and `docs`: no links found to validate.
- Consumer-style tests contain no `import ProvenanceEngineSQLite`.

Last local verification for Slice E readiness on 2026-07-25:

- `swift test --filter CurrentContextSDKTests`: 5 tests passed.
- `swift build`: passed.
- `swift test`: 83 tests passed.
- Package description and public import validation passed.
- `git diff --check`: passed.
- Additional validation is recorded in `docs/current-context-readiness-slice-completion.md`.

## V1 Write-Side Validation

V1 write-side validation is complete in this repository and recorded in
`docs/write-side-validation-milestone.md`. The validation added a generic
non-bmux producer example, SDK tests that write only through public
`appendEvent(...)`, and a projection rebuild test proving that current-state
projections can be deleted and rebuilt from the immutable event ledger with
identical query results.

The result keeps the public write primitive unchanged. Producer integration
friction is domain-shape verbosity and stable-ID discipline, not implementation
leakage. No public API redesign is justified by this milestone.

## V1 Boundary Review

The canonical V1 platform boundary is recorded in
`docs/v1-boundary-review.md`. V1 is defined as the local-first public SDK
platform for immutable engineering evidence and deterministic Current State.
Knowledge Compiler, semantic retrieval, organization-wide evidence stores,
remote services, cross-machine sync, authentication, GitHub organization
ingestion, and AI-generated knowledge remain explicitly outside V1.

## V1 Boundary Refinement

The final V1 boundary refinement is complete in this repository. The canonical
public lifecycle helper is `recordSessionLifecycle(...)`; the earlier
`recordSubsessionLifecycle(...)` name remains only as a deprecated compatibility
wrapper. V1 now explicitly guarantees that successful local SDK writes are
committed to the local event ledger before success is returned. Producer-side
retry/outbox delivery before acceptance remains outside the core engine boundary.

Current State is now documented as the canonical deterministic interpretation of
engineering evidence in `docs/reference-architecture.md` and the V1 completion
statement in `docs/v1-boundary-review.md` has been updated to include durable
accepted writes and producer-neutral lifecycle terminology.
