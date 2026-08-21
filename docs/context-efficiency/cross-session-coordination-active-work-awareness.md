# Cross-Session Coordination and Active Work Awareness

Status: planning integrated on 2026-07-22. This document records the
architecture target for cross-session coordination in the standalone Provenance
Engine and bmux. It does not authorize implementation while the standalone
engine foundation, first bmux adoption slice, normalized provenance, structured
knowledge, semantic processing, and retrieval prerequisites remain incomplete.

Related plans:

- `docs/context-efficiency/provenance-engine-semantic-roadmap.md`
- `docs/context-efficiency/agent-retrieval-knowledge-projection-plan.md`
- `docs/context-efficiency/provenance-observability-integration-plan.md`

## Mission

Enable independent AI agents to coordinate through structured project knowledge
instead of shared chat transcripts.

The system should let an agent understand what related agents are doing, what
they already did, why important decisions were made, whether duplicate or
conflicting work exists, and which evidence matters for the current task without
loading another session's full conversation.

Guiding principle:

> Project knowledge should grow continuously. Agent context should not.

## Ownership Boundary

The Provenance Engine owns shared project knowledge. It should remain
repository-agnostic and should expose coordination through general APIs, not
through bmux-specific concepts.

Engine-owned capabilities include:

- session registry
- task registry
- event ledger
- decision graph
- artifact graph
- derived knowledge
- retrieval engine
- active work index
- conflict detection
- cross-session queries

bmux owns developer experience and orchestration. It launches sessions, records
lifecycle events, sends heartbeats, streams provenance events, asks the engine
for relevant context, injects only bounded context into prompts, displays active
work, and warns about possible conflicts.

bmux must remain a client of the engine. Coordination logic belongs in the
engine; presentation and workflow choices belong in bmux.

## Coordination Pipeline

The long-term pipeline is:

```text
bmux launches or observes sessions
    -> lifecycle and work events are appended
    -> engine updates registries and projections
    -> engine derives knowledge and active-work indexes
    -> engine answers task-specific coordination queries
    -> bmux presents compact evidence or prompt context
```

The engine is the shared memory layer. bmux is the orchestration layer.

Normal Coding-Agent Evidence Ingestion is now a data-foundation prerequisite for
validating this target with real bmux/Codex usage. Agent Chat can produce
high-fidelity structured evidence today, but cross-session awareness should not
depend on that UI path. Historical and live normal-terminal Codex transcript
ingestion should give the engine representative prompts, turns, commands, plans,
file attribution, and source provenance before coordination and retrieval quality
are judged.

## Session Lifecycle Events

Every session should eventually produce structured lifecycle and work events:

- session started
- task created or associated
- heartbeat
- command observed
- file modified
- artifact produced
- research performed
- decision recorded
- task completed
- session closed

These events should update both historical knowledge and the active-work index.

## Active Session Registry

The active session registry should expose compact current state for each live
session:

- session identifier
- status
- repository
- branch
- worktree
- current task
- objective summary
- confidence
- last heartbeat
- related sessions

The registry enables discovery and conflict checks without transcript
inspection.

## Active Work Model

Each active task should expose structured metadata:

- repository
- branch
- issue or external work item
- worktree
- touched files
- packages
- subsystem
- objectives
- current status
- confidence
- dependencies
- related tasks
- recent decisions

This metadata must be searchable and evidence-linked. Agent-declared or inferred
metadata must not be treated as observed fact.

## Cross-Session Queries

Future engine APIs should answer coordination questions such as:

- who is working on a subsystem
- whether someone already investigated an issue
- which sessions modified a package or file
- what decisions affected a file
- what changed while the current session was working
- which sessions are related to a task
- what a completed session discovered
- whether another session is already implementing a feature
- which architectural decision explains an implementation
- which artifact should be read first

These answers should return structured evidence, not transcripts, by default.

## Retrieval Policy

Agents should not receive another session's transcript by default. The engine
should return bounded, ranked, source-linked evidence:

- relevant sessions and why they matched
- compact summaries
- decisions
- artifacts
- references
- supporting evidence
- confidence and freshness
- omitted counts

Transcript retrieval is an exceptional debugging or audit operation, not the
normal coordination path.

## Context Assembly

When bmux prepares a prompt for a new agent, it should:

1. identify the task, repository, worktree, branch, files, and user objective;
2. ask the Provenance Engine for relevant active and historical knowledge;
3. rank evidence by task relevance, authority, freshness, and confidence;
4. build a compact context package with explicit inclusion reasons;
5. launch the agent with only the bounded context needed for that task.

No global project dump should be injected.

## Conflict Detection

The engine should detect likely overlap and conflict across active and recent
work. Initial conflict classes include:

- same file
- same package
- same issue or external task
- same feature or subsystem
- same worktree
- contradictory architectural decisions
- duplicate investigations
- duplicate implementations

The engine owns detection and evidence. bmux owns how the conflict is surfaced,
whether to warn, and which user action to offer.

Conflict detection must begin as passive and explainable. It must not block
work, mutate prompts, reassign tasks, or stop sessions automatically.

## Derived Knowledge

The raw event ledger is not the primary agent-facing product. The preferred
retrieval source should be derived, evidence-linked knowledge:

- implementation summaries
- architectural evolution
- decision histories
- subsystem ownership
- common debugging paths
- recurring failure patterns
- implementation timelines
- task relationships
- active-work snapshots

Derived knowledge is rebuildable and never replaces raw evidence.

## Historical Awareness

Completed sessions remain searchable through the same structured knowledge
model. Future agents should be able to find prior investigations, historical
implementations, superseded approaches, abandoned experiments, and architectural
evolution without replaying old conversations.

## Roadmap Placement

Cross-session coordination depends on earlier standalone-engine capabilities:

```text
Reliable lifecycle capture
-> normalized provenance
-> task and session identity
-> normal coding-agent evidence ingestion
-> structured decisions and project facts
-> semantic processing and knowledge projection
-> retrieval and context packages
-> active work index and conflict detection
-> bmux coordination UI and prompt assembly
```

The normal-ingestion dependency does not invalidate completed downstream
implementation history, such as factual projection, semantic inference, or
human-readable semantic messaging. It does materially affect how useful those
systems are in practice because ordinary terminal sessions must supply
representative evidence before cross-session and retrieval experiments can be
trusted.

Do not implement active-work coordination before retrieval quality is validated.
The first implementation gate is an architecture investigation that inspects
current session lifecycle capture, task identity, heartbeat sources, file-change
capture, worktree identity, conflict surfaces, and existing bmux UI options.

## Future Scope

The same architecture should eventually scale beyond one repository to
multi-repository and organization-wide coordination. That requires access
control, retention policy, privacy boundaries, dependency awareness, and
organization-scoped decision graphs, but it does not require bmux-specific
engine concepts.

## Guardrails

- Sessions remain independent; they coordinate through structured knowledge.
- Retrieval is selective and answers a specific question.
- Knowledge growth must improve targeting, not prompt size.
- Facts, declarations, and inferences remain distinct.
- bmux stays lightweight and does not duplicate engine-owned knowledge models.
- Conflict detection starts in passive, explainable mode.
- Large transcript loading remains exceptional.
