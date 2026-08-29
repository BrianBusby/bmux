# Provenance Engine Roadmap

This is the package roadmap for Provenance Engine inside the bmux monorepo. It defines implementation sequence and priorities for reusable provenance contracts, storage, SDK boundaries, retrieval, shared evidence, and derived knowledge. The full platform shape is defined in `docs/reference-architecture.md`; root Project Truth is the current status authority. bmux product behavior and user experience belong in the bmux roadmap.

## Current Project Status

The authoritative generated status is:

- [Project status](../../../../docs/generated/project-status.md)
- [Nested roadmap](../../../../docs/generated/nested-roadmap.md)
- [Ownership boundary](../../../../docs/generated/ownership-boundary.md)
- [Repository status](../../../../docs/generated/repository-status.md)

This roadmap defines sequencing and rationale. It must not independently
maintain active gates, milestone state, evidence commits, release state, or open
caveat status. It also must not independently maintain dependency-ready,
selected-next, or active branch/worktree claims; those volatile planning facts
belong in the generated roadmap.

## V1 Adoption Guidance

The immediate roadmap priority is observation of the accepted bmux integration,
not speculative engine expansion. After observation produces concrete findings,
the next selected work should be one explicit slice such as legacy cleanup,
observability API design, release packaging, or another bounded adoption path.

The accepted next product direction is richer live coding-agent understanding,
but implementation must still be selected as an explicit slice. The planning
name for the high-level projection is `SessionWorkModel`; the target design is
`docs/session-work-model.md`.

Canonical current milestone state and evidence are generated from
`../../../../project/project-state.yaml`. Historical adoption sequencing details live
in `docs/bmux-integration-roadmap.md`.

## Additional Bmux Adoption Paths

The initial V1 package and bmux adoption sequence is complete. Future bmux
adoption work should still be selected one path at a time after observation
findings justify it.

V1 adoption paths validated by the shared roadmap:

- Current session and task context through `currentContext(...)`.
- Supported lifecycle recording through `recordSessionLifecycle(...)`.
- Accepted Git/worktree observation capture through `appendEvent(...)`.
- Workspace-display Current State through `workspaceDisplay(...)`.
- Operational production default storage cutover to
  `~/.local/state/provenance-engine/provenance.sqlite`.

Still gated as planning topics until selected through the project manifest:

- Broad legacy bmux-local database migration or deletion.
- A public observability trace API, if observation proves one is needed.
- Workspace-display follow-up diagnostics or compatibility work beyond the
  accepted durable-context projection.
- Additional richer coding-agent evidence ingestion beyond the accepted
  foundation, such as approval, validation, error, and compaction units.
- Semantic `SessionWorkModel` enrichment above the implemented factual session
  projection, preserving field-level basis/provenance and keeping semantic
  inference out of deterministic Current State.
- A tagged Provenance Engine release to replace revision pins.
- Daemon/service transport, only if the in-process SDK boundary proves
  insufficient.
- Shared evidence, GitHub ingestion, retrieval, and Knowledge Compiler work.

Execution-telemetry live state, provider acquisition, raw streams, transport
deltas, capture policy, diagnostics, orchestration, UI, and analytics remain
bmux-owned. Provenance Engine receives only explicitly approved durable
engineering evidence through public contracts. The new direction revises the
approved-evidence boundary so completed meaningful units may cross into PE;
it does not authorize raw execution-telemetry persistence.

Workspace display Current State is implemented for the accepted durable-context
projection. Provenance Engine owns accepted workspace-display evidence
contracts, deterministic projection semantics, and Current State APIs for
workspace title, repository/worktree identity, branch, PR, ticket, project,
current-work, and prompt display facts. bmux owns observation adapters, UI
rendering, custom sidebar field compatibility, temporary optimistic display
state, fallback behavior, and diagnostics that compare observed display state
with PE Current State and latest accepted evidence.

## Richer Coding-Agent Evidence And SessionWorkModel

Status: durable sequencing lives here; current dependency readiness, explicit
selection, active assignments, and implementation evidence are generated from
Project Truth. The implemented sequence now includes the evidence foundation,
factual session projection read contract, deterministic Turn Outcome
projection, semantic inference framework, first coding-agent semantic
inferences, human-readable semantic messaging, and the first PE-owned
SessionWorkModel foundation. Session Outcome aggregation, the first read-only related-session awareness
foundation, and artifact-collision awareness are implemented factual/read model
layers before richer cross-session semantics, agent-accessible retrieval, and
context assembly.

This phase addresses the main gap found after the execution-telemetry and
workspace-display slices: bmux can observe richer structured coding-agent data
than Provenance Engine currently receives.

The implementation sequence is:

1. Define explicit evidence contracts for completed or meaningful coding-agent
   units rather than provider transport deltas. Implemented for thread, turn,
   prompt, plan update, completed command, visible reasoning summary, and
   file-change attribution evidence.
2. Capture structured Codex thread, turn, plan, reasoning-summary, command,
   and file-change evidence where available and policy-approved. Approval,
   validation, error, and compaction capture remain unimplemented.
3. Relate that evidence to existing session, worktree, contribution,
   change-set, file-change, and validation records. Implemented for session,
   repository, worktree, change-set, and file-change relationships where
   producers can establish them; contribution and validation relationships
   remain future work.
4. Add deterministic factual session projections for live state only.
   Implemented through the first revisioned `factualSessionProjection(...)`
   read contract for one PE session.
5. Add deterministic Turn Outcome projection as the factual outcome unit for
   one coding-agent turn. Implemented through `turnOutcome(...)` with
   projection revisions, source evidence watermarks, completeness metadata, and
   field or item evidence references.
6. Add Session Outcome aggregation over TurnOutcome revisions before later
   Smart Session and cross-session work consumes outcome facts. Implemented
   through `sessionOutcome(...)` with exact constituent TurnOutcome revision
   tracking, source watermarks, completeness metadata, and bounded factual
   session outcome fields.
7. Add an inference framework with evidence references, producer versions,
   confidence, specificity, and supersession. The foundation is implemented as
   reusable semantic record storage and invalidation/coalescing policy.
8. Implement the first semantic vertical slice: thread intent, turn intent,
   session phase, and current activity. This is the first concrete semantic
   inference layer and still stops before milestone, architecture, presentation,
   and knowledge-compilation work.
9. Add human-readable semantic messaging above semantic inference truth. This is
   implemented as semantic message contracts, deterministic first-pass wording,
   message cache/history persistence, and public query/materialization APIs.
10. Add a bmux factual Session view that renders PE factual session projection
    data without adding semantic inference. This is factual consumer groundwork
    and diagnostic/inspection scaffolding, not the full Smart Session product.
11. Productize bmux's existing React `agent-chat` surface as the Terminal view
    for live interaction. This can proceed independently from many PE semantic
    slices as long as it stays focused on provider live UX and does not become a
    semantic engine.
12. Add a separate React Smart Session foundation that consumes PE factual
    projection and semantic messages for summary-oriented presentation.
13. Define the first PE-owned `SessionWorkModel` contract above factual
    projection and active semantic inference records so bmux does not compose a
    second session model locally. Semantic messages remain presentation records,
    not work-model truth inputs.
14. Add a PE-owned related-session awareness read above Session Outcome and
    SessionWorkModel. Implemented through `relatedSessions(...)` with bounded
    deterministic relationship reasons, compact outcome briefs, freshness,
    revision metadata, and factual-versus-semantic provenance separation.
15. Add PE-owned artifact-collision awareness above Session Outcome and
    related-session discovery. Implemented through `artifactCollisions(...)`
    with exact-path overlap candidates, repository/worktree/branch/HEAD
    boundaries, temporal and freshness states, revision metadata, and explicit
    non-coordination semantics.
16. Add milestone hierarchy/description and blocker or approach-change
    semantics in their own structured-understanding slices after the first
    session inference concepts are stable.
17. Consume the PE `SessionWorkModel` from the React Smart Session surface for
    completed/current turn summaries, progress, blockers, validations, risks,
    and richer session-level synthesis.
18. Add clickable semantic explanation and evidence drilldown inside the React
    Smart Session surface, preserving the boundary between observed evidence,
    deterministic projection, semantic inference, and wording.
19. Add scoped architecture inference/projection for thread and current-turn
    scopes.
20. Add milestone-to-architecture relationships.
21. Add milestone-to-diff, Git, and GitHub attribution.
22. Use the Knowledge Compiler later for durable implementation outcomes and
    decisions beyond the live session model.

The first semantic inference slice is accepted when one coding-agent session can
produce refreshable thread intent, turn intent, session phase, and current
activity records with structured payloads, evidence references, factual
revision, producer version, confidence, specificity, and supersession. Existing
lower-level APIs must remain available, and tests or fixtures must prove
semantic fields are not written into deterministic Current State. Milestones,
architecture, validation/risk synthesis, presentation wording, and full
`SessionWorkModel` presentation remain later slices.

The first semantic message slice is accepted when semantic inference records can
be rendered into cached concise and expanded message records that preserve
structured semantic meaning, provenance, confidence, specificity, producer,
presentation policy, history, and supersession without making wording the source
of semantic truth or deterministic Current State. bmux UI presentation,
presentation language calibration, and feedback learning are separate slices;
consult the generated roadmap for their current readiness and selection state.

The first SessionWorkModel foundation is accepted when a public
`sessionWorkModel(...)` read composes factual projection plus current active
semantic inference records for thread intent, turn intent, session phase, and
current activity; preserves provenance, factual revision, semantic ids, and
unknown/unavailable states; and keeps semantic messages as optional presentation
records rather than authoritative truth. Milestones, blockers, approach
changes, architecture projection, GitHub attribution, progress synthesis, and
Knowledge Compiler output remain later slices.

The first related-session awareness foundation is accepted when a public
`relatedSessions(...)` read can discover bounded sessions related to a target
PE session from accepted facts and existing projections; return inspectable
same-repository, same-worktree, same-branch, session-tree, provider-identity,
external-identity, and shared changed-artifact reasons; track exact Session
Outcome and SessionWorkModel revisions; expose freshness and completeness; and
avoid raw transcripts, prompt injection, LLM-authored cross-session summaries,
artifact-collision warnings, and new semantic inference.

The artifact-collision awareness slice is accepted when a public
`artifactCollisions(...)` read detects exact-path artifact overlaps between a
target session and bounded related sessions; explains repository, worktree,
branch, HEAD, temporal, freshness, completeness, and evidence boundaries;
preserves Session Outcome and related-session revision identities; handles
duplicate, late, corrected, and out-of-order evidence deterministically; and
explicitly avoids semantic compatibility judgments, rename approximation,
automatic coordination, prompt injection, raw transcript sharing, proactive UI,
and Knowledge Compiler behavior.

The three-view bmux product model is a consumer constraint on this PE roadmap:
Native remains provider-native, Terminal remains React live interaction, and
Session becomes a separate React smart summary surface backed by PE factual and
semantic models. PE should add contracts that make the Session view reliable;
it should not require bmux to infer session meaning from raw live events merely
because the Terminal surface can observe them.

## External Evidence Model Validation

Status: planned and gated after Engineering Observation Period findings justify
the next post-V1 evidence-model slice.

This phase validates repository and external evidence without conflating it with personal AI-session evidence. It should refine origin/scope usage, authorization expectations, compatibility rules, and evidence-store boundaries before adding broad ingestion.

## Shared Evidence-Store Design

Status: planned and gated.

Design personal, project, and organization evidence scopes so shared repository evidence is ingested once for a repository or organization instead of being independently collected and summarized by every engineer.

## GitHub Ingestion Spike

Status: post-V1 spike only.

The spike should ingest raw objective evidence only:

- Commits and commit metadata.
- Changed files and changed symbols.
- Pull request metadata and bodies.
- PR comments.
- Submitted reviews.
- Inline review comments.
- Merge status.
- Commit-to-PR relationships.
- Review thread resolution.

No AI summarization should run during this spike. The spike exists to validate storage shape, incremental sync, authentication, API limits, ingestion performance, commit-to-PR relationships, changed-file/symbol preservation, and review-thread-to-diff relationships before introducing interpretation.

## Pull Request Decision Summary Compiler

Status: planned after the GitHub ingestion spike.

The Knowledge Compiler consumes immutable evidence and produces versioned knowledge artifacts. Evidence remains immutable; knowledge can be regenerated by newer compiler versions.

Initial artifact:

```text
Pull Request Decision Summary
```

Suggested fields:

- Intent.
- Accepted constraints.
- Rejected alternatives.
- Important review findings.
- Deferred work.
- Final outcome.
- Supporting evidence references.

## Evidence-Aware Retrieval Validation

Status: exploratory until compiled PR decision summaries exist.

Retrieval should prefer compiled knowledge plus minimal supporting evidence. Agents should not receive thousands of commits, full PR discussions, or complete review threads by default.

## Organization-Scale Deployment

Status: deferred.

Daemon or service transport, shared deployment, authorization enforcement, compatibility policy across released versions, and organization-scale storage operations belong after local V1 adoption and evidence-aware retrieval have both been validated.

## V1 Write-Side Validation Result

The write-side architecture has been validated by a generic non-bmux producer
using only `ProvenanceEngineContracts` and `ProvenanceEngineSDK`. The result is
recorded in `docs/write-side-validation-milestone.md`.

Accepted conclusion: `appendEvent(...)` remains the V1 write primitive. The
validated friction is payload verbosity and stable-ID guidance, not storage or
bmux leakage. Future write-side improvements should be producer convenience and
documentation work unless new consumer evidence justifies a public contract
change.

## Canonical V1 Boundary

The canonical V1 boundary is `docs/v1-boundary-review.md`.

V1 is complete when independent producers and consumers can record and retrieve
local engineering provenance through the public SDK, with immutable evidence as
the system of record and deterministic Current State rebuilt from that evidence,
without depending on bmux, storage internals, or future knowledge-platform
components.

Capabilities outside that definition should be treated as post-V1 unless a
future boundary review explicitly reclassifies them.

## V1 Freeze Refinement

The V1 freeze boundary includes producer-neutral lifecycle recording through
`recordSessionLifecycle(...)`, durable accepted local SDK writes, and Current
State as the first-class deterministic engine layer between immutable evidence
and public read APIs. The deprecated `recordSubsessionLifecycle(...)` wrapper is
compatibility-only and should not be used by new producers.

Producer delivery reliability before engine acceptance, distributed queues,
remote services, Knowledge Compiler, semantic retrieval, and organization-scale
evidence stores remain post-V1.
