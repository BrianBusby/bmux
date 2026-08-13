# Provenance Engine Architecture

Provenance Engine is a Swift package that separates public provenance contracts from storage implementation.

This document describes the architecture currently implemented in this repository and the active design boundaries for V1 adoption. The platform north star is `docs/reference-architecture.md`. Implementation sequence and priorities live in `docs/roadmap.md`, and public adopter contracts live in `docs/integration-contract.md`.

## Modules

`ProvenanceEngineContracts` owns DTOs, request/response types, health checks, and the `ProvenanceEngineClient` protocol. External adopters should import this module for stable contract types.

`ProvenanceEngineSDK` owns public client construction. External adopters should create clients through `ProvenanceEngineClientFactory`, not by naming the SQLite repository directly.

`ProvenanceEngineSQLite` owns the in-process SQLite implementation. It is an implementation module for the SDK and tests, not the preferred integration surface.

## Storage Shape

The SQLite backend stores an immutable event ledger and rebuildable current-state projections. Projection reads are bounded by request limits and are ordered by the engine's query implementation.

Current accepted projections include repositories, worktrees, sessions, session relationships, file explanations, current context records, and workspace-display Current State.

## Evidence Model

The ledger stores evidence, not final knowledge. Evidence is immutable factual input: session events, observed repository state, terminal activity, future Git records, future GitHub pull requests, future review comments, and future document records.

`ProvenanceSource` describes how trustworthy the event's claim is: observed, declared, inferred, reconciled, or unattributed. It does not identify the producing system. `ProvenanceEvidenceOrigin` identifies the producing system, such as `codex-session`, `git`, `github-pull-request`, `github-review`, `github-review-comment`, `github-review-thread`, `terminal`, `document`, or `derived`.

`ProvenanceEvidenceScope` identifies the coarse ownership boundary for the event:

- `personal`: private evidence for one engineer or local installation, such as AI sessions, terminal commands, local notes, unpublished branches, worktrees, and generated artifacts.
- `project`: shared evidence for one project or repository family.
- `organization`: shared evidence across an organization.

The V1 storage and query behavior remains personal-session oriented, but accepted event records no longer assume every event is personal. Future ingestion adapters should populate origin and scope explicitly.

## North-Star Boundaries

The long-term platform includes shared repository evidence, a Knowledge Compiler, a Knowledge Store, evidence-aware retrieval, and local or shared service deployment. Those concepts are defined in `docs/reference-architecture.md`.

They are not implemented in V1. This repository currently preserves the event metadata needed to avoid hard-coding all evidence as personal-only, but GitHub ingestion, shared evidence-store deployment, Knowledge Compiler implementation, and retrieval remain frozen until the current bmux adoption gate is complete.

## Dependency Direction

Contracts are the lowest layer. SDK depends on Contracts and SQLite. SQLite depends on Contracts. Consumers should depend on Contracts and SDK, then interact only through `any ProvenanceEngineClient`.

## Expansion Rule

Additional daemon, migration, retrieval, semantic, and observability capabilities are intentionally frozen until external adoption proves the contract from a real bmux path.

GitHub ingestion and Knowledge Compiler implementation are also frozen until after the current V1 adoption milestone. The accepted V1-compatible change is limited to preserving source-origin and scope metadata on events so later shared evidence does not require reworking the core ledger contract.

## Current State

Current State is a first-class V1 subsystem, not a storage-detail synonym for projection tables. It is the canonical deterministic interpretation of accepted engineering evidence for present-tense provenance questions.

The SQLite target implements Current State with rebuildable projection tables, but those tables are not the public contract. The public contract is the bounded domain behavior exposed through worktrees, session trees, file explanations, current context, and workspace display. Producers append evidence; the engine derives Current State; consumers present the returned domain records.

Workspace-display Current State is reduced field by field from accepted evidence.
A missing value in a newer observation preserves the previously known field; it
does not clear state. Fields clear only through explicit clear evidence recorded
on the workspace-display DTO, such as `pull_request`, `tickets`, `branch`,
`current_work_summary`, or `last_submitted_prompt`. The reducer records
field-level metadata so diagnostics can trace displayed values back to their
source event, observed time, source/origin, freshness, and explicit-clear state.
