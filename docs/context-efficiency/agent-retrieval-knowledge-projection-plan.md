# Bmux Provenance: Agent Retrieval and Knowledge Projection Integration

Status: planning integrated on 2026-07-18 and updated on 2026-07-19 with provenance observability requirements. This plan extends the subsession/delegation provenance roadmap. It does not replace `WorkProvenance`, `BmuxContextEfficiency`, raw evidence storage, the append-only event ledger, or the future observability trace store.

2026-07-22 update: the standalone engine semantic roadmap in
`docs/context-efficiency/provenance-engine-semantic-roadmap.md` is canonical for
long-term ownership of normalized provenance, structured decisions, project
facts, semantic processing, and task-context packs. This document remains useful
for bmux-era retrieval tactics, evaluation criteria, and sequencing details.

2026-07-22 coordination update:
`docs/context-efficiency/cross-session-coordination-active-work-awareness.md`
extends the later retrieval roadmap with active session/task registries,
cross-session queries, and passive conflict detection. Those capabilities depend
on validated retrieval and context-package quality; they should not create a
parallel bmux-owned coordination store.

## Purpose

Add an agent-oriented retrieval and knowledge-projection layer so a current or future agent can retrieve the smallest reliable body of context needed to continue work safely.

The target architecture remains:

```text
Raw evidence
-> immutable provenance events
-> authoritative projections
-> derived knowledge projections
-> bounded agent context packages
```

The retrieval layer must be derived, rebuildable, evidence-linked, freshness-aware, repository-scoped, raw-payload-safe, and optimized for bounded agent consumption.

The same retrieval discipline applies to active work awareness: agents receive
structured evidence about related active or historical sessions, not chat
transcripts, unless a user explicitly asks for audit/debug-level detail.

Retrieval must also be observable. A future retrieval result should explain why records were selected or omitted, which versions produced ranking and token budgeting, which evidence supports each selected record, and whether supplied context was later used, corrected, or contradicted. Detailed requirements live in `docs/context-efficiency/provenance-observability-integration-plan.md`.

## Context Assembly Principle

Project knowledge should grow continuously, but agent context should not. Bmux should organize knowledge hierarchically and retrieve only the minimum evidence and design context necessary for the current task. Context is assembled dynamically rather than being statically defined, and each item included in an agent session needs a justifiable reason for being present.

This principle should shape the retrieval architecture in four ways:

- Provenance should store durable facts, decisions, findings, relationships, and source references without trying to preload the whole project history into every future session.
- Knowledge projections should be indexes and navigational aids over evidence, not replacements for evidence or duplicated copies of raw artifacts.
- Retrieval and context-package generation should prefer facts over summaries, evidence over assumptions, references over duplication, and retrieval over preloading.
- Future project organization should make durable knowledge easy to address hierarchically by repository, worktree, subsystem, file, work item, session, decision, and evidence reference.

Increasing project knowledge should improve agent effectiveness through better targeting and evidence selection, not through larger default working contexts.

## Layer Boundaries

Bmux should distinguish four layers:

1. Evidence layer: source events and raw/recoverable artifacts such as Codex rollouts, terminal output, tool calls, command output, Git observations, diffs, validation output, commits, prompts, child reports, and token telemetry. Raw evidence remains recoverable but outside frequently queried SQLite rows.
2. Provenance layer: authoritative semantic facts and relationships owned by `WorkProvenance`, including repositories, worktrees, sessions, work items, contributions, delegations, checkpoints, change sets, file changes, validations, commits, integration decisions, source, confidence, and lifecycle status.
3. Knowledge projection layer: compact query-oriented summaries derived from evidence and provenance, such as session summaries, delegation summaries, work-item summaries, file histories, subsystem summaries, decisions, findings, failed approaches, invariants, open questions, validation summaries, and handoff summaries.
4. Context assembly layer: bounded packages for a specific agent objective, assembled dynamically from exact entity resolution, structured facts, lexical search, optional semantic search, provenance edges, ranking, token budgeting, omitted counts, inclusion reasons, and source references.

Knowledge projections are not source of truth. They must carry generator/schema versions, content hashes, evidence references, freshness, and supersession metadata.

## Roadmap Placement

Update the context-efficiency roadmap sequence to include retrieval after semantic provenance is established:

```text
Milestone 3: Command, reference, and subsession lifecycle attribution
Milestone 4: Efficiency profiler
Milestone 5: Project progress, delegation, and semantic provenance
Milestone 5.5: Agent retrieval and knowledge projection
Milestone 6: Coordination UI
Milestone 7: Shadow lifecycle engine
Milestone 8: Assisted handoffs and context packages
```

Do not delay the initial subsession lifecycle implementation. The intended dependency order is:

```text
Reliable lifecycle capture
-> session and delegation identity
-> semantic work records
-> retrieval projections
-> bounded context-package generation
-> coordination UI
-> lifecycle recommendations
-> assisted orchestration
```

## Store Ownership

`WorkProvenance` owns sessions, delegations, work items, contributions, files, validations, commits, decisions, findings, relationships, knowledge projections, context-package manifests, source, and confidence.

`BmuxContextEfficiency` continues to own imported read-only facts: Codex threads, model calls, token telemetry, tool calls, tool outputs, rollout source references, parser errors, command execution candidates, and work-item reference candidates.

`ProvenanceObservability` will own operational and quality telemetry about provenance processing and retrieval: projection runs, derivations, invalidations, retrieval runs, retrieval candidates, ranking explanations, feedback, evaluation results, and shadow comparisons. It is not the source of truth for engineering work.

Do not duplicate all context-efficiency rows inside `WorkProvenance`. Link through stable external identities and evidence references.

Raw output storage remains external. Knowledge records may contain compact summaries, hashes, stable references, and small structured facts, but not complete transcripts, tool outputs, diffs, or rollout payloads.

## Scope

Implement in this initiative:

- semantic entities required for useful retrieval
- typed provenance relationships
- materialized knowledge records
- full-text indexing
- freshness and supersession
- bounded context-package generation
- retrieval query API
- retrieval evaluation fixtures
- CLI access
- rebuild and invalidation support

Do not implement yet:

- autonomous agent orchestration
- automatic delegation decisions
- automatic prompt injection
- automatic session handoff
- adaptive policy learning
- enterprise or organization-wide cloud search
- mandatory vector database
- graph database migration
- model-generated truth without evidence
- broad UI work before retrieval quality is validated

## Semantic Provenance Entities

Add these incrementally after lifecycle and delegation identity are proven.

- Decisions: scoped records for accepted, rejected, proposed, superseded, or
  withdrawn decisions, with rationale, source, confidence, evidence, and
  supersession metadata.
- Findings: scoped records for discoveries, constraints, invariants, risks,
  failed approaches, open questions, assumptions, and recommendations.
- Artifacts: compact records for generated plans, reports, patches, diagrams, and child reports.
- Commits: first-class records before commit-oriented retrieval.

## Provenance Edges

Add typed edge projections when retrieval needs richer traversal than existing foreign keys. Initial relationships include parent/child, delegated-to, contributes-to, produced, inspected, changed, validated-by, supports, contradicts, depends-on, derived-from, implements, supersedes, accepted, rejected, references, followed-by, and related-to.

Edges must preserve source and confidence, support validity intervals, prevent exact duplicate active edges, support indexed forward and reverse traversal, and remain rebuildable where possible. Do not migrate every existing foreign key into an edge immediately.

## Knowledge Records

Introduce materialized knowledge records optimized for retrieval. Each record carries kind, repository/worktree/branch/revision scope, work-item/contribution/session/delegation/entity scope, title, body, keywords, evidence references, related entity references, generator ID/version, source projection version, confidence, freshness, validity interval, supersession, content hash, and timestamps.

Initial kinds: repository summary, subsystem summary, work-item summary, contribution summary, session summary, delegation summary, file history, decision summary, finding summary, validation summary, commit summary, and handoff summary.

Initial freshness states: fresh, possibly stale, stale, superseded, and unknown.

Knowledge records must never override provenance facts. Every material statement must be supported by evidence references.

## Projection, Search, And Context Packages

Create a knowledge projection service separate from event ingestion. It should rebuild repositories or individual entities, invalidate impacted records with a reason, maintain stable content hashes, avoid duplicate records, and keep FTS rows consistent.

Use SQLite FTS5 for the first retrieval index over selected knowledge fields such as title, body, keywords, repository identifier, branch, and entity type. Retrieval must work without embeddings.

The retrieval pipeline should resolve exact entities, read authoritative records, search knowledge records, optionally retrieve semantic matches, expand selected edges, add active decisions/invariants/risks/open questions, remove duplicates, filter stale or superseded records unless requested, rank deterministically, allocate an explicit token budget, assemble a context package, and include omitted counts plus source references. It should also record why each included item was selected, because context without a task-specific reason is preloading by another name.

Context packages are bounded agent-facing results. Each item includes a title, compact body, kind, entity reference, confidence, freshness, relationship to the query, inclusion reason, source references, and estimated token count.

## CLI

Future read-only commands may include:

- `bmux provenance context --repo /path/to/repo --question "..." --file <path> --token-budget 8000 --json`
- `bmux provenance knowledge rebuild --repository <id>`
- `bmux provenance knowledge search "<query>" --repository <id>`
- `bmux provenance decision list --repository <id>`
- `bmux provenance finding list --kind failed-approach`
- `bmux provenance edges show <entity-type> <entity-id>`

All JSON must be bounded, versioned, raw-payload-safe, explicit about confidence/freshness/omissions, and explicit about whether semantic search was available.

## Subsession And Delegation Integration

Subsessions and delegations are major retrieval scopes. Future child input context packages should include objective-specific context, relevant files, accepted decisions, active invariants, failed approaches, open questions, validation requirements, and path restrictions.

Parent acceptance, partial acceptance, or rejection must update semantic records, supersede obsolete recommendations when appropriate, invalidate impacted knowledge, and cause future context packages to prefer accepted results. A child report does not automatically become accepted knowledge.

## Evaluation

Create deterministic retrieval fixtures before semantic ranking or automated context injection. Initial scenarios should cover continuing implementation, avoiding a failed approach, modifying a core file, researching prior subsession identifiers, and resolving a superseded decision.

Metrics include required-record recall, misleading-record rate, stale-record rate, superseded-record leakage, token-budget compliance, source-reference coverage, determinism, and latency. Do not optimize primarily for subjective summary quality.

Retrieval observability must preserve coverage and correctness as separate measurements. A broad candidate set, high selected-record count, or high attribution rate is not by itself a quality improvement.

## Migration Sequence

Do not add every concept in one migration. Recommended order: R1 decisions/findings/edges, R2 knowledge records plus FTS, and R3 optional context package manifests/projection state. Follow current `WorkProvenance` migration and replay conventions.

## Implementation Phases

- R0 investigation: inspect current stores, migration patterns, retrieval capabilities, FTS support, schemas, invalidation design, roadmap insertion points, first migration, and first fixture.
- R1 semantic records: implement decisions, findings, events, projections, queries, and tests.
- R2 provenance edges: implement edge table, typed relationships, traversal queries, and tests.
- R3 knowledge projection: implement deterministic rule-based summaries.
- R4 FTS retrieval: implement lexical search, filters, ranking, and fixtures.
- R5 context packages: implement graph expansion, token budgeting, output, CLI, and metrics.
- R6 subsession integration: wire child context, invalidation, projection, and parent disposition.
- R7 optional semantic search: add only after lexical and structured retrieval are evaluated.
- R8 UI and assisted handoff: expose previews and editable packages; no automatic injection yet.

Observability should overlap these phases: projection lineage with R3, retrieval traces and candidate omission reasons with R4/R5, feedback and correction with R6, evaluation harness before ranking changes, shadow comparison before algorithm promotion, and consumption/outcome traces with assisted handoffs.

## Acceptance Criteria

Retrieval is ready for broader use when decisions and findings are first-class, failed approaches/invariants/open questions are queryable, every semantic record links to evidence, typed edges are queryable, knowledge records are rebuildable and freshness-aware, retrieval works without embeddings, superseded records are excluded by default, accepted decisions are prioritized, context packages obey token budgets and expose omissions/source references, child reports do not automatically become accepted truth, parent disposition changes future retrieval, complete transcripts are not loaded during normal retrieval, retrieval remains repository-scoped, existing tests remain green, CLI output is bounded and raw-payload-safe, and no automatic orchestration or handoff occurs.

## Codex Working Instructions

Before retrieval implementation, inspect the existing provenance and subsession implementation and return the Phase R0 architecture report. The first retrieval implementation slice is `DecisionRecord`, `FindingRecord`, supporting events/projections, basic queries, and migration tests. Do not begin with embeddings, context-package generation, or UI.

Use subsessions only for bounded investigation or review tasks such as schema/migration review, FTS investigation, retrieval fixture design, provenance-edge design review, privacy review, or test-matrix review. The parent session remains responsible for architectural consistency, duplicate-concept avoidance, migration sequencing, final acceptance decisions, and documentation updates.
