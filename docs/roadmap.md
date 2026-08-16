# Provenance Engine Roadmap

This is the authoritative roadmap for the provenance-engine repository. It defines implementation sequence and priorities for reusable provenance contracts, storage, SDK boundaries, retrieval, shared evidence, and derived knowledge. The full platform shape is defined in `docs/reference-architecture.md`; this file describes when slices of that architecture should be pursued. bmux product behavior and user experience belong in the bmux roadmap. Coordinated adoption milestones live in `docs/bmux-integration-roadmap.md`.

## Current Project Status

The authoritative generated status is:

- [Project status](generated/project-status.md)
- [Nested roadmap](generated/nested-roadmap.md)
- [Ownership boundary](generated/ownership-boundary.md)
- [Repository status](generated/repository-status.md)

This roadmap defines sequencing and rationale. It must not independently
maintain active gates, milestone state, evidence commits, release state, or open
caveat status.

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
`project/project-state.yaml`. Cross-repository sequencing details live in
`docs/bmux-integration-roadmap.md`.

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

Status: evidence foundation and factual session projection read contract
implemented; semantic `SessionWorkModel` inference, milestone synthesis, and
architecture projection remain planned and gated.

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
5. Add an inference framework with evidence references, producer versions,
   confidence, specificity, and supersession. The foundation is implemented as
   reusable semantic record storage and invalidation/coalescing policy, without
   defining first semantic concepts.
6. Introduce semantic `SessionWorkModel` enrichment above the factual projection
   and lower-level APIs.
7. Implement the first semantic vertical slice: thread intent, turn intent,
   session phase, and current activity. This is the first concrete semantic
   inference layer and still stops before milestone, architecture, presentation,
   and knowledge-compilation work.
8. Add milestone hierarchy/description in its own semantic work-understanding
   slice after the first session inference concepts are stable.
9. Add scoped architecture inference/projection for thread and current-turn
   scopes.
10. Add milestone-to-architecture relationships.
11. Add milestone-to-diff, Git, and GitHub attribution.
12. Use the Knowledge Compiler later for durable implementation outcomes and
    decisions beyond the live session model.

The first semantic inference slice is accepted when one coding-agent session can
produce refreshable thread intent, turn intent, session phase, and current
activity records with structured payloads, evidence references, factual
revision, producer version, confidence, specificity, and supersession. Existing
lower-level APIs must remain available, and tests or fixtures must prove
semantic fields are not written into deterministic Current State. Milestones,
architecture, validation/risk synthesis, and full `SessionWorkModel`
presentation remain later slices.

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
