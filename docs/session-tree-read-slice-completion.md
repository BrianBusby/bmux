# Session-Tree Read Slice Completion

Branch: `slice-c-session-tree-read-contract`

Acceptance: accepted on 2026-07-24 after bmux consumer adoption and final validation.

This document preserves the Slice Completion Architecture Review for the engine-owned portion of the bmux session-tree read migration.

## Implementation Summary

Confirmed during implementation that Slice C was the active coordinated milestone from `docs/roadmap.md`, `docs/current-status.md`, and `docs/bmux-integration-roadmap.md`. The engine-side work preserved the existing public `ProvenanceEngineClient.sessionTree(...)` contract, documented it in `docs/integration-contract.md`, and added SDK-level compatibility coverage proving an adopter can create a client through `ProvenanceEngineClientFactory`, seed through public `appendEvent` calls, and read a session tree without importing or querying SQLite internals.

No new storage, daemon, retrieval, semantic, GitHub ingestion, Knowledge Compiler, UI, capture, or bmux-specific behavior was introduced.

bmux adoption confirmed the contract was sufficient. The only integration
finding was limit semantics: `ProvenanceSessionTreeRequest.limit` is a combined
engine row budget across sessions and relationships, while bmux's legacy CLI
behavior is a session-oriented presentation cap. bmux adapts that at its CLI
boundary. The engine keeps returned relationships coherent with returned
sessions and returns external identities for included sessions.

## Architecture Review

### 1. Architecture Validation

The slice validated the Reference Architecture rather than changing it. It reinforced the current V1 boundary: Provenance Engine owns reusable contracts and private storage-backed projections, while bmux owns command behavior, rendering, fallback policy, and migration rollout.

### 2. Public API Review

No new public API was required. The existing `ProvenanceEngineClient.sessionTree(ProvenanceSessionTreeRequest(rootSessionID:limit:))` surface is sufficient for the current consumer path. The API did not feel awkward for the read migration because it returns domain records and leaves presentation compatibility to bmux.

### 3. Encapsulation Review

The work did not leak storage details. The new compatibility test uses `ProvenanceEngineClientFactory`, `appendEvent`, and `sessionTree`; the integration contract explicitly prohibits consumers from reading session-tree SQLite tables directly.

### 4. Reference Architecture Review

No Reference Architecture change is recommended from this slice. The learning is implementation and integration-contract evidence: the current architecture supports this read migration without expanding into future retrieval, compiler, or shared evidence capabilities.

### 5. Consumer Capability

bmux can now rely on documented, SDK-tested session-tree reads through the public engine client. It can migrate `bmux provenance sessions tree <session-id>` away from bmux-local SQL while preserving its own CLI output behavior.

### 6. Technical Debt

No code debt was intentionally introduced. The remaining debt is migration sequencing debt in bmux: the legacy session-tree adapter and local query helpers should remain only until the bmux command is migrated and accepted.

### 7. Future Opportunities

The session-tree path may later help validate lifecycle-write adoption because the same relationship and external-identity projections are read here. That is an opportunity only; lifecycle writes remain a later roadmap item.

### 8. Overall Architectural Confidence

Architecture validated.

The current public SDK boundary handled the next adopter read path without requiring new API surface or internal storage exposure.

## ADR Recommendation

No ADR is recommended from this slice. If future capture or lifecycle slices repeatedly raise ownership ambiguity between bmux capture policy and engine persistence behavior, elevate that into an ADR rather than repeating it in slice reviews.
