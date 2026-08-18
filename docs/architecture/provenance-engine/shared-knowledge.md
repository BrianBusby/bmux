# Shared Provenance Engine Knowledge Architecture

Status: future architecture horizon; implementation should follow successful local Knowledge Compiler and evidence-aware retrieval validation.

## Goal

Allow multiple engineers to contribute selected Provenance Engine-derived knowledge and normalized observations to a shared organizational store, then retrieve and compare that shared understanding without replacing the richer private local PE store.

The shared layer should make team knowledge cumulative while preserving local-first operation, explicit visibility boundaries, and evidence/provenance.

## Local-First Boundary

Each engineer keeps a local PE as the primary private evidence and inference store.

The shared service is additive:

```text
Engineer A local PE --\
Engineer B local PE ----> Shared PE service
Engineer C local PE --/          |
                                +-- shared durable knowledge
                                +-- shared architecture understanding
                                +-- team patterns / conventions
                                +-- normalized aggregate observations
                                +-- cross-engineer comparison signals
```

The shared store must not require raw coding-agent transcripts, prompts, reasoning summaries, commands, source snippets, or other sensitive session material to be centralized by default.

## Publish Boundary

Sharing should happen through an explicit derivation/policy boundary:

```text
LOCAL PE
raw evidence + private semantic state
        |
        | Knowledge Compiler + sharing policy
        v
SHARED PE
approved derived knowledge
architecture / contracts / decisions
patterns and conventions
normalized aggregate observations
selected evidence references
```

The default direction is to publish durable derived knowledge and normalized observations, not raw session exhaust.

Future visibility scopes may include:

- private;
- repository team;
- organization.

Visibility may also vary by knowledge kind. The exact policy model is deferred, but visibility must be first-class and enforced server-side.

## Canonical Shared Store

For the first shared implementation, prefer PostgreSQL/Aurora-compatible relational storage as the canonical shared store.

The PE knowledge model is expected to contain typed entities, typed relationships, revisions, evidence references, users, repositories, components, sessions, and milestones. A relational database gives flexibility while those query patterns are still evolving.

Logical tables may eventually include concepts such as:

```text
organizations
users
repositories

knowledge
knowledge_revisions
knowledge_relationships

entities
entity_relationships
knowledge_entities

evidence
knowledge_evidence

sessions
milestones
observations
```

These names are illustrative, not a frozen schema.

Do not introduce a graph database merely because knowledge has graph relationships. Typed edge tables and materialized relational indexes should remain the default until measured requirements demonstrate otherwise.

## Shared Provenance

Every shared knowledge object should preserve enough origin information to explain why it exists and where it came from without exposing unnecessary private session content.

Useful provenance dimensions include:

- organization;
- repository;
- contributing user or pseudonymous contributor identity when appropriate;
- source local PE/compiler revision;
- source session/milestone identifiers where policy permits;
- evidence references safe for the selected visibility scope;
- knowledge revision and supersession state.

Shared knowledge must remain revisioned and supersedable rather than accumulating forever as immutable AI-generated memory.

## Retrieval Model

Local and shared knowledge should be merged during retrieval rather than forcing bmux to choose one store.

```text
Current task
    |
    v
PE retrieval
    |
 +-- local/private knowledge
 +-- shared repository/org knowledge
    |
    v
merge + rank
    |
    v
bounded context packet
```

Local PE knowledge should normally receive a relevance advantage when it reflects the current engineer's immediate work context. Shared knowledge adds broader team evidence; it should not automatically override local knowledge merely because it is centralized.

Conflicts between local and shared knowledge should be surfaced through revision, confidence, provenance, and contradiction/supersession semantics rather than silently resolved by source precedence alone.

## Team Comparison and Aggregate Observations

The shared service may also accept normalized derived observations suitable for aggregation, for example:

```text
task_type: bug_fix
component: session-state
duration_bucket / duration
approach_changes
blocker_duration
files_touched
test_iterations
```

These normalized records can support team-level questions such as:

- common blockers in a component;
- typical task duration by task/component class;
- repeated approach-change patterns;
- components that generate unusually high debugging or validation churn;
- whether a current session is behaving unusually compared with similar historical work.

This capability should be designed to improve engineering assistance, not individual surveillance. Prefer aggregate/team comparisons and privacy-preserving views over employee ranking or raw activity inspection.

## Potential AWS Shape

A first AWS deployment may remain intentionally simple:

```text
bmux / local PE
      |
    HTTPS
      |
API Gateway or small authenticated service
      |
Lambda / containerized PE shared service
      |
Aurora PostgreSQL
```

Authentication should integrate with the organization's identity system where possible. The exact AWS products are implementation choices rather than architectural requirements.

If fuzzy semantic retrieval later proves useful, a search/vector system such as OpenSearch may be added as a derived index. It must not become the canonical shared knowledge store.

## Sync Direction

Initial synchronization should be explicit and narrow:

1. local PE compiles or updates durable knowledge;
2. local sharing policy determines eligible records/fields;
3. client publishes revisioned shared records through a PE-owned service contract;
4. shared service validates organization/repository/visibility scope;
5. shared store records revisions and provenance;
6. local retrieval may query shared knowledge and merge it with private local candidates.

Do not begin with bidirectional replication of the entire local SQLite database.

## Sequencing

Recommended project sequence:

```text
local factual evidence
  -> local semantic inference / SessionWorkModel
  -> milestone + blocker + code + architecture relationships
  -> local durable Knowledge Compiler
  -> local evidence-aware retrieval
  -> local context-effectiveness validation
  -> shared evidence/knowledge contract spike
  -> shared multi-user knowledge store
  -> merged local + shared retrieval
  -> team aggregate/comparison intelligence
```

The cloud layer should follow proof that local compiled knowledge is useful and retrievable. Otherwise the project risks scaling the wrong information model.

## Non-Goals / Guardrails

Do not:

- replace local PE with a mandatory network dependency;
- upload raw prompts, transcripts, reasoning, source snippets, commands, or secrets by default;
- replicate the entire local PE database into AWS;
- let the shared service become the sole authority for an engineer's private current session state;
- centralize data without first-class visibility and repository/organization access controls;
- build employee productivity scoring as a primary product objective;
- introduce OpenSearch/vector search as the canonical knowledge model;
- build the cloud synchronization layer before local Knowledge Compiler and retrieval behavior have been validated.

## Future Validation Questions

Before broad rollout, validate:

- which durable knowledge kinds engineers actually want to share;
- what evidence can be retained while respecting repository and company privacy constraints;
- how local and shared conflicting claims should rank and be explained;
- whether shared architecture/contract knowledge measurably improves coding-agent performance;
- what aggregate observations are useful without becoming invasive;
- what latency and availability characteristics are required for retrieval without weakening local-first behavior;
- how organization/repository membership changes revoke future access and handle already-cached knowledge;
- whether pseudonymous or aggregate comparison data is sufficient for most team insights.
