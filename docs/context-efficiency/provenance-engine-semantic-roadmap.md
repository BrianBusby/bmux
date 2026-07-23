# Provenance Engine Semantic Processing and Agent Context Roadmap

Status: planning integrated on 2026-07-22. This document is canonical for the
standalone Provenance Engine semantic-processing, structured-decision,
project-knowledge, and task-context roadmap. It does not authorize implementation
of those later phases while the standalone storage foundation and first bmux
adoption slice are still active.

Inputs:

- `docs/context-efficiency/adr-001-provenance-engine-extraction.md`
- `docs/context-efficiency/provenance-engine-phase3-plan.md`
- `docs/context-efficiency/provenance-engine-phase4-reconnect-plan.md`
- `docs/context-efficiency/agent-retrieval-knowledge-projection-plan.md`
- `docs/context-efficiency/cross-session-coordination-active-work-awareness.md`
- Current standalone engine schema at
  `/Users/brianbusby/repos/provenance-engine` on branch
  `provenance-session-tree-storage`

## Purpose

Raw provenance is necessary but not sufficient.

The engine must preserve complete evidence while deriving compact,
task-relevant project knowledge that helps future agents understand current
state, avoid repeated investigation, respect settled architectural decisions,
identify relevant prior work, reason from evidence, and consume fewer tokens.

Guiding statement:

> Project knowledge should grow continuously. Agent context should not.

Core principle:

> Preserve everything. Retrieve almost nothing.

The append-only raw event ledger remains complete. Codex and other agents should
not receive the raw provenance firehose. The engine should derive small,
addressable knowledge units and assemble only the evidence relevant to the
current task.

## Product Boundary

The Provenance Engine owns raw provenance events, normalized event
representations, project entities and relationships, structured engineering
decisions, stable project facts, current-state projections, task and session
summaries, evidence links, semantic processing state, task-specific context
retrieval, context-pack generation, active-work indexes, conflict detection,
cross-session query APIs, and semantic processing cost telemetry.

bmux owns observing and forwarding local activity, identifying session,
worktree, repository, and agent relationships it controls, requesting context
for a task, presenting context, decisions, active work, and conflict warnings to
users, and optionally prompting users to confirm important inferred decisions.

Codex is a client and producer of evidence. Codex is not the authoritative store
of project state.

## Provenance Layers

The long-term engine pipeline is:

```text
Raw events
    -> Normalized facts
    -> Entities and relationships
    -> Candidate knowledge
    -> Validated decisions and current-state projections
    -> Task-specific retrieval
    -> Codex context pack
```

Every derived layer must retain references to the evidence from which it was
produced. Higher layers must be rebuildable from lower layers wherever
possible.

## Authority and Evidence Origins

The engine must keep observed activity, orchestrator-declared activity,
agent-declared meaning, and machine-inferred meaning distinct.

Observed activity is mechanically captured fact.

Examples include sessions, turns, tool calls, commands, and commits.

Orchestrator-declared activity is fact recorded because bmux or another
orchestrator performed the action.

Agent-declared meaning is a durable conclusion explicitly stated by an agent.

Machine-inferred meaning is semantic processor output. It requires confidence,
source evidence, processor identity, and processor version.

Future semantic records should support an evidence-origin model with observed,
orchestrator-declared, agent-declared, and inferred cases. Evidence metadata
should include origin, optional numeric confidence, source event IDs, processor
ID, processor version, occurred-at time, and recorded-at time.

The current contracts have `ProvenanceSource` and `ProvenanceConfidence`, but
they are not enough for later semantic processing. `ProvenanceSource.declared`
does not distinguish orchestrator declarations from agent declarations.

## Structured Engineering Decisions

Structured engineering decisions are first-class engine entities. They represent
important choices that affect future work, including architecture, ownership
boundaries, public APIs, storage design, protocol design, migration strategy,
security assumptions, performance tradeoffs, and long-term invariants.

Do not capture trivial implementation choices unless they establish durable
project constraints.

Decision records should include stable ID, project or repository scope, title,
statement, rationale, alternatives, status, affected entities, supersession
links, evidence metadata, and created/updated timestamps.

Decision status values should cover proposed, accepted, rejected, superseded,
deprecated, and unknown.

A decision must be traceable back to sessions, messages, code changes, commits,
or other evidence that supports it.

Stable project facts are separate from decisions. A decision explains why a
choice was made. A project fact describes current state resulting from choices,
for example "the event ledger is append-only" or "the current integration
strategy is in-process Swift SDK first."

## Current-State Projections

Agents usually need current state, not a replay of all project history. The
engine should eventually expose rebuildable projections for repositories,
worktrees, branches, sessions, agents, tasks, commits, artifacts, public APIs,
dependencies, active migrations, current architecture, ownership boundaries,
unresolved risks, deprecated paths, build/test status, accepted decisions,
superseded decisions, and pending decisions.

## Active Work and Cross-Session Coordination

Cross-session coordination is a later engine capability built on normalized
provenance, structured knowledge, semantic processing, and retrieval.

The engine should maintain active session and active task registries that expose
compact current state for live work: repository, branch, worktree, issue,
objective, touched files, packages, subsystem, status, confidence, dependencies,
related tasks, recent decisions, and heartbeat freshness.

These registries should power cross-session queries such as who is working on a
subsystem, whether an issue was already investigated, which sessions touched a
file or package, what changed while the current agent was working, which
decisions affect a file, and whether duplicate or conflicting work exists.

Normal coordination retrieval must return structured evidence, not transcripts:
relevant sessions, inclusion reasons, summaries, decisions, artifacts,
references, confidence, freshness, and omitted counts. Transcript retrieval is
an exceptional audit/debug operation.

Conflict detection belongs in the engine and should cover same file, same
package, same issue, same feature, same worktree, contradictory decisions,
duplicate investigations, and duplicate implementations. bmux decides how to
present those conflicts and must begin with passive, explainable warnings rather
than blocking or automatic intervention.

## Semantic Processing Strategy

Do not send every event to a model.

Deterministic processing owns event parsing, grouping, identity association,
token accounting, projection updates, content hashing, and candidate triggers.

Rule-based processing owns task-boundary and decision-language heuristics.

It also owns API-change and migration-state heuristics.

AI-assisted processing is reserved for interpretation.

Examples include decision extraction, contradiction detection, task summaries,
context-pack generation, and task-specific reranking.

Semantic processing should run at boundaries such as task completion, commit
creation, session completion, session compaction, explicit decision declaration,
major project-state change, detected contradiction, explicit context request, or
manual user request.

## Processing Budget and Telemetry

Default behavior is deterministic processing only.

Escalate to a small model for task-boundary summaries, candidate decisions,
material project-state changes, or ambiguous retrieval ranking.

Escalate to a stronger model only when ambiguity affects architecture,
decisions conflict, a high-impact decision requires synthesis, or the user
explicitly requests deep analysis.

Every semantic model call must record trigger, input evidence IDs, model, input
tokens, output tokens, latency, estimated or actual cost, output record IDs,
whether durable knowledge was produced, and whether output was later accepted,
rejected, or superseded.

This telemetry is required to measure whether semantic processing saves more
tokens than it consumes.

## Context Packs

The engine should expose a task-oriented context API after the semantic model is
proven. Requests should include project/repository/worktree scope, task
description, current files, token budget, and whether raw evidence may be
included.

Responses should be compact, ranked, bounded, and citation-backed. Sections may
include relevant decisions, current project state, relevant prior tasks,
important constraints, affected APIs and components, known risks, rejected
approaches, unresolved questions, and evidence references.

Retrieval should prefer authoritative evidence, current accepted decisions, and
repository/worktree scope. It should exclude superseded facts by default, fit a
strict token budget, preserve source citations, avoid repeated evidence, and
return uncertainty explicitly.

Do not build one permanently growing project summary. Knowledge must remain
granular and composable.

## Confirmation Workflow

Important inferred decisions should support confirmation. A detected decision
candidate can be presented to a user or authorized agent, then accepted, edited,
or rejected.

Confirmation converts an inferred candidate into an accepted or agent-declared
record while retaining the original evidence and inference metadata.

## Privacy and Security

Semantic processing may include source code, prompts, commands, and internal
architecture. The engine design must support local-only processing,
configurable model providers, redaction before external model calls, secret
detection, repository-level processing policy, organization-level retention
rules, access control for decisions and context packs, audit logs for model
processing, and prevention of cross-project knowledge leakage.

Do not assume every repository permits remote semantic processing. Processing
policy must be explicit and configurable.

## Roadmap Placement

These are standalone Provenance Engine product capability phases. They preserve
the current Phase 3 and Phase 4 focus; do not pull these later capabilities into
the storage foundation or first bmux reconnect.

- Phase 3: standalone engine foundation.
- Phase 4: bmux adoption.
- Phase 5: normalized provenance model.
- Phase 6: structured decisions and project knowledge.
- Phase 7: semantic processing.
- Phase 8: agent context retrieval.
- Phase 8.5: active-work indexing, cross-session queries, and conflict
  detection.

Phase 5 exits when the engine can convert raw bmux/Codex activity into
normalized, queryable provenance without AI processing.

Phase 6 exits when decisions and durable facts can be recorded, queried,
superseded, and traced to evidence.

Phase 7 exits when useful semantic knowledge can be derived at task boundaries
without per-event model calls.

Phase 8 exits when a new Codex task can receive a compact, evidence-backed
context pack that reduces rediscovery without loading broad project history.

Phase 8.5 exits when the engine can answer active-work and cross-session
coordination queries with bounded evidence, detect likely overlap/conflicts
passively, and expose enough explanation for bmux to display warnings without
duplicating engine-owned coordination logic.

## Near-Term Compatibility Requirements

No later-phase implementation is required now. The current foundation should
avoid blocking the roadmap by keeping the raw ledger append-only, retaining
source and parent event relationships where available, recording repository,
worktree, session, agent, and task identifiers where available, keeping
projection logic rebuildable, and avoiding schemas that assume all knowledge is
observed fact.

The foundation should also leave room for processor metadata and confidence,
track model and token telemetry for semantic processing, and keep bmux-specific
concepts out of public engine models unless they are external identities or
client metadata.

## Current Schema Risks

The current `provenance_events` table has an append sequence and payload JSON,
which is compatible with later metadata. Event types are open string values,
which is compatible with adding observed, orchestrator, agent-declared, and
inferred categories.

Risks to address before semantic APIs:

- `ProvenanceSource.declared` collapses orchestrator-declared and agent-declared
  authority.
- `ProvenanceConfidence` is categorical; inferred semantic records need numeric
  confidence.
- The ledger has no first-class source-event or parent-event link yet.
- The engine has no processor/model/token/cost telemetry table yet.
- Projection rows with `source` and `confidence` must not be treated as proof
  that a row is observed fact.

Small compatibility change recommended now:

- Add a planning gate before new event producers or public semantic APIs:
  explicitly design evidence origin, source-event links, and processor telemetry.
  No code or migration is needed for this docs-only task because the current
  ledger JSON payload and open event-type model do not block later extension.

## Implementation Guardrail

Do not implement Phases 5 through 8.5 during Phase 3 foundation or first Phase
4 adoption. The next implementation slice should stay focused on the minimum
public in-process SDK product or factory needed by the Phase 4 worktree-list
adapter.
