# SessionWorkModel Target Design

Status: accepted target direction. The lower-level richer-session evidence
foundation and first factual public session-projection read contract are
implemented; semantic `SessionWorkModel` inference, milestone synthesis, and
architecture projection are not implemented.

This document defines the planned high-level Provenance Engine projection for
live coding-agent work. It records product and architecture direction for the
next richer-session milestone without treating the implemented factual Current
State projection as the semantic model.

## Name

The chosen planning name is `SessionWorkModel`.

Rationale:

- It is domain-oriented and belongs to Provenance Engine, not to bmux
  presentation.
- It scopes the projection to one coding-agent session while allowing thread,
  turn, worktree, and project context inside that session.
- It avoids the ambiguity of a global `WorkModel`, which could imply repository
  or organization-wide work state.
- It avoids `SessionPresentationModel`, which would make a reusable engine
  contract sound like a bmux UI shape.

The planning name is reserved for the later semantic projection. The
implemented factual substrate intentionally uses the
`ProvenanceFactualSessionProjection*` prefix and
`ProvenanceEngineClient.factualSessionProjection(...)` so consumers can depend
on deterministic Current State without assuming intent, milestone, activity,
risk, or architecture meaning exists.

## Existing Contracts Stay Useful

`SessionWorkModel` does not replace the existing V1 read contracts:

- `currentContext(...)`
- `sessionTree(...)`
- `fileExplanation(...)`
- `workspaceDisplay(...)`
- `factualSessionProjection(...)`

Those remain lower-level domain and diagnostic contracts. The future semantic
projection is a coherent consumer view assembled by Provenance Engine so
sophisticated clients do not have to orchestrate many small queries and then
perform semantic merging locally.

## Epistemic Layers

The model must preserve the basis of every derived field. These layers stay
separate even if the public response combines them for convenience.

1. Observable evidence: directly emitted or observed facts, such as session,
   thread, turn, command, approval, file-change, validation, plan, and lifecycle
   records.
2. Deterministic Current State: rebuildable state derived mechanically from
   accepted evidence. It must not contain model-generated milestone meaning,
   intent, or architecture conclusions.
3. Inference and semantic synthesis: rule-derived or model-derived
   interpretations backed by evidence, such as thread intent, turn intent,
   milestone hierarchy, current activity, blockers, and scoped architecture
   projections.
4. Compiled knowledge: durable higher-level knowledge that may outlive the
   live session, such as implementation outcomes, accepted decisions, and
   reusable architecture constraints.

`SessionWorkModel` may include fields from layers 2 and 3, but each field must
carry provenance metadata identifying whether it is observed, deterministic,
rule-derived, model-derived, or compiled from a later knowledge artifact.

## Ownership Boundary

bmux owns:

- live coding-agent processes, PTYs, WebViews, and App Server connections;
- live interaction, approvals, and user-facing control flow;
- provider-specific acquisition and normalization;
- immediate ephemeral UI state;
- rendering, presentation, and interaction;
- forwarding accepted observable engineering evidence to Provenance Engine.

Provenance Engine owns:

- evidence validation;
- durable immutable evidence storage;
- evidence relationships;
- deterministic Current State;
- session and work projections;
- evidence-backed inference;
- milestone structure and semantic enrichment;
- thread and turn intent inference;
- scoped architecture projections;
- knowledge compilation;
- provenance, confidence, and supersession metadata for derived information.

## Execution Evidence Ingestion Boundary

Provenance Engine should not ingest every transport delta emitted by a provider.
Streaming, high-frequency, and UI-animation state remain bmux runtime concerns.

The intended boundary is completed or meaningful evidence units:

| Source unit | bmux live responsibility | Provenance Engine durable responsibility |
| --- | --- | --- |
| stdout/stderr deltas | render live stream | no default durable record |
| completed command | show live result | command fact with cwd, status, exit/result metadata, bounded summaries, and evidence links |
| reasoning deltas | optional live display | no default durable record |
| completed reasoning summary | optional live display | summary evidence when exposed as a supported provider summary, not hidden chain-of-thought |
| plan update | render current plan | plan evidence linked to thread/turn/session |
| file-change or diff unit | show live diff/status | completed file-change or diff evidence linked to worktree/change-set where possible |
| approval request/resolution | drive interaction | approval evidence when it materially affects engineering risk or write behavior |
| validation result | show status | validation evidence linked to command, turn, worktree, and contribution |
| compaction event | update live state | compaction evidence when it changes thread continuity or context availability |

This boundary revises the older "execution telemetry remains bmux-owned"
wording without reversing the raw-stream policy. Raw execution telemetry is
still not persisted as provenance by default. Selected completed evidence units
become durable only through explicit event contracts, retention rules, and
privacy policy.

Codex App Server exposes structured concepts that should be considered for this
boundary, including thread identity, turn identity and lifecycle, user messages,
plan updates, reasoning summaries, command execution, file changes and diffs,
turn-level diff updates, tool calls, approval state, errors, and compaction
events. The first contracts should preserve these source identities where
available rather than flattening everything into generic text records.

## Implemented Evidence Foundation

The first narrow implementation slice records selected observable coding-agent
facts below the semantic layer. Producers append these facts through
`ProvenanceEngineClient.appendEvent(...)`; Provenance Engine stores them in the
immutable ledger and rebuilds deterministic projection tables from that ledger.

Implemented durable evidence records:

- `ProvenanceCodingAgentThreadRecord`
- `ProvenanceCodingAgentTurnRecord`
- `ProvenanceCodingAgentPromptRecord`
- `ProvenanceCodingAgentPlanUpdateRecord`
- `ProvenanceCodingAgentCommandRecord`
- `ProvenanceCodingAgentReasoningSummaryRecord`
- `ProvenanceCodingAgentFileChangeAttributionRecord`

The records preserve provider identity (`provider`, provider thread id, provider
turn id, operation/item ids where available) and relate evidence to PE session,
repository, worktree, change-set, and file-change records when the producer can
establish those relationships. Unknown relationships remain absent rather than
guessed.

This slice does not persist raw stdout/stderr deltas, raw reasoning deltas,
hidden chain-of-thought, unrestricted transcripts, token-by-token provider
envelopes, or bmux live projection state. Command output summaries are part of
the contract shape but bmux does not populate them yet; that remains a
retention/privacy decision.

## Implemented Factual Session Projection Foundation

The first public read contract is:

- `ProvenanceFactualSessionProjectionRequest`
- `ProvenanceFactualSessionProjectionResponse`
- `ProvenanceFactualSessionProjectionSnapshot`
- `ProvenanceFactualSessionProjectionProviderThreadIdentity`
- `ProvenanceFactualSessionProjectionTurnReference`
- `ProvenanceFactualSessionProjectionTurnSnapshot`
- `ProvenanceFactualSessionTurnDetailRequest`
- `ProvenanceFactualSessionTurnDetailResponse`
- `ProvenanceEngineClient.factualSessionProjection(...)`
- `ProvenanceEngineClient.factualSessionTurnDetail(...)`
- `ProvenanceEngineCapability.queryFactualSessionProjection`
- `ProvenanceEngineCapability.queryFactualSessionTurnDetail`

It returns one PE session's observed coding-agent evidence grouped into factual
thread and turn structure. The current session snapshot shape emphasizes PE
session identity, observed provider thread identities as factual data, detailed
factual latest-turn state, and compact prior-turn references. Provider thread
identity is not treated as proof of a permanent 1:1 PE session/thread mapping.
Consumers that need full detail for an older turn use the separate
`ProvenanceFactualSessionTurnDetailRequest` /
`ProvenanceFactualSessionTurnDetailResponse` read contract. The compatibility
`turns` array still carries detailed observed turns for existing lower-level
diagnostic consumers.

Detailed factual turn snapshots include latest submitted prompt, latest plan
update, completed commands, visible reasoning summaries, and file-change
attributions linked directly to the turn. Session and turn-detail revisions are
the newest ledger append sequence for the owning session.

The implementation is deterministic and rebuildable from the immutable ledger.
It is deliberately below `SessionWorkModel`: it does not synthesize missing
turns, infer intent, derive milestones, classify current activity, compute
risks, infer architecture, ingest GitHub evidence, or compile knowledge
artifacts. Unknown relationships remain absent rather than guessed.

## Conceptual Shape

`SessionWorkModel`

- `revision` or `version`: monotonically increasing model revision.
- `subject` or `project`: stable project/repository/worktree subject context.
- `thread`:
  - provider thread id and Provenance Engine session identity.
  - current inferred intent.
  - intent history and supersession.
- `currentTurn`:
  - provider turn id when available.
  - inferred turn intent.
  - plan evidence.
  - milestone hierarchy.
  - current milestone.
  - current activity.
- `execution`:
  - worktree, branch, and head facts.
  - working set and files with current evidence.
  - validation state.
  - risks, conflicts, and blockers.
- `architecture`:
  - thread-scoped projection.
  - current-turn-scoped projection.
- `provenance`:
  - evidence ids for observed fields.
  - Current State source event ids for deterministic fields.
  - inference ids, producer versions, confidence, and supersession status for
    semantic fields.

The response should be optimized for a consumer that needs to answer:

> If I look at this for three seconds, can I tell whether the agent is making
> progress, stuck, or doing something risky?

It must also support drilldown into the project subject, current thread intent,
current turn intent, milestones, current activity, risks, architecture, and code
relationships.

## Live Synchronization

The projection should follow the established bmux synchronization pattern:

1. Producers or adapters append evidence.
2. Provenance Engine computes an authoritative snapshot.
3. The snapshot carries a monotonically increasing revision.
4. Push notifications or deltas are hints only.
5. Consumers re-fetch the authoritative projection for reconciliation.

UI correctness must not depend on perfect push delivery.

## Milestone Model

Milestones are a living semantic hierarchy, not a static todo list.

Codex plan steps can seed initial milestones when appropriate. Provenance
Engine can then enrich titles, descriptions, roles, and completion criteria;
discover nested sub-milestones as work reveals structure; and supersede or
split milestones without silently overwriting completed history.

A milestone may eventually include:

- stable id and revision;
- title;
- status;
- purpose;
- role in the current turn;
- completion criteria;
- current focus;
- children;
- evidence references;
- touched, affected, and contextual architecture nodes;
- related files, diffs, commits, and pull requests;
- inference method, producer version, model version when applicable, confidence,
  and supersession status.

Milestone completion should not assume that one commit equals one milestone.
Attribution may need to operate at file-change or diff-hunk granularity before
later resolving to commits and pull requests.

## Thread And Turn Intent

Subject or project context should be more stable than thread intent.

Thread intent is durable but revisable. It may narrow, broaden, shift, or be
superseded as the broader objective changes. It should not be fixed forever at
thread creation.

Turn intent changes more readily than thread intent and should be linked to the
current prompt, plan updates, tool activity, command/file evidence, and any
inference records that refined it.

## Scoped Architecture Projections

Architecture projections should explain the work at the scope where it is
happening. They are not whole-repository diagrams.

Required scopes:

1. Thread scope.
2. Current turn scope.

Provenance Engine should produce the smallest architecture subgraph necessary
to understand the work.

Node roles:

- touched: directly modified or directly exercised by evidence.
- affected: behavior, contract, or dependency likely affected by the work.
- contextual: not directly changed, but materially helpful for explaining why
  the touched or affected nodes matter.

Example:

```text
Socket API ----\
                -> TabManager -> Surface Focus
App Menu ------/
```

If Surface Focus is not edited but explains why a workspace-selection migration
matters, it may be contextual. Unrelated architecture should not be included
just because it exists elsewhere in the repository.

Architecture inference should be backed where possible by files, symbols,
imports, call relationships, diffs, tests, explicit plans or reasoning
summaries, and existing docs. Unsupported relationships must not be presented as
fact.

## Milestone, Architecture, And Code Relationships

The long-term model should support:

- click milestone -> highlight touched, affected, and contextual architecture
  nodes;
- click architecture node -> show milestones and evidence touching it;
- completed milestone -> show corresponding file changes, diff hunks, commits,
  or pull requests when known;
- milestone detail -> show purpose, role, completion criteria, and code
  evidence.

These relationships should be represented in Provenance Engine evidence and
inference records first. bmux should render and interact with them, not infer
them independently.

## Inference Pipeline

The likely pipeline is:

```text
new evidence
  -> determine stale inference kinds
  -> gather bounded relevant evidence packet
  -> run deterministic rule and/or model inference
  -> validate schema, evidence references, and material claims
  -> persist inference with provenance
  -> supersede prior inference when appropriate
  -> update SessionWorkModel projection
```

Inference records should preserve:

- kind;
- value;
- supporting evidence ids;
- deterministic, rule-derived, or model-derived basis;
- producer or inference-definition version;
- model version when applicable;
- confidence;
- created time;
- active, superseded, or invalidated status.

Potential inference definitions:

- `ThreadIntentInference`
- `TurnIntentInference`
- `SessionPhaseInference`
- `CurrentActivityInference`
- `MilestoneStructureInference`
- `MilestoneDescriptionInference`
- `MilestoneCurrentFocusInference`
- `BlockerInference`
- `ApproachChangeInference`
- `ArchitectureScopeInference`
- `ArchitectureProjectionInference`
- `ImplementationOutcomeCompiler` later

These are roadmap candidates, not current implemented contracts.

## First Vertical Slice

The first useful experiment should use one real Codex turn and produce a
minimal evidence-backed `SessionWorkModel` resembling:

```text
THREAD
Canonical Domain Mutations

THREAD INTENT
Consolidate workspace mutations through canonical domain paths

TURN
Migrate workspace-selection callers

MILESTONES
[done] Inspect selection behavior
[active] Migrate callers
   - [done] Socket
   - [active] App Menu
   - [todo] AppleScript
[todo] Validate

CURRENT
Migrating App Menu through TabManager

ARCHITECTURE
Socket ----\
            -> TabManager -> Focus
Menu ------/
```

Every non-observed field must trace to evidence.

Acceptance criteria:

- One real Codex App Server turn emits durable evidence for thread identity,
  turn identity/lifecycle, user prompt, plan update, completed command facts,
  completed reasoning summary if available, completed file-change/diff units,
  approval state when present, validation result when present, errors when
  present, and compaction when present.
- Streaming deltas remain bmux live state and are not persisted as raw
  provenance by default.
- Evidence relates cleanly to existing session, worktree, change-set, file, and
  validation models where those relationships exist.
- Deterministic session/current-state projections cover factual live state only.
- A first `SessionWorkModel` snapshot exposes revision, subject, thread,
  current turn, current activity, milestone hierarchy, validation/risk state,
  and provenance metadata.
- Thread intent, turn intent, session phase, current activity, milestone
  hierarchy, and milestone descriptions are produced as active inference records
  with supporting evidence, producer version, confidence, and supersession
  status.
- A small turn-scoped architecture projection includes touched, affected, and
  contextual nodes with evidence-backed relationships.
- Milestone-to-architecture links are available for the projected nodes.
- At least one completed milestone links to file-change or diff evidence; commit
  or pull-request attribution is optional for this first slice.
- The projection can be refreshed by revision. Push or delta delivery is treated
  only as a hint.
- Existing lower-level APIs remain available and are not replaced wholesale.
- Tests or fixtures prove that model-derived fields are not written into
  deterministic Current State.

## Later Work

After the first vertical slice:

1. Expand structured Codex evidence ingestion deliberately.
2. Add stronger deterministic session projections.
3. Broaden inference definitions and invalidation.
4. Improve thread and turn scoped architecture inference.
5. Add milestone-to-diff, milestone-to-Git, and milestone-to-GitHub
   attribution.
6. Use the Knowledge Compiler later for durable implementation outcomes and
   decisions beyond the live session model.

## Non-Goals For The Next Slice

- Persisting every provider transport delta.
- Storing unrestricted command output, transcripts, or private reasoning.
- Building a bmux-only semantic model.
- Treating inferred milestone or architecture meaning as deterministic Current
  State.
- Replacing `currentContext`, `sessionTree`, `fileExplanation`, or
  `workspaceDisplay`.
- Whole-repository architecture diagrams.
- Assuming commits or pull requests are the unit of milestone completion.
- Building durable Knowledge Compiler artifacts before the live session model
  proves ingestion, inference, provenance, and usefulness.

## Open Decisions

- Final public API names and request/response DTO names.
- Whether `SessionWorkModel` is queried by session id, provider thread id,
  bmux workspace id, worktree id, or a composite selector.
- Exact retention policy for bounded command summaries, reasoning summaries,
  diffs, and approval payloads.
- Whether architecture inference starts from code symbols, file paths, existing
  docs, model synthesis, or a hybrid.
- How much of the first inference pipeline is synchronous with evidence append
  versus asynchronous and eventually consistent.
- Whether model-derived inference requires human/user confirmation before any
  field is promoted into compiled knowledge.
