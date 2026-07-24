# Provenance Engine Current Status

This document records the accepted baseline and active integration gate. The complete platform north star is `docs/reference-architecture.md`; the currently implemented architecture and active design boundaries are in `docs/architecture.md`.

Accepted baseline: `0.1.0` plus engine-side Slice C session-tree read contract
acceptance.

Source baseline: `provenance-session-tree-storage` through commit `b43146d634f7c11f8e14bf95da5418bef502b0de`.

The accepted engine is an independent Swift package with three modules:

- `ProvenanceEngineContracts`
- `ProvenanceEngineSDK`
- `ProvenanceEngineSQLite`

The supported client entrypoint is `ProvenanceEngineClientFactory`, which creates an in-process SQLite-backed `any ProvenanceEngineClient`. The current storage backend owns SQLite schema creation, event ledger persistence, worktree/session/file/current-context projections, validation summaries, and repair reports.

The first bmux adoption path, `bmux provenance worktrees list`, now consumes this package through `ProvenanceEngineClientFactory` and `ProvenanceEngineClient.worktrees(...)`.

Current integration gate: complete Slice D file-explanation read migration.
Engine-side Slice D readiness is accepted in
`docs/file-explanation-readiness-slice-completion.md`: real bmux adoption
validated the existing `fileExplanation` public contract, required no new public
API, and did not cross the storage boundary. bmux adoption remains pending final
dependency stabilization and acceptance, so Slice D as a whole is not accepted
until the bmux adoption PR merges. Slice C consumer adoption merged in bmux PR 7
at `08763dd0d3256989180dcc04f426da1f24369175` on 2026-07-24T17:20:04Z,
with an explicit GitHub Actions waiver for unavailable Blacksmith runner
evidence. Provenance Engine should not add storage, daemon, migration,
retrieval, semantic, observability, GitHub ingestion, or Knowledge Compiler
implementation before Slice D is fully accepted.

Slice C accepted the second bmux adoption path, `bmux provenance sessions tree <session-id>`, through `ProvenanceEngineClientFactory` and `ProvenanceEngineClient.sessionTree(ProvenanceSessionTreeRequest(rootSessionID:limit:))`. SDK-level tests cover a client created by `ProvenanceEngineClientFactory`, seeded through public `appendEvent` calls, and queried through `sessionTree` without direct SQLite access.

Long-term architecture note: shared repository evidence and Knowledge Compiler work are accepted as post-V1 planning targets only. The current package preserves optional event evidence-origin and evidence-scope metadata, but GitHub ingestion, shared evidence-store deployment, retrieval, and compiler implementation remain frozen until after the current V1 bmux adoption sequence.

Required verification for this baseline:

```bash
swift test --package-path /Users/brianbusby/repos/provenance-engine
```

Last local verification for Slice C acceptance on 2026-07-24:

- `swift test --package-path /Users/brianbusby/repos/provenance-engine --filter ProvenanceEngineClientFactoryTests`: 3 tests passed.
- `swift test --package-path /Users/brianbusby/repos/provenance-engine`: 71 tests passed.
- Package product verification confirmed only `ProvenanceEngineContracts` and `ProvenanceEngineSDK` public products.
- `git diff --check`: passed.
- Markdown link scan over `README.md` and `docs`: no links found to validate.
- Consumer-style tests contain no `import ProvenanceEngineSQLite`.
