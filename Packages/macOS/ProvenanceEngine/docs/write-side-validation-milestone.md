> **Historical record:** This document records the state at the time it was written and is not the current project-status authority. See `docs/generated/project-status.md`.

# V1 Write-Side Validation Milestone

Status: complete in provenance-engine as of 2026-07-25.

This milestone validated whether a non-bmux producer can record engineering activity through the public Provenance Engine SDK without understanding storage internals or query implementation.

## Validation Artifacts

- Generic producer example: `Examples/GenericAgentRuntime/main.swift`.
- Consumer-focused SDK tests: `Tests/ProvenanceEngineSDKTests/WriteSideProducerSDKTests.swift`.
- Projection rebuild proof: `Tests/ProvenanceEngineSQLiteTests/ProjectionRebuildValidationTests.swift`.

The SDK tests import only `ProvenanceEngineContracts` and `ProvenanceEngineSDK`. They do not import `ProvenanceEngineSQLite`, open SQLite directly, delete projection tables, or assert storage schemas.

## Generic Producer Result

The `GenericAgentRuntime` example records these producer-side facts through `ProvenanceEngineClient.appendEvent(...)`:

- session started
- task created
- command executed
- file modified
- checkpoint recorded
- validation completed
- artifact generated
- session completed

The producer supplies stable domain identifiers, timestamps, confidence, source classification, origin/scope metadata, and typed payload records. It does not read or write SQLite tables and does not know about projections, indexes, rebuild behavior, or query implementation.

## Public SDK Review

### Did the write API feel natural?

Mostly yes. `appendEvent(...)` is the right primitive for the current architecture because the producer records immutable evidence and the engine owns current-state query behavior. The extensible `ProvenanceEventType` also allowed generic producer events such as `command_executed`, `file_modified`, `validation_completed`, and `artifact_generated` without a public API change.

### What was awkward?

Payload construction is verbose. A producer has to understand the current provenance record shapes well enough to build `ProvenanceRepositoryRecord`, `ProvenanceWorktreeRecord`, `ProvenanceSessionRecord`, `ProvenanceWorkItemRecord`, `ProvenanceContributionRecord`, `ProvenanceCheckpointRecord`, `ProvenanceChangeSetRecord`, `ProvenanceFileChangeRecord`, and `ProvenanceValidationRunRecord` consistently.

The awkwardness is domain-model verbosity, not storage leakage. It may justify producer-oriented convenience builders later, but this milestone does not justify changing the write primitive itself.

### Did implementation details leak?

No storage implementation leaked through the public producer path. The generic producer did not need knowledge of SQLite, projection tables, indexes, schema migrations, repair metadata, or rebuild mechanics.

One important implementation-adjacent constraint remains visible as a domain responsibility: producers must use stable IDs consistently across related evidence. For example, file changes, checkpoints, validation runs, and contributions must refer to the same worktree/contribution/checkpoint identifiers for the engine to connect query results.

### Were provenance concepts intuitive?

The main concepts were intuitive for engineering evidence:

- `source` describes how the claim was obtained: observed, declared, inferred, reconciled, or unattributed.
- `confidence` describes reliability.
- `evidenceOrigin` identifies the producing system.
- `evidenceScope` identifies the ownership boundary.
- typed payload records describe observable repository, session, task, file, checkpoint, and validation facts.

The distinction between `eventType` and typed payload may need explicit docs for new producers. `eventType` names the occurrence; payload records update the engine-owned projections.

### What would another engineering team struggle with?

A new team would likely ask for examples that show which payload records belong with common events. The hardest part is not calling the SDK; it is choosing stable IDs and deciding when an event should include a full projection record versus only a forward-compatible event type with no current-state payload.

### What API changes are justified?

No public API redesign is justified by this validation. The evidence supports keeping `appendEvent(...)` as the V1 write primitive.

Potential later improvements should be treated as convenience APIs rather than architectural changes:

- documented producer recipes for common event shapes
- optional helper builders for common session/task/checkpoint/file/validation events
- naming guidance for stable producer IDs and custom event types
- an explicit artifact payload shape if artifact provenance becomes a real query requirement

## Deterministic Responsibility Review

The boundary held:

- Producers emitted facts: observed sessions, task declarations, commands, file changes, checkpoints, validation runs, and completion facts.
- The engine derived current context, active sessions, file explanation links, validation ordering, and completed-session exclusion from active work.
- The producer did not compute current session state, active work, file explanations, session relationships, knowledge summaries, or engineering conclusions.

The SDK naturally supports the intended direction: facts go in; engine-owned interpretation comes out through read APIs.

## Projection Rebuild Proof

`ProjectionRebuildValidationTests.repairRebuildsDeletedProjectionsToIdenticalQueryResults` demonstrates the required architecture sequence:

```text
events

delete projections

rebuild projections

identical query results
```

The test seeds events, captures query responses, deletes projection rows, confirms the current-context query can no longer find the worktree, repairs projection drift through ledger replay, and verifies that worktrees, current context, file explanation, and session tree query responses are identical to the pre-delete responses.

This keeps the event ledger as the system of record and validates current-state projections as disposable derived state.

## V1 Readiness Reassessment

Write-side confidence now broadly matches read-side confidence for V1 local-first use:

- Read side: validated by Session Tree, File Explanation, and Current Context migrations.
- Write side: validated by a generic non-bmux producer using public SDK append calls.
- Storage boundary: still hidden from public producers and consumers.
- Determinism: projection rebuild from the event ledger is covered by direct engine validation.

Remaining confidence gaps are not V1 architecture blockers. They are future product capabilities: capture reliability, retry/outbox behavior, daemon/service transport, GitHub ingestion, semantic retrieval, Knowledge Compiler, and shared organizational evidence stores.

## Conclusion

The success statement is satisfied for the current V1 architecture:

> A new engineering team could build a producer for the Provenance Engine using only the public SDK without studying bmux or implementation internals.

The team would need concise producer examples and domain-shape guidance, but it would not need bmux knowledge or storage knowledge. The validated next step is to continue building capabilities on the existing write primitive rather than redesigning the public API prematurely.
