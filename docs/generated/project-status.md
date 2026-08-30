<!--
GENERATED FILE. DO NOT EDIT MANUALLY.
Sources:
- project/project-state.yaml
- project/repo-status.yaml
Regenerate with: ./scripts/project-docs generate
-->


# Project Status

## Active Gate

- ID: `engineering_observation_period`
- Title: Engineering Observation Period
- Status: active

## What Can Be Worked On Next

### Current Capability Frontier

- Primary Capability Frontier: Richer Session Understanding (`richer_session_understanding`)
- Active or selected slices in the frontier:
  - Blocker and approach-change semantics (`blocker_approach_change_semantics`) - maturity: active; status: active; selection: current; owner: Provenance Engine

### Active Implementation

- Blocker and approach-change semantics (`blocker_approach_change_semantics`) - maturity: active; status: active; selection: current; owner: Provenance Engine

### Selected Next

- None.

### Ready Candidates

- None.

### Gated / Blocked Downstream Work

- React Terminal live interaction productization (`react_terminal_productization`) - maturity: captured; status: planned; selection: planned; owner: Bmux
  - Architecture or product direction is captured, but the slice is not implementation-ready.
- React Smart SessionWorkModel consumer (`react_smart_session_work_model_consumer`) - maturity: gated; status: planned; selection: planned; owner: Bmux
  - Blocker and approach-change semantics (`blocker_approach_change_semantics`) is not dependency-satisfying
  - Blocker and approach-change semantics (`blocker_approach_change_semantics`) has maturity active; requires validated for gate `blocker_approach_semantics_validated`: Smart Session blocker and approach-change presentation must be backed by validated PE semantics.
- Clickable semantic explanation UI (`clickable_semantic_explanation_ui`) - maturity: captured; status: planned; selection: planned; owner: Bmux
  - Architecture or product direction is captured, but the slice is not implementation-ready.
- Three-view session navigation (`three_view_session_navigation`) - maturity: gated; status: planned; selection: planned; owner: Bmux
  - React Terminal live interaction productization (`react_terminal_productization`) is not dependency-satisfying
  - React Terminal live interaction productization (`react_terminal_productization`) has maturity captured; requires validated for gate `terminal_productized`: Three-view navigation should preserve identity across a productized Terminal surface, not an unfinished live-interaction direction.
- Rich cross-session work-state semantics (`rich_cross_session_work_state_semantics`) - maturity: gated; status: planned; selection: planned; owner: Provenance Engine
  - Blocker and approach-change semantics (`blocker_approach_change_semantics`) is not dependency-satisfying
  - Blocker and approach-change semantics (`blocker_approach_change_semantics`) has maturity active; requires validated for gate `blocker_approach_semantics_validated`: Cross-session blockers, failed attempts, and approach changes must be backed by validated PE semantic records.
- Agent-accessible cross-session retrieval (`agent_accessible_cross_session_retrieval`) - maturity: gated; status: planned; selection: planned; owner: Provenance Engine
  - Rich cross-session work-state semantics (`rich_cross_session_work_state_semantics`) is not dependency-satisfying
  - Rich cross-session work-state semantics (`rich_cross_session_work_state_semantics`) has maturity gated; requires validated for gate `cross_session_semantics_validated`: Agent questions about blockers, decisions, failed approaches, and validation require validated semantic brief fields.
- Proactive bmux cross-session awareness (`proactive_bmux_cross_session_awareness`) - maturity: gated; status: planned; selection: planned; owner: Bmux
  - Agent-accessible cross-session retrieval (`agent_accessible_cross_session_retrieval`) is not dependency-satisfying
  - Agent-accessible cross-session retrieval (`agent_accessible_cross_session_retrieval`) has maturity gated; requires validated for gate `cross_session_retrieval_validated`: Proactive presentation should depend on observed useful retrieval and relevance behavior.
- Cross-session context assembly experiment (`cross_session_context_assembly_experiment`) - maturity: gated; status: planned; selection: planned; owner: Bmux
  - Agent-accessible cross-session retrieval (`agent_accessible_cross_session_retrieval`) is not dependency-satisfying
  - Agent-accessible cross-session retrieval (`agent_accessible_cross_session_retrieval`) has maturity gated; requires validated for gate `cross_session_retrieval_validated`: Automatic context assembly should be an experiment after explicit cross-session retrieval proves useful.
- Knowledge Compiler cross-session bridge (`knowledge_compiler_cross_session_bridge`) - maturity: gated; status: deferred; selection: deferred; owner: Provenance Engine
  - Agent-accessible cross-session retrieval (`agent_accessible_cross_session_retrieval`) is not dependency-satisfying
  - Local Knowledge Compiler (`knowledge_compiler_outcomes`) is not dependency-satisfying
  - Agent-accessible cross-session retrieval (`agent_accessible_cross_session_retrieval`) has maturity gated; requires validated for gate `cross_session_retrieval_validated`: The bridge should consume validated working-memory retrieval behavior, not transient session statements.
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

## Shared Milestones

| Milestone | Owner | Delivery | Acceptance | Evidence |
| --- | --- | --- | --- | --- |
| Provenance Engine V1 package (`provenance_engine_v1`) | Provenance Engine | merged | accepted | BrianBusby/bmux@18f5511a7c83, BrianBusby/bmux@0ed9f68b6612 |
| Bmux Provenance Engine Slice E adoption (`bmux_slice_e_adoption`) | Bmux | merged | accepted | BrianBusby/bmux@3cbacd150176, BrianBusby/bmux@0ed9f68b6612 |
| Provider-neutral execution telemetry foundation (`execution_telemetry_foundation`) | Bmux | merged | implemented | BrianBusby/bmux@c32ed93989c8, BrianBusby/bmux@9d7fefacbb40, BrianBusby/bmux#12 by [BrianBusby](https://github.com/BrianBusby) |
| Claude lifecycle telemetry migration (`claude_lifecycle_telemetry`) | Bmux | merged | implemented | BrianBusby/bmux@5a4a463f17e0, BrianBusby/bmux@3f49c5d5abbe, BrianBusby/bmux#13 by [BrianBusby](https://github.com/BrianBusby) |
| Workspace Display Durable Context and Reconciliation (`workspace_display_durable_context`) | Bmux | open | implemented | BrianBusby/bmux@bdf81ae0454f, BrianBusby/bmux@543161954689 |
| Richer Coding-Agent Evidence and Factual Session Projection (`richer_session_work_model`) | Provenance Engine | merged | implemented | BrianBusby/bmux@9e69452a2ec2, BrianBusby/bmux@2add52c611e2, BrianBusby/bmux@a0f8c1fa2d0e, BrianBusby/bmux@45b7188ea62d, BrianBusby/bmux#48 by [BrianBusby](https://github.com/BrianBusby) |

## Open Shared Caveats

| Caveat | Owner | Status | Issue |
| --- | --- | --- | --- |
| Broad legacy bmux-local storage migration (`broad_legacy_storage_migration`) | Bmux | open |  |
| Observability trace API boundary (`observability_trace_api`) | Provenance Engine | open |  |
| GitHub Actions runner reliability (`github_actions_runner_reliability`) | Bmux | open | BrianBusby/bmux#8 |

## Automatic Checkpoints

- Implementation status: not implemented
- Selected for implementation: false
- Operational statement: automatic diagnostic checkpoints are not operational.
