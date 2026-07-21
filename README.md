# ProvenanceEngine

ProvenanceEngine is the independent local-first provenance product. This repository currently contains only the Phase 3B minimal SwiftPM skeleton.

## Package

- Package: `ProvenanceEngine`
- Initial module: `ProvenanceEngineContracts`
- Language mode: Swift 6
- Scope: Foundation-only health and capability contracts

The first module is intentionally narrow. It does not include bmux imports, AppKit, SwiftUI, SQLite implementation, daemon or IPC transport, launch agents, CLI surfaces, storage migration, retrieval, lifecycle policy, UI, or observability.

New engine-owned data will later default to `~/.local/state/provenance-engine/provenance.sqlite`, but this skeleton does not create, move, or migrate storage.
