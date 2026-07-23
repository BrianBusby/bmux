# Provenance Engine Architecture

Provenance Engine is a Swift package that separates public provenance contracts from storage implementation.

## Modules

`ProvenanceEngineContracts` owns DTOs, request/response types, health checks, and the `ProvenanceEngineClient` protocol. External adopters should import this module for stable contract types.

`ProvenanceEngineSDK` owns public client construction. External adopters should create clients through `ProvenanceEngineClientFactory`, not by naming the SQLite repository directly.

`ProvenanceEngineSQLite` owns the in-process SQLite implementation. It is an implementation module for the SDK and tests, not the preferred integration surface.

## Storage Shape

The SQLite backend stores an immutable event ledger and rebuildable current-state projections. Projection reads are bounded by request limits and are ordered by the engine's query implementation.

Current accepted projections include repositories, worktrees, sessions, session relationships, file explanations, and current context records.

## Evidence Model

The ledger stores evidence, not final knowledge. Evidence is immutable factual input: session events, observed repository state, terminal activity, future Git records, future GitHub pull requests, future review comments, and future document records.

`ProvenanceSource` describes how trustworthy the event's claim is: observed, declared, inferred, reconciled, or unattributed. It does not identify the producing system. `ProvenanceEvidenceOrigin` identifies the producing system, such as `codex-session`, `git`, `github-pull-request`, `github-review`, `github-review-comment`, `github-review-thread`, `terminal`, `document`, or `derived`.

`ProvenanceEvidenceScope` identifies the coarse ownership boundary for the event:

- `personal`: private evidence for one engineer or local installation, such as AI sessions, terminal commands, local notes, unpublished branches, worktrees, and generated artifacts.
- `project`: shared evidence for one project or repository family.
- `organization`: shared evidence across an organization.

The V1 storage and query behavior remains personal-session oriented, but accepted event records no longer assume every event is personal. Future ingestion adapters should populate origin and scope explicitly.

## Knowledge Layers

The long-term system has three layers:

- Personal evidence: private engineer-local evidence that remains local until intentionally shared.
- Shared repository evidence: organization-owned repository facts such as commits, pull requests, reviews, changed files, changed symbols, merge history, release tags, and branch relationships.
- Derived knowledge: versioned interpretation artifacts compiled from evidence, such as architecture summaries, migration summaries, decision summaries, ownership summaries, constraints, and PR decision summaries.

Evidence is immutable. Derived knowledge is reproducible interpretation and must reference the evidence that supports it. Compiler improvements create newer artifact versions instead of rewriting evidence.

## Shared Repository Evidence

Repository history is shared organizational evidence and should not be independently ingested and summarized by every engineer. The long-term architecture is:

```text
GitHub
    -> Organization Ingestion
    -> Shared Evidence Store
    -> Knowledge Compiler
    -> Knowledge Artifacts
    -> Retrieval
```

The purpose is to avoid duplicated storage, duplicated AI summarization, duplicated indexing, and inconsistent interpretations. V1 must not implement GitHub ingestion before the current bmux adoption gate completes.

## Knowledge Compiler

The Knowledge Compiler is a planned post-V1 subsystem. It consumes immutable evidence and produces versioned knowledge artifacts for retrieval. Initial artifact candidates include:

- Pull Request Decision Summary
- Architecture Summary
- Migration Summary
- Decision Summary
- Ownership Summary
- Constraint Summary

The first compiler target should be `Pull Request Decision Summary`, with intent, accepted constraints, rejected alternatives, important review findings, deferred work, final outcome, and supporting evidence references. It should be evaluated for retrieval usefulness before broader compiler work begins.

## Retrieval Philosophy

Retrieval should prefer compiled knowledge plus minimal supporting evidence. Agents should almost never receive thousands of commits, full PR discussions, or complete review threads by default.

Example retrieval shape:

```text
Authentication middleware intentionally avoids request-specific assumptions.

Evidence:
- PR #417
- Review Thread #8821
- Commit abc123
```

This preserves the core principle that project knowledge can grow continuously while agent context stays bounded.

## Dependency Direction

Contracts are the lowest layer. SDK depends on Contracts and SQLite. SQLite depends on Contracts. Consumers should depend on Contracts and SDK, then interact only through `any ProvenanceEngineClient`.

## Expansion Rule

Additional daemon, migration, retrieval, semantic, and observability capabilities are intentionally frozen until external adoption proves the contract from a real bmux path.

GitHub ingestion and Knowledge Compiler implementation are also frozen until after the current V1 adoption milestone. The accepted V1-compatible change is limited to preserving source-origin and scope metadata on events so later shared evidence does not require reworking the core ledger contract.
