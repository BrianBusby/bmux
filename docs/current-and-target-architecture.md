# Current And Target Architecture

This is the short living architecture orientation for bmux and its Provenance
Engine integration. It explains what exists now, what each side owns, and where
the architecture is going. It is intended to be readable in 5-10 minutes by the
user, a new engineer, or Codex starting a slice.

Volatile status is generated from canonical project truth. If this page and the
generated files disagree, trust:

- [generated/project-status.md](generated/project-status.md)
- [generated/repository-status.md](generated/repository-status.md)
- [generated/nested-roadmap.md](generated/nested-roadmap.md)
- [generated/ownership-boundary.md](generated/ownership-boundary.md)

Use [provenance-integration.md](provenance-integration.md) and
[execution-telemetry/architecture.md](execution-telemetry/architecture.md) for
bmux-specific integration details. This page is the current-and-target working
map, not a replacement for durable design references.

## System Purpose

bmux is the interactive product surface for coding-agent work. It owns live
provider sessions, terminals, process/runtime behavior, immediate interaction,
and presentation.

Provenance Engine preserves accepted engineering evidence, derives
deterministic Current State, and provides factual and later semantic projections
that bmux, agents, CLI tools, IDEs, and future services can consume through
public contracts.

Together, the system should make live agent work understandable without turning
raw streams or private transient state into durable project truth by default.

## Ownership Boundary

bmux owns provider acquisition, PTY/process/runtime behavior, live streaming
state, immediate interaction, normalization at the product edge, presentation,
UI, capture policy, optimistic UI, and user-facing fallback behavior.

Provenance Engine owns accepted durable evidence, deterministic Current State,
factual projections, semantic inference, the future `SessionWorkModel`,
milestone semantics, scoped architecture projections, and later knowledge
compilation, storage, retrieval, citation, and context budgeting.

The boundary is intentionally asymmetric: bmux sees more than it persists.
Provenance Engine stores only explicit accepted evidence, then derives reusable
facts and interpretations with provenance.

## Current Architecture

The generated status block later in this document is authoritative for exact
current state, dependency readiness, selected-next work, and active branch or
worktree assignments. The durable architecture keeps bmux runtime acquisition,
PE factual projections, PE semantic inference, semantic messages, and bmux
presentation as separate layers.

```text
Provider events
  Codex / Claude / future coding agents
        |
        v
bmux acquisition and normalization
  provider identity, lifecycle, runtime state, live interaction, UI policy
        |
        v
Accepted PE evidence contracts
  lifecycle, worktree/session facts, workspace display facts,
  coding-agent thread, turn, prompt, plan, completed command,
  visible reasoning summary, and file-change attribution facts
        |
        v
PE durable evidence store
        |
        v
PE deterministic Current State and factual projections
        |
        v
PE semantic inference and semantic messages
  implemented and owned in PE; consumed by bmux UI as adoption slices land
        |
        v
bmux presentation
  sidebars, diagnostics, interaction, fallback, live state, and later semantic
  explanation UI
```

Implemented work should be read from generated Project Truth status. Completion
of one layer does not imply raw stdout/stderr deltas, hidden reasoning,
unrestricted transcripts, validation, semantic milestones, architecture
inference, feedback learning, or Knowledge Compiler artifacts are available
unless generated status says the relevant slice is implemented.

## Target Architecture

The target keeps the live-product loop and durable-knowledge loop connected but
separate.

```text
Provider events
        |
        v
bmux acquisition -> normalization -> accepted evidence submission
        |
        v
PE evidence store -> deterministic Current State -> factual projections
        |                                      |
        |                                      v
        |                              semantic inference
        |                                      |
        |                                      v
        |                              SessionWorkModel
        |                                      |
        |                                      v
        |                              presentation policy
        |                                      |
        |                                      v
        |                                  bmux UI
        |                                      |
        |                                      v
        |                         user feedback and presentation learning
        |
        v
Knowledge Compiler -> Knowledge Store -> Retrieval
        |                                  |
        v                                  v
evidence-linked durable knowledge       agent context / bmux / CLI / IDEs
```

Immediate bmux runtime behavior must remain responsive even if semantic
inference is delayed or unavailable. bmux renders PE-owned semantic state when
it exists, keeps factual/runtime UI independent, and exposes provenance without
duplicating inference in the UI layer.

## Canonical Status

<!-- BEGIN GENERATED: current-target-architecture-status -->
Generated from `project/project-state.yaml` and `project/repo-status.yaml`. For the full generated views, see [project status](generated/project-status.md), [repository status](generated/repository-status.md), and [nested roadmap](generated/nested-roadmap.md).

### Current Active Work

- Active gate: Engineering Observation Period (`engineering_observation_period`) - active
- Active implementation slice: Factual agent session view (`factual_agent_session_view`) - draft
- Bmux repository state: active

### Current Roadmap Lanes

- Bmux and Provenance Engine (`bmux_provenance_platform`) - project; status: active; owner: Provenance Engine
- Richer Session Understanding (`richer_session_understanding`) - program; status: active; owner: Provenance Engine
- Semantic Understanding (`semantic_understanding`) - phase; status: active; owner: Provenance Engine
- Semantic SessionWorkModel Projection (`semantic_session_work_model_projection`) - milestone; status: active; owner: Provenance Engine
- Factual agent session view (`factual_agent_session_view`) - slice; status: active; owner: Bmux

### Major Node Summaries

#### Bmux provider acquisition and runtime observation

- Status: Provider-neutral execution telemetry foundation (`execution_telemetry_foundation`): implemented, delivery merged, acceptance implemented; Claude lifecycle telemetry migration (`claude_lifecycle_telemetry`): implemented, delivery merged, acceptance implemented
- Owns: Provider acquisition, PTY/process/runtime, live streaming state, immediate interaction, normalization, capture policy, and presentation/UI.
- Inputs: Provider runtime events, terminal/process state, user interaction, repository/worktree facts observed by bmux.
- Outputs: Normalized accepted evidence submitted through Provenance Engine public contracts, plus bmux-owned live display state.
- Does not own: Durable evidence semantics, deterministic Current State, semantic inference, milestone meaning, or Knowledge Compiler outputs.
- Related slices: Provider-neutral execution telemetry foundation (`execution_telemetry_foundation`), Claude lifecycle telemetry migration (`claude_lifecycle_telemetry`), Workspace Display Durable Context and Reconciliation (`workspace_display_durable_context`)

#### Provenance Engine durable evidence

- Status: Provenance Engine V1 package (`provenance_engine_v1`): accepted, delivery merged, acceptance accepted; Richer coding-agent evidence foundation (`richer_coding_agent_evidence_foundation`): implemented, delivery merged, acceptance implemented; Public In Process Sdk: not listed; Engine Owned Sqlite Store: not listed; Immutable Ledger: not listed; Schema Identity Validation: not listed; Producer Neutral Lifecycle Recording: not listed; Richer Coding Agent Evidence: not listed
- Owns: Accepted durable engineering evidence, validation, immutable ledger semantics, source/origin/scope metadata, and evidence relationships.
- Inputs: Explicitly accepted events from producers such as bmux; completed or meaningful coding-agent units when policy allows them.
- Outputs: Ledger events and rebuildable evidence relationships for lower projections and later inference.
- Does not own: Raw provider streams, hidden reasoning, unrestricted transcripts, live replay state, or capture policy.
- Related slices: Provenance Engine V1 package (`provenance_engine_v1`), Richer coding-agent evidence foundation (`richer_coding_agent_evidence_foundation`)

#### Deterministic Current State

- Status: Workspace Display Durable Context and Reconciliation (`workspace_display_durable_context`): implemented, delivery open, acceptance implemented; Factual session projection foundation (`factual_session_projection_foundation`): implemented, delivery open, acceptance implemented; Deterministic Current State: not listed; Workspace Display Current State: not listed; Workspace Display Projection Cursors: not listed; Workspace Display Ticket Link Facts: implemented; Workspace Display Ticket Title Facts: not listed; Workspace Display Project Link Facts: not listed; Workspace Display Durable Context: implemented
- Owns: Mechanical, rebuildable present-tense state derived only from accepted evidence.
- Inputs: Immutable ledger events and deterministic reducer rules.
- Outputs: Workspace display facts, current context, session/worktree/file views, and other factual public reads.
- Does not own: Intent, milestones, current activity, risk, architecture meaning, or model-derived conclusions.
- Related slices: Workspace Display Durable Context and Reconciliation (`workspace_display_durable_context`), Factual session projection foundation (`factual_session_projection_foundation`)

#### Factual session projection

- Status: Factual session projection foundation (`factual_session_projection_foundation`): implemented, delivery open, acceptance implemented; Factual projection consumer shape follow-up (`factual_projection_consumer_shape_followup`): implemented, delivery merged, acceptance implemented; Factual agent session view (`factual_agent_session_view`): active, delivery draft, acceptance proposed; Factual Session Projection: not listed
- Owns: Revisioned factual snapshots of observed coding-agent thread and turn evidence for one PE session.
- Inputs: Coding-agent thread, turn, prompt, plan, completed command, visible reasoning summary, and file-change attribution evidence.
- Outputs: Observed thread/turn grouping with latest prompt, plan, commands, summaries, file changes, and ledger revision.
- Does not own: Synthetic turns, inferred intent, milestone hierarchy, session phase, risks, or architecture projection.
- Related slices: Richer coding-agent evidence foundation (`richer_coding_agent_evidence_foundation`), Factual session projection foundation (`factual_session_projection_foundation`), Factual projection consumer shape follow-up (`factual_projection_consumer_shape_followup`), Factual agent session view (`factual_agent_session_view`)

#### Semantic inference framework

- Status: Semantic inference framework (`semantic_inference_framework`): implemented, delivery merged, acceptance implemented; First semantic session inferences (`first_semantic_session_inferences`): implemented, delivery merged, acceptance implemented; Semantic Inference Framework: not listed; Semantic Session Work Model Projection: not listed
- Owns: Evidence-backed inference records, producer versions, confidence, supersession, and semantic projection updates.
- Inputs: Factual projections, bounded evidence packets, plans, commands, reasoning summaries, file changes, and later validation evidence.
- Outputs: Thread intent, turn intent, session phase, current activity, blocker/approach-change facts, and SessionWorkModel fields.
- Does not own: Deterministic Current State or bmux rendering and interaction policy.
- Related slices: Semantic inference framework (`semantic_inference_framework`), First semantic session inferences (`first_semantic_session_inferences`), Blocker and approach-change semantics (`blocker_approach_change_semantics`)

#### SessionWorkModel semantic projection

- Status: Semantic SessionWorkModel Projection (`semantic_session_work_model_projection`): active; First semantic session inferences (`first_semantic_session_inferences`): implemented, delivery merged, acceptance implemented; Semantic Session Work Model Projection: not listed
- Owns: A coherent semantic view of one live coding-agent session with provenance on every non-observed field.
- Inputs: Deterministic factual session projection plus active inference records.
- Outputs: Subject, thread, current turn, current activity, milestones, validation/risk state, scoped architecture, and provenance metadata.
- Does not own: Lower-level public APIs or durable compiled knowledge that outlives the live session.
- Related slices: Semantic SessionWorkModel Projection (`semantic_session_work_model_projection`), First semantic session inferences (`first_semantic_session_inferences`), Human-readable semantic messaging (`human_readable_semantic_messaging`)

#### Milestone semantics

- Status: Milestone inference (`milestone_inference`): planned, delivery proposed, acceptance proposed; Milestone-to-code relationships (`milestone_to_code_relationships`): planned, delivery proposed, acceptance proposed
- Owns: Evidence-backed milestone hierarchy, descriptions, current focus, completion criteria, and relationships to code evidence.
- Inputs: Plans, prompts, command/file-change evidence, validation facts, reasoning summaries, and later Git/GitHub evidence.
- Outputs: Nested live milestones and milestone-to-code relationships for SessionWorkModel and later knowledge compilation.
- Does not own: bmux todo rendering or the assumption that commits and PRs are milestone boundaries.
- Related slices: Milestone inference (`milestone_inference`), Milestone-to-code relationships (`milestone_to_code_relationships`)

#### Scoped architecture projection

- Status: Scoped architecture projection (`scoped_architecture_projection`): planned, delivery proposed, acceptance proposed; Milestone-to-architecture relationships (`milestone_to_architecture_relationships`): planned, delivery proposed, acceptance proposed; Scoped Architecture Projection: not listed
- Owns: Thread-scoped and current-turn-scoped touched, affected, and contextual architecture subgraphs.
- Inputs: Evidence-backed file/symbol relationships, diffs, docs, plans, reasoning summaries, and inference records.
- Outputs: Small scoped architecture projections and milestone-to-architecture links.
- Does not own: Whole-repository diagrams or unsupported architectural claims.
- Related slices: Scoped architecture projection (`scoped_architecture_projection`), Milestone-to-architecture relationships (`milestone_to_architecture_relationships`)

#### Knowledge Compiler, Knowledge Store, and Retrieval

- Status: Knowledge Compiler work later (`knowledge_compiler_outcomes`): deferred, delivery proposed, acceptance proposed
- Owns: Later durable knowledge artifacts, evidence-linked regeneration, scoped storage, retrieval, citation, ranking, and context budgeting.
- Inputs: Evidence, Current State, inference records, milestones, architecture relationships, Git/GitHub/review/document evidence, and accepted human decisions.
- Outputs: Compiled knowledge, knowledge indexes, and bounded context packages for agents, bmux, CLI, IDEs, and organization services.
- Does not own: The live session model's immediate interaction loop or consumer-specific UI presentation.
- Related slices: Knowledge Compiler work later (`knowledge_compiler_outcomes`)

### Dependency-Ready Work

- Presentation language calibration corpus (`presentation_language_calibration_corpus`) - selection: planned; owner: Provenance Engine; depends on: `first_semantic_session_inferences`.
- Milestone inference (`milestone_inference`) - selection: planned; owner: Provenance Engine; depends on: `first_semantic_session_inferences`.
- Blocker and approach-change semantics (`blocker_approach_change_semantics`) - selection: planned; owner: Provenance Engine; depends on: `semantic_inference_framework`.
- Scoped architecture projection (`scoped_architecture_projection`) - selection: planned; owner: Provenance Engine; depends on: `first_semantic_session_inferences`.

### Selected Next Work

- Clickable semantic explanation UI (`clickable_semantic_explanation_ui`) - dependency status: blocked by `factual_agent_session_view`; owner: Bmux; depends on: `factual_agent_session_view`, `human_readable_semantic_messaging`.

### Dependency-Ready But Not Selected

- Presentation language calibration corpus (`presentation_language_calibration_corpus`) - owner: Provenance Engine; depends on: `first_semantic_session_inferences`
- Milestone inference (`milestone_inference`) - owner: Provenance Engine; depends on: `first_semantic_session_inferences`
- Blocker and approach-change semantics (`blocker_approach_change_semantics`) - owner: Provenance Engine; depends on: `semantic_inference_framework`
- Scoped architecture projection (`scoped_architecture_projection`) - owner: Provenance Engine; depends on: `first_semantic_session_inferences`

### Open Caveats

- Broad legacy bmux-local storage migration (`broad_legacy_storage_migration`) - owner: Bmux; status: open
- Observability trace API boundary (`observability_trace_api`) - owner: Provenance Engine; status: open
- GitHub Actions runner reliability (`github_actions_runner_reliability`) - owner: Bmux; status: open; issue: BrianBusby/bmux#8
<!-- END GENERATED: current-target-architecture-status -->
