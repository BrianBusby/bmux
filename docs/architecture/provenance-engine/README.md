# Provenance Engine Boundary

Provenance Engine is an independent Swift package inside the bmux monorepo.
The monorepo removes Git coordination overhead; it does not remove the
architectural boundary.

## Package Location

```text
Packages/macOS/ProvenanceEngine/
  Package.swift
  Sources/ProvenanceEngineContracts/
  Sources/ProvenanceEngineSDK/
  Sources/ProvenanceEngineSQLite/
  Tests/
  docs/
```

The package currently targets macOS and is grouped under `Packages/macOS` to
match bmux workspace/package policy. If PE becomes shared across platforms or
external consumers later, move it through the documented package-group workflow.

## Public Products

- `ProvenanceEngineContracts`: DTOs, request/response types, public protocol,
  health, factual projection, semantic record, semantic message, SessionWorkModel,
  and related-session awareness contracts.
- `ProvenanceEngineSDK`: public client construction through
  `ProvenanceEngineClientFactory`.

`ProvenanceEngineSQLite` is an internal implementation target, not a public
library product for bmux integration.

## Dependency Direction

Allowed:

```text
bmux -> ProvenanceEngineContracts
bmux -> ProvenanceEngineSDK
ProvenanceEngineSDK -> ProvenanceEngineSQLite -> ProvenanceEngineContracts
```

Forbidden:

```text
ProvenanceEngine -> bmux app/runtime/UI internals
bmux production integration -> ProvenanceEngineSQLite implementation types
React Session UI -> raw semantic inference from provider events
bmux presentation -> separate cross-session semantic model over provider output
```

## Future Independence

Keep PE extractable by preserving:

- standalone `Package.swift` and package tests,
- package-local docs for PE public API and storage architecture,
- no imports from bmux sources,
- public contracts that do not encode bmux UI concepts,
- component release metadata under root Project Truth,
- migration ledger and ADR documenting where history came from.

Future options include independent semantic versioning, mirroring the package to
a public repository, publishing package products, or extracting the package back
to a standalone repository.
