# Provenance Engine Roadmap

## Accepted

- Independent Swift package with contract, SDK, and SQLite modules.
- Public in-process client factory.
- SQLite event ledger, projections, validation, and repair reports.
- Worktree list query exposed through `ProvenanceEngineClient.worktrees`.

## Current Slice

Adopt the independent package from bmux for exactly one read path:

```text
bmux provenance worktrees list
```

The bmux slice must preserve existing CLI JSON/text output, ordering, and limits while seeding tests through the public engine API.

## Frozen Until Adoption Completes

- Additional storage features.
- Daemon process design.
- Migration tooling beyond accepted SQLite schema migration support.
- Retrieval and semantic indexing.
- Observability pipeline expansion.
- Additional bmux provenance reconnect paths.

## Next Eligible Work

After the worktree read path is accepted, produce an integration findings report. Use that report to choose the next single bmux provenance path to reconnect.
