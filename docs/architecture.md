# Provenance Engine Architecture

Provenance Engine is a Swift package that separates public provenance contracts from storage implementation.

## Modules

`ProvenanceEngineContracts` owns DTOs, request/response types, health checks, and the `ProvenanceEngineClient` protocol. External adopters should import this module for stable contract types.

`ProvenanceEngineSDK` owns public client construction. External adopters should create clients through `ProvenanceEngineClientFactory`, not by naming the SQLite repository directly.

`ProvenanceEngineSQLite` owns the in-process SQLite implementation. It is an implementation module for the SDK and tests, not the preferred integration surface.

## Storage Shape

The SQLite backend stores an immutable event ledger and rebuildable current-state projections. Projection reads are bounded by request limits and are ordered by the engine's query implementation.

Current accepted projections include repositories, worktrees, sessions, session relationships, file explanations, and current context records.

## Dependency Direction

Contracts are the lowest layer. SDK depends on Contracts and SQLite. SQLite depends on Contracts. Consumers should depend on Contracts and SDK, then interact only through `any ProvenanceEngineClient`.

## Expansion Rule

Additional daemon, migration, retrieval, semantic, and observability capabilities are intentionally frozen until external adoption proves the contract from a real bmux path.
