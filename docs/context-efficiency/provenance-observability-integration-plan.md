# Bmux Provenance: Observability Integration Plan

Status: planning integrated on 2026-07-19. This plan extends the context-efficiency, subsession/delegation, semantic provenance, retrieval, and handoff roadmap. It does not replace `WorkProvenance`, `BmuxContextEfficiency`, or raw evidence storage.

## Purpose

Add observability to the provenance pipeline so Bmux can explain not only what engineering work happened, but how a conclusion was derived, how reliable it was, how it was used, and whether it later proved helpful or wrong.

Observability must help developers detect missing or delayed provenance, inspect incorrect identity and attribution decisions, measure coverage separately from accuracy, understand why knowledge records were generated, inspect why retrieval selected or omitted records, compare active and candidate algorithms, collect corrections, detect regressions, and evaluate changes over time.

This must not become a parallel provenance system.

## Store Ownership

`WorkProvenance` remains the authoritative semantic history of engineering work. It owns repositories, worktrees, sessions, subsessions, external identities, work items, contributions, delegations, file changes, commands, validations, commits, artifacts, decisions, findings, invariants, failed approaches, open questions, typed relationships, knowledge records, accepted and rejected results, source references, confidence, freshness, and supersession.

`BmuxContextEfficiency` remains the read-only telemetry and imported-evidence system for Codex and similar sources. It owns rollout events, model calls, token telemetry, tool calls, tool outputs, parser errors, command candidates, reference candidates, source offsets, and evidence locations. Do not move semantic provenance ownership into this package.

Create a separate logical observability store, initially `ProvenanceObservability.sqlite`. It owns pipeline traces, stage durations and failures, identity-resolution attempts, attribution attempts, derivation explanations, projection runs, invalidation events, retrieval traces, ranking explanations, context-package consumption, corrections and feedback, evaluation results, shadow comparisons, quality snapshots, and algorithm/configuration versions.

This database is operational and analytical. It is not authoritative engineering history and should be safe to delete or rebuild where source data permits.

## Pipeline Model

The provenance architecture should become:

```text
Raw evidence
-> observation and ingestion
-> identity reconciliation
-> attribution
-> authoritative provenance events
-> authoritative projections
-> semantic records
-> knowledge projections
-> retrieval and ranking
-> bounded context package
-> agent consumption
-> downstream engineering outcome
```

Observability instruments every transition, from ingestion trace through identity-resolution trace, attribution trace, projection trace, retrieval trace, context-package trace, consumption trace, and feedback/outcome trace.

Every important derived result should answer:

- What source evidence contributed to this result?
- Which rule, algorithm, model, prompt, and version interpreted it?
- What confidence was assigned, and why?
- Was it later confirmed, corrected, rejected, superseded, or marked stale?
- Was it selected for an agent?
- Is there evidence that the agent used it?
- What downstream outcome followed?

## Roadmap Integration

Do not create one late observability milestone. Add observability requirements to every provenance milestone:

- Milestone 3: command, reference, and subsession lifecycle attribution, plus ingestion and identity observability.
- Milestone 4: context-efficiency profiler, plus telemetry quality and import observability.
- Milestone 5: delegation and semantic provenance, plus attribution and derivation observability.
- Milestone 5.5: agent retrieval and knowledge projection, plus projection and retrieval observability.
- Milestone 6: coordination UI, plus pipeline health, trace, and quality views.
- Milestone 7: shadow lifecycle engine, plus active-versus-candidate policy comparisons.
- Milestone 8: assisted handoffs and context packages, plus consumption and downstream-outcome observability.

Observability phases overlap the main roadmap: O0 foundations and architecture investigation, O1 pipeline tracing, O2 identity and attribution explainability, O3 projection lineage, O4 feedback and correction, O5 retrieval observability, O6 evaluation harness, O7 shadow experimentation, O8 outcome measurement, and O9 operational UI.

## Design Principles

- Observe attempts, unresolved outcomes, ambiguous outcomes, failures, retries, timeouts, conflicts, dropped records, filtered records, skipped records, and degraded operation.
- Track coverage, accuracy, and confidence calibration separately. A higher attribution rate is not automatically better.
- Preserve derivation lineage: inputs, evidence, rules, generator versions, model/prompt versions where applicable, confidence components, timestamps, and output hashes.
- Prefer deterministic observability for metrics, trace correlation, replay, and evaluation.
- Avoid circular authority. Observability may report likely wrong provenance, but must not silently rewrite authoritative provenance.
- Version all behavior with named subsystem versions in addition to any application Git commit.
- Keep observability bounded. Store identifiers, references, counts, hashes, durations, structured explanations, and compact redacted samples where needed.
- Do not duplicate complete transcripts, command output, rollout payloads, or diffs.
- Observability is normally non-blocking. A failed observability write should not block provenance event append, projection update, lifecycle persistence, retrieval, or context assembly.

## Correlation Identifiers

Introduce stable correlation identifiers that coexist with domain identifiers:

```text
pipeline_run_id
pipeline_stage_execution_id
observation_id
derivation_id
projection_run_id
retrieval_run_id
context_package_id
evaluation_run_id
shadow_comparison_id
```

Domain identifiers such as `repository_id`, `worktree_id`, `session_id`, `delegation_id`, `work_item_id`, `contribution_id`, `file_change_id`, `validation_id`, `decision_id`, `finding_id`, and `knowledge_record_id` remain authoritative.

A single evidence item should be traceable from imported telemetry or hook evidence through identity resolution, attribution, event append, projection, retrieval, context package generation, consumption, and feedback.

## Initial Schema

Implement incrementally. Do not add every table in the first slice.

Initial records:

- `ProvenancePipelineRunRecord`: bounded processing operation with pipeline kind, trigger, repository/worktree/session scope, status, implementation/configuration versions, timestamps, input/output/warning/error counts, and bounded error summary.
- `ProvenancePipelineStageExecutionRecord`: stage name/version, status, input/output/skipped/unresolved/conflict counts, timestamps, duration, and bounded error fields.
- `ProvenanceDerivationRecord`: target entity, derivation kind, generator ID/version, input/evidence/rule/confidence references, overall confidence, input/output hashes, and pipeline run.
- `ProvenanceFeedbackRecord`: explicit judgment, corrected value where applicable, reporter, reason, evidence references, and timestamp.
- `ProvenanceRetrievalRunRecord`: repository/session scope, question hash, scope, retrieval/ranking/token-budget/index versions, candidate counts, filter counts, selected count, estimated tokens, duration, and status.
- `ProvenanceRetrievalCandidateRecord`: knowledge record, source, ranking components, final score, selected or omitted state, omission reason, and token allocation.

Initial pipeline kinds: `rollout_import`, `lifecycle_ingestion`, `identity_reconciliation`, `command_attribution`, `file_attribution`, `event_projection`, `semantic_projection`, `knowledge_projection`, `retrieval`, `context_assembly`, and `evaluation`.

Initial statuses: `running`, `succeeded`, `partially_succeeded`, `failed`, `cancelled`, and `degraded`.

Initial feedback judgments: `correct`, `incorrect`, `partially_correct`, `missing`, `stale`, `irrelevant`, `misleading`, `duplicate`, and `unresolved`.

Initial retrieval omission reasons: `duplicate`, `stale`, `superseded`, `below_confidence_threshold`, `outside_scope`, `lower_rank`, `token_budget`, `record_limit`, `invalid_evidence`, and `privacy_filter`.

## Explainability Requirements

Identity-resolution attempts must record input identity type and hashed value, candidate count, selected entity, confidence, ambiguity margin, candidate scores, rules applied, outcome, unresolved reason, resolver version, and timestamp.

Attribution attempts must record attribution type, source entity, candidate count, selected target, confidence, confidence components, evidence references, competing candidates, outcome, unresolved reason, attribution version, and timestamp.

Preserve these distinctions:

```text
observed during session
possibly caused by session
causally attributed to session
explicitly declared by session
confirmed by parent or human
```

Do not treat a dirty-file observation alone as causal attribution.

## Projection And Retrieval Observability

Projection runs should record projection kind, scope, input version/hash/count, generator version, output hash/count, inserted/updated/unchanged/invalidated/superseded counts, duration, status, and timestamps.

Invalidations should record target entity, projection kind, reason code, trigger entity, creation time, and rebuild time. Initial reasons include file changed, decision accepted/superseded, finding resolved/superseded, delegation completed or disposition changed, validation added, commit linked, session completed, external identity reconciled, generator version changed, and manual rebuild.

Every retrieval request should trace scope resolution, exact-entity resolution, structured lookup, FTS lookup, optional semantic lookup, graph expansion, deduplication, freshness/supersession/confidence filtering, ranking, token allocation, and context assembly.

Context-package consumption is distinct from retrieval. Supplying context is not proof that it was useful. Usage signals must be classified as explicit, strongly inferred, weakly inferred, or unknown; weak inference must not be reported as confirmed usage.

## Metrics And Evaluation

Track operational health independently from semantic quality: pipeline runs, failures, degraded runs, stage durations, stage errors, ingestion lag, events received/deduplicated/dropped/skipped/unresolved, projection failures/retries, database lock duration, stale/pending projections, and orphaned evidence references.

Track coverage using meaningful denominators: repository resolution, worktree resolution, subsession parent resolution, command-to-session attribution, causal file attribution, validation linkage, commit linkage, decision/finding evidence coverage, and knowledge derivation coverage.

Track quality separately for attribution precision/recall/calibration, projection determinism/freshness/replay consistency, retrieval required-record recall and stale/superseded leakage, consumption usage and missing-context signals, and associated engineering outcome correlations. Do not claim causality without controlled comparison.

Build deterministic evaluation fixtures for identity, attribution, projection, retrieval, and context-package behavior before relying heavily on production metrics or changing ranking/attribution algorithms.

Unknown labels are not incorrect labels and must not reduce confidence by themselves.

## Shadow Mode

Meaningful algorithm changes should support shadow execution. The active algorithm produces the operational result; the candidate algorithm processes the same input into shadow-only rows; comparison records agreement, differences, and expected downstream impact.

Applicable systems include identity resolution, parent-child reconciliation, command/file/commit attribution, semantic extraction, knowledge projection, retrieval ranking, token budgeting, and lifecycle recommendations.

Begin with one subsystem, preferably file attribution or retrieval ranking. Do not shadow every subsystem at once.

## Privacy And Retention

Do not copy full transcripts, command output, complete diffs, or raw rollout payloads into observability tables. Hash sensitive queries when raw text is unnecessary, use evidence references, redact secrets from compact diagnostic samples, enforce repository boundaries, support repository-level disablement, support retention policies, bound candidate-ranking traces, sample high-volume successes only when necessary, and never sample errors or corrections by default.

For retrieval observability, store raw user questions only when explicitly allowed. Otherwise store question hash, extracted entities, scope, query length, and query category.

## CLI Surface

Initial read-only commands:

```bash
bmux provenance observability health
bmux provenance observability coverage --repository <id>
bmux provenance observability trace --pipeline-run <id>
bmux provenance observability derivation --entity-type knowledge-record --entity-id <id>
bmux provenance observability attribution --entity-type file-change --entity-id <id>
bmux provenance observability retrieval --retrieval-run <id>
bmux provenance observability feedback list --repository <id>
bmux provenance observability evaluation run
bmux provenance observability evaluation compare --baseline <version> --candidate <version>
bmux provenance observability shadow report --subsystem file-attribution
```

JSON output must be bounded, versioned, repository-scoped, raw-payload-safe, explicit about unknown data, explicit about confidence, and explicit about measured versus inferred values.

Do not make UI the first observability deliverable. After CLI and evaluation quality are established, add pipeline health, trace explorer, and quality dashboard views.

## Implementation Phases

### O0 Architecture Investigation

Before implementation, inspect the current provenance, context-efficiency, subsession, delegation, retrieval, migration, CLI, logging, and diagnostics code.

Produce the O0 report before adding observability schema or code.

### O1 Foundations

Implement only the smallest complete slice: pipeline runs, stage executions, correlation identifiers, subsession lifecycle trace, basic trace CLI, and tests.

Instrument one narrow flow: AgentSubsessionLifecycleChange -> WorkProvenance event append -> projection update.

Acceptance: one lifecycle event can be traced end to end; success and failure are distinguishable; stage duration is visible; event and projection IDs are correlated; no raw transcript data is duplicated.

### O2-O9 Expansion

O2 covers identity and attribution explainability. O3 covers projection lineage. O4 covers feedback and correction. O5 covers retrieval observability. O6 covers deterministic evaluation. O7 covers shadow mode. O8 covers consumption and outcome correlations. O9 covers operational UI after CLI and evaluation foundations are proven.

## Failure Isolation

Default behavior: primary provenance operation succeeds; observability write fails; Bmux records a bounded application error, marks the telemetry gap where possible, and continues the primary workflow. Exceptions are explicit evaluation and replay commands where observability output is the requested product.

## Tests And Acceptance

Tests should cover store persistence, migration, reopening, trace success and failure, skipped and unresolved stages, duplicate events, degraded telemetry dependencies, derivation lineage, missing-evidence warnings, stable hashes, version persistence, confidence components, feedback/correction/invalidation, retrieval selected and omitted candidates, deterministic ranking, query hashing, cross-repository isolation, secret redaction, and bounded diagnostic samples.

Initial observability integration is complete when stable correlation IDs exist; pipeline runs and stages are inspectable; subsession lifecycle ingestion is traceable end to end; unresolved/conflicting results are visible; derived records identify generator versions; corrections are explicit; evaluation detects regressions; at least one subsystem supports shadow comparison; coverage and correctness remain separate; observability avoids large raw evidence duplication; repository isolation is enforced; CLI output is bounded/versioned; existing WorkProvenance and BmuxContextEfficiency tests remain green; observability write failures do not block provenance processing; and observability failures are logged through normal application logging.

## Codex Working Instructions

Begin with investigation. Read current provenance, context-efficiency, subsession, delegation, retrieval, migration, and CLI code before choosing final type names. Follow repository-local naming and architectural patterns. Do not assume this document's proposed schema is final.

Before implementation, return the O0 report listed above. Then implement only the smallest complete O1 slice. Do not begin with dashboards, learned quality models, semantic evaluation, outcome claims, organization-wide aggregation, broad sampling infrastructure, automatic algorithm promotion, automatic correction, or every proposed observability table.

Use subsessions for bounded research tasks such as observability schema review, existing logging audit, failure-isolation review, evaluation-fixture design, privacy review, and CLI design review. The parent session remains responsible for architectural consistency, store ownership, avoiding circular provenance, migration sequencing, versioning consistency, failure isolation, final acceptance, and updating the integrated roadmap.
