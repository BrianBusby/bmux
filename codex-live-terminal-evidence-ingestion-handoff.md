# Handoff: Restore and Implement Live Ordinary-Codex Evidence Ingestion

## Introduction

We found an architectural gap in the current bmux + Provenance Engine roadmap that needs to be reconciled before the richer session-understanding work gets much farther.

The project already has most of the surrounding pieces:

- Ordinary Codex terminal sessions are detected and tracked by bmux.
- Codex hooks provide lifecycle and some prompt/session information.
- Agent Chat / Codex app-server sessions can produce rich structured coding-agent evidence.
- Provenance Engine has a richer coding-agent evidence model and factual session projections.
- The React Smart Session surface and initial SessionWorkModel consumer exist.
- Historical ordinary-Codex JSONL transcripts can now be imported into canonical PE coding-agent evidence through the work merged in PR #66.

However, ordinary live Codex terminal sessions still do not continuously produce the same coherent rich evidence while they are running.

The architecture documentation explicitly identifies live transcript-backed ingestion as planned. There was also recent Project Truth work naming a slice:

```text
live_terminal_codex_evidence_ingestion
```

but the Project Truth PR carrying that roadmap update was closed without merging during the recent sequencing/reconciliation work.

As a result, the architectural intent still exists, but the current canonical executable roadmap appears to have lost the explicit slice.

There is also an important correctness problem that this work must solve, not merely a missing background tailer:

Hook events and Codex transcript events are different evidence sources describing the same underlying coding-agent session/turn. They must not become duplicate logical sessions, turns, prompts, or activities in PE.

For example, if PE receives something conceptually equivalent to:

```text
hook-codex-turn-X
transcript-codex-turn-Y
```

for the same logical Codex turn, downstream consumers should not have to discover that those are duplicates.

PE's factual layer should reconcile the evidence into one coherent logical turn before semantic inference and Smart Session consume it.

This task is therefore both:

- Restore the missing roadmap/data-foundation slice.
- Implement the first robust live ordinary-Codex ingestion/reconciliation path.

Do not treat this as a Smart Session UI problem.

Do not solve it in the semantic inference layer.

Do not require the user to run Codex through Agent Chat.

## Goal

Make an ordinary Codex CLI session running inside bmux continuously converge into PE's canonical coding-agent evidence and factual session model, using its live Codex JSONL transcript plus the existing hook/runtime evidence.

The intended data flow should become approximately:

```text
ordinary Codex CLI
       |
       +-- bmux lifecycle/hooks
       |
       +-- Codex JSONL transcript
                  |
                  v
          bmux capture/adaptation
                  |
                  v
        canonical PE evidence writes
                  |
                  v
       evidence identity/reconciliation
                  |
                  v
        factualSessionProjection
                  |
                  v
          SessionWorkModel
                  |
                  v
       semantic inference / Smart Session
```

The hook path and transcript path are complementary evidence producers, not competing session models.

## First: Inspect and Reconcile Current Project Truth

Before implementing anything, inspect the actual current state on main.

At minimum inspect:

- `project/project-state.yaml`
- `docs/generated/nested-roadmap.md`
- `docs/generated/project-status.md`
- `docs/roadmap.md`
- `docs/provenance-integration.md`
- Relevant PE session/evidence architecture docs
- The implementation merged by PR #66
- The abandoned/closed Project Truth work around PR #65 if useful
- Current PR #67 / milestone inference work so this change does not accidentally collide with active semantic work

Determine whether `live_terminal_codex_evidence_ingestion` exists under another name or was intentionally replaced.

Do not blindly recreate old planning if the current architecture has superseded it.

If the capability is genuinely absent, restore it as an explicit Project Truth slice.

A reasonable hierarchy would be something along these lines:

```text
Richer Session Understanding
  Evidence and Factual State
    Normal Coding-Agent Evidence Ingestion
      Codex transcript canonical evidence import       [implemented]
      Live terminal Codex evidence ingestion           [planned/ready]
```

Use the actual current Project Truth taxonomy rather than forcing these exact names if the schema has evolved.

## Roadmap Requirements

The roadmap must clearly distinguish:

### Already Implemented

Historical/replay import of existing Codex transcripts into canonical PE evidence.

That is the PR #66 capability.

### Missing Capability

Live incremental ingestion of a currently-running ordinary Codex terminal session.

### Later Work

Semantic interpretation such as:

- Milestone inference
- Blockers
- Approach changes
- Validation/risk
- Architecture understanding
- Cross-session semantic briefs

Those semantic layers should consume reconciled factual session evidence.

They should not be responsible for repairing duplicate hook/transcript identities.

## Important Sequencing Decision

Inspect the dependencies carefully.

Do not unnecessarily derail the currently active milestone-inference PR merely because this gap was found.

However, establish the correct dependency boundary going forward:

Any consumer that claims a coherent factual representation of ordinary live Codex sessions must depend on canonical live ingestion/reconciliation being available and validated.

It may be valid for generic semantic infrastructure to continue in parallel using existing fixtures/evidence.

It is not valid to declare ordinary Codex live-session fidelity solved while hook and transcript evidence can independently appear as separate logical work.

Encode the dependency/gate at the narrowest correct point.

## Implementation Target

Implement a first live-ingestion slice for ordinary Codex terminal sessions inside bmux.

The implementation should reuse the transcript parsing/canonicalization machinery already created for historical import wherever possible.

There should not be two independent Codex transcript interpretation implementations unless there is a compelling architectural reason.

Prefer something conceptually like:

```text
Codex JSONL
   |
   v
shared transcript adapter/parser
   |
   +-- batch historical importer
   |
   +-- incremental live tailer
             |
             v
       canonical PE writes
```

Batch import and live ingestion should differ primarily in delivery mechanics, not evidence semantics.

## Live Transcript Discovery

Bmux already knows substantial information about ordinary Codex sessions, including some combination of:

- Provider/session identity
- Transcript path
- Surface
- Workspace
- Current working directory
- PID/process identity
- Repository/worktree context

Use authoritative session tracking that already exists.

Do not rediscover transcripts through fragile "newest JSONL file" heuristics when a known session/transcript binding exists.

A live Codex session should establish something equivalent to:

```text
Bmux session identity
        |
        v
Codex provider session/thread identity
        |
        v
Codex transcript path
        |
        v
PE provenance session identity
```

That relationship should remain stable across incremental ingestion.

## Tailing Behavior

For an active transcript, implement incremental consumption rather than rereading the entire file on every update.

The tailer needs durable or reconstructable progress information sufficient to handle:

- Normal append
- Delayed writes
- Multiple JSONL records arriving together
- File replacement/recreation where applicable
- Application restart
- Session resume
- Duplicate observations
- Incomplete final lines
- Parser failures
- Session completion

The exact mechanism can be selected after inspecting existing transcript/tailer infrastructure.

Possible mechanisms include:

- File-system notifications with reconciliation reads
- Actor-owned incremental polling
- Existing bmux transcript tail infrastructure
- A hybrid notification + periodic reconciliation approach

Favor correctness and simplicity over pretending filesystem events are perfectly reliable.

A missed notification must not permanently lose evidence.

## Do Not Tail Every Codex Transcript Globally

The live path should be scoped to known/relevant bmux-managed Codex sessions.

Avoid introducing an always-running recursive watcher over the entire Codex session history unless the existing architecture provides a strong reason for doing so.

Historical reconciliation belongs to the batch importer.

Live ingestion belongs to known active/recent session bindings.

## Canonical Evidence Identity

This is one of the most important requirements.

Historical import is already intended to be idempotent through stable evidence IDs.

Live ingestion must use the same canonical identity rules.

The same logical transcript record seen:

- During live tailing
- During restart reconciliation
- During a later historical import

must not produce three different evidence records.

Design stable identities from durable provider/session/turn/item identity where available.

Only fall back to deterministic transcript-derived identities when provider-native identities are unavailable.

## Hook/Transcript Reconciliation

Do not assume hook events and transcript records share the same identifiers.

Create an explicit reconciliation strategy.

For each logical entity, determine the strongest available keys.

Examples may include:

```text
session
  provider
  provider session/thread ID
  transcript path
  PE provenance session ID
```

```text
turn
  provider turn ID when available
  session ID
  sequence/order
  temporal relationship
  prompt association
```

```text
prompt
  provider/session/turn identity
  normalized submitted content
  hook submission evidence
  transcript user-message evidence
```

```text
command/tool activity
  provider item/call ID when present
  containing turn
  command/tool identity
```

Do not use fuzzy semantic text matching as the primary identity mechanism.

Text and time correlation may be a fallback when Codex exposes no stronger identifier.

## One Logical Turn, Multiple Evidence Sources

The PE model should support the concept:

```text
Logical Turn T
   +-- hook observation
   +-- transcript prompt observation
   +-- transcript plan observation
   +-- transcript command observation
   +-- transcript assistant-visible summary
   +-- lifecycle completion observation
```

rather than:

```text
Hook Turn
Transcript Turn
Prompt Turn
Command Turn
```

all independently appearing as user-visible turns.

The evidence ledger can retain multiple immutable observations.

The projection should reconcile those observations into one factual logical entity.

Never destroy provenance merely to hide duplication.

## Preserve Provenance

When two sources describe the same logical fact, retain enough provenance to answer:

- Which source observed it
- When it was observed
- Which event/evidence record supplied it
- Whether another source corroborated it

For example, a submitted prompt might have:

```text
logical prompt
  observed by:
    - codex hook UserPromptSubmit
    - codex transcript user message
```

The projection should show one prompt.

The evidence history should still show both observations where appropriate.

## State Convergence

A turn may first appear only partially.

Example:

```text
t0 hook says prompt submitted
t1 transcript contains user prompt
t2 transcript contains command call
t3 transcript contains visible assistant response
t4 hook/session lifecycle indicates idle/completed
```

PE should converge the factual turn over time rather than create a fresh replacement turn for every stage.

Support transitions such as:

```text
observed -> active -> completed
```

and where evidence supports them:

```text
failed
interrupted
```

Do not fabricate a completion status when the evidence does not establish one.

## Transcript Facts to Capture

Capture policy-approved, user-visible or operationally meaningful facts that Codex exposes and PE already has contracts for.

Likely candidates include:

- Provider session/thread identity
- Provider turn identity
- Submitted user prompts
- Provider plan updates
- Completed command/tool facts
- File-change attribution
- Visible assistant output or bounded visible reasoning summaries when already supported
- Turn start/completion lifecycle
- Model/configuration metadata when reliably exposed and already within contract scope

Inspect the actual JSONL schema and existing importer rather than assuming these fields.

## Explicit Non-Goals

Do not expand this slice into:

- Hidden chain-of-thought storage
- Raw reasoning-delta persistence
- Unrestricted full assistant transcript persistence
- Token-stream storage
- Full raw provider-envelope persistence
- Approval-policy redesign
- Semantic milestone inference
- Blocker inference
- Architecture inference
- Knowledge Compiler work
- Cross-session context injection
- Smart Session redesign
- Global Codex configuration modification

This is a factual ingestion/reconciliation slice.

## PE Ownership Boundary

Maintain the current architecture.

Bmux owns:

- Provider/session discovery
- Transcript file access
- Incremental tailing
- Hooks
- Runtime lifecycle
- Provider-specific parsing/adaptation
- Live UI/runtime interaction
- Capture/delivery reliability

Provenance Engine owns:

- Accepted durable evidence
- Canonical evidence contracts
- Deterministic factual projections
- Logical evidence reconciliation where that belongs to the domain model
- Provenance relationships
- Revisioned read models

Do not add direct writes to PE projection tables from bmux.

Use public PE contracts/SDK boundaries.

## Factual Projection Acceptance Requirement

Acceptance:

An ordinary Codex CLI turn observed through both bmux hooks and the Codex transcript should appear as one logical turn in `factualSessionProjection`.

Evidence/provenance from both sources should remain available where present.

That is more important than merely proving that the transcript tailer reads bytes.

Also test the inverse cases:

- Hook evidence arrives before transcript.
- Transcript arrives before corresponding hook.
- Only hook evidence exists.
- Only transcript evidence exists.
- Duplicated transcript event.
- Application restart and replay.
- Later batch import of evidence already ingested live.

All should converge predictably.

## Required Tests

Add focused tests at the appropriate layers.

At minimum cover:

- Incremental JSONL append ingestion.
- Partial final JSONL line: do not consume until complete.
- Multiple lines appended together.
- Idempotent replay of the same transcript records.
- Live-ingested record followed by batch historical import: no duplicate canonical evidence.
- Hook-first ordering.
- Transcript-first ordering.
- Hook + transcript prompt deduplication/reconciliation.
- Hook + transcript logical-turn reconciliation.
- App restart/recovery from an already partially consumed active transcript.
- Session resume where identity remains the same provider session.
- Two simultaneous Codex sessions: no transcript/session cross-contamination.
- Factual projection: one logical turn rather than duplicate source-specific turns.
- Provenance: evidence sources remain inspectable even after logical reconciliation.

Use real representative Codex JSONL fixture shapes where possible.

## Diagnostics

Add enough diagnostics that future failures can be localized.

It should be possible to determine:

- Which bmux session?
- Which Codex transcript?
- What offset/revision was consumed?
- What transcript record was adapted?
- What stable evidence ID was produced?
- Was it inserted or already known?
- What logical session/turn did it reconcile to?
- What factual projection revision resulted?

Do not log unrestricted prompt/transcript contents merely for diagnostics.

Use IDs, event kinds, counts, offsets, hashes, and bounded metadata where appropriate.

## Performance

This work must not create a heavy main-thread parsing path.

Transcript reading/parsing should remain off the UI/main actor.

Avoid repeatedly reparsing complete large JSONL transcripts.

Avoid high-frequency SQLite churn when several transcript records can safely be processed as a bounded batch.

But do not sacrifice correctness for micro-optimization in the first slice.

## Historical Importer Refactor

If necessary, refactor the PR #66 importer so batch and live ingestion share a proper reusable layer.

A desirable shape might be:

```text
CodexTranscriptReader
CodexTranscriptRecord
CodexTranscriptEvidenceAdapter
CanonicalEvidenceWriter
```

with separate orchestration:

```text
CodexTranscriptBatchImporter
CodexTranscriptLiveIngestor
```

Names are illustrative only.

Follow the repository's existing conventions.

## Project Truth Updates

Once the design is understood, update Project Truth so the state is explicit.

Record:

- Historical Codex transcript canonical import as implemented
- Live terminal Codex evidence ingestion as its own slice
- Its dependencies
- What it enables
- Maturity/status
- Expected contract domains
- Expected code areas
- Conflict domains
- Acceptance criteria
- Appropriate validation gate before downstream ordinary-session fidelity relies on it

Regenerate all generated docs with the canonical project tooling.

Do not manually edit generated roadmap/status files.

## Architecture Documentation

Update relevant architecture/provenance documentation to state clearly:

```text
Agent Chat:
  high-fidelity structured live provider telemetry

Ordinary Codex CLI:
  hooks + live transcript adaptation

Both:
  converge into the same PE coding-agent evidence/factual session model
```

The distinction should be about capture mechanism, not two different provenance models.

## Relationship to Agent Chat

Agent Chat remains useful and should not be dismantled.

Its Codex app-server path can expose information that ordinary JSONL transcripts may not expose.

The goal is not necessarily byte-for-byte evidence parity.

The goal is:

Ordinary Codex CLI sessions should reach the richest factual PE representation that the available transcript/hooks legitimately support, without requiring Agent Chat.

Unknown information should remain unknown.

Do not synthesize missing facts merely to make the paths look equivalent.

## Relationship to Smart Session

Smart Session should not know or care whether a fact originated from:

- Agent Chat app-server
- Codex transcript
- Codex hook

except when showing provenance/debug detail.

Its normal domain input should be the reconciled PE factual/semantic model.

If Smart Session currently contains source-specific duplication workarounds, identify them, but do not expand this slice into a UI cleanup unless a very small change is required to prove the corrected projection.

## Relationship to Milestone Inference

PR #67 currently works on milestone inference.

Coordinate rather than stepping on it.

If milestone inference can be developed/tested against synthetic or existing canonical evidence, it may continue independently.

This work should ensure that once live ordinary Codex evidence is used in production, milestone inference receives coherent turns rather than source-specific duplicates.

Do not modify milestone semantics merely to compensate for bad evidence identity.

## Deliverable Strategy

Work on a dedicated branch/worktree.

I would prefer the work be split into logical commits, roughly:

1. Project Truth / architecture reconciliation: restore the missing capability and document correct sequencing.
2. Shared transcript adaptation refactor: only if necessary to avoid duplicating the historical importer.
3. Live transcript ingestion: attach incremental transcript ingestion to known ordinary Codex sessions.
4. Evidence identity/reconciliation: ensure hook/transcript observations converge onto logical sessions/turns/prompts.
5. Projection/tests/diagnostics: prove the end-to-end factual behavior.

These do not have to become separate PRs unless the actual dependency structure warrants it.

Prefer one coherent PR if reviewability remains good.

## Success Criteria

This work is successful when I can:

- Open bmux.
- Start a normal Codex CLI session in a terminal.
- Never open Agent Chat.
- Submit several prompts.
- Let Codex run commands/change files/respond.
- Inspect PE while the session is still active.
- See rich factual coding-agent evidence arriving incrementally.
- Open the Session/Smart Session surface.
- See that same ordinary Codex session represented coherently.
- Not see duplicate turns merely because both hooks and transcripts observed them.
- Restart bmux and continue/resume without duplicating previous evidence.
- Run the historical transcript importer afterward and have it remain idempotent.

The architectural invariant should be:

```text
many observations
      |
      v
one canonical evidence graph
      |
      v
one coherent factual session model
      |
      v
semantic understanding
      |
      v
presentation
```

not:

```text
hook model
transcript model
agent-chat model
      |
      v
UI tries to reconcile everything
```

## Final Instruction

Start by auditing the current implementation and Project Truth rather than immediately coding.

Report back briefly with:

- What currently exists
- Whether the missing slice really fell out of Project Truth
- Where the existing PR #66 transcript adapter can be reused
- How ordinary Codex sessions currently expose transcript identity/path
- Your proposed canonical session/turn identity and reconciliation mechanism
- Whether any part of current PR #67 should be gated, left parallel, or rebased around this work

Then update the planning state and proceed with the implementation when the dependencies are clear.

Do not stop at producing a plan if the implementation is dependency-ready.
