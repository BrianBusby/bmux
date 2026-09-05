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
factual projections, semantic inference, `SessionWorkModel`, milestone
semantics, related-session awareness, scoped architecture projections, and later knowledge
compilation, storage, retrieval, citation, and context budgeting.

The boundary is intentionally asymmetric: bmux sees more than it persists.
Provenance Engine stores only explicit accepted evidence, then derives reusable
facts and interpretations with provenance.

## Three-view Coding Session Experience

A coding-agent session should have three distinct user-facing views over the
same underlying provider/session identity:

- Native: the provider-native surface. For Codex this is the native Codex
  terminal/session experience, preserved for fidelity, debugging, provider
  features bmux has not normalized, and escape-hatch workflows.
- Terminal: bmux's React live interaction surface. The existing `agent-chat`
  architecture is the foundation for this view: conversation rendering,
  streaming response state, tool and command lifecycle, provider controls,
  approvals, interrupts, skills, modes, and working-directory controls.
- Session: bmux's separate React smart summary surface. It should explain the
  goal, completed turns, current turn, activity, plan state, worked-on areas,
  validations, risks, blockers, and progress using PE factual and semantic
  models.

These views must not collapse into one overloaded interface. Native answers
what the provider natively exposes. Terminal answers what is happening live and
how the user interacts with the agent. Session answers what the work means and
how it is progressing.

The current factual Session UI work is useful as factual consumer groundwork
and diagnostic/inspection scaffolding, but it is not the full Smart Session
experience. Where it is implemented as native Swift UI, future slices should
decide whether to keep it as diagnostics, reuse its data-access foundation, or
migrate presentation into React. The intended user-facing Smart Session
information architecture is React; native code should host, route, restore, and
preserve session identity rather than independently growing a second Smart
Session product.

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
PE SessionWorkModel and related-session awareness
  bounded factual/semantic session views and cross-session relationship briefs
        |
        v
bmux presentation
  Native provider surface, React Terminal live interaction, diagnostics,
  fallback, and later React Smart Session summary UI
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

React Terminal can use ephemeral provider/runtime events directly because it is
the live interaction surface. React Smart Session should preferentially consume
PE factual projection, semantic inference records, semantic messages, and the
`SessionWorkModel`; it should not independently infer session meaning
from raw Terminal events.

Related-session awareness is a PE read model above Session Outcome and
SessionWorkModel. It returns bounded, evidence-backed relationship briefs for a
target session; bmux may present those results later, but should not infer a
parallel cross-session semantic model from provider output.

## Canonical Status

<!-- BEGIN GENERATED: current-target-architecture-status -->
Generated from `project/project-state.yaml` and `project/repo-status.yaml`. For the full generated views, see [project status](generated/project-status.md), [repository status](generated/repository-status.md), and [nested roadmap](generated/nested-roadmap.md).

### Current Active Work

- Active gate: Engineering Observation Period (`engineering_observation_period`) - active
- Primary capability frontier: Process Integrity (`process_integrity`)
- Active implementation slice: Deterministic App Runtime Composition and App-Host Test Isolation (`deterministic_app_runtime_composition`) - open
- Bmux repository state: active

### Current Roadmap Lanes

- Bmux and Provenance Engine (`bmux_provenance_platform`) - project; status: active; owner: Provenance Engine
- Process Integrity (`process_integrity`) - program; status: active; owner: Bmux
- App Runtime Composition and Test Isolation (`app_runtime_composition_and_test_isolation`) - phase; status: active; owner: Bmux
- App Runtime Composition Migration (`app_runtime_composition_migration`) - milestone; status: active; owner: Bmux
- Deterministic App Runtime Composition and App-Host Test Isolation (`deterministic_app_runtime_composition`) - slice; status: active; owner: Bmux
- Project Truth Governance (`project_truth_governance`) - program; status: active; owner: Provenance Engine
- Canonical Project Truth State (`canonical_project_truth_state`) - phase; status: active; owner: Provenance Engine
- Project Truth Manifest and CI (`project_truth_manifest_and_ci`) - milestone; status: active; owner: Provenance Engine
- Richer Session Understanding (`richer_session_understanding`) - program; status: active; owner: Provenance Engine
- Semantic Understanding (`semantic_understanding`) - phase; status: active; owner: Provenance Engine
- Semantic SessionWorkModel Projection (`semantic_session_work_model_projection`) - milestone; status: active; owner: Provenance Engine
- Three-view Coding Session Experience (`three_view_coding_session_experience`) - phase; status: active; owner: Bmux
- Coding Session View Surfaces (`coding_session_view_surfaces`) - milestone; status: active; owner: Bmux
- Cross-Session Work Awareness (`cross_session_work_awareness`) - program; status: active; owner: Provenance Engine
- Cross-Session Retrieval and Context (`cross_session_awareness_retrieval_and_context`) - phase; status: active; owner: Provenance Engine
- Cross-Session Retrieval and Presentation (`cross_session_retrieval_and_presentation`) - milestone; status: active; owner: Provenance Engine

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

- Status: Workspace Display Durable Context and Reconciliation (`workspace_display_durable_context`): implemented, delivery merged, acceptance accepted; Factual session projection foundation (`factual_session_projection_foundation`): implemented, delivery open, acceptance implemented; Deterministic Current State: not listed; Workspace Display Current State: not listed; Workspace Display Projection Cursors: not listed; Workspace Display Ticket Link Facts: implemented; Workspace Display Ticket Title Facts: not listed; Workspace Display Project Link Facts: not listed; Workspace Display Durable Context: implemented
- Owns: Mechanical, rebuildable present-tense state derived only from accepted evidence.
- Inputs: Immutable ledger events and deterministic reducer rules.
- Outputs: Workspace display facts, current context, session/worktree/file views, and other factual public reads.
- Does not own: Intent, milestones, current activity, risk, architecture meaning, or model-derived conclusions.
- Related slices: Workspace Display Durable Context and Reconciliation (`workspace_display_durable_context`), Factual session projection foundation (`factual_session_projection_foundation`)

#### Factual session projection

- Status: Factual session projection foundation (`factual_session_projection_foundation`): implemented, delivery open, acceptance implemented; Factual projection consumer shape follow-up (`factual_projection_consumer_shape_followup`): implemented, delivery merged, acceptance implemented; Factual agent session view (`factual_agent_session_view`): implemented, delivery merged, acceptance implemented; Factual Session Projection: not listed
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

- Status: Milestone inference (`milestone_inference`): implemented, delivery merged, acceptance implemented; Milestone-to-code relationships (`milestone_to_code_relationships`): planned, delivery proposed, acceptance proposed
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

- Status: Local Knowledge Compiler (`knowledge_compiler_outcomes`): deferred, delivery proposed, acceptance proposed
- Owns: Later durable knowledge artifacts, evidence-linked regeneration, scoped storage, retrieval, citation, ranking, and context budgeting.
- Inputs: Evidence, Current State, inference records, milestones, architecture relationships, Git/GitHub/review/document evidence, and accepted human decisions.
- Outputs: Compiled knowledge, knowledge indexes, and bounded context packages for agents, bmux, CLI, IDEs, and organization services.
- Does not own: The live session model's immediate interaction loop or consumer-specific UI presentation.
- Related slices: Local Knowledge Compiler (`knowledge_compiler_outcomes`)

### Dependency-Ready Work

- None.

### Selected Next Work

- None.

### Dependency-Ready But Not Selected

- None.

### Gated / Blocked Downstream Work

- Background Service Lifecycle Migration (`app_runtime_service_lifecycle_migration`) - maturity: gated; status: planned; selection: planned; owner: Bmux
  - Deterministic App Runtime Composition and App-Host Test Isolation (`deterministic_app_runtime_composition`) is not dependency-satisfying
  - Deterministic App Runtime Composition and App-Host Test Isolation (`deterministic_app_runtime_composition`) has maturity active; requires validated for gate `runtime_composition_validated`: Additional background services should migrate only after the first PE-backed production/test composition path is validated.
- React Terminal live interaction productization (`react_terminal_productization`) - maturity: captured; status: planned; selection: planned; owner: Bmux
  - Architecture or product direction is captured, but the slice is not implementation-ready.
- React Smart SessionWorkModel consumer (`react_smart_session_work_model_consumer`) - maturity: gated; status: planned; selection: planned; owner: Bmux
  - Capability maturity is gated; declare satisfied prerequisites and move it to ready before selection.
- Clickable semantic explanation UI (`clickable_semantic_explanation_ui`) - maturity: captured; status: planned; selection: planned; owner: Bmux
  - Architecture or product direction is captured, but the slice is not implementation-ready.
- Three-view session navigation (`three_view_session_navigation`) - maturity: gated; status: planned; selection: planned; owner: Bmux
  - React Terminal live interaction productization (`react_terminal_productization`) is not dependency-satisfying
  - React Terminal live interaction productization (`react_terminal_productization`) has maturity captured; requires validated for gate `terminal_productized`: Three-view navigation should preserve identity across a productized Terminal surface, not an unfinished live-interaction direction.
- Cross-session context assembly experiment (`cross_session_context_assembly_experiment`) - maturity: gated; status: planned; selection: planned; owner: Bmux
  - Capability maturity is gated; declare satisfied prerequisites and move it to ready before selection.
- Knowledge Compiler cross-session bridge (`knowledge_compiler_cross_session_bridge`) - maturity: gated; status: deferred; selection: deferred; owner: Provenance Engine
  - Local Knowledge Compiler (`knowledge_compiler_outcomes`) is not dependency-satisfying
  - Local Knowledge Compiler (`knowledge_compiler_outcomes`) has maturity gated; requires active for gate `compiler_implementation_available`: Cross-session outcomes cannot be promoted into durable knowledge until the Knowledge Compiler exists.
- Continuous presentation learning (`continuous_presentation_learning`) - maturity: gated; status: planned; selection: planned; owner: Provenance Engine
  - Clickable semantic explanation UI (`clickable_semantic_explanation_ui`) is not dependency-satisfying
  - Presentation language calibration corpus (`presentation_language_calibration_corpus`) is not dependency-satisfying
  - Clickable semantic explanation UI (`clickable_semantic_explanation_ui`) has maturity captured; requires validated for gate `explanation_ui_validated`: Presentation learning needs validated explanation affordances and feedback capture before wording examples are durable.
  - Presentation language calibration corpus (`presentation_language_calibration_corpus`) has maturity captured; requires validated for gate `calibration_corpus_validated`: Presentation learning needs a validated corpus before feedback changes policy.
- Presentation language calibration corpus (`presentation_language_calibration_corpus`) - maturity: captured; status: planned; selection: planned; owner: Provenance Engine
  - Architecture or product direction is captured, but the slice is not implementation-ready.
- Milestone-to-code relationships (`milestone_to_code_relationships`) - maturity: gated; status: planned; selection: planned; owner: Provenance Engine
  - Capability maturity is gated; declare satisfied prerequisites and move it to ready before selection.
- Scoped architecture projection (`scoped_architecture_projection`) - maturity: gated; status: planned; selection: planned; owner: Provenance Engine
  - Milestone-to-code relationships (`milestone_to_code_relationships`) is not dependency-satisfying
  - Milestone-to-code relationships (`milestone_to_code_relationships`) has maturity gated; requires validated for gate `milestone_code_relationships_validated`: Scoped architecture projection should be designed against validated milestone-to-code evidence relationships.
- Milestone-to-architecture relationships (`milestone_to_architecture_relationships`) - maturity: gated; status: planned; selection: planned; owner: Provenance Engine
  - Scoped architecture projection (`scoped_architecture_projection`) is not dependency-satisfying
  - Scoped architecture projection (`scoped_architecture_projection`) has maturity gated; requires validated for gate `scoped_architecture_validated`: Milestone-to-architecture links require validated scoped architecture projections.
- Local Knowledge Compiler (`knowledge_compiler_outcomes`) - maturity: gated; status: deferred; selection: deferred; owner: Provenance Engine
  - Milestone-to-code relationships (`milestone_to_code_relationships`) is not dependency-satisfying
  - Milestone-to-architecture relationships (`milestone_to_architecture_relationships`) is not dependency-satisfying
  - Milestone-to-code relationships (`milestone_to_code_relationships`) has maturity gated; requires validated for gate `milestone_code_relationships_validated`: The compiler should consume validated milestone-to-code relationships rather than infer from branch existence.
  - Milestone-to-architecture relationships (`milestone_to_architecture_relationships`) has maturity gated; requires validated for gate `milestone_architecture_relationships_validated`: The compiler should consume validated milestone-to-architecture relationships before producing reusable knowledge.
- Validate compiled knowledge usefulness (`compiled_knowledge_validation`) - maturity: gated; status: deferred; selection: deferred; owner: Provenance Engine
  - Local Knowledge Compiler (`knowledge_compiler_outcomes`) is not dependency-satisfying
  - Local Knowledge Compiler (`knowledge_compiler_outcomes`) has maturity gated; requires active for gate `compiler_implementation_available`: Usefulness validation needs real compiler output to evaluate.
- Evidence-aware knowledge retrieval (`evidence_aware_knowledge_retrieval`) - maturity: gated; status: deferred; selection: deferred; owner: Provenance Engine
  - Validate compiled knowledge usefulness (`compiled_knowledge_validation`) is not dependency-satisfying
  - Local Knowledge Compiler (`knowledge_compiler_outcomes`) has maturity gated; requires validated for gate `compiled_knowledge_validated`: Retrieval should be designed against real useful compiled knowledge.
  - Validate compiled knowledge usefulness (`compiled_knowledge_validation`) has maturity gated; requires validated for gate `compiler_usefulness_validated`: Retrieval should wait until compiled-knowledge usefulness has been observed.
- Validate context effectiveness (`validate_context_effectiveness`) - maturity: gated; status: deferred; selection: deferred; owner: Provenance Engine
  - Evidence-aware knowledge retrieval (`evidence_aware_knowledge_retrieval`) is not dependency-satisfying
  - Evidence-aware knowledge retrieval (`evidence_aware_knowledge_retrieval`) has maturity gated; requires active for gate `retrieval_implementation_available`: Context effectiveness validation needs a retrieval implementation to measure.
- PE-backed specialist agent (`pe_backed_specialist_agent`) - maturity: gated; status: deferred; selection: deferred; owner: Provenance Engine
  - Validate context effectiveness (`validate_context_effectiveness`) is not dependency-satisfying
  - Validate context effectiveness (`validate_context_effectiveness`) has maturity gated; requires validated for gate `context_effectiveness_validated`: Specialist agents should use retrieval only after context effectiveness has been validated.
- Shared knowledge (`shared_knowledge`) - maturity: gated; status: deferred; selection: deferred; owner: Provenance Engine
  - PE-backed specialist agent (`pe_backed_specialist_agent`) is not dependency-satisfying
  - PE-backed specialist agent (`pe_backed_specialist_agent`) has maturity gated; requires validated for gate `specialist_agent_validated`: Shared knowledge should wait until PE-backed specialist-agent consumption proves the local retrieval path.
- Shared retrieval (`shared_retrieval`) - maturity: gated; status: deferred; selection: deferred; owner: Provenance Engine
  - Shared knowledge (`shared_knowledge`) is not dependency-satisfying
  - Shared knowledge (`shared_knowledge`) has maturity gated; requires validated for gate `shared_knowledge_validated`: Shared retrieval requires validated shared-knowledge storage and evidence boundaries.
- Curated training corpus (`curated_training_corpus`) - maturity: gated; status: deferred; selection: deferred; owner: Provenance Engine
  - PE-backed specialist agent (`pe_backed_specialist_agent`) is not dependency-satisfying
  - PE-backed specialist agent (`pe_backed_specialist_agent`) has maturity gated; requires validated for gate `specialist_agent_validated`: Training corpus curation should wait for validated PE-backed specialist-agent behavior and evidence selection.
- PE-trained behavior layer (`pe_trained_behavior_layer`) - maturity: gated; status: deferred; selection: deferred; owner: Provenance Engine
  - Curated training corpus (`curated_training_corpus`) is not dependency-satisfying
  - Curated training corpus (`curated_training_corpus`) has maturity gated; requires validated for gate `training_corpus_validated`: PE-trained behavior requires a validated, curated, evidence-safe corpus first.
- Organization-specific engineering intelligence (`organization_specific_engineering_intelligence`) - maturity: gated; status: deferred; selection: deferred; owner: Provenance Engine
  - Shared retrieval (`shared_retrieval`) is not dependency-satisfying
  - PE-trained behavior layer (`pe_trained_behavior_layer`) is not dependency-satisfying
  - Shared retrieval (`shared_retrieval`) has maturity gated; requires validated for gate `shared_retrieval_validated`: Organization-specific intelligence requires validated shared retrieval.
  - PE-trained behavior layer (`pe_trained_behavior_layer`) has maturity gated; requires validated for gate `trained_behavior_validated`: Organization-specific intelligence should only combine with PE-trained behavior after that layer is validated.

### Open Caveats

- Broad legacy bmux-local storage migration (`broad_legacy_storage_migration`) - owner: Bmux; status: open
- Observability trace API boundary (`observability_trace_api`) - owner: Provenance Engine; status: open
- GitHub Actions runner reliability (`github_actions_runner_reliability`) - owner: Bmux; status: open; issue: BrianBusby/bmux#8
<!-- END GENERATED: current-target-architecture-status -->
