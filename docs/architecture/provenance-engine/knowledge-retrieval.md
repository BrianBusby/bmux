# Provenance Engine Knowledge Retrieval Architecture

Status: design intent; implementation deferred until durable compiled knowledge exists.

This document records the intended retrieval architecture for durable Provenance Engine knowledge. It is deliberately more stable than an implementation plan: it defines ownership, retrieval order, and architectural constraints without freezing a database schema, ranking formula, cache strategy, or public API before the Knowledge Compiler output model has been validated.

## Goal

Provenance Engine should accumulate durable project knowledge without requiring coding agents to accumulate equivalent context. bmux should be able to ask PE for the smallest currently relevant, evidence-backed knowledge packet for the work being performed now.

The target property is **knowledge growth without context growth**.

## Architectural Boundary

bmux must not traverse, interpret, or rank PE's knowledge graph itself.

bmux owns current coding-session context and presentation. PE owns durable knowledge, knowledge relationships, retrieval planning, ranking, provenance, validity/revision state, and bounded context assembly.

The normal interaction should therefore be task-oriented:

```text
bmux current task/session context
        |
        v
PE retrieval contract
        |
        v
candidate generation + ranking
        |
        v
bounded knowledge packet
        |
        v
bmux / coding agent
```

The exact public API is intentionally not fixed yet. Conceptually, bmux should eventually be able to ask for context for a task/session and PE should perform the retrieval plan internally rather than exposing storage or graph traversal mechanics.

## Knowledge Organization

Durable knowledge should remain structured and evidence-backed rather than becoming a collection of unstructured session summaries.

Useful dimensions include:

- scope: repository, component/subsystem, feature, workflow, file, symbol, or cross-repository concern;
- kind: architecture, behavior, contract/API, decision, invariant/constraint, convention/pattern, or operational knowledge;
- relationships: typed links such as `depends_on`, `implements`, `consumes`, `supersedes`, `affects`, `derived_from`, or `contradicts`;
- provenance: supporting sessions, milestones, commits, files, symbols, semantic records, or other evidence;
- validity/revision: when a claim became supported, whether it remains current, what supersedes it, and enough revision identity to rebuild it deterministically.

Vector embeddings may index this knowledge, but embeddings must not become the canonical knowledge model.

## Retrieval Order

PE should prefer deterministic structural evidence before fuzzy similarity.

The intended ordering is:

1. exact structural matches;
2. typed graph relationships / architecture proximity;
3. lexical matches;
4. vector/semantic similarity.

For example, if bmux knows the current repository, worktree, session, milestone, files, and symbols, those identifiers should be used to narrow retrieval before broad semantic search is attempted.

This is a deliberate rejection of embeddings-first generic RAG as the primary retrieval architecture.

## Materialized Retrieval Projections

Normal retrieval should not recursively walk the raw evidence graph.

PE should eventually maintain rebuildable retrieval projections/indexes optimized for common access paths, potentially including knowledge by entity, file, symbol, component, repository, kind, and typed relationship neighborhood.

These indexes are derived acceleration structures, not a second source of truth. The canonical evidence and durable knowledge records remain authoritative and must be sufficient to rebuild them.

The exact physical schema is deferred.

## Task Context from bmux

bmux has an important retrieval advantage: it already knows what the coding agent is doing now.

When available, a task-oriented PE request should carry stable context such as:

- repository identity;
- worktree identity;
- coding-agent session identity;
- current task/prompt;
- inferred current milestone or activity;
- changed/open/relevant files;
- relevant symbols or architectural entities.

PE can use this context to resolve exact entities and graph neighborhoods before fuzzy search.

This context is retrieval input. It does not transfer semantic authority to bmux.

## Candidate Ranking

Ranking should occur after structural candidate generation whenever possible.

The future ranking model may combine signals such as exact entity match, file/symbol proximity, architecture proximity, relationship strength, semantic similarity, recency, confidence, validity, and supersession state.

No numeric formula is canonical yet. Real compiled knowledge and observed retrieval behavior should inform that choice.

## Session Locality and Caching

Coding sessions usually operate within a relatively small neighborhood for meaningful periods of time. PE should be free to exploit this locality with session-scoped caches or incrementally maintained candidate sets.

Caching must remain an optimization. It must not create authoritative semantic state outside PE's revisioned models or make retrieval results impossible to reproduce after invalidation.

## Retrieval vs. Context Assembly

Retrieval and agent-context construction should remain conceptually distinct.

PE may identify more relevant knowledge than should be inserted into an agent context window. A context assembler should select and compress a bounded subset according to task relevance and a caller-provided or policy-derived budget.

The normal consumer result should therefore be a compact knowledge packet, not an entire graph neighborhood.

When a consumer needs justification, PE should expose provenance/explanation separately rather than always injecting full evidence into the primary context response.

## Storage Direction

Start local and embedded. The current PE package and SQLite-backed architecture are sufficient for initial validation.

Do not introduce a network graph database such as Neo4j merely because the logical model contains graph relationships. Typed relational edges plus targeted indexes/materialized projections are the preferred starting point unless measured requirements demonstrate otherwise.

The storage design must preserve PE's package boundary and future extractability.

## Sequencing with Semantic Inference and the Knowledge Compiler

This retrieval architecture should influence the shape of Knowledge Compiler outputs, but the full retrieval implementation should not precede useful durable compiled knowledge.

Recommended sequence:

```text
factual evidence
  -> factual session projection
  -> semantic SessionWorkModel
  -> milestones / blockers / approach changes
  -> milestone-to-code relationships
  -> scoped architecture relationships
  -> durable Knowledge Compiler output
  -> evidence-aware knowledge retrieval
  -> bounded agent context assembly
```

The compiler should produce knowledge that is typed, scoped, revisioned, related, and traceable enough for structural retrieval. Retrieval implementation details should then be validated against real compiled knowledge rather than hypothetical examples.

## Non-Goals / Guardrails

Do not:

- make bmux a graph-query client that understands PE's storage schema;
- make bmux independently rank or infer canonical project knowledge;
- make vector search the canonical knowledge representation;
- copy all historical session summaries into coding-agent context;
- require traversal of the raw evidence ledger on every interactive request;
- introduce a distributed/network graph store before local performance requires one;
- freeze the exact retrieval DTOs, ranking weights, or physical index schema before the Knowledge Compiler vertical slice provides real data.

## Future Validation Questions

When implementation begins, validate at least:

- whether exact file/symbol/component lookup produces a sufficiently small candidate set;
- which relationship depths are useful without introducing irrelevant graph expansion;
- how often semantic/vector search materially improves structurally generated candidates;
- what knowledge packet sizes improve agent performance without creating context bloat;
- whether session-local caches materially improve latency;
- how superseded or contradicted knowledge should be ranked and explained;
- whether retrieval can be rebuilt deterministically from canonical PE state.

These are implementation experiments, not reasons to weaken the architectural ownership boundary above.
