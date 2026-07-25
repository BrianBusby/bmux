# Provenance Engine V1 Boundary Review

Status: canonical V1 boundary review as of 2026-07-25.

This review defines the Provenance Engine V1 platform after read-side and write-side SDK validation. It intentionally narrows V1 to the architecture that has been proven by public SDK consumers and producers.

## Executive Summary

Provenance Engine V1 is a local-first evidence platform for engineering activity.

It solves one core problem: independent producers can record observable engineering evidence into an immutable ledger, and independent consumers can retrieve deterministic current provenance context through stable public SDK contracts without depending on bmux or storage internals.

V1 is not the full long-term Provenance Engine knowledge platform. It does not compile knowledge, perform semantic retrieval, ingest organization-wide systems, synchronize across machines, or produce AI-generated engineering conclusions. Those capabilities remain part of the reference architecture, but they are outside the V1 completion boundary.

The validated V1 platform consists of:

- public contract types in `ProvenanceEngineContracts`
- public client construction in `ProvenanceEngineSDK`
- durable immutable event append through `appendEvent(...)`
- normalized lifecycle recording for session relationships
- deterministic current-state projections rebuilt from the event ledger
- public read APIs for worktrees, session trees, file explanations, and current context
- evidence source, origin, scope, and confidence metadata
- an internal SQLite-backed implementation hidden behind the SDK

Current State should be treated as a first-class V1 architecture component. It is not merely a storage optimization. It is the deterministic domain layer that turns immutable evidence into bounded, useful present-tense answers.

## What Provenance Engine V1 Is

Provenance Engine V1 is the reusable local SDK boundary for recording and reading engineering provenance evidence.

It is:

- A Swift package with public `ProvenanceEngineContracts` and `ProvenanceEngineSDK` products.
- A local-first in-process client backed by engine-owned SQLite storage.
- An immutable event ledger for evidence records.
- A deterministic projection system for current-state provenance answers.
- A public write surface for independent producers.
- A public read surface for independent consumers.
- A boundary that prevents producers and consumers from depending on bmux internals, SQLite schemas, projection tables, indexes, or rebuild behavior.

The problem V1 solves:

> Preserve local engineering evidence through a stable public SDK and answer bounded provenance questions from deterministic engine-owned state.

The problem V1 intentionally does not solve:

> Transform evidence into organization-scale knowledge, semantically retrieve historical context, or operate as a distributed authenticated service.

## What Provenance Engine V1 Is Not

V1 is not:

- A Knowledge Compiler.
- A semantic search or retrieval system.
- A cross-machine or organization-wide evidence platform.
- A GitHub ingestion platform.
- A daemon, service, or remote API.
- A synchronization layer.
- An authorization or authentication system.
- A replacement for Git history.
- A product UI.
- A consumer presentation layer.
- A source of AI-generated engineering conclusions.

V1 records and deterministically organizes evidence. It does not create durable interpreted knowledge artifacts.

## Included Capabilities

### Public Platform Surface

| Capability | V1 classification | Rationale |
| --- | --- | --- |
| `ProvenanceEngineContracts` product | Essential | Defines the stable public DTOs, requests, responses, and client protocol. |
| `ProvenanceEngineSDK` product | Essential | Provides the supported public construction path for in-process clients. |
| `ProvenanceEngineClientFactory.sqliteClient(databaseURL:)` | Essential | Enables deterministic local integration tests and explicit adopter-controlled storage. |
| `ProvenanceEngineClientFactory.defaultSQLiteClient(...)` | Essential | Establishes the engine-owned local storage path for real local-first use. |
| `ProvenanceEngineClient.health()` | Essential | Lets adopters verify availability and capability support without storage knowledge. |
| `ProvenanceEngineClient.appendEvent(...)` | Essential | The validated V1 write primitive for immutable evidence capture. |
| `ProvenanceEngineClient.recordSessionLifecycle(...)` | Essential adapter convenience | Public producer-neutral lifecycle recording is included because session lifecycle and session relationships are foundational V1 evidence, but it does not replace `appendEvent(...)` as the primitive. |
| `ProvenanceEngineClient.recordSubsessionLifecycle(...)` | Deprecated compatibility wrapper | Retained only to avoid source breakage for early adopters; new code should use `recordSessionLifecycle(...)`. |
| `ProvenanceEngineClient.worktrees(...)` | Essential | Validated read path for known repository/worktree state. |
| `ProvenanceEngineClient.sessionTree(...)` | Essential | Validated read path for session and session-relationship provenance. |
| `ProvenanceEngineClient.fileExplanation(...)` | Essential | Validated read path for explaining current file-level evidence. |
| `ProvenanceEngineClient.currentContext(...)` | Essential | Validated read path for present-tense worktree/session/file/checkpoint/validation context. |
| String-backed `ProvenanceEventType` | Essential | Allows producers to preserve newer or producer-specific event names without public API churn. |
| `ProvenanceSource`, `ProvenanceConfidence`, `ProvenanceEvidenceOrigin`, `ProvenanceEvidenceScope` | Essential | Distinguish observation quality, producer system, and ownership boundary without hard-coding bmux or personal-only assumptions. |
| Public projection DTOs | Essential | They are the current V1 domain vocabulary for records returned by queries and carried in event payloads. |
| Internal SQLite implementation | Included implementation | Required for V1 local-first operation, but not part of the public integration surface. |
| Projection validation and rebuild internals | Included implementation | Required to prove the event ledger is the system of record; not a public adopter API. |

### Evidence Model

The V1 evidence model is sufficient for the validated local-first platform.

Included V1 evidence concepts:

- repositories
- worktrees
- sessions
- session relationships
- external session identities
- lifecycle transitions
- work items and task assignment
- contributions
- checkpoints
- change sets
- file changes
- validation runs
- source classification
- confidence
- evidence origin
- evidence scope
- forward-compatible event types

Partially included concepts:

- Commands: represented by event type plus validation-run or empty payload evidence. V1 does not define a dedicated command projection.
- Artifacts: represented by event type and event metadata. V1 does not define a dedicated artifact payload or query surface.
- Explicit decisions: representable as event types or declared payload metadata, but V1 does not define a decision record, decision query, or compiled decision artifact.

Foundational gaps for V1: none that block the platform boundary.

The partial concepts are not blockers because V1's core mission is evidence capture plus deterministic current state, not durable knowledge compilation. Dedicated command, artifact, and decision records should be added only when a validated producer/consumer path needs structured query semantics for them.

### Query Surface

The current public read APIs are sufficient for V1:

- `worktrees(...)` answers what worktrees the engine knows about.
- `sessionTree(...)` answers how sessions relate.
- `fileExplanation(...)` answers why the engine believes a file has current provenance evidence.
- `currentContext(...)` answers what is active or recently relevant in a worktree now.

No additional public query is foundational for V1.

Deferred query ideas such as command history, artifact lookup, decision search, historical rename lookup, full activity timelines, semantic search, or organization-wide context are legitimate future capabilities, but they are not required to declare the V1 platform complete.

### Write Surface

The V1 write platform is complete with:

- `appendEvent(...)`
- `recordSessionLifecycle(...)`
- `ProvenanceEvent`
- `ProvenanceEventPayload`
- source, confidence, origin, and scope metadata
- forward-compatible event types

`appendEvent(...)` remains the public primitive. Producer-oriented helpers may be useful later, but they should be convenience APIs unless new evidence shows that the primitive itself is wrong.


### Local Durability Contract

V1 includes an engine durability guarantee for accepted local writes:

> When `appendEvent(...)` or `recordSessionLifecycle(...)` returns success, the event has been committed to the local ledger and can survive ordinary process termination.

The current SQLite implementation inserts the ledger event and applies Current State projection updates inside one transaction. Success is returned only after `COMMIT` succeeds. If persistence or projection work fails, the transaction is rolled back and the producer receives an error or an unaccepted lifecycle response; the event is not partially accepted.

Duplicate event identifiers are rejected by the ledger uniqueness constraint. Producers may use stable event IDs for idempotency, but a duplicate submission is a failure signal rather than a second success.

V1 does not guarantee producer delivery before acceptance. If a producer observes an event and crashes before calling the SDK, or calls the SDK but never receives an acknowledgement, retry/outbox behavior remains producer-owned or integration-owned.

### Current State

Deterministic Current State is officially part of V1.

It owns:

- active session interpretation
- current worktree state
- current work contribution links
- dirty and unattributed file evidence
- recent checkpoints
- validation run ordering
- potential active contribution conflicts
- linked context for file explanations and current-context responses

Current State is first-class because it is the engine-owned meaning layer for present-tense provenance. It is derived from immutable evidence, rebuildable from the ledger, and exposed through stable read APIs. Consumers should not reconstruct it from storage tables or raw events.

## Deferred Capabilities

| Capability | Deferred because |
| --- | --- |
| Knowledge Compiler | Produces interpreted knowledge artifacts, which is beyond V1 evidence and deterministic current state. |
| Semantic retrieval | Requires compiled knowledge, ranking, citation, and context budgeting that are outside the validated SDK boundary. |
| Knowledge Store | Stores regenerated interpretation, not raw evidence or current-state projections. |
| Organization-wide evidence store | Requires shared deployment, authorization, tenancy, retention, and sync semantics. |
| GitHub organization ingestion | Requires external API sync, auth, rate-limit handling, incremental import, and organization evidence policy. |
| Remote daemon or service API | Requires process lifecycle, IPC or network transport, compatibility policy, and operational reliability. |
| Cross-machine synchronization | Requires identity, conflict resolution, replication, and authorization semantics. |
| Distributed storage | Requires deployment and consistency choices that are unrelated to local V1 validation. |
| Authentication and authorization | Required for shared platforms, not local in-process V1. |
| AI-generated engineering knowledge | Belongs to the Knowledge Compiler and must preserve evidence citations. |
| Rename-aware historical identity | Requires deeper Git/filesystem history semantics than V1 path identity. |
| Advanced ranking | Belongs to retrieval and search, not deterministic V1 current state. |
| Search optimization | Not needed for the bounded V1 query surface. |
| Producer delivery retry/outbox reliability | Important production hardening, but separate from the V1 engine guarantee that successful SDK writes are durable. |
| Dedicated command, artifact, and decision projections | Useful when real query requirements appear; not foundational to V1 completion. |
| Consumer UI and presentation policy | Consumers own rendering, defaults, fallbacks, and product-specific interaction. |

## Architectural Principles

These principles are canonical for V1:

- Evidence is immutable.
- The event ledger is the system of record.
- Accepted SDK writes are durably committed before success is returned.
- Current-state projections are rebuildable and disposable.
- Producers emit observable or declared facts.
- The engine owns deterministic interpretation.
- Consumers own presentation.
- Public APIs expose provenance concepts, not storage concepts.
- Public contracts must remain implementation-independent.
- Bounded queries are part of the contract shape.
- Stable domain identifiers are producer responsibilities.
- Event types are forward-compatible strings to avoid premature public API expansion.
- Knowledge must not replace evidence.
- New public APIs require real producer or consumer evidence, not speculation.

Additional V1 principle:

> Current State is the canonical deterministic interpretation of engineering evidence.

That means Current State belongs in the engine architecture even though the specific projection tables remain implementation details.

## Remaining Risks

No known risk blocks declaring the V1 platform architecture complete.

Material risks to track after V1:

- Producer ergonomics: payload construction is verbose, and new teams will need recipes for common event shapes.
- Stable-ID discipline: producers must generate and reuse consistent identifiers across related evidence.
- Partial command/artifact/decision structure: V1 can record these as events, but structured query semantics are deferred.
- Local-only operation: V1 does not answer shared-team or organization deployment questions.
- Producer delivery reliability: V1 guarantees durable storage after accepted SDK writes, not eventual delivery for events that a producer observes but fails to submit or never receives acknowledgement for.
- Path identity: V1 file explanation uses exact stored worktree/path identity and does not solve rename-aware history.

These are not V1 architecture blockers because they do not undermine the validated boundary: independent producers and consumers can use the public SDK without implementation knowledge.

## Recommended Definition Of V1 Complete

V1 Complete should be evaluated against objective platform boundaries, not against future knowledge-platform ambitions.

Provenance Engine V1 is complete when:

- the public contracts and SDK expose only implementation-independent provenance concepts;
- independent read consumers use `worktrees`, `sessionTree`, `fileExplanation`, and `currentContext` without reading storage internals;
- independent write producers record evidence through `appendEvent(...)` or normalized lifecycle recording without bmux or SQLite knowledge;
- the event ledger remains the system of record;
- deterministic current-state projections can be rebuilt from the event ledger with identical public query results;
- V1 evidence source, confidence, origin, and scope metadata are available to producers;
- the canonical V1 boundary is documented and future Knowledge Compiler, retrieval, organization-store, daemon, sync, and ingestion work is explicitly deferred.

> Provenance Engine V1 is complete when independent producers can durably record local observable or declared engineering evidence through a producer-neutral public SDK, and independent consumers can retrieve bounded deterministic Current State through public read APIs, with immutable evidence as the system of record and without depending on bmux, storage internals, or post-V1 knowledge-platform components.
