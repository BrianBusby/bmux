# Session Outcome Projection

`SessionOutcome` is the factual, revisioned outcome projection for one
coding-agent session. It aggregates the accepted `TurnOutcome` revisions that
belong to the session so later Smart Session and cross-session work can read a
bounded description of what factually happened without replaying every turn.

The projection is deterministic Current State. It is rebuilt from immutable PE
evidence plus the exact `TurnOutcome` revisions selected at projection time. It
does not infer intent, evaluate quality, write LLM-authored summaries, rank
cross-session relevance, retain raw transcripts, or persist hidden reasoning.

## Public Contract

The public read surface is:

- Request: `ProvenanceSessionOutcomeRequest(sessionID:revisionID:)`.
- Response: `ProvenanceSessionOutcomeResponse`.
- Outcome DTO: `ProvenanceSessionOutcome`.
- Projection metadata DTO: `ProvenanceSessionOutcomeProjectionMetadata`.
- Constituent-turn DTO: `ProvenanceSessionOutcomeTurnReference`.
- Completeness DTOs: `ProvenanceSessionOutcomeCompleteness` and
  `ProvenanceSessionOutcomeAvailability`.
- Repository/worktree boundary DTO:
  `ProvenanceSessionOutcomeRepositoryBoundary`.
- Item DTOs:
  `ProvenanceSessionOutcomePlanItem`,
  `ProvenanceSessionOutcomeCommand`,
  `ProvenanceSessionOutcomeArtifact`,
  `ProvenanceSessionOutcomeValidation`, and
  `ProvenanceSessionOutcomeTextFact`.
- Client method: `ProvenanceEngineClient.sessionOutcome(...)`.
- Capability: `query_session_outcome`.

The bmux CLI exposes the same read through
`bmux provenance session outcome <session-id> [--revision <revision-id>] [--database <path>] [--json]`.
Text output is compact. `--json` returns the full public contract, including
constituent turn references, exact turn outcome revision ids, evidence
references, and completeness metadata.

## Supported Facts

The v1 projection supports PE session identity, external/provider identities,
ordered constituent turns, exact `TurnOutcome` revision identity for each
included turn, explicit objectives, latest factual plan states, completed
actions, completed commands, attributed file changes, validation attempts,
explicit blockers, explicit unresolved items, explicit resume points,
repository/worktree/branch/HEAD boundaries, lifecycle state, completion state,
source availability, projection rule identity, source evidence watermark,
content fingerprint, and revision identity.

Decisions are intentionally empty in v1 unless an accepted turn outcome already
contains an explicit decision. Assistant prose that merely describes a design or
future possibility is not treated as an accepted decision.

## Reconciliation Rules

Constituent turns are ordered by turn start time, then completion time, then
last update time, then stable turn id. This preserves chronology while staying
deterministic for equal timestamps.

The projection aggregates the latest accepted `TurnOutcome` revision for each
included turn unless the caller requests a historical `SessionOutcome` revision.
Historical `SessionOutcome` revisions preserve the exact constituent turn
revision ids and content fingerprints that were used when that session revision
was created.

Objectives, completed actions, completed commands, changed artifacts,
validation attempts, blockers, unresolved items, decisions, and resume points
preserve turn chronology and item chronology within each turn. Repeated command
or artifact facts remain explicit repeated observations when the underlying
accepted turn outcomes expose them as distinct facts.

Plan items reconcile by normalized factual text. The first observed occurrence
sets display order and first-observed metadata. The latest supported factual
state supplies the current text, status, evidence references, and latest
observed turn outcome revision. This gives consumers one bounded current plan
without erasing the evidence trail.

Repository boundaries reconcile by exact repository path, worktree path, branch,
HEAD, current working directory, and linked repository/worktree ids. A session
with multiple supported boundaries returns all boundaries and marks
`repository_boundaries` partial with reason `multiple_repository_boundaries`.
The projector does not silently merge incompatible worktree or HEAD facts.

Completion state is derived only from accepted lifecycle status evidence. It is
`completed`, `failed`, `cancelled`, `interrupted`, `incomplete`, or `unknown`.
A passing validation command does not prove the session's whole change is valid.

## Provenance

Every populated item carries field or item evidence references from the
underlying turn outcome where available. Session-level wrapper items also record
the source turn id and exact source turn outcome revision id. Constituent turn
references record turn id, provider identity, order, turn outcome revision id,
turn outcome content fingerprint, source evidence watermark, and turn
timestamps.

The outcome projection metadata records the projection rule id/version,
projection revision id, content fingerprint, source evidence watermark, and
deterministic generation time. Consumers should trace a claim by reading the
session item, then the source turn outcome revision, then the underlying
accepted ledger evidence referenced by that turn outcome.

## Rebuild And Revisions

Session outcomes are rebuildable from immutable accepted evidence and
deterministic `TurnOutcome` inputs. SQLite stores historical revisions in
`provenance_coding_agent_session_outcome_revisions` and the latest pointer in
`provenance_coding_agent_session_outcomes`.

A new revision is created when factual session-outcome content changes or when
the projection rule version changes. Duplicate replay or overlapping evidence
that changes only supporting references does not create a new factual revision.
Late or corrected evidence that changes an included turn outcome revision or
session-level factual content does create a new revision while preserving older
revisions.

The source evidence watermark is the accepted ledger sequence boundary used to
produce the projection. Rebuilds from the same accepted evidence and rule
version produce the same latest factual outcome content. Consumers can request
the latest revision or a specific revision id.

## Completeness

Completeness is explicit rather than inferred:

- `complete`: every tracked v1 field is observed.
- `partial`: accepted evidence exists, but one or more tracked fields are not
  observed, unavailable, or partial.
- `unavailable`: the requested session does not exist or a specific optional
  fact has no supported evidence.
- `stale`: reserved for future scheduling where a latest pointer is known to
  lag accepted evidence.

Arrays may be empty because no supported evidence was observed. Optional scalar
facts may be `nil` because they were not observed, unavailable, or unsupported
by v1 rules. Consumers must distinguish an empty observed section from a
missing outcome through `found`, `reason`, and outcome completeness metadata.

## Relationship To Other Projections

`factualSessionProjection(...)` remains the lower-level deterministic grouping
of observed session, thread, turn, prompt, plan, command, visible-summary, and
file-attribution evidence. `turnOutcome(...)` remains the factual outcome view
for one turn. `sessionOutcome(...)` is the factual aggregation layer above
`turnOutcome(...)` and below semantic `SessionWorkModel` interpretation.

The related-session awareness read now consumes Session Outcome as its bounded
session-level factual source. It records the exact Session Outcome revision id
used for every related-session brief and derives compact outcome summaries from
Session Outcome fields without replaying whole turns or transcripts.

Deferred work includes context injection, Knowledge Compiler output, raw
transcript retention policy changes, richer dedicated validation evidence
beyond command-attempt classification, and future semantic categories beyond the
implemented milestone, blocker, and approach-change fields.

## Example

```swift
import ProvenanceEngineContracts
import ProvenanceEngineSDK

let client = try ProvenanceEngineClientFactory()
    .sqliteClient(databaseURL: databaseURL)

let response = try await client.sessionOutcome(
    ProvenanceSessionOutcomeRequest(sessionID: "session-pe-123")
)

guard let outcome = response.outcome else {
    print(response.reason ?? "missing outcome")
    return
}

print(outcome.projection.revisionID)
print(outcome.completeness.status)

for turn in outcome.constituentTurns {
    print(turn.turnID)
    print(turn.turnOutcomeRevisionID)
}

for validation in outcome.validationsAttempted {
    print(validation.validation.command)
    print(validation.validation.resultStatus)
    print(validation.sourceTurnOutcomeRevisionID)
}
```

The validation facts above remain validation attempts. A consumer must not treat
them as proof that the whole session outcome is valid unless a later factual or
semantic contract explicitly supports that stronger claim.
