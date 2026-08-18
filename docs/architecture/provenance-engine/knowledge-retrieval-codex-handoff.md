# Codex Handoff: Evidence-Aware Knowledge Retrieval

Status: future implementation handoff; do not start until Project Truth selects this slice and durable Knowledge Compiler output exists to retrieve.

## Read First

Before making changes, inspect the current repository rather than assuming this handoff still matches implementation details. At minimum read:

1. `AGENTS.md`
2. root Project Truth state and generated roadmap/status docs
3. `docs/architecture/provenance-engine/README.md`
4. `docs/architecture/provenance-engine/knowledge-retrieval.md`
5. current Provenance Engine package docs and public contracts
6. current Knowledge Compiler / durable knowledge contracts and storage implementation
7. current bmux PE client integration and coding-session context model

If Project Truth or newer architecture decisions conflict with this handoff, stop and reconcile the docs rather than creating a parallel architecture.

## Objective

Implement the smallest useful vertical slice of evidence-aware durable-knowledge retrieval from Provenance Engine for bmux/coding-agent consumption.

The slice should prove that bmux can supply concrete current-task context and receive a small, relevant, evidence-backed PE knowledge packet without bmux understanding PE storage or traversing PE's graph itself.

## Required Architectural Boundary

PE owns:

- canonical durable knowledge;
- typed knowledge relationships;
- validity/revision and supersession state;
- retrieval planning and candidate generation;
- ranking;
- provenance/explanation;
- bounded knowledge packet construction.

bmux owns:

- current repository/worktree/session/task context;
- presentation and coding-agent integration;
- choosing when to request PE context.

Do not move semantic or retrieval authority into bmux.

## Retrieval Direction

Prefer retrieval signals in this order:

1. exact structural matches;
2. typed graph/architecture relationships;
3. lexical matches;
4. vector/semantic similarity when useful.

Do not implement embeddings-first generic RAG as the primary retrieval path.

Use the concrete context bmux already knows — repository, worktree, session, task, milestone/activity, files, symbols, and architecture entities when available — to narrow candidates before fuzzy search.

## Expected Shape of the First Slice

Fit this into the current PE public-contract and SDK conventions rather than copying these names literally.

The vertical slice should establish:

- one PE-owned task-context retrieval request/response contract;
- one implementation path that resolves structurally relevant durable knowledge;
- typed/rebuildable lookup projections or indexes sufficient for the selected access path;
- deterministic exclusion or strong demotion of superseded knowledge;
- a bounded response suitable for coding-agent context;
- provenance identifiers that allow a separate explanation/detail request;
- bmux integration through PE public contracts/SDK only;
- tests proving the boundary and ranking behavior.

Start with the smallest structural retrieval path that real compiled knowledge supports. File/component/entity retrieval is preferable to speculative breadth if that is where the compiler has reliable relationships.

## Materialized Index Principle

Do not recursively traverse the raw evidence ledger for every interactive query.

Add only the derived/materialized lookup structures required for this slice. They must be rebuildable from canonical PE knowledge/evidence and must not become an independent source of truth.

Do not prematurely implement every possible index listed in the architecture note.

## Context Budget

The retrieval response must be bounded. Do not return an entire graph neighborhood merely because it is related.

Use the current project conventions for limits if they exist. Otherwise introduce the smallest explicit budget contract necessary for the slice and document why it is sufficient.

Keep full provenance/evidence out of the normal hot response when identifiers can support a separate explanation path.

## Performance

This is an interactive bmux path. Avoid LLM inference on the normal retrieval hot path unless the selected Knowledge Compiler architecture explicitly requires it and Project Truth has accepted that tradeoff.

Prefer indexed local operations. Measure the vertical slice with a representative local fixture and record latency rather than making unverified performance claims.

Session-scoped caching is allowed only if measurements justify it. Caching is an optimization, not authoritative state.

## Non-Goals

Do not, in this first slice:

- introduce Neo4j or another network graph database without measured need;
- expose PE SQLite/storage types to bmux;
- teach bmux PE graph traversal semantics;
- make embeddings the canonical knowledge model;
- build a general-purpose search language;
- implement every planned relationship depth or ranking signal;
- solve shared/multi-user knowledge retrieval;
- solve mobile/remote retrieval unless Project Truth has explicitly moved that work forward;
- rewrite the Knowledge Compiler merely to make retrieval convenient without first documenting the contract problem.

## Validation / Acceptance

The slice is complete only when tests demonstrate that:

1. a bmux-like caller can provide current task context through PE's public contract;
2. exact structural context retrieves the expected durable knowledge without requiring prompt-text similarity;
3. typed relationships can add a directly relevant neighboring knowledge item for the chosen vertical slice;
4. unrelated knowledge is excluded or ranks below structurally relevant knowledge;
5. superseded knowledge does not displace its current replacement;
6. results obey the configured context/result budget;
7. returned items retain enough provenance identity for later explanation;
8. derived retrieval indexes/projections can be rebuilt from canonical PE state;
9. bmux does not import or depend on PE storage implementation types;
10. repository Project Truth and architecture docs are reconciled with the delivered behavior.

## Delivery Discipline

Keep the PR narrowly scoped. If real compiled knowledge reveals that the proposed retrieval model is wrong, update the architecture note and Project Truth explicitly rather than silently widening the implementation.

Record measured behavior and rejected alternatives in the PR/handoff so the next agent can distinguish validated design from assumptions.
