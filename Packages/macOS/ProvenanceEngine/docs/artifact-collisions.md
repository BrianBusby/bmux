# Artifact Collision Awareness

`ArtifactCollision` is a PE-owned deterministic read model for possible
artifact and change collisions between a target coding-agent session and its
related sessions. It answers factual overlap questions without coordinating
agents, mutating files, or judging semantic compatibility.

The projection is read-only from a workflow perspective. A SQLite read may
materialize deterministic revision and latest-pointer rows, but it does not
interrupt sessions, notify users, inject prompt context, rebase, merge, stash,
or modify artifacts.

## Public Contract

The public read surface is:

- Request: `ProvenanceArtifactCollisionRequest(targetSessionID:limit:artifactPath:updatedAfter:staleBefore:revisionID:relatedSessionLimit:exclusionLimit:)`.
- Response: `ProvenanceArtifactCollisionResponse`.
- Projection DTO: `ProvenanceArtifactCollisionProjection`.
- Projection metadata DTO: `ProvenanceArtifactCollisionProjectionMetadata`.
- Candidate DTO: `ProvenanceArtifactCollisionCandidate`.
- Participant DTO: `ProvenanceArtifactCollisionSessionParticipation`.
- Artifact identity DTO: `ProvenanceArtifactCollisionArtifactIdentity`.
- Path boundary DTO: `ProvenanceArtifactCollisionPathBoundary`.
- Boundary comparison DTO: `ProvenanceArtifactCollisionBoundaryComparison`.
- Temporal relationship DTO: `ProvenanceArtifactCollisionTemporalOverlap`.
- Reason enum and DTO: `ProvenanceArtifactCollisionReasonKind` and `ProvenanceArtifactCollisionReason`.
- Evidence reference DTO: `ProvenanceArtifactCollisionEvidenceReference`.
- Freshness DTO: `ProvenanceArtifactCollisionFreshness`.
- Completeness DTOs: `ProvenanceArtifactCollisionCompleteness` and `ProvenanceArtifactCollisionAvailability`.
- Exclusion DTO: `ProvenanceArtifactCollisionCandidateExclusion`.
- Client method: `ProvenanceEngineClient.artifactCollisions(...)`.
- Capability: `query_artifact_collisions`.

When the target PE session does not exist, the response returns `found == false`,
`reason == "no_session"`, and `projection == nil`. A caller may request a
specific historical artifact-collision projection revision with `revisionID`;
missing revisions return `found == false` with `reason == "no_revision"`.

## Query Bounds

`limit` bounds returned candidates. `relatedSessionLimit` bounds the
related-session projection used before candidate discovery. `exclusionLimit`
bounds explanations for omitted candidates or unsupported relationships.
Negative limits are treated as zero by the SQLite implementation.

`artifactPath` narrows discovery to one observed path after deterministic path
normalization. Invalid or empty path filters produce an `invalid_artifact_path`
exclusion and no path match. `updatedAfter` omits candidates whose latest
artifact observation is older than that boundary, with an
`outside_recent_boundary` exclusion. `staleBefore` does not omit candidates; it
classifies otherwise complete candidates as `stale` when their latest artifact
observation is older than the boundary.

The read uses accepted PE state and projections. It does not load raw provider
transcripts, hidden reasoning, full command output, unrestricted conversation
history, or live bmux runtime streams.

## Candidate Discovery

The v1 rule id is `deterministic_artifact_collision_awareness` with rule
version `1`. Candidate discovery starts from the target session's accepted
Session Outcome changed artifacts and the bounded `relatedSessions(...)` result
for the same target. A candidate exists only when at least one related session
has a changed artifact with the same normalized repository-relative path and the
participants share an accepted repository identity key.

Repository identity keys can come from repository id, repository path, or remote
slug preserved by the related-session/source projections. Same relative path in
different repositories is reported only as an excluded candidate with
`same_path_different_repository`; it is not returned as a collision candidate.
Similar paths, neighboring directories, or identical filenames in different
directories are not treated as overlaps.

## Artifact Identity

V1 artifact identity is exact normalized path inside shared repository identity.
Path normalization trims whitespace, converts backslashes to slashes, removes
`.` path elements, resolves lexical `..` elements within the relative path, and
preserves case. The projection records the observed paths, normalized path,
shared repository keys, relationship kind `exact_path`, case sensitivity
`case_sensitive`, and rename support
`unsupported_without_accepted_rename_evidence`.

Stable file identity across renames, copies, symlinks, case-only renames, and
diff hunks is not currently supported. Rename or move evidence is therefore
recorded as unsupported unless future accepted evidence can establish it
deterministically. The projection never approximates rename identity through
path similarity.

## Participant And Boundary Facts

Each candidate records one participation row per session that touched the
artifact. A participation row includes the current session projection, lifecycle
and completion state, the exact Session Outcome revision used, matched
Session Outcome artifact facts, repository boundaries, worktree boundaries,
first and last observed artifact-change timestamps, evidence references, and
completeness metadata.

Boundary comparison reports only observed facts:

- repository relationship: `shared_repository` or `missing_repository_evidence`;
- worktree relationship: `same_worktree`, `different_worktrees`, or `unknown_worktree`;
- branch relationship: `same_branch`, `different_branches`, or `unknown_branch`;
- HEAD relationship: `same_head`, `divergent_head`, or `unknown_head`.

The projection does not decide that one branch is stale, obsolete, correct, or
likely to overwrite another. Divergent branch, worktree, or HEAD facts are
boundaries that consumers may display or inspect.

## Temporal And Freshness Rules

Temporal overlap is computed from each participant's session start, session
update time, artifact observation timestamps, and open/closed lifecycle state.
Open sessions are treated as open-ended ranges. Complete timestamp evidence can
produce `temporally_overlapping_edits` or `ordered_edits`. Missing artifact
observation timestamps produce `missing_timestamps` and an incomplete candidate.

Candidate state is derived deterministically:

- `current`: complete candidate with at least one active/open participant;
- `historical`: complete candidate where all participants are completed and the
  candidate is not stale;
- `stale`: complete candidate whose latest artifact observation is older than
  the request's `staleBefore` boundary;
- `incomplete`: required evidence is missing for the candidate.

A historical or stale candidate is still an artifact overlap fact. It is not a
claim that any current work will conflict.

## Reasons And Ordering

Supported v1 reason kinds are:

- `exact_path_overlap`
- `shared_repository`
- `same_worktree`
- `different_worktrees`
- `same_branch`
- `different_branches`
- `same_head`
- `divergent_head`
- `temporally_overlapping_edits`
- `historical_overlap`
- `stale_overlap`
- `incomplete_evidence`
- `unsupported_rename_identity`

Returned candidates are sorted deterministically by candidate state priority,
temporal overlap priority, latest artifact observation time descending,
normalized path, then stable candidate id. State priority is current,
incomplete, historical, then stale. Reason arrays are sorted by bounded reason
priority, kind, and stable values. There is no semantic relevance score,
embedding rank, or LLM-authored collision summary.

## Revisions And Retirement

SQLite schema version 24 stores artifact-collision projection revisions in
`provenance_artifact_collision_revisions` and latest pointers in
`provenance_artifact_collisions`. Consumers must use
`ProvenanceEngineClient.artifactCollisions(...)`; table names are storage
details.

Projection metadata records rule id/version, request fingerprint, content
fingerprint, result limits, related-session limit, exclusion limit, optional
path and freshness boundaries, source evidence watermark, generated time, and
revision id. The target Session Outcome projection and related-session
projection metadata used for discovery are also returned.

Content revisions change when public candidate content changes: candidate set,
state, normalized path, boundary facts, temporal state, participants, matched
artifact identities, Session Outcome revisions, or completeness status.
Duplicate or overlapping evidence that changes only supporting references or
watermarks may update the latest projection record without creating a new
content revision. Late, corrected, and out-of-order evidence is handled by
rebuilding from accepted ledger order and producing a deterministic new revision
when returned content changes. If later evidence removes the overlap from the
current bounded read, the latest projection no longer returns the candidate;
older revisions remain readable by exact `revisionID`.

## Evidence Semantics

Every candidate and participant carries supporting evidence references. These
can include accepted ledger event ids and sequences, event types, source,
evidence origin and scope, PE session and turn ids, file-change and
file-attribution record identities, Session Outcome revision ids,
related-session projection revision ids, projection watermarks, and
field-specific reference labels.

Observed facts, explicit plan/file evidence, and existing semantic inference
records remain separate. Existing semantic fields do not silently become
collision facts. The projection does not persist raw transcripts, hidden
reasoning, prompt-context packs, LLM summaries, or semantic compatibility
judgments.

## Non-Goals

This slice does not implement automatic coordination, merge or rebase actions,
file locks, interruption policy, prompt injection, agent-to-agent messaging,
proactive bmux notifications, Smart Session collision UI, agent-facing
retrieval, Knowledge Compiler integration, remote or organization-scale
collision handling, or semantic conflict detection.

A returned candidate means PE found an evidence-backed artifact overlap under
the documented boundaries. It does not prove that changes are incompatible,
that a merge conflict will occur, that one session is obsolete, or that any
session should stop.
