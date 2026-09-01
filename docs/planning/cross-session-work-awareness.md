# Cross-Session Work Awareness

Status: implemented related-session foundation, artifact-collision awareness,
rich carried work-state semantics, and agent-accessible retrieval plus planning
context. Generated Project Truth is authoritative for dependency readiness,
selected-next work, and active implementation:

- [Nested roadmap](../generated/nested-roadmap.md)
- [Project status](../generated/project-status.md)
- [Ownership boundary](../generated/ownership-boundary.md)

This document records the intended capability so future agents do not need an
external handoff to reconstruct the sequence. It is not implementation
authorization.

## Purpose

Cross-session work awareness lets a coding-agent session discover bounded,
evidence-backed information about other related active or recent sessions. The
goal is to reduce duplicate investigation, missed decisions, repeated failed
approaches, validation churn, and parallel-work collisions without sharing raw
conversations or injecting historical context blindly.

A related-session result should eventually answer:

- which sessions are related to the current session;
- why each relationship exists;
- what durable work state is relevant;
- which repository, branch, worktree, ticket, milestone, or artifact is linked;
- what changed, what was validated, and what remains blocked or unresolved;
- what provenance supports those claims.

The foundation slice implements the first PE-owned read model for this purpose.
`ProvenanceEngineClient.relatedSessions(...)` accepts a target PE session id,
bounded result and omission limits, an optional recent-time boundary, and an
optional historical revision id. The read returns deterministic
`ProvenanceRelatedSessionBrief` values with exact Session Outcome revision ids,
compact Session Outcome facts, freshness metadata, relationship reasons,
supporting evidence or projection references, and explicit
availability/completeness states.

Implemented v1 relationship reasons are same repository, same worktree, same
branch, session-tree ancestor, session-tree descendant, session-tree sibling,
shared provider thread, shared external identity, and shared changed artifact
path when a shared repository or worktree context is also established. Returned
briefs are ordered by strongest relationship reason, then freshness, then
stable PE session id. Omitted related sessions can be reported with
`result_limit` or `outside_recent_boundary` explanations within the configured
omission bound.

This foundation intentionally does not add bmux UI, automatic context assembly,
agent coordination, proactive notifications, raw transcript sharing, hidden
reasoning storage, LLM-authored cross-session summaries, Knowledge Compiler
integration, or organization-scale storage. The rich work-state semantic slice
now carries existing PE milestone, blocker, and approach-change records through
related-session briefs, but it does not create new semantic inference, unify
cross-session identities, or infer decision/risk/architecture relationships.
Artifact-collision awareness is implemented separately as an inspectable
factual PE read and still does not warn, block, coordinate, inject context, or
judge semantic conflict.
Agent-accessible retrieval exposes both reads through the existing bmux
`provenance` CLI namespace for explicit, bounded agent queries without adding a
sidecar, MCP server, prompt injection, or automatic coordination policy.

## Ownership

Provenance Engine owns the canonical relationship and read model:

- related-session identities and relationship reasons;
- deterministic derivation from durable evidence;
- bounded `RelatedSessionBrief`-style public contracts;
- factual versus semantic provenance;
- freshness, revision, ordering, and bounding rules;
- reusable read models for retrieval and later Knowledge Compiler inputs.

bmux owns product integration:

- provider/runtime identity acquisition;
- live session orchestration and presentation;
- explicit calls into PE public APIs;
- notification or UI surfaces;
- any later prompt/context assembly policy.

bmux must not build a second semantic engine over raw provider output. If a
relationship or brief field requires semantic meaning, that meaning comes from
PE-owned semantic inference records or PE-owned projections.

## Epistemic Boundaries

Cross-session briefs must preserve the authority of each statement:

- Observed facts: accepted evidence and deterministic Current State, such as a
  session operating in a worktree or modifying a repository-relative path.
- Explicit statements or plans: provider/user/agent statements recorded as
  evidence, such as a plan update naming files or a task.
- Semantic inference: PE-owned inference records, such as thread intent,
  current activity, milestone identity, blocker state, or approach changes.

Presentation wording and semantic messages are not canonical truth inputs.
Whole transcripts, hidden reasoning, raw streaming deltas, and unrestricted
command output are not cross-session awareness records.

## Relationship Derivation

The foundation slice should start with deterministic relationship reasons that
existing evidence can support. Examples include explicit parent/child session
relationships, same repository, same worktree, same branch, and overlapping
recorded file-change paths.

Richer reasons remain downstream until their source models are validated:
milestone identity, blockers, approach changes, scoped architecture, planned
file overlap, validation state, and component/module relationships.

Relationship reasons should be individually inspectable. If ranking is added,
it must be deterministic and explainable rather than an opaque relevance score.

## Implemented Foundation Details

The read model is built from accepted PE state and projections:

```text
accepted evidence
  -> deterministic session/repository/worktree/session-tree state
  -> TurnOutcome
  -> SessionOutcome
  -> SessionWorkModel semantic fields, if already present
  -> relatedSessions(...)
```

Facts, explicit plan evidence, and semantic inference remain separate:

- Relationship reasons come only from observed deterministic facts or existing
  factual projections.
- Explicit plans, commands, validations, blockers, unresolved items, changed
  artifacts, and resume points come through bounded Session Outcome facts.
- Existing SessionWorkModel thread intent, turn intent, current activity,
  milestones, blockers, approach changes, and session phase fields are carried
  only with their semantic provenance, confidence, specificity, producer,
  inference version, source revisions, source-session scope, evidence basis,
  and supported bounded payload. They are not relationship reasons.

SQLite schema 23 stores related-session content revisions and latest pointers.
Projection metadata records the rule id/version, request fingerprint, content
fingerprint, source evidence watermark, result limits, optional recent-time
boundary, generated time, and revision id. Content revisions change when public
relationship content changes; duplicate or overlapping evidence that changes
only supporting references can update freshness or watermarks without creating
a new content revision.

Known limitations:

- Provider-thread and external-identity reasons appear only when current
  accepted evidence preserves shareable identities for both sessions.
- Shared changed artifact is only same normalized changed path within shared
  repository/worktree context; it is not rename, diff-hunk, semantic component,
  or collision analysis.
- The bmux CLI retrieval boundary requires an explicit PE session id. It does
  not infer identity from focus, provider thread id, workspace id, surface id,
  or the first matching session.

Artifact-collision awareness now adds `artifactCollisions(...)` above the
related-session foundation. It detects exact normalized path overlaps within
shared repository identity, records repository/worktree/branch/HEAD and
temporal boundaries, returns per-session participation and evidence references,
classifies current, historical, stale, or incomplete evidence states, and
preserves the language boundary that a possible collision is not a proven
semantic conflict. Stable rename identity remains unsupported until accepted
evidence can establish it deterministically.

Rich cross-session work-state semantics now carries existing milestone,
blocker, and approach-change records into related-session briefs with explicit
unknown, unavailable, partial, stale, and bounded-omission semantics.
Agent-accessible cross-session retrieval adds `bmux provenance sessions related`
and `bmux provenance sessions collisions` as CLI consumers of those public PE
reads. The collision command preserves the PE limitation that path filtering
only narrows overlaps for target-session changed artifacts; it is not arbitrary
file-history search.

## Sequence

Project Truth models the capability as these slices:

1. Cross-session work awareness foundation: implemented PE public read model
   and deterministic related-session briefs.
2. Rich cross-session work-state semantics: validated milestone, blocker,
   approach-change, validation, and activity semantics in briefs.
3. Artifact and change collision awareness: implemented detection and
   explanation of exact-path overlapping work, not automatic blocking.
4. Agent-accessible cross-session retrieval: implemented explicit bounded agent
   queries through the provenance CLI.
5. Proactive bmux cross-session awareness: presentation or notifications for
   especially relevant changes.
6. Cross-session context assembly experiment: measured, bounded automatic
   context assembly only after retrieval proves useful.
7. Knowledge Compiler cross-session bridge: promotion of stable outcomes into
   long-lived knowledge after the compiler exists.

Only the generated roadmap may move a slice from planned to selected-next or
current.

## Non-Goals

Cross-session awareness does not initially implement:

- automatic prompt or context injection;
- coordination policy, file locks, merge blocking, interruption, or reassignment;
- agent-to-agent messaging;
- whole-transcript sharing;
- unrestricted summarization of raw session history;
- speculative milestone, blocker, or architecture inference;
- durable organization-wide knowledge.

The first implementation slice is read-only awareness. It answers what related
work exists and why; it does not decide what another agent should do.

## Working Memory Versus Knowledge

Cross-session awareness is nearby project working memory for active or recent
work. The Knowledge Compiler is later durable engineering knowledge.

```text
session evidence
  -> factual session projection
  -> SessionWorkModel
  -> cross-session relationships and briefs
  -> short- and medium-lived project awareness

many validated outcomes
  -> Knowledge Compiler
  -> durable engineering knowledge
  -> evidence-aware retrieval
  -> future sessions
```

Not every transient session statement should become durable knowledge.
