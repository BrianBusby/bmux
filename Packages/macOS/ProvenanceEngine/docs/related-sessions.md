# Related Session Awareness

`RelatedSession` is the first PE-owned cross-session awareness read model. It
discovers sessions related to one target PE session and returns bounded,
evidence-backed briefs without sharing whole transcripts or creating new
semantic claims.

The projection is read-only from a workflow perspective. A SQLite read may
materialize deterministic projection cache rows and revisions, but it does not
mutate sessions, coordinate agents, inject prompt context, notify users, or
write new semantic inferences.

## Public Contract

The public read surface is:

- Request: `ProvenanceRelatedSessionRequest(targetSessionID:limit:updatedAfter:revisionID:exclusionLimit:)`.
- Response: `ProvenanceRelatedSessionResponse`.
- Projection DTO: `ProvenanceRelatedSessionProjection`.
- Projection metadata DTO: `ProvenanceRelatedSessionProjectionMetadata`.
- Brief DTO: `ProvenanceRelatedSessionBrief`.
- Outcome brief DTO: `ProvenanceRelatedSessionOutcomeBrief`.
- Relationship kind enum: `ProvenanceRelatedSessionRelationshipKind`.
- Relationship reason DTO: `ProvenanceRelatedSessionRelationshipReason`.
- Evidence reference DTO: `ProvenanceRelatedSessionEvidenceReference`.
- Freshness DTO: `ProvenanceRelatedSessionFreshness`.
- Completeness DTOs: `ProvenanceRelatedSessionCompleteness` and
  `ProvenanceRelatedSessionAvailability`.
- Worktree boundary DTO: `ProvenanceRelatedSessionWorktreeBoundary`.
- Exclusion DTO: `ProvenanceRelatedSessionCandidateExclusion`.
- Client method: `ProvenanceEngineClient.relatedSessions(...)`.
- Capability: `query_related_sessions`.

When the target PE session does not exist, the response returns
`found == false`, `reason == "no_session"`, and `projection == nil`. A caller
may request a specific historical related-session projection revision with
`revisionID`; missing revisions return `found == false` with
`reason == "no_revision"`.

## Query Bounds

`limit` bounds the number of returned related-session briefs. Negative limits
are treated as zero by the SQLite implementation. `exclusionLimit` bounds the
number of omitted-session explanations. `updatedAfter` filters related sessions
whose observed freshness is older than the boundary.

The read scans accepted PE session state and supporting projections. It does
not load raw provider transcripts, hidden reasoning, full command output, or
unbounded conversation history.

## Relationship Reasons

The v1 rule id is `deterministic_related_sessions` with rule version `1`.
Implemented relationship kinds are:

- `same_repository`: both sessions have accepted evidence for the same
  repository id, repository path, or repository remote slug.
- `same_worktree`: both sessions have accepted evidence for the same worktree id
  or worktree path.
- `same_branch`: both sessions have accepted evidence for the same branch within
  a shared repository key.
- `session_tree_ancestor`: the related session is an accepted ancestor of the
  target session.
- `session_tree_descendant`: the related session is an accepted descendant of
  the target session.
- `session_tree_sibling`: both sessions share an accepted session-tree parent.
- `shared_provider_thread`: both sessions have accepted evidence for the same
  provider thread identity.
- `shared_external_identity`: both sessions have accepted evidence for the same
  external provider/runtime identity.
- `shared_changed_artifact`: both sessions have accepted Session Outcome facts
  for the same changed artifact path, and they also share a repository or
  worktree key.

Every relationship reason is typed and individually inspectable. There is no
opaque relevance score. Artifact overlap is intentionally minimal and factual inside the
related-session read. The separate artifact-collision awareness projection owns
possible-collision explanations and still does not warn, block, coordinate, or
infer semantic conflict risk.

## Ordering

Returned related sessions are sorted deterministically by strongest relationship
reason, then freshness, then stable PE session id. Current strength order is:

1. same worktree
2. session-tree ancestor or descendant
3. shared provider thread
4. session-tree sibling
5. same branch
6. shared changed artifact
7. same repository
8. shared external identity

Reasons inside a brief are sorted by the same strength order, then reason kind,
reason values, and relationship depth. Result-limit exclusions are emitted
after the same ordering pass.

## Brief Contents

Each related-session brief exposes:

- stable PE session identity and current session record;
- provider/runtime identities when accepted evidence supports them;
- repository, worktree, branch, and HEAD boundaries when observed;
- lifecycle state and completion state;
- exact Session Outcome revision metadata used for the brief;
- a compact outcome brief derived from Session Outcome;
- existing SessionWorkModel semantic fields, when present, with their original
  semantic provenance;
- relationship freshness and source-watermark metadata;
- supporting evidence or projection references;
- explicit completeness and availability states.

The outcome brief is deliberately bounded: two objectives, five plan items,
five completed actions, five completed commands, ten changed artifacts, five
validation attempts, five blockers, five unresolved items, and one latest resume
point. Truncated fields are listed explicitly.

## Revisions And Freshness

Projection metadata records the request fingerprint, content fingerprint,
projection rule id/version, source evidence watermark, result limits, optional
recent-time boundary, generated time, and revision id.

The content revision changes when the public relationship content changes:
session identity fields, lifecycle/completion state, boundary facts, provider
identity facts, relationship reasons, Session Outcome revision identity, or
selected SessionWorkModel semantic revision identity. Duplicate or overlapping
evidence that changes only supporting reference availability can advance
freshness or source watermark without creating a new content revision.

The brief freshness state exposes the relationship evidence watermark,
relationship observed time, Session Outcome generated time, newest selected
SessionWorkModel semantic inference time, and related-session projection
generated time. Consumers should present stale or partial information from these
fields rather than treating the projection as a live guarantee.

SQLite schema version 23 stores related-session content revisions in
`provenance_related_session_revisions` and latest pointers in
`provenance_related_sessions`.

## Facts Versus Semantics

Relationship reasons come only from observed deterministic facts and existing
versioned projections. Explicit plan, command, file, validation, blocker,
unresolved, and resume facts appear through Session Outcome. Existing
SessionWorkModel semantic fields may be included, but they preserve their
semantic record, inference kind/version, confidence, specificity, producer, and
evidence basis.

This projector does not create new milestone, blocker, decision,
approach-change, risk, architecture, or progress inference. Semantic message
wording and ordinary assistant prose do not become relationship facts.

## Known Limitations

Provider-thread and external-identity relationships depend on accepted
current-state identity records. They remain absent when producers do not append
or preserve those identities in a shareable way.

The v1 related-session artifact relationship is only a factual shared
changed path inside shared repository/worktree context. Possible-collision
explanations now live in `artifact-collisions.md`, and they are still not
rename tracking, diff-hunk identity, semantic component overlap, coordination,
or conflict proof.

There is no bmux UI, CLI command, prompt assembly, automatic retrieval,
proactive notification, Knowledge Compiler bridge, organization-scale storage,
remote sharing, raw transcript retention, or LLM-authored cross-session summary
in this slice.
