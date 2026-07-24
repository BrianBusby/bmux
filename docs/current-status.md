# Provenance Engine Current Status

This document records the accepted baseline and active integration gate. The complete platform north star is `docs/reference-architecture.md`; the currently implemented architecture and active design boundaries are in `docs/architecture.md`.

Accepted baseline: `0.1.0` plus Slice C session-tree read contract acceptance
and Slice D file-explanation read adoption acceptance.

Source baseline: `main` through Slice D readiness merge commit
`126afde36671f53a137953200e7883e6b4093ac3`.

The accepted engine is an independent Swift package with three modules:

- `ProvenanceEngineContracts`
- `ProvenanceEngineSDK`
- `ProvenanceEngineSQLite`

The supported client entrypoint is `ProvenanceEngineClientFactory`, which creates an in-process SQLite-backed `any ProvenanceEngineClient`. The current storage backend owns SQLite schema creation, event ledger persistence, worktree/session/file/current-context projections, validation summaries, and repair reports.

The first bmux adoption path, `bmux provenance worktrees list`, now consumes this package through `ProvenanceEngineClientFactory` and `ProvenanceEngineClient.worktrees(...)`.

Current integration gate: none selected after Slice D acceptance.

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

The next bmux migration slice may now be selected, but no next slice is active.
Provenance Engine should not add storage, daemon, migration, retrieval,
semantic, observability, GitHub ingestion, or Knowledge Compiler implementation
until a new migration slice explicitly proves the need.

Long-term architecture note: shared repository evidence and Knowledge Compiler work are accepted as post-V1 planning targets only. The current package preserves optional event evidence-origin and evidence-scope metadata, but GitHub ingestion, shared evidence-store deployment, retrieval, and compiler implementation remain frozen until after the current V1 bmux adoption sequence.

Required verification for this baseline:

```bash
swift test --package-path /Users/brianbusby/repos/provenance-engine
```

Last local verification for Slice D readiness on 2026-07-24:

- `swift test --package-path /Users/brianbusby/repos/provenance-engine --filter ProvenanceEngineFileExplanationSDKTests`: 7 tests passed.
- `swift test --package-path /Users/brianbusby/repos/provenance-engine`: passed before PR 5 merge.
- Package product verification confirmed only `ProvenanceEngineContracts` and `ProvenanceEngineSDK` public products.
- `git diff --check`: passed.
- Markdown link scan over `README.md` and `docs`: no links found to validate.
- Consumer-style tests contain no `import ProvenanceEngineSQLite`.
