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
  health, workspace/coding-agent session association, factual projection,
  semantic record, semantic message, SessionWorkModel, and related-session
  awareness contracts.
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
bmux Session/Smart Session -> workspace display metadata as authoritative session identity
```

## Workspace/Session Association

The durable workspace-to-coding-agent-session association belongs to Provenance
Engine. bmux observes Codex hook, transcript, sidecar, lifecycle, display, and
replay evidence, but PE owns the canonical association record and the readiness
state that tells consumers whether the session is unavailable, pending,
failed, or available.

The intended path is:

```text
Codex evidence
-> identity reconciliation
-> durable PE workspace/session association
-> factual projection
-> Session/Smart Session consumers
```

Display metadata such as `lastSubmittedPromptSessionID` may still describe a
workspace row, but it must not be the only bridge from a workspace to a PE
coding-agent session. Native Session, React Smart Session, and later
cross-session consumers should read through PE public contracts so replay and
projection rebuilds reproduce the same identity relationship.

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
