# ProvenanceEngine

ProvenanceEngine is the independent local-first provenance product. This repository currently contains the initial contract module and the first internal storage support module.

## Package

- Package: `ProvenanceEngine`
- Public contract module: `ProvenanceEngineContracts`
- Internal storage module: `ProvenanceEngineSQLite`
- Language mode: Swift 6
- Scope: Foundation-only contracts plus engine-owned SQLite connection/statement support

The first public module is intentionally narrow. It does not include bmux imports, AppKit, SwiftUI, daemon or IPC transport, launch agents, CLI surfaces, storage migration, retrieval, lifecycle policy, UI, or observability.

New engine-owned data will later default to `~/.local/state/provenance-engine/provenance.sqlite`, but this package does not move or migrate existing bmux storage.
