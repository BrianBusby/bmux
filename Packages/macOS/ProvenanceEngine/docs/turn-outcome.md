# Turn Outcome Projection

`TurnOutcome` is the factual, revisioned outcome projection for one
coding-agent turn. It is the smallest durable unit PE exposes for later
session-outcome aggregation and bounded cross-session handoffs.

The projection is deterministic Current State. It summarizes accepted evidence
already in the immutable PE ledger. It does not infer intent, evaluate quality,
write semantic summaries, rank cross-session relevance, retain raw transcripts,
or persist hidden reasoning.

## Public Contract

The public read surface is:

- Request: `ProvenanceTurnOutcomeRequest(turnID:revisionID:)`.
- Response: `ProvenanceTurnOutcomeResponse`.
- Outcome DTO: `ProvenanceTurnOutcome`.
- Projection metadata DTO: `ProvenanceTurnOutcomeProjectionMetadata`.
- Evidence reference DTO: `ProvenanceTurnOutcomeEvidenceReference`.
- Repository/worktree boundary DTO:
  `ProvenanceTurnOutcomeRepositoryBoundary`.
- Item DTOs:
  `ProvenanceTurnOutcomePlanItem`,
  `ProvenanceTurnOutcomeCommand`,
  `ProvenanceTurnOutcomeArtifact`,
  `ProvenanceTurnOutcomeValidation`, and
  `ProvenanceTurnOutcomeTextFact`.
- Client method: `ProvenanceEngineClient.turnOutcome(...)`.
- Capability: `query_turn_outcome`.

The bmux CLI exposes the same read through
`bmux provenance turn outcome <turn-id> [--revision <revision-id>] [--database <path>] [--json]`.
Text output is intentionally compact. `--json` returns the full public contract,
including item-level evidence references and completeness metadata.

## Supported Facts

The v1 projection supports PE session identity, provider identity, provider turn
identity, turn lifecycle, repository/worktree/branch/HEAD boundary, explicit
objectives, plan items, completed commands, attributed file changes, explicit
completed actions, validation attempts, explicit blockers, explicit unresolved
items, explicit resume points, and completion metadata when accepted evidence is
available.

Decisions are intentionally empty in v1 unless a future accepted evidence record
or versioned deterministic rule can support an explicit decision. Assistant
prose that merely describes a design is not treated as an accepted decision.

## Factuality Rules

Every populated field or item must be backed by accepted evidence. Supported
sources include canonical transcript evidence, hook evidence, Git/worktree
observations, command result evidence, linked validation evidence, explicit plan
states, and explicit user or assistant visible statements accepted into PE
evidence.

Allowed deterministic work includes grouping by stable turn identity, selecting
latest or relevant records by ledger sequence and timestamp rules, classifying
commands through small versioned rules, reconciling duplicate transcript and
hook observations for the same event, and reporting unknown, unavailable,
partial, or not-observed states when evidence is missing.

The projector must not infer unstated objective, treat ordinary assistant prose
as accepted decisions, invent blockers or unresolved work, infer validation of
the whole change from one passing command, generate LLM-authored summaries,
persist raw transcripts or hidden reasoning, or rank and inject cross-session
context.

## Provenance

Each projected fact carries `ProvenanceTurnOutcomeEvidenceReference` values
where the contract can identify supporting records. A reference records the
canonical evidence id, source kind, origin and scope where available, adapter or
projection rule identity/version, source completeness state, accepted ledger
sequence, and event timestamp where known.

The outcome projection metadata records the projection rule id/version,
projection revision id, source evidence watermark, creation time, and whether
the response is the latest revision. Consumers should trace a claim by reading
the claim's evidence references first, then inspecting the underlying accepted
event through the engine-owned evidence/debug path available to that consumer.

## Rebuild And Revisions

Turn outcomes are rebuildable from the immutable ledger and deterministic rule
version. SQLite stores historical outcome revisions in
`provenance_coding_agent_turn_outcome_revisions` and the latest pointer in
`provenance_coding_agent_turn_outcomes`.

A new revision is created when accepted evidence or the projection rule version
changes factual outcome content. Duplicate replay or overlapping transcript and
hook evidence that changes only supporting references does not create a new
factual revision. Late or corrected evidence that changes outcome content does
create a new revision while preserving older revisions.

The source evidence watermark is the accepted ledger sequence boundary used to
produce the projection. Rebuilds from the same accepted evidence and rule
version produce the same factual outcome content. Consumers can request the
latest revision or a specific revision id.

## Completeness

Completeness is explicit rather than inferred:

- `complete`: the projection has required turn/session identity and no known
  partial-source caveat.
- `partial`: accepted evidence exists, but one or more expected sources or
  relationships are partial.
- `unavailable`: the requested turn does not exist or a specific optional fact
  has no supported evidence.
- `stale`: reserved for future scheduling where a latest pointer is known to
  lag accepted evidence.

Arrays may be empty because no supported evidence was observed. Optional scalar
facts may be `nil` because they were not observed, unavailable, or unsupported
by v1 rules. Consumers must distinguish an empty observed section from a missing
outcome through `found`, `reason`, and outcome completeness metadata.

## Relationship To Other Projections

`factualSessionProjection(...)` remains the lower-level deterministic grouping
of observed session, thread, turn, prompt, plan, command, visible-summary, and
file-attribution evidence. `turnOutcome(...)` is a more outcome-oriented view
for one turn, still entirely factual and evidence-backed.

`SessionWorkModel` remains the PE-owned composition layer above factual
projection and active semantic inference records. Turn Outcome is not a
semantic field inside SessionWorkModel; it is a factual input that later
Session Outcome and Smart Session work may consume.

Deferred work includes Session Outcome aggregation, richer dedicated validation
evidence links, approval/error/compaction evidence, milestone and blocker
semantics, progress/risk/architecture semantics, cross-session retrieval and
handoff assembly, and Knowledge Compiler output.

## Example

```swift
import ProvenanceEngineContracts
import ProvenanceEngineSDK

let client = try ProvenanceEngineClientFactory()
    .sqliteClient(databaseURL: databaseURL)

let response = try await client.turnOutcome(
    ProvenanceTurnOutcomeRequest(turnID: "turn-pe-123")
)

guard let outcome = response.outcome else {
    print(response.reason ?? "missing outcome")
    return
}

print(outcome.projection.revisionID)
print(outcome.completeness.status)

if let validation = outcome.validationsAttempted.first {
    print(validation.command)
    print(validation.resultStatus ?? "unknown")

    for reference in validation.evidence {
        print(reference.evidenceID)
        print(reference.sourceKind)
        print(reference.adapterVersion ?? "no adapter version")
    }
}
```

The validation claim above is inspectable because it carries the command
evidence references that caused the projector to classify the command as a
validation attempt. A consumer should not treat that validation as proving the
whole turn valid unless a later factual or semantic contract explicitly
supports that stronger claim.
