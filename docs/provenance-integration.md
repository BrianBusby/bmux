# bmux Provenance Integration

This document records bmux's reference integration with the finalized Provenance Engine V1 public contract.

The cross-repository roadmap remains in provenance-engine:

https://github.com/BrianBusby/provenance-engine/blob/main/docs/bmux-integration-roadmap.md

The Provenance Engine integration contract remains the technical authority for public APIs:

https://github.com/BrianBusby/provenance-engine/blob/main/docs/integration-contract.md

## Public SDK Boundary

bmux imports only the public engine products for adopted provenance paths:

```swift
import ProvenanceEngineContracts
import ProvenanceEngineSDK
```

Client construction happens through the public SDK factory:

```swift
let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
    try ProvenanceEngineClientFactory().sqliteClient(databaseURL: databaseURL)
```

The SQLite-backed factory is an SDK construction detail. bmux code must not import engine implementation targets, instantiate engine SQLite types directly, or read engine projection tables from adopted read/write paths.

## Current State Reads

bmux treats Provenance Engine Current State as authoritative present-tense provenance.

Adopted CLI reads:

- `bmux provenance worktrees list` calls `client.worktrees(...)`.
- `bmux provenance sessions tree <session-id>` calls `client.sessionTree(...)`.
- `bmux provenance explain <path>` calls `client.fileExplanation(...)`.
- `bmux provenance context current` calls `client.currentContext(...)`.

bmux still owns command parsing, Git path normalization, output compatibility, fallback text, JSON/text rendering, and UI presentation. The engine owns evidence, deterministic Current State, provenance interpretation, and bounded provenance queries.

## Producer Writes

bmux records observable activity through public engine writes:

- Agent lifecycle changes are normalized into `ProvenanceSessionLifecycleRequest` and sent through `client.recordSessionLifecycle(...)`.
- Git/worktree observations are normalized into immutable `ProvenanceEvent` values and sent through `client.appendEvent(...)`.

bmux producer responsibilities are limited to observing engineering activity, assigning stable producer identities when available, recording observable or declared facts, and retaining best-effort error state for diagnostics. bmux must not compute deterministic Current State or reinterpret evidence already owned by the engine.

## Remaining Local Code

Some bmux-local storage and observability files remain for historical compatibility tests and lifecycle trace presentation. They are not the adopted runtime source of truth for Current State reads or lifecycle writes.

Do not add new provenance consumer behavior to `WorkProvenanceStore`, `BmuxLegacyProvenanceClient`, or direct SQLite readers. New consumer behavior must use `ProvenanceEngineContracts` and `ProvenanceEngineSDK`.

## Reference Integration Checklist

Future producers should follow bmux's adopted pattern:

1. Import `ProvenanceEngineContracts` and `ProvenanceEngineSDK`.
2. Create a `ProvenanceEngineClient` through `ProvenanceEngineClientFactory`.
3. Record lifecycle with `recordSessionLifecycle(...)`.
4. Record immutable evidence with `appendEvent(...)`.
5. Read present-tense provenance through Current State APIs.
6. Keep presentation and workflow policy in the consumer.
7. Keep evidence interpretation and deterministic state in the engine.
