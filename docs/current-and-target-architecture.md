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
- Active implementation slice: none selected
- Bmux repository state: observation

### Current Roadmap Lanes

- Bmux and Provenance Engine (`bmux_provenance_platform`) - project; status: active; owner: Provenance Engine
- Process Integrity (`process_integrity`) - program; status: active; owner: Bmux
- Project Truth Delivery Lifecycle (`project_truth_delivery_lifecycle`) - phase; status: active; owner: Bmux
- Post-Merge Project Truth Reconciliation (`post_merge_project_truth_reconciliation_milestone`) - milestone; status: active; owner: Bmux
- App Runtime Composition and Test Isolation (`app_runtime_composition_and_test_isolation`) - phase; status: active; owner: Bmux
- App Runtime Composition Migration (`app_runtime_composition_migration`) - milestone; status: active; owner: Bmux
- Project Truth Governance (`project_truth_governance`) - program; status: active; owner: Provenance Engine
- Canonical Project Truth State (`canonical_project_truth_state`) - phase; status: active; owner: Provenance Engine
- Project Truth Manifest and CI (`project_truth_manifest_and_ci`) - milestone; status: active; owner: Provenance Engine
- Richer Session Understanding (`richer_session_understanding`) - program; status: active; owner: Provenance Engine
- Semantic Understanding (`semantic_understanding`) - phase; status: active; owner: Provenance Engine
- Semantic SessionWorkModel Projection (`semantic_session_work_model_projection`) - milestone; status: active; owner: Provenance Engine
- Three-view Coding Session Experience (`three_view_coding_session_experience`) - phase; status: active; owner: Bmux
- Coding Session View Surfaces (`coding_session_view_surfaces`) - milestone; status: active; owner: Bmux
- Shared-session Chat and permanent Terminal (`shared_session_chat`) - slice; status: active; owner: Bmux
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

- Status: Workspace Display Durable Context and Reconciliation (`workspace_display_durable_context`): implemented, delivery merged, acceptance accepted; Factual session projection foundation (`factual_session_projection_foundation`): implemented, delivery merged, acceptance implemented; Deterministic Current State: not listed; Workspace Display Current State: not listed; Workspace Display Projection Cursors: not listed; Workspace Display Ticket Link Facts: implemented; Workspace Display Ticket Title Facts: not listed; Workspace Display Project Link Facts: not listed; Workspace Display Durable Context: implemented
- Owns: Mechanical, rebuildable present-tense state derived only from accepted evidence.
- Inputs: Immutable ledger events and deterministic reducer rules.
- Outputs: Workspace display facts, current context, session/worktree/file views, and other factual public reads.
- Does not own: Intent, milestones, current activity, risk, architecture meaning, or model-derived conclusions.
- Related slices: Workspace Display Durable Context and Reconciliation (`workspace_display_durable_context`), Factual session projection foundation (`factual_session_projection_foundation`)

#### Factual session projection

- Status: Factual session projection foundation (`factual_session_projection_foundation`): implemented, delivery merged, acceptance implemented; Factual projection consumer shape follow-up (`factual_projection_consumer_shape_followup`): implemented, delivery merged, acceptance implemented; Factual agent session view (`factual_agent_session_view`): implemented, delivery merged, acceptance implemented; Factual Session Projection: not listed
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

- React Smart SessionWorkModel consumer (`react_smart_session_work_model_consumer`) - selection: planned; owner: Bmux; depends on: `react_smart_session_initial_work_model_consumer`, `react_smart_session_foundation`, `session_work_model_contract_foundation`, `milestone_inference`, `blocker_approach_change_semantics`. Rationale: Consume the PE SessionWorkModel for completed-turn summaries, current-turn state, plan/progress, blockers, approach changes, validations, and richer session-level synthesis once those contracts exist.
- Cross-session context assembly experiment (`cross_session_context_assembly_experiment`) - selection: planned; owner: Bmux; depends on: `agent_accessible_cross_session_retrieval`. Rationale: Measure whether bounded explainable cross-session context improves outcomes before making automatic context assembly a product behavior.
- Milestone-to-code relationships (`milestone_to_code_relationships`) - selection: planned; owner: Provenance Engine; depends on: `milestone_inference`, `richer_coding_agent_evidence_foundation`.

### Selected Next Work

- None.

### Dependency-Ready But Not Selected

- React Smart SessionWorkModel consumer (`react_smart_session_work_model_consumer`) - owner: Bmux; depends on: `react_smart_session_initial_work_model_consumer`, `react_smart_session_foundation`, `session_work_model_contract_foundation`, `milestone_inference`, `blocker_approach_change_semantics`
- Cross-session context assembly experiment (`cross_session_context_assembly_experiment`) - owner: Bmux; depends on: `agent_accessible_cross_session_retrieval`
- Milestone-to-code relationships (`milestone_to_code_relationships`) - owner: Provenance Engine; depends on: `milestone_inference`, `richer_coding_agent_evidence_foundation`

### Gated / Blocked Downstream Work

- Residual App-Host Background Service Audit (`app_runtime_residual_app_host_service_audit`) - maturity: captured; status: deferred; selection: deferred; owner: Bmux
  - Architecture or product direction is captured, but the slice is not implementation-ready.
- Workspace Display File-Watcher Churn Policy (`workspace_display_file_watcher_churn_policy`) - maturity: ready; status: deferred; selection: deferred; owner: Bmux
- Local PE SQLite Multi-Writer Policy (`pe_shared_sqlite_writer_policy`) - maturity: captured; status: deferred; selection: deferred; owner: Bmux
  - Architecture or product direction is captured, but the slice is not implementation-ready.
- Historical Codex Transcript Import Startup Boundary Guard (`codex_historical_import_startup_boundary_guard`) - maturity: ready; status: deferred; selection: deferred; owner: Bmux
- Config Workspace-Launch Canonicalization (`config_workspace_launch_canonicalization`) - maturity: ready; status: deferred; selection: deferred; owner: Bmux
- Swift Package Test Determinism Burn-Down (`test_determinism_swift_package_burndown`) - maturity: ready; status: deferred; selection: deferred; owner: Bmux
- Python Socket and Tmux Compatibility Test Determinism Burn-Down (`test_determinism_python_socket_tmux_burndown`) - maturity: ready; status: deferred; selection: deferred; owner: Bmux
- UI Test Determinism Burn-Down (`test_determinism_ui_burndown`) - maturity: captured; status: deferred; selection: deferred; owner: Bmux
  - Architecture or product direction is captured, but the slice is not implementation-ready.
- Legacy Bmux-Local Provenance Caller Inventory and Retirement Plan (`legacy_bmux_provenance_caller_inventory`) - maturity: ready; status: deferred; selection: deferred; owner: Bmux
- Legacy Bmux-Local Provenance Storage Cleanup (`legacy_bmux_provenance_storage_cleanup`) - maturity: gated; status: deferred; selection: deferred; owner: Bmux
  - Legacy Bmux-Local Provenance Caller Inventory and Retirement Plan (`legacy_bmux_provenance_caller_inventory`) is not dependency-satisfying
  - Legacy Bmux-Local Provenance Caller Inventory and Retirement Plan (`legacy_bmux_provenance_caller_inventory`) has maturity ready; requires validated for gate `legacy_inventory_validated`: Cleanup must wait for an explicit caller inventory PE replacement map and rollback/data-preservation decision.
- Monorepo Migration Ledger Disposition Closure (`monorepo_migration_ledger_disposition_closure`) - maturity: ready; status: deferred; selection: deferred; owner: Bmux
- React Chat live interaction productization (`react_terminal_productization`) - maturity: captured; status: planned; selection: planned; owner: Bmux
  - Architecture or product direction is captured, but the slice is not implementation-ready.
- Clickable semantic explanation UI (`clickable_semantic_explanation_ui`) - maturity: captured; status: planned; selection: planned; owner: Bmux
  - Architecture or product direction is captured, but the slice is not implementation-ready.
- Three-view session navigation (`three_view_session_navigation`) - maturity: gated; status: planned; selection: planned; owner: Bmux
  - React Chat live interaction productization (`react_terminal_productization`) is not dependency-satisfying
  - React Chat live interaction productization (`react_terminal_productization`) has maturity captured; requires validated for gate `terminal_productized`: Three-view navigation should preserve identity across a productized Chat surface, not an unfinished live-interaction direction.
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
- Scoped architecture projection (`scoped_architecture_projection`) - maturity: gated; status: planned; selection: planned; owner: Provenance Engine
  - Milestone-to-code relationships (`milestone_to_code_relationships`) is not dependency-satisfying
  - Milestone-to-code relationships (`milestone_to_code_relationships`) has maturity ready; requires validated for gate `milestone_code_relationships_validated`: Scoped architecture projection should be designed against validated milestone-to-code evidence relationships.
- Milestone-to-architecture relationships (`milestone_to_architecture_relationships`) - maturity: gated; status: planned; selection: planned; owner: Provenance Engine
  - Scoped architecture projection (`scoped_architecture_projection`) is not dependency-satisfying
  - Scoped architecture projection (`scoped_architecture_projection`) has maturity gated; requires validated for gate `scoped_architecture_validated`: Milestone-to-architecture links require validated scoped architecture projections.
- Local Knowledge Compiler (`knowledge_compiler_outcomes`) - maturity: gated; status: deferred; selection: deferred; owner: Provenance Engine
  - Milestone-to-code relationships (`milestone_to_code_relationships`) is not dependency-satisfying
  - Milestone-to-architecture relationships (`milestone_to_architecture_relationships`) is not dependency-satisfying
  - Milestone-to-code relationships (`milestone_to_code_relationships`) has maturity ready; requires validated for gate `milestone_code_relationships_validated`: The compiler should consume validated milestone-to-code relationships rather than infer from branch existence.
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

- Native deadline now owns the test wrapper inside the console session; output-pipeline and cancellation controls pass, real runner cleanup remains unverified (`app_host_cancellation_ownership_verification`) - owner: Bmux; status: open
- Session persistence store capture builds as 794 and passes compiled policy/store checks; macOS 15 app-host teardown verification remains pending (`session_write_store_capture_verification`) - owner: Bmux; status: open
- Bash refresh FIFO observation awaits app-host verification and retains detached stub cleanup risk (`bash_relay_refresh_fixture_verification`) - owner: Bmux; status: open
- Joined Kiro lifecycle no-response fixture awaits actual app-host verification (`kiro_lifecycle_feed_fixture_verification`) - owner: Bmux; status: open
- Four-agent one-way feed fixture awaits fixed-head app-host verification (`feed_hook_no_response_fixture_verification`) - owner: Bmux; status: open
- Claude notification full-suite process timeouts remain unresolved despite focused app-host completion (`claude_notification_target_fixture_verification`) - owner: Bmux; status: open
- Focused Hermes startup and stale-PID suites pending actual app-host verification (`resume_policy_execution_fixture_verification`) - owner: Bmux; status: open
- Focused browser profile and remote store move suite pending actual app-host verification (`browser_remote_store_fixture_verification`) - owner: Bmux; status: open
- Focused Cloud attach retry contract suite pending actual app-host verification (`cloud_attach_retry_fixture_verification`) - owner: Bmux; status: open
- Focused managed appearance startup suite pending actual app-host verification (`managed_appearance_startup_fixture_verification`) - owner: Bmux; status: open
- Broad legacy bmux-local storage migration (`broad_legacy_storage_migration`) - owner: Bmux; status: open
- Residual app-runtime lifecycle ownership outside BmuxAppRuntimeServices (`residual_app_runtime_lifecycle_ownership`) - owner: Bmux; status: open
- Workspace Display file-watcher SQLite churn (`workspace_display_file_watcher_churn`) - owner: Bmux; status: open
- Local PE SQLite multi-writer policy (`pe_shared_sqlite_multi_writer_policy`) - owner: Bmux; status: open
- Historical Codex transcript import startup boundary (`codex_historical_import_startup_boundary`) - owner: Bmux; status: monitoring
- Test determinism allowlist debt (`test_determinism_allowlist_debt`) - owner: Bmux; status: open
- Config workspace-launch mutation-path bypass (`config_workspace_launch_mutation_bypass`) - owner: Bmux; status: open
- Monorepo migration ledger pending dispositions (`monorepo_migration_ledger_pending_dispositions`) - owner: Bmux; status: open
- Observability trace API boundary (`observability_trace_api`) - owner: Provenance Engine; status: open
- GitHub Actions runner reliability (`github_actions_runner_reliability`) - owner: Bmux; status: open; issue: BrianBusby/bmux#8
- Mixed-signature regressions failed in actual D2 CI and all14 fixed artifact tests pass locally; full Release and fresh-runner validation pending (`bundled_cli_mixed_signature_regression_verification`) - owner: Bmux; status: open
- Bundled CLI dynamic and Release artifact relocation verification (`bundled_cli_artifact_relocation_verification`) - owner: Bmux; status: open
- Focused browser app-host gate includes discard policy tests; local native cases pass and pushed-head CI remains pending (`browser_discard_policy_focused_gate_verification`) - owner: Bmux; status: open
- Codex Stop focused app-host passes nine functions in three suites; full-suite verification remains pending (`codex_stop_fixture_app_host_verification`) - owner: Bmux; status: open
- CommandRunner blocking pipe readers can exhaust the cooperative executor during parallel socket tests (`command_runner_parallel_pipe_capture`) - owner: Bmux; status: open
- Browser legacy theme startup migration focused gate awaits fixed app-host CI (`browser_legacy_theme_startup_migration_verification`) - owner: Bmux; status: open
- Focused browser app-host gate includes background compositing tests; local native cases pass and pushed-head CI remains pending (`browser_background_compositing_focused_gate_verification`) - owner: Bmux; status: open
- Right sidebar shortcut fixture repair passes local flag-state coverage; focused app-host CI verification remains pending (`right_sidebar_shortcut_fixture_app_host_verification`) - owner: Bmux; status: open
- CI app-host Option/Alt step selects nine SSH lifecycle tests plus managed attach cleanup fixture; pushed-head verification pending (`ssh_startup_lifecycle_focused_gate_verification`) - owner: Bmux; status: open
- SSH manual reconnect has actual CI red and native 779 green; fixed-head app-host and runtime acceptance remain pending (`ssh_manual_reconnect_handoff_regression`) - owner: Bmux; status: open
- Browser discard initial-navigation readiness timed out on macOS 15 CI; bounded fixture diagnostics await app-host evidence (`browser_discard_restore_focused_gate_verification`) - owner: Bmux; status: open
- Focused app-host gate includes default and configured sidebar width policy tests; local native cases pass and pushed-head CI remains pending (`sidebar_width_persistence_focused_gate_verification`) - owner: Bmux; status: open
- Claude replaced-session cleanup fixture focused gate awaits app-host CI (`claude_session_end_scope_focused_gate_verification`) - owner: Bmux; status: open
- Published maintenance fixes are composed for CI; full authoritative native and artifact gates remain pending (`maintenance_combined_validation_pending`) - owner: Bmux; status: open
- Agent launch fixture joins timeout and cancellation producers before cleanup; native controls pass and app-host verification remains pending (`agent_launch_joined_producer_verification`) - owner: Bmux; status: open
- Agent launch environment fixture adopts existing 20-second CI process policy after S timeouts; local five-second verification passes and fixed-head app-host evidence remains pending (`agent_launch_environment_fixture_focused_gate_verification`) - owner: Bmux; status: open
- SSH workspace creation fixture adopts existing 20-second CI process policy after S timeouts; local five-second verification passes and fixed-head app-host evidence remains pending (`ssh_workspace_creation_fixture_focused_gate_verification`) - owner: Bmux; status: open
- SSH agent environment fixture focused gate awaits app-host CI (`ssh_agent_environment_fixture_focused_gate_verification`) - owner: Bmux; status: open
- Foreign workspace close reproduces destructive teardown; owned-instance guard awaits fixed native and app-host verification (`workspace_close_ownership_verification`) - owner: Bmux; status: open
- Antigravity hook fixture joins request producers without blocked accept workers; full app-host verification pending (`antigravity_hook_lifecycle_fixture_verification`) - owner: Bmux; status: open
- Initial-input and command fixtures await native readiness without user-window attachment; full app-host verification pending (`terminal_initial_runtime_readiness_verification`) - owner: Bmux; status: open
- Workspace close uses a real ready runtime and coordinator owns injected-free scheduling coverage; full app-host verification pending (`workspace_runtime_close_fixture_verification`) - owner: Bmux; status: open
- Grok hook fixtures drain RPC and one-way telemetry across notification payloads, saved-route chat turns, and missing-cwd completion; app-host verification pending (`grok_hook_connection_fixture_verification`) - owner: Bmux; status: open
- Persistent SSH child exit reproduces sibling tracking loss; last-surface guard awaits fixed native and app-host verification (`persistent_pty_child_exit_verification`) - owner: Bmux; status: open
- SSH PTY initial resize acknowledgement CI timeouts remain unresolved (`ssh_pty_lifecycle_fixture_verification`) - owner: Bmux; status: open
- CI Option/Alt step selects CodexMonitorLeaseTests sequential and nested controls; actual app-host verification pending (`codex_monitor_lease_fixture_verification`) - owner: Bmux; status: open
- Respawn window protocol fixture focused gate awaits app-host CI (`respawn_window_protocol_fixture_focused_gate_verification`) - owner: Bmux; status: open
- Workspace fallback regression test red and production fix verification pending (`workspace_fallback_regression_verification`) - owner: Bmux; status: open
- Portal geometry and workspace creation/publication fixture corrections await fixed-head app-host verification (`native_portal_workspace_contract_fixture_verification`) - owner: Bmux; status: open
- Completed-close history and batched mobile response fixture corrections await fixed-head app-host verification (`native_history_and_batched_frame_fixture_verification`) - owner: Bmux; status: open
- Retained Markdown rendering windows and event-driven fixture await fixed-head app-host verification (`markdown_window_retained_fixture_verification`) - owner: Bmux; status: open
- Notification-record restore fixtures await fixed-head app-host verification (`notification_record_restore_fixture_verification`) - owner: Bmux; status: open
- Retained Welcome shortcut window fixture awaits fixed-head app-host verification (`welcome_window_retained_fixture_verification`) - owner: Bmux; status: open
- WebAuthn relay fixture awaits Promise completion and passes native build 799; fixed-head macOS 15 app-host CI remains pending (`browser_webauthn_async_result_fixture_verification`) - owner: Bmux; status: open
- Popup termination fixture verifies controller release after autorelease drainage; fixed-head macOS 15 app-host CI remains pending (`browser_popup_termination_ownership_fixture_verification`) - owner: Bmux; status: open
- Browser inspector window-close correction and raw-close lifecycle fixture await fixed-head app-host verification (`browser_inspector_window_ownership_verification`) - owner: Bmux; status: open
- Remote agent restore directory guard passes native build 783; full app-host verification pending (`remote_restore_working_directory_regression`) - owner: Bmux; status: open
- Focused global search configured-conflict priority suite awaits app-host verification (`global_search_shortcut_conflict_verification`) - owner: Bmux; status: open
- Bounded process diagnostics are enabled for all broad PR shards and focused shard 1; usable macOS 15 call graphs and timeout causes remain unverified (`focused_app_host_process_diagnostics_verification`) - owner: Bmux; status: open
- Remote tmux CRLF record correction passes isolated artifact checks; full CI pending (`remote_tmux_crlf_record_parsing_verification`) - owner: Bmux; status: open
- Quarantine outbound metadata and native readback contract pass local checks; app-host verification remains pending (`browser_download_quarantine_boundary_verification`) - owner: Bmux; status: open
- Configured and chorded file preview save fixtures await fixed-head app-host verification (`file_preview_save_shortcut_fixture_verification`) - owner: Bmux; status: open
- Panel clear-content and opaque chrome compositing suite awaits fixed-head app-host verification (`panel_appearance_compositing_fixture_verification`) - owner: Bmux; status: open
- Narrow titlebar reservation fix preserves offscreen reference layout; integrated app verification remains pending (`titlebar_narrow_window_layout_verification`) - owner: Bmux; status: open
- Claude resume and disabled git-watch contract migrations pass native 786; fixed-head app-host verification pending (`claude_resume_and_no_git_watch_fixture_verification`) - owner: Bmux; status: open
- Titlebar hit-target sizing and search metadata fixture migrations pass native 786; app-host and Swift 6 shortcut-store isolation remain open (`titlebar_search_metadata_fixture_verification`) - owner: Bmux; status: open
- K focused CI reproduces local Git root-alias loss; build 791 preserves caller paths and passes all provider cases, with fixed-head macOS verification pending (`file_explorer_git_root_alias_regression`) - owner: Bmux; status: open
- Three tagged CLI fixtures use short owned homes; native 786 exposes a separate multiline receive-timeout error in two cases (`cli_socket_home_fixture_verification`) - owner: Bmux; status: open
- Native titlebar default-width and voice-control fixture corrections pass locally; app-host verification remains pending (`titlebar_product_contract_fixture_verification`) - owner: Bmux; status: open
- CLI socket capture completion focused gate and shared-caller verification (`cli_socket_capture_completion_verification`) - owner: Bmux; status: open
- Remote tmux LF and CRLF parser focused gate awaits fixed-head CI verification (`remote_tmux_parser_focused_gate_verification`) - owner: Bmux; status: open
- Per-descriptor native readiness is bounded locally; final app-host timeout attribution and verification remain pending (`cli_socket_readiness_coalescing_verification`) - owner: Bmux; status: open
- Sidebar pointer fixture exercises the actual four-point content overlap; full app-host verification remains pending (`sidebar_terminal_hit_boundary_verification`) - owner: Bmux; status: open
- Browser portal resize, reveal, and transient rebind contracts pass native 786; integrated app-host verification remains pending (`browser_portal_presentation_fixture_verification`) - owner: Bmux; status: open
- Native project parsing and D2 build gates pass after quoting extension filenames; final integrated checks remain pending (`native_xcode_project_parse_verification`) - owner: Bmux; status: open
- Browser omnibar arrow fixtures own the required native window context; fixed-head app-host verification remains pending (`browser_omnibar_arrow_fixture_verification`) - owner: Bmux; status: open
- Paste shortcut fixtures verify native custom binding output and runtime recovery; default clipboard delivery is untested and integrated app-host verification remains pending (`terminal_paste_binding_fixture_verification`) - owner: Bmux; status: open
- Native input and Kitty PTY fixtures use causal readiness and complete-screen reads; integrated macOS app-host verification remains pending (`terminal_native_input_delivery_fixture_verification`) - owner: Bmux; status: open
- Remote agent fork fixture owns its existing agent path and passes native checks; app-host verification remains pending (`remote_agent_fork_fixture_verification`) - owner: Bmux; status: open
- Default cloud proxy retry correction passes native build787 original and five preserved controls; integrated CI remains pending (`default_cloud_proxy_retry_state_verification`) - owner: Bmux; status: open
- Deleted agent-hook cwd correction passes native build787 regression and nine directory controls; integrated app-host verification pending (`deleted_agent_hook_cwd_regression`) - owner: Bmux; status: open
- Combined 576-file test target compiles locally; conditional argument correction awaits Xcode 26.3 and integrated app-host verification (`session_resume_fork_contract_fixture_verification`) - owner: Bmux; status: open
- Sidebar PR aggregate and focused projection fixture correction awaits fixed-head app-host verification (`sidebar_pr_focus_contract_fixture_verification`) - owner: Bmux; status: open
- Notification focus fixture awaits the existing event flush and passes native proof; fixed-head app-host remains pending (`notification_focus_event_fixture_verification`) - owner: Bmux; status: open
- Keydown notification fixture isolates runtime and surface-flash preferences; fixed-head app-host remains pending (`notification_keydown_fixture_verification`) - owner: Bmux; status: open
- Clipboard timeout and queued-run fixtures await causal completion; local event-only proofs pass but real pasteboard transactions require isolated app-host CI (`textbox_clipboard_timeout_fixture_verification`) - owner: Bmux; status: open
- Native symbol sizing fixture preserves AppKit configured dimensions; fixed-head app-host verification remains pending (`native_symbol_size_fixture_verification`) - owner: Bmux; status: open
- File preview inset fixture uses the maintained TextKit stack; fixed-head app-host verification remains pending (`file_preview_inset_fixture_verification`) - owner: Bmux; status: open
- Browser Find fixtures distinguish owned-window search from menu fallback; integrated app-host verification remains pending (`browser_find_routing_fixture_verification`) - owner: Bmux; status: open
- Shortcut parser fixtures distinguish pure normalization from runtime subscribers; integrated app-host verification remains pending (`shortcut_parser_lookup_attribution_verification`) - owner: Bmux; status: open
- Remote loopback bridge fixture owns native loading observation and cleanup; macOS 15 timeout cause and app-host verification remain open (`browser_remote_loopback_fixture_verification`) - owner: Bmux; status: open
- Tmux split rejection fixture joins CLI and socket completion; actual macOS 15 timeout cause and app-host verification remain open (`tmux_split_rejection_fixture_verification`) - owner: Bmux; status: open
- Tmux launch identity fixture uses an owned short endpoint and requires focused-context exchange; integrated app-host verification remains pending (`tmux_launch_identity_fixture_verification`) - owner: Bmux; status: open
- Orphan workspace shortcut fixture owns focused-context attribution; integrated app-host verification remains pending (`orphan_workspace_shortcut_fixture_verification`) - owner: Bmux; status: open
- Explicit titlebar event-context suite passes native build789 including ambient keyboard control; integrated app-host verification remains pending (`titlebar_hit_test_event_context_verification`) - owner: Bmux; status: open
- Legacy CLI socket setup rejects invalid paths and cleans partial fixture construction failures; native controls pass and integrated app-host verification remains pending (`cli_notify_socket_bind_guard_verification`) - owner: Bmux; status: open
- SSH agent fixture joins its producer and bounds failure summaries; app-host timeouts remain unresolved (`ssh_agent_joined_producer_verification`) - owner: Bmux; status: open
- Eight selected test-window constructors retain Swift ownership through close; offscreen controls pass, exact app-host cases and crash attribution remain pending (`selected_native_window_close_ownership_verification`) - owner: Bmux; status: open
- File-preview and notification test-window constructor ownership corrected; four affected app-host cases remain pending (`native_window_close_ownership_verification`) - owner: Bmux; status: open
- Terminal file launch fixtures compare directory identity and retain exact quoting; native controls pass and integrated app-host verification remains pending (`terminal_file_launch_directory_contract_verification`) - owner: Bmux; status: open
- Hook prompt evidence fixture uses the accepted stable workspace identity; native old expectation fails and corrected case passes, app-host verification pending (`hook_prompt_stable_workspace_fixture_verification`) - owner: Bmux; status: open
- Closed retained window routing passes isolated build 790 native controls while manager recovery is preserved; real-window app-host verification remains pending (`closed_main_window_routing_verification`) - owner: Bmux; status: open
- Focused Git metadata fixture verifies sidebar publication and duplicate suppression without workspace publication; native control passes and app-host verification remains pending (`sidebar_git_publication_fixture_verification`) - owner: Bmux; status: open
- Notification focus dismissal fixture uses the existing broadcaster completion boundary; native controls pass and exact-head app-host verification remains pending (`notification_focus_completion_fixture_verification`) - owner: Bmux; status: open
- CLI telemetry fixture joins its producer at unchanged failure bounds; owned-shell counterexample passes and actual telemetry app-host verification remains pending (`cli_telemetry_joined_producer_verification`) - owner: Bmux; status: open
- Plain terminal attachment and deferred TCIM fixtures await readiness; native controls pass and integrated app-host verification remains pending (`terminal_attachment_deferred_ime_fixture_verification`) - owner: Bmux; status: open
- Obsolete Gemini dead-PID nil oracle removed under accepted restore policy; native positive and maintained stale-PID coverage pass, integrated app-host verification pending (`gemini_stale_pid_obsolete_oracle_verification`) - owner: Bmux; status: open
- Browser preload fixture retains its owned window through close; native ownership control passes and full app-host verification remains pending (`browser_preload_window_ownership_verification`) - owner: Bmux; status: open
- Hermes hook fixtures join each producer and socket phase; unchanged build 790 passes original contracts, integrated app-host verification remains pending (`hermes_hook_phase_fixture_verification`) - owner: Bmux; status: open
- Korean marked-text fixture awaits terminal readiness; native composition controls pass and macOS app-host verification remains pending (`korean_marked_text_runtime_readiness_verification`) - owner: Bmux; status: open
- Closed-stderr fixture uses the maintained exit contract and joined process owner with absolute deadlines; macOS app-host verification remains pending (`cli_closed_stderr_contract_verification`) - owner: Bmux; status: open
- Terminal config inheritance uses existing runtime ownership guard; build 796 native controls and integrated test compilation pass, macOS 15 app-host verification remains pending (`terminal_inherited_surface_guard_verification`) - owner: Bmux; status: open
- SSH workspace creation fixture joins its producer and owns authentication; native contracts pass, fixed-head app-host verification remains pending (`ssh_creation_joined_producer_verification`) - owner: Bmux; status: open
- Mermaid scaling correction follows five actual CI geometry failures and passes native build 792 coverage; integrated app-host verification remains pending (`markdown_mermaid_double_zoom_verification`) - owner: Bmux; status: open
- Browser chrome reference follows the shared shipped font default; native metrics coverage passes and integrated app-host verification remains pending (`browser_chrome_default_contract_verification`) - owner: Bmux; status: open
- OMX HUD restore fixture establishes its existing-directory precondition; native restoration and missing-directory controls pass, integrated app-host verification pending (`omx_hud_restore_directory_fixture_verification`) - owner: Bmux; status: open
- Palette shortcut fixtures own their settings and window context; native routing controls pass and integrated app-host verification remains pending (`palette_selection_shortcut_fixture_verification`) - owner: Bmux; status: open
- Split workspace title fixture advances the recorded notification coalescer callback; native controls pass and integrated app-host verification remains pending (`split_workspace_title_delivery_fixture_verification`) - owner: Bmux; status: open
- Live-surface recovery fixture establishes a visible retained window; direct-context native controls and compilation pass, real presentation app-host verification remains pending (`live_surface_recovery_window_fixture_verification`) - owner: Bmux; status: open
- Claude session replacement and startup-restorable fixtures join each hook and socket phase; native controls pass and integrated app-host verification remains pending (`claude_session_phase_fixture_verification`) - owner: Bmux; status: open
- Codex installer fixture counts configured prompt entries and owns generated script paths; native controls pass and integrated app-host verification remains pending (`codex_hook_installation_fixture_verification`) - owner: Bmux; status: open
- Migrated CLI fixture deadlines restore their original host-CI minimum; local policy controls pass and fixed-head app-host verification remains pending (`migrated_cli_process_ci_deadline_verification`) - owner: Bmux; status: open
- Crash-report symlink fixture owns an existing report and isolated home; build 795 and complete test target compile pass, macOS 15 app-host verification remains pending (`crash_report_symlink_fixture_verification`) - owner: Bmux; status: open
- CI flags now cross console and XCTest boundaries after actual test-only CI red; fixed-head guard and native app-host verification remain pending (`ci_test_host_environment_propagation_verification`) - owner: Bmux; status: open
- Native test target explicitly disables in-process parallelization for shared AppKit and runtime state; hostless controls pass, full app-host coverage and unchanged 900-second budget remain unverified (`app_host_shared_resource_isolation_verification`) - owner: Bmux; status: open
- Workspace chrome tests follow opaque compositing in scoped light and dark appearances; native build 796 passes, integrated macOS 15 app-host verification remains pending (`workspace_chrome_color_contract_verification`) - owner: Bmux; status: open
- Two portal geometry and overlay fixtures preserve their scheduled-action and animation-completion assertions; native controls pass, fixed-head app-host verification remains pending (`portal_animation_completion_fixture_verification`) - owner: Bmux; status: open
- Markdown atomic file reload uses the existing content sequence with a joined three-second wait; native build 796 passes, integrated macOS 15 app-host verification remains pending (`markdown_file_reload_fixture_verification`) - owner: Bmux; status: open
- Notification settings retry fixture follows synchronous injected callbacks and retains its window; native build 796 passes, integrated macOS 15 app-host verification remains pending (`notification_settings_retry_fixture_verification`) - owner: Bmux; status: open
- Same-directory Git snapshot fixture owns count observations and reader cleanup; native controls pass, integrated macOS 15 app-host verification remains pending (`workspace_git_snapshot_observation_verification`) - owner: Bmux; status: open
- Grok sibling completion uses owned authenticated joined connections and preserves saved-route status assertions; native build 796 passes five cases, integrated macOS 15 app-host verification remains pending (`grok_sibling_status_fixture_verification`) - owner: Bmux; status: open
- Dock pane prompt fixture preserves producer event order and arrival timestamps within its one-second bound; native build 799 callback, delayed-consumer and cancellation controls pass, corrected macOS 15 verification and existing suite isolation warning remain pending (`dock_close_confirmation_owner_verification`) - owner: Bmux; status: open
- Persistent PTY reinstall contract uses verified owned cache and materializes task-group completion before requiring its value for older Testing compatibility; local controls pass, corrected package CI and retained Workspace integration coverage remain pending (`remote_daemon_bootstrap_contract_verification`) - owner: Bmux; status: open
- Managed shortcut fixtures follow file-authoritative bindings and restore owned settings; native build 796 controls pass, integrated macOS 15 verification remains pending (`managed_shortcut_authority_fixture_verification`) - owner: Bmux; status: open
- Codex queue observes owned submission and RPC boundaries, OpenCode auth matches the explicit username, and Claude final text is not counted as pending delta; fresh build 797 passes native contracts and controls, fixed-head macOS 15 app-host verification remains pending (`agent_session_stream_contract_verification`) - owner: Bmux; status: open
- Settings sheet fixture observes synchronous injected alert completion and retains its window; build 796 controls pass, integrated macOS 15 verification remains pending (`notification_settings_sheet_fixture_verification`) - owner: Bmux; status: open
- Tagged theme notification and ambiguous Claude workflow fixtures own their CLI completion and paths; fixed-head macOS 15 app-host verification remains pending (`theme_session_cli_fixture_verification`) - owner: Bmux; status: open
- Workspace stress profiles preserve workload and timing categories while awaiting bounded FIFO delivery; native build 797 passes locally, fixed-head macOS 15 verification remains pending (`workspace_stress_delivery_verification`) - owner: Bmux; status: open
- Native deadline owner records numeric termination and final-exit phases; local status controls pass, actual macOS console pipeline completion diagnosis remains pending (`native_deadline_exit_diagnostics_verification`) - owner: Bmux; status: open
- Approved agent-hook launch commands participate in existing running-state and directory cleanup ownership without requiring a separate agent snapshot; fresh build 798 passes both regressions and three policy controls, fixed-head macOS 15 verification remains pending (`binding_only_resume_state_verification`) - owner: Bmux; status: open
- Pointer and keyboard dismissal share owned input and renderer delivery fixtures; native build 797 passes, fixed-head macOS 15 coverage and legacy AppFocusState isolation remain pending (`terminal_pointer_notification_fixture_verification`) - owner: Bmux; status: open
- Sidebar tool focus preservation observes all three deferred owner phases with unchanged one-second bounds; native build 797 passes, integrated macOS 15 verification remains pending (`sidebar_tool_focus_delivery_verification`) - owner: Bmux; status: open
- Kiro deny and Codex late-PR feed contract uses owned joined producers and excludes detached monitor composition; fixed-head macOS 15 app-host verification remains pending (`kiro_codex_feed_contract_verification`) - owner: Bmux; status: open
- Shared terminal and browser divider caches validate bounded weak child snapshots instead of relying on subviews KVO; fresh build 799 passes existing portal tests and browser counterparts, fixed-head latency and macOS 15 coverage remain pending (`nested_split_divider_cache_verification`) - owner: Bmux; status: open
- Claude idle reminders retain Idle and cached not-pending metadata through joined phases with original five-second limits; native build 797 passes, fixed-head macOS 15 verification remains pending (`claude_idle_reminder_contract_verification`) - owner: Bmux; status: open
- Canvas split shortcut fixtures synchronize existing panel descriptors before geometry assertions; owned native controls pass, original app-host window verification remains pending (`canvas_split_shortcut_initial_panes_verification`) - owner: Bmux; status: open
- Same-path Find scope reset uses real presentation query submission with original reset assertions; build 799 passes, fixed-head macOS 15 app-host coverage remains pending (`find_workspace_scope_fixture_verification`) - owner: Bmux; status: open
- Identity-only session linkage fixture joins hook persistence within its original one-second bound and releases SQLite before cleanup; native build 797 passes, integrated macOS 15 verification remains pending (`prompt_session_link_completion_fixture_verification`) - owner: Bmux; status: open
- Codex prompt cache and detached fallback launch retain original assertions with an owned missing-path precondition and final-write signal; native controls pass, fixed-head macOS 15 execution remains pending (`codex_prompt_cache_fallback_fixture_verification`) - owner: Bmux; status: open
- Option-digit fixture observes native readiness before explicit focus and keeps real key-equivalent assertions; fixed-head macOS 15 app-host verification remains pending (`option_digit_terminal_focus_fixture_verification`) - owner: Bmux; status: open
- Pending diff ordering fixture owns Git and gh setup and materializes task-group completion before its Testing assertion; original phase and cleanup controls pass locally, corrected macOS 15 CI and pre-announcement child tails remain explicit limits (`pending_diff_ordering_fixture_verification`) - owner: Bmux; status: open
- Visible terminal responder repair uses buffered readiness and native focus delivery with original bounds; offscreen controls and strict compilation pass, actual app-host verification remains pending (`visible_terminal_responder_readiness_verification`) - owner: Bmux; status: open
- Three V2 fixture migrations retain joined five-second CLI producers and finite browser focus delivery; native positive and negative controls pass, fixed-head macOS 15 app-host execution remains pending (`v2_cli_and_browser_completion_fixture_verification`) - owner: Bmux; status: open
- V4 terminal search repair uses buffered readiness and native overlay delivery while stranded-sidebar restoration explicitly selects Terminal; strict compilation and offscreen boundary controls pass, full macOS 15 window cases remain pending (`v4_terminal_search_and_window_restore_fixture_verification`) - owner: Bmux; status: open
- Remaining V non-focus split cases retain native queued selection and original phase bounds while Option-digit explicitly mounts Terminal; native split controls pass, full macOS 15 app-host verification remains pending (`v_tail_nonfocus_and_option_terminal_fixture_verification`) - owner: Bmux; status: open
- Codex pending-write fixture observes real request boundaries and joins its held submission on timeout or cancellation; build 799 passes local controls, integrated macOS 15 verification remains pending (`codex_pending_turn_write_fixture_verification`) - owner: Bmux; status: open
- Actual CI proves stopped-child cancellation fails without resume; the lock now forwards the original signal then resumes its owned command and all thirteen local cancellation cases pass, fixed-head CI and historical V pipe completion cause remain unresolved (`app_host_lock_stopped_child_verification`) - owner: Bmux; status: open
- Fork cache refresh fixture supplies matching live workspace and surface environment identities; missing and wrong scope controls fail while the corrected native case passes, fixed-head macOS 15 verification remains pending (`fork_live_process_scope_fixture_verification`) - owner: Bmux; status: open
- Eight deterministic native shards preserve the complete selector partition and unchanged 900-second bound; measured V workload supports added capacity, final CI completion and increased runner queue cost remain pending (`app_host_eight_shard_capacity_verification`) - owner: Bmux; status: open
- Search-overlay mouse fixtures own a real focused workspace and native mount delivery with a new three-second runtime prerequisite and original one-second mount cap; build 799 controls pass, integrated macOS 15 verification remains pending (`terminal_search_overlay_mouse_fixture_verification`) - owner: Bmux; status: open
- Welcome shortcut timeout retains its original route and one-second observer while reporting bounded callback and native window state; historical V timeout cause and next macOS 15 execution remain unresolved (`welcome_shortcut_delivery_diagnostic_verification`) - owner: Bmux; status: open
- Expired pending-open Escape fixture preserves the real main-window route and original no-dismiss bounds with raw-state failure diagnostics; target compilation passes, full macOS 15 failure attribution remains pending (`command_palette_expired_escape_diagnostics`) - owner: Bmux; status: open
- Inspector close failure diagnostics preserve actions and deadlines; explicit closure typing passes Swift 5 and 6 focused compilation after the integrated parser failure, corrected full-target build and actual macOS 15 cause remain pending (`inspector_close_failure_diagnostics`) - owner: Bmux; status: open
- Cold app-host compilation precedes the unchanged 900-second native test deadline with shared build arguments and rebuild on package retry; owned executable controls pass, actual macOS CI build and test completion remain pending (`app_host_cold_build_deadline_boundary`) - owner: Bmux; status: open
- Legacy remote cwd trust fixture targets the original panel identity and restores it focused before testing presented directory; build 799 positive and trust-negative controls pass, actual macOS 15 CI remains pending (`legacy_remote_directory_trust_fixture_verification`) - owner: Bmux; status: open
- Three terminal overlay cases observe native completion with preserved intervals and oracles; drop and rebind controls pass, Escape delivery calibration exposes the offscreen gap and awaits presented macOS 15 app-host verification (`terminal_overlay_completion_fixture_verification`) - owner: Bmux; status: open
- Codex approval fixture observes keyed async replies while preserving standard and full-access permission assertions with a new one-second observation bound; owned build 799 controls pass, integrated macOS 15 CI remains pending (`codex_approval_response_observation_verification`) - owner: Bmux; status: open
- Two notification coalescer cases observe real native timer callbacks within the original one-second total bound; latest-action and separate-burst controls pass, actual macOS 15 verification remains pending (`notification_burst_native_completion_verification`) - owner: Bmux; status: open
- LaunchServices scheduling test restores its original delegate and route-retirer composition; native 799 scheduling and identity controls pass, historical inspector routing linkage and macOS 15 app-host verification remain unproven (`launch_services_scheduling_fixture_ownership_verification`) - owner: Bmux; status: open
- FilePreviewPendingFocusTests retains its owned window through explicit close and preserves both focus assertions; native 799 ownership controls pass, exact historical crash object and macOS 15 verification remain unresolved (`file_preview_pending_focus_window_ownership_verification`) - owner: Bmux; status: open
- Two file-explorer shortcut cases own their real event-window context with all routing assertions retained; offscreen build 799 controls pass, presented macOS 15 CI and legacy settings-owner strict concurrency remain unverified (`file_explorer_shortcut_context_fixture_verification`) - owner: Bmux; status: open
- Redundant browser visibility fixture observes native loading within its original one-second bound; build 799 positive and omission controls pass locally, actual macOS 15 verification and historical startup latency remain unresolved (`browser_visible_notification_completion_verification`) - owner: Bmux; status: open
- Session fork diagnostic fixture joins CLI completion within its original plain five-second local and CI bound; build 799 positive and fork-mode negative controls pass, historical timeout cause and integrated macOS 15 verification remain unresolved (`session_fork_diagnostic_completion_verification`) - owner: Bmux; status: open
- Agent liveness fixture observes its actual watch reload before scope mutation and final refresh before cleanup; all seven original assertions and owned build 799 controls pass, integrated macOS 15 and private-task failure cleanup remain pending (`agent_liveness_watch_completion_verification`) - owner: Bmux; status: open
- Editable terminal-child Undo requires its real native key-window menu context with original routing assertions retained; isolated inactive build 799 reproduces missing target, active macOS 15 positive verification remains pending (`editable_terminal_undo_key_context_verification`) - owner: Bmux; status: open
- Y1 overlay fixtures observe queued mounting and adopt the maintained three-second runtime setup bound for Escape while retaining fifty-millisecond overlay phases and real key-up calibration; owned bundle controls isolate startup delay, presented macOS 15 verification remains pending (`terminal_overlay_runtime_setup_verification`) - owner: Bmux; status: open
- Actual Y Welcome callback arrived after the one-second fixture bound with correct state; explicit three-second absolute functional containment retains all routing assertions, owned controls pass and macOS 15 verification remains pending (`welcome_shortcut_delivery_containment_verification`) - owner: Bmux; status: open
- Current terminal and workspace-rail body coverage preserves all six minimal-mode assertions; root-built 800 fails the three noninvalidation checks and 801 passes while actual inset edits still invalidate, full app-host macOS 15 verification remains pending (`minimal_mode_current_shell_invalidation_verification`) - owner: Bmux; status: open
- Seven terminal focus recovery cases observe queued work and establish authoritative visibility and geometry prerequisites within 50ms completion bounds; owned build 799 positive and omission controls pass, real presented macOS 15 verification remains pending (`workspace_terminal_focus_completion_verification`) - owner: Bmux; status: open
- Actual shard-3 precursor fixtures restore shared delegate and known route-retirer composition with scoped resource cleanup; build 799 identity controls pass, historical inspector causality and presented macOS 15 acceptance remain pending (`inspector_precursor_delegate_composition_verification`) - owner: Bmux; status: open
- PR 171 review 5543944260 duplicate-title filter warning has actual CI red in run 38876211760 shard 4 and an identity-based fix with five local passing cases in Swift 5 and 6; fixed integrated build and CI green remain pending (`workspace_filter_selection_identity_verification`) - owner: Bmux; status: open
- Z shard 6 background HIToolbox crash has a source-supported main-actor shortcut fixture repair with three local native cases passing in Swift 5 and 6; matched CI symbols and fixed macOS 15 CI remain pending (`keyboard_space_native_layout_isolation_verification`) - owner: Bmux; status: open
- Zsh prompt-refresh fixture observes both inherited-FIFO callbacks within the original one-second phase and joins its five-second shell; local Swift 5 and 6 controls pass, detached exits and integrated macOS 15 verification remain unproven (`zsh_relay_refresh_completion_verification`) - owner: Bmux; status: open
- Minimal-mode fixture records native event decisions before async consumption under unchanged one-second bounds; four delayed-consumer counterexamples and bounded omission, late-event and cleanup controls pass locally, actual macOS 15 verification and historical timeout phase remain unresolved (`minimal_mode_failure_phase_diagnostics_verification`) - owner: Bmux; status: open
- Z7 markdown scroll-frame fixture and its callback operation preserve first native arrival with joined cancellation and unchanged deadlines; controlled frame and DOM cleanup checks pass, while displayed native-frame verification awaits an unlocked desktop or CI (`markdown_scroll_frame_completion_verification`) - owner: Bmux; status: open
- Z8 executed redraw fixture now restores shared delegate and active manager with native 799 identity and redraw controls; actual installed-monitor attribution and macOS 15 inspector verification remain open (`z_inspector_redraw_precursor_verification`) - owner: Bmux; status: open
- Z3 focus and Z1 overlay fixtures share a duration-configured value owner for native FIFO producer-arrival completion at unchanged 50ms bounds; Swift 5 and 6 ordering and cancellation controls pass, while historical scheduling attribution and presented macOS 15 verification remain open (`workspace_focus_delivery_arrival_verification`) - owner: Bmux; status: open
<!-- END GENERATED: current-target-architecture-status -->

The closed-peer CLI repair gives receive timeout configuration/cache and byte reads one internal `CLISocketReceiver` owner with a borrowed descriptor. `SocketClient` retains framing, connection lifecycle, request policy and telemetry. Actual G regression red is recorded; extracted-owner controls, tagged build 788 bundled CLI checks, and H shard 3 fixed-head CLI checks pass. The full combined native and artifact gates remain pending.
- CLI telemetry fixture joins its producer at unchanged failure bounds; owned-shell counterexample passes and actual telemetry app-host verification remains pending (`cli_telemetry_joined_producer_verification`) - owner: Bmux; status: open
- Plain terminal attachment and deferred TCIM fixtures await readiness; native controls pass and integrated app-host verification remains pending (`terminal_attachment_deferred_ime_fixture_verification`) - owner: Bmux; status: open
- Obsolete Gemini dead-PID nil oracle removed under accepted restore policy; native positive and maintained stale-PID coverage pass, integrated app-host verification pending (`gemini_stale_pid_obsolete_oracle_verification`) - owner: Bmux; status: open
- Browser preload fixture retains its owned window through close; native ownership control passes and full app-host verification remains pending (`browser_preload_window_ownership_verification`) - owner: Bmux; status: open
