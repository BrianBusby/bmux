<!--
GENERATED FILE. DO NOT EDIT MANUALLY.
Sources:
- project/project-state.yaml
- project/repo-status.yaml
Regenerate with: ./scripts/project-docs generate
-->


# Nested Roadmap

This view is generated from `project/project-state.yaml` and preserves the roadmap hierarchy, sequencing, and evidence references.

## What Can Be Worked On Next

### Current Capability Frontier

- Primary Capability Frontier: Richer Session Understanding (`richer_session_understanding`)
- Active or selected slices in the frontier:
  - Milestone inference (`milestone_inference`) - maturity: ready; status: planned; selection: selected next; owner: Provenance Engine

### Active Implementation

- Project Truth dependency and capability frontier governance (`project_truth_capability_frontier_governance`) - maturity: active; status: active; selection: current; owner: Provenance Engine

### Selected Next

- Milestone inference (`milestone_inference`) - maturity: ready; status: planned; selection: selected next; owner: Provenance Engine; dependency status: ready

### Ready Candidates

- Blocker and approach-change semantics (`blocker_approach_change_semantics`) - maturity: ready; status: planned; selection: planned; owner: Provenance Engine

### Gated / Blocked Downstream Work

- React Terminal live interaction productization (`react_terminal_productization`) - maturity: captured; status: planned; selection: planned; owner: Bmux
  - Architecture or product direction is captured, but the slice is not implementation-ready.
- React Smart SessionWorkModel consumer (`react_smart_session_work_model_consumer`) - maturity: gated; status: planned; selection: planned; owner: Bmux
  - Milestone inference (`milestone_inference`) is not dependency-satisfying
  - Blocker and approach-change semantics (`blocker_approach_change_semantics`) is not dependency-satisfying
  - Milestone inference (`milestone_inference`) has maturity ready; requires validated for gate `milestone_semantics_validated`: Smart Session must not present progress or milestone structure until PE milestone semantics are validated.
  - Blocker and approach-change semantics (`blocker_approach_change_semantics`) has maturity ready; requires validated for gate `blocker_approach_semantics_validated`: Smart Session blocker and approach-change presentation must be backed by validated PE semantics.
- Clickable semantic explanation UI (`clickable_semantic_explanation_ui`) - maturity: captured; status: planned; selection: planned; owner: Bmux
  - Architecture or product direction is captured, but the slice is not implementation-ready.
- Three-view session navigation (`three_view_session_navigation`) - maturity: gated; status: planned; selection: planned; owner: Bmux
  - React Terminal live interaction productization (`react_terminal_productization`) is not dependency-satisfying
  - React Terminal live interaction productization (`react_terminal_productization`) has maturity captured; requires validated for gate `terminal_productized`: Three-view navigation should preserve identity across a productized Terminal surface, not an unfinished live-interaction direction.
- Continuous presentation learning (`continuous_presentation_learning`) - maturity: gated; status: planned; selection: planned; owner: Provenance Engine
  - Clickable semantic explanation UI (`clickable_semantic_explanation_ui`) is not dependency-satisfying
  - Presentation language calibration corpus (`presentation_language_calibration_corpus`) is not dependency-satisfying
  - Clickable semantic explanation UI (`clickable_semantic_explanation_ui`) has maturity captured; requires validated for gate `explanation_ui_validated`: Presentation learning needs validated explanation affordances and feedback capture before wording examples are durable.
  - Presentation language calibration corpus (`presentation_language_calibration_corpus`) has maturity captured; requires validated for gate `calibration_corpus_validated`: Presentation learning needs a validated corpus before feedback changes policy.
- Presentation language calibration corpus (`presentation_language_calibration_corpus`) - maturity: captured; status: planned; selection: planned; owner: Provenance Engine
  - Architecture or product direction is captured, but the slice is not implementation-ready.
- Milestone-to-code relationships (`milestone_to_code_relationships`) - maturity: gated; status: planned; selection: planned; owner: Provenance Engine
  - Milestone inference (`milestone_inference`) is not dependency-satisfying
  - Milestone inference (`milestone_inference`) has maturity ready; requires validated for gate `milestone_semantics_validated`: Code relationships need validated milestone identity and hierarchy before attribution can be trusted.
- Scoped architecture projection (`scoped_architecture_projection`) - maturity: gated; status: planned; selection: planned; owner: Provenance Engine
  - Milestone-to-code relationships (`milestone_to_code_relationships`) is not dependency-satisfying
  - Milestone-to-code relationships (`milestone_to_code_relationships`) has maturity gated; requires validated for gate `milestone_code_relationships_validated`: Scoped architecture projection should be designed against validated milestone-to-code evidence relationships.
- Milestone-to-architecture relationships (`milestone_to_architecture_relationships`) - maturity: gated; status: planned; selection: planned; owner: Provenance Engine
  - Scoped architecture projection (`scoped_architecture_projection`) is not dependency-satisfying
  - Milestone inference (`milestone_inference`) is not dependency-satisfying
  - Scoped architecture projection (`scoped_architecture_projection`) has maturity gated; requires validated for gate `scoped_architecture_validated`: Milestone-to-architecture links require validated scoped architecture projections.
  - Milestone inference (`milestone_inference`) has maturity ready; requires validated for gate `milestone_semantics_validated`: Milestone-to-architecture links require validated milestone identity and hierarchy.
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

## Roadmap Tree

- **Bmux and Provenance Engine** (`bmux_provenance_platform`) - project; status: active; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: platform; layer: platform; execution: current / Shared; parallelism: safe
  Rationale: Canonical monorepo roadmap root for Provenance Engine-owned evidence/current-state work and bmux-owned observation/presentation work.
  - **V1 Foundation and Bmux Adoption** (`v1_foundation_and_adoption`) - program; status: accepted; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: v1 adoption; layer: platform; execution: complete / Shared; parallelism: serial
    Rationale: Records the accepted V1 package and first bmux adoption path without expanding the legacy flat milestone list.
    - **V1 Baseline** (`v1_baseline`) - phase; status: accepted; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: v1 adoption; layer: evidence store; execution: complete / Shared; parallelism: serial
      - **V1 Package and Slice E Adoption** (`v1_package_and_slice_e`) - milestone; status: accepted; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: v1 adoption; layer: platform; execution: complete / Shared; parallelism: serial
        - **Provenance Engine V1 package** (`provenance_engine_v1`) - slice; status: accepted; owner: Provenance Engine; repositories: Provenance Engine; concept: v1 adoption; layer: evidence store; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: accepted; mirrors: `provenance_engine_v1`
          Enables: `bmux_slice_e_adoption`
          Evidence: BrianBusby/bmux@18f5511a7c83, BrianBusby/bmux@0ed9f68b6612
        - **Bmux Provenance Engine Slice E adoption** (`bmux_slice_e_adoption`) - slice; status: accepted; owner: Bmux; repositories: Bmux, Provenance Engine; concept: v1 adoption; layer: consumer presentation; execution: complete / Bmux; parallelism: serial; delivery: merged; acceptance: accepted; mirrors: `bmux_slice_e_adoption`
          Depends on: `provenance_engine_v1`
          Evidence: BrianBusby/bmux@3cbacd150176, BrianBusby/bmux@0ed9f68b6612
    - **Runtime Observation and Workspace Display** (`runtime_observation_and_workspace_display`) - phase; status: implemented; owner: Bmux; repositories: Bmux, Provenance Engine; concept: workspace display; layer: deterministic current state; execution: complete / Shared; parallelism: serial
      Depends on: `bmux_slice_e_adoption`
      Rationale: Captures the post-V1 adoption work that connected bmux runtime observation to Provenance Engine-owned durable context and deterministic display projections.
      - **Execution Telemetry Migration** (`execution_telemetry_migration`) - milestone; status: implemented; owner: Bmux; repositories: Bmux; concept: execution telemetry; layer: evidence sources; execution: complete / Bmux; parallelism: serial
        Enables: `workspace_display_durable_context`
        - **Provider-neutral execution telemetry foundation** (`execution_telemetry_foundation`) - slice; status: implemented; owner: Bmux; repositories: Bmux; concept: execution telemetry; layer: evidence sources; execution: complete / Bmux; parallelism: serial; delivery: merged; acceptance: implemented; mirrors: `execution_telemetry_foundation`
          Enables: `claude_lifecycle_telemetry`
          Evidence: BrianBusby/bmux@c32ed93989c8, BrianBusby/bmux@9d7fefacbb40, BrianBusby/bmux#12 by [BrianBusby](https://github.com/BrianBusby)
        - **Claude lifecycle telemetry migration** (`claude_lifecycle_telemetry`) - slice; status: implemented; owner: Bmux; repositories: Bmux; concept: execution telemetry; layer: evidence sources; execution: complete / Bmux; parallelism: serial; delivery: merged; acceptance: implemented; mirrors: `claude_lifecycle_telemetry`
          Depends on: `execution_telemetry_foundation`
          Evidence: BrianBusby/bmux@5a4a463f17e0, BrianBusby/bmux@3f49c5d5abbe, BrianBusby/bmux#13 by [BrianBusby](https://github.com/BrianBusby)
      - **Workspace Display Current State** (`workspace_display_current_state`) - milestone; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: workspace display; layer: deterministic current state; execution: complete / Shared; parallelism: serial
        Depends on: `execution_telemetry_migration`
        Enables: `richer_session_understanding`
        - **Workspace Display Durable Context and Reconciliation** (`workspace_display_durable_context`) - slice; status: implemented; owner: Bmux; repositories: Bmux, Provenance Engine; concept: workspace display; layer: deterministic current state; execution: complete / Shared; parallelism: serial; delivery: open; acceptance: implemented; mirrors: `workspace_display_durable_context`
          Depends on: `claude_lifecycle_telemetry`
          Enables: `richer_session_understanding`
          Evidence: BrianBusby/bmux@bdf81ae0454f, BrianBusby/bmux@543161954689
  - **Project Truth Governance** (`project_truth_governance`) - program; status: active; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: project truth; layer: project truth; execution: current / Provenance Engine; parallelism: safe
    Rationale: Maintains canonical structured project state, generated status, and read-only CI checks that prevent authored documentation drift.
    - **Canonical Project Truth State** (`canonical_project_truth_state`) - phase; status: active; owner: Provenance Engine; repositories: Provenance Engine; concept: project truth; layer: project truth; execution: current / Provenance Engine; parallelism: serial
      - **Project Truth Manifest and CI** (`project_truth_manifest_and_ci`) - milestone; status: active; owner: Provenance Engine; repositories: Provenance Engine; concept: project truth; layer: project truth; execution: current / Provenance Engine; parallelism: serial
        - **Canonical project truth manifest and generated docs** (`canonical_project_truth_manifest`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: project truth; layer: project truth; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented
          Enables: `read_only_project_truth_ci_gate`
          Evidence: BrianBusby/bmux@88a9b4e175d4
        - **Read-only Project Truth CI gate** (`read_only_project_truth_ci_gate`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: project truth; layer: cross repository workflow; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented
          Depends on: `canonical_project_truth_manifest`
          Evidence: BrianBusby/bmux@df3866f697a9
        - **Phase 0A Canonical Nested Roadmap and Concept Classification** (`phase_0a_canonical_nested_roadmap`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: project truth; layer: project truth; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented
          Depends on: `read_only_project_truth_ci_gate`
          Enables: `phase_0b_current_target_architecture`
          Expected contract domains: `roadmap_hierarchy`, `roadmap_dependency_validation`
          Expected code areas: `project/project-state.yaml`, `project/schema/project-state.schema.json`, `tools/project-docs`, `docs/generated`
          Likely conflict domains: `project/project-state.yaml`, `project/schema`, `tools/project-docs`, `docs/generated`
          Contract dependencies: `project_truth_generated_docs`, `project_docs_validation`
          Worktree required: true
          Evidence: BrianBusby/bmux@e278a4423f15
          Rationale: Establishes the nested dependency-aware roadmap and generated nested-roadmap view that later planning and architecture slices build on.
        - **Phase 0B Current-and-Target Architecture** (`phase_0b_current_target_architecture`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: project truth; layer: project truth; execution: complete / Provenance Engine; parallelism: safe; delivery: merged; acceptance: implemented
          Depends on: `phase_0a_canonical_nested_roadmap`
          Enables: `phase_0c_parallel_worktree_metadata`
          Expected contract domains: `current_target_architecture_status`
          Expected code areas: `docs/current-and-target-architecture.md`, `tools/project-docs`
          Likely conflict domains: `project/project-state.yaml`, `docs/generated`
          Contract dependencies: `project_truth_generated_docs`
          Worktree required: true
          Evidence: BrianBusby/bmux@533567ead8c6
          Rationale: Records the living current-and-target architecture guide and its generated status block as project-truth infrastructure without changing product implementation sequencing.
        - **Phase 0C Parallel Slice Planning and Worktree Safety Metadata** (`phase_0c_parallel_worktree_metadata`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: project truth; layer: cross repository workflow; execution: complete / Provenance Engine; parallelism: safe; delivery: merged; acceptance: implemented
          Depends on: `phase_0b_current_target_architecture`
          Expected contract domains: `roadmap_parallelism_metadata`, `active_worktree_preflight`
          Expected code areas: `project/project-state.yaml`, `project/schema/project-state.schema.json`, `project/schema/repo-status.schema.json`, `tools/project-docs`, `docs/generated`
          Likely conflict domains: `project/project-state.yaml`, `project/schema`, `tools/project-docs`, `docs/generated`
          Contract dependencies: `project_truth_generated_docs`, `project_docs_validation`
          Worktree required: true
          Evidence: BrianBusby/bmux@6fee11b0fa40
          Rationale: Adds manifest-only parallel slice planning metadata, active worktree and branch safety validation, and generated preflight visibility without assigning future work automatically.
        - **bmux and Provenance Engine monorepo consolidation** (`monorepo_repository_consolidation`) - slice; status: implemented; owner: Bmux; repositories: Bmux, Provenance Engine; concept: project truth; layer: project truth; execution: complete / Shared; parallelism: conditional; delivery: merged; acceptance: implemented
          Depends on: `phase_0c_parallel_worktree_metadata`
          Enables: `react_smart_session_foundation`, `session_work_model_contract_foundation`, `milestone_inference`, `scoped_architecture_projection`
          Expected contract domains: `monorepo_project_truth`, `provenance_engine_package_boundary`, `local_pe_dependency`, `architecture_documentation`
          Expected code areas: `Packages/macOS/ProvenanceEngine`, `bmux.xcodeproj/project.pbxproj`, `bmux.xcworkspace/contents.xcworkspacedata`, `project`, `tools/project-docs`, `scripts/project-docs`, `docs/architecture`, `docs/product`, `docs/decisions`, `.github/workflows/project-truth.yml`
          Likely conflict domains: `project_truth_manifest`, `project_docs_generation`, `provenance_engine_dependency_model`, `architecture_documentation`, `open_bmux_pe_branch_reconciliation`
          Contract dependencies: `provenance_engine_public_contracts`, `project_docs_validation`, `bmux_package_boundary_rules`
          Worktree required: true
          Conflict note: This slice intentionally freezes artificial cross-repository coordination work while active branches are inventoried and rebased or superseded in the monorepo. It must preserve PE as an independent Swift package and prohibit PE imports of bmux runtime or UI internals.
          Execution notes: One canonical bmux repository now contains the independent Provenance Engine SwiftPM package under Packages/macOS/ProvenanceEngine, with public contracts consumed locally by bmux.
          Evidence: BrianBusby/bmux@f4b96132c2c7, BrianBusby/bmux#53 by [BrianBusby](https://github.com/BrianBusby)
          Rationale: Consolidates the Git repository boundary that had become accidental coordination overhead while preserving Provenance Engine as a standalone Swift package boundary, retaining imported PE history, and replacing peer-repo Project Truth with a root-local canonical project graph.
          Acceptance reason: PR #53 merged the local Provenance Engine package, root Project Truth tooling, generated docs, and monorepo package dependency model without making PE a bmux-internal module.
        - **Project Truth dependency and capability frontier governance** (`project_truth_capability_frontier_governance`) - slice; status: active; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: project truth; layer: project truth; execution: current / Provenance Engine; parallelism: safe; delivery: open; acceptance: proposed; maturity: active
          Depends on: `monorepo_repository_consolidation`
          Expected contract domains: `roadmap_capability_maturity`, `roadmap_readiness_gates`, `primary_capability_frontier`
          Expected code areas: `project/project-state.yaml`, `project/repo-status.yaml`, `project/schema/project-state.schema.json`, `tools/project-docs`, `docs/generated`, `AGENTS.md`
          Likely conflict domains: `project_truth_manifest`, `project_docs_generation`, `roadmap_schema`
          Contract dependencies: `project_truth_generated_docs`, `project_docs_validation`
          Worktree required: true
          Conflict note: Infrastructure-only governance slice. It may run beside semantic-session implementation work when it does not edit product contracts, runtime behavior, or downstream PE capability code.
          Active assignment: worktree: `/Users/brianbusby/repos/bmux-project-truth-capability-frontier-governance`; branch: `project-truth-capability-frontier-governance`; agent: `Codex`
          Rationale: Add explicit capability maturity, readiness gates, primary frontier reporting, and stricter validation so documented future architecture cannot become implementation-ready without Project Truth authorization.
  - **Richer Session Understanding** (`richer_session_understanding`) - program; status: active; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: inference session work projections; execution: current / Shared; parallelism: safe; maturity: active
    Depends on: `workspace_display_durable_context`
    Rationale: Richer coding-agent evidence and session projections are the active direction after V1 adoption and workspace-display observation. This program now explicitly supports bmux's three-view coding-session model: Native provider-native fidelity, React Terminal live interaction, and React Smart Session understanding backed by PE factual and semantic models.
    - **Evidence and Factual State** (`richer_session_evidence_and_factual_state`) - phase; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: deterministic current state; execution: complete / Provenance Engine; parallelism: serial
      - **Richer Coding-Agent Evidence Foundation** (`richer_session_observable_evidence`) - milestone; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: evidence store; execution: complete / Provenance Engine; parallelism: serial
        Enables: `factual_session_projection_read_contract`
        - **Richer coding-agent evidence foundation** (`richer_coding_agent_evidence_foundation`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: evidence store; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented; mirrors: `richer_session_work_model`; maturity: complete
          Enables: `factual_session_projection_foundation`
          Evidence: BrianBusby/bmux@9e69452a2ec2, BrianBusby/bmux@45b7188ea62d, BrianBusby/bmux#48 by [BrianBusby](https://github.com/BrianBusby)
          Acceptance reason: Completed-unit coding-agent evidence exists below the semantic layer; raw provider streams, private reasoning, approvals, validation, errors, and compaction remain gated follow-ups.
      - **Factual Session Projection Read Contract** (`factual_session_projection_read_contract`) - milestone; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: deterministic current state; execution: complete / Provenance Engine; parallelism: serial
        Depends on: `richer_session_observable_evidence`
        - **Factual session projection foundation** (`factual_session_projection_foundation`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: evidence and factual state; layer: deterministic current state; execution: complete / Provenance Engine; parallelism: serial; delivery: open; acceptance: implemented; mirrors: `richer_session_work_model`; maturity: validated
          Depends on: `richer_coding_agent_evidence_foundation`
          Enables: `factual_projection_consumer_shape_followup`
          Evidence: BrianBusby/bmux@2add52c611e2, BrianBusby/bmux@a0f8c1fa2d0e
          Acceptance reason: First revisioned factualSessionProjection read contract returns observed thread/turn evidence without semantic inference.
        - **Factual projection consumer shape follow-up** (`factual_projection_consumer_shape_followup`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: deterministic current state; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented; maturity: complete
          Depends on: `factual_session_projection_foundation`
          Enables: `factual_agent_session_view`, `semantic_inference_framework`
          Sequence before: `semantic_inference_framework`
          Expected contract domains: `factual_session_projection`, `deterministic_current_state`
          Expected code areas: `Sources/ProvenanceEngineContracts`, `Sources/ProvenanceEngineCore`, `Tests/ProvenanceEngineTests`, `bmux factual projection consumers`
          Likely conflict domains: `factual_session_projection_contract`, `deterministic_current_state_projection`, `bmux_consumer_contract_shape`
          Contract dependencies: `factual_session_projection_foundation`, `deterministic_current_state_api`
          Worktree required: true
          Evidence: BrianBusby/bmux@db5f21f4bb56
          Rationale: Confirmed the PE-owned consumer shape before semantic inference depends on the factual session projection.
          Acceptance reason: The public factual projection now exposes a detailed latest-turn snapshot, compact prior-turn references, compact provider-thread identities, and independent factual turn-detail retrieval while preserving deterministic evidence-only semantics and v1 decoding compatibility.
          Acceptance criteria: Confirm the factual projection shape needed by early consumers before semantic SessionWorkModel inference begins.; Preserve the boundary that deterministic Current State contains observed facts only.
    - **Semantic Understanding** (`semantic_understanding`) - phase; status: active; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: semantic understanding; layer: inference session work projections; execution: current / Provenance Engine; parallelism: serial; maturity: active
      Depends on: `factual_projection_consumer_shape_followup`
      - **Semantic SessionWorkModel Projection** (`semantic_session_work_model_projection`) - milestone; status: active; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: semantic understanding; layer: inference session work projections; execution: current / Provenance Engine; parallelism: serial; maturity: active
        - **Semantic inference framework** (`semantic_inference_framework`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: semantic understanding; layer: inference session work projections; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented; maturity: validated
          Depends on: `factual_projection_consumer_shape_followup`
          Enables: `first_semantic_session_inferences`, `blocker_approach_change_semantics`
          Expected contract domains: `semantic_inference_records`, `session_work_model_semantics`
          Expected code areas: `Sources/ProvenanceEngineContracts`, `Sources/ProvenanceEngineCore`, `Tests/ProvenanceEngineTests`
          Likely conflict domains: `semantic_inference_schema`, `session_work_model_projection`
          Contract dependencies: `factual_session_projection`, `evidence_reference_identity`
          Worktree required: true
          Evidence: BrianBusby/bmux@d66e847c5cb7
          Acceptance reason: Versioned semantic inference records, bounded input/invalidation/coalescing contracts, SQLite persistence, transactional supersession, and public query/publish APIs are implemented above deterministic factual projections without adding concrete semantic concepts.
          Acceptance criteria: Inference records carry supporting evidence, producer version, confidence, and supersession state.; Model-derived fields remain out of deterministic Current State.
        - **First semantic session inferences** (`first_semantic_session_inferences`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: semantic understanding; layer: inference session work projections; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented; maturity: validated
          Depends on: `semantic_inference_framework`
          Enables: `human_readable_semantic_messaging`, `milestone_inference`, `scoped_architecture_projection`
          Expected contract domains: `semantic_session_inferences`, `session_work_model_semantics`
          Expected code areas: `Sources/ProvenanceEngineCore`, `Tests/ProvenanceEngineTests`
          Likely conflict domains: `semantic_inference_schema`, `session_work_model_projection`
          Contract dependencies: `semantic_inference_records`, `factual_session_projection`
          Worktree required: true
          Evidence: BrianBusby/bmux@50a4fb58a114
          Acceptance reason: First concrete rule-produced semantic records now materialize thread intent, turn intent, session phase, and current activity from factual session projections with structured payloads, evidence references, factual revision, producer metadata, confidence, specificity, and supersession while keeping deterministic Current State factual only.
          Acceptance criteria: Thread intent, turn intent, session phase, and current activity are evidence-backed.
        - **Human-readable semantic messaging** (`human_readable_semantic_messaging`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: semantic understanding; layer: inference session work projections; execution: complete / Provenance Engine; parallelism: safe; delivery: merged; acceptance: implemented; maturity: validated
          Depends on: `first_semantic_session_inferences`
          Enables: `clickable_semantic_explanation_ui`, `presentation_language_calibration_corpus`, `react_smart_session_foundation`, `session_work_model_contract_foundation`
          Parallel with: `presentation_language_calibration_corpus`
          Expected contract domains: `semantic_message_contract`, `session_work_model_presentation`
          Expected code areas: `Sources/ProvenanceEngineCore`, `docs/session-work-model.md`, `bmux semantic presentation consumers`
          Likely conflict domains: `semantic_message_contract`, `session_work_model_projection`
          Contract dependencies: `semantic_session_inferences`
          Worktree required: true
          Conflict note: Safe with the calibration corpus only when messaging edits stay in presentation contract code and corpus edits stay in example data.
          Evidence: BrianBusby/bmux@ec0baa4b0d83
          Acceptance reason: Human-readable semantic message contracts, deterministic default rendering for first coding-agent semantic kinds, SQLite message cache/history persistence, public publish/query/materialization APIs, and coverage for wording, policy separation, supersession, rollback, retrieval, and Current State separation are implemented.
          Acceptance criteria: Semantic inference records can be rendered into cached concise and expanded messages.; Message records preserve structured semantic meaning, provenance, confidence, specificity, producer, policy, history, and supersession.; Presentation wording remains separate from semantic inference truth and deterministic Current State.
        - **SessionWorkModel contract foundation** (`session_work_model_contract_foundation`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: semantic understanding; layer: inference session work projections; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented; maturity: validated
          Depends on: `human_readable_semantic_messaging`
          Enables: `react_smart_session_initial_work_model_consumer`, `react_smart_session_work_model_consumer`
          Expected contract domains: `session_work_model_contract`, `factual_semantic_provenance`, `semantic_inference_records`
          Expected code areas: `Sources/ProvenanceEngineContracts`, `Sources/ProvenanceEngineCore`, `Tests/ProvenanceEngineTests`, `docs/session-work-model.md`
          Likely conflict domains: `session_work_model_projection`, `semantic_inference_contract`, `factual_session_projection_contract`
          Contract dependencies: `factual_session_projection`, `semantic_inference_records`, `semantic_session_inferences`
          Worktree required: true
          Conflict note: Define the PE-owned contract before bmux builds richer Smart Session presentation so bmux consumes a revisioned model instead of composing its own semantic interpretation.
          Evidence: BrianBusby/bmux@c623bf26bd8a, BrianBusby/bmux#57 by [BrianBusby](https://github.com/BrianBusby)
          Rationale: Introduce the first revisioned PE-owned SessionWorkModel snapshot contract for Smart Session consumers. The contract preserves evidence references, deterministic factual projections, semantic inference records, and presentation boundaries without using semantic messages as truth input.
          Acceptance reason: PR #57 merged the SessionWorkModel contract foundation. The contract is validated for the initial supported semantic fields while milestone, blocker, approach-change, progress, validation, and architecture semantics remain gated.
          Acceptance criteria: Expose a public SessionWorkModel read contract through ProvenanceEngineClient.; Compose deterministic factual session projection with active semantic inference records.; Preserve factual and semantic provenance, revision metadata, unknown states, and semantic-message separation.
        - **Continuous presentation learning** (`continuous_presentation_learning`) - slice; status: planned; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: semantic understanding; layer: inference session work projections; execution: planned / Shared; parallelism: safe; delivery: proposed; acceptance: proposed; maturity: gated
          Depends on: `clickable_semantic_explanation_ui`, `presentation_language_calibration_corpus`
          Expected contract domains: `presentation_feedback_events`, `semantic_message_calibration`
          Expected code areas: `Sources/ProvenanceEngineCore`, `bmux semantic feedback surfaces`
          Likely conflict domains: `presentation_feedback_events`, `semantic_message_calibration`
          Contract dependencies: `semantic_explanation_provenance`, `presentation_language_corpus`
          Worktree required: true
          Gate `explanation_ui_validated`: requires `clickable_semantic_explanation_ui` maturity validated; reason: Presentation learning needs validated explanation affordances and feedback capture before wording examples are durable.
          Gate `calibration_corpus_validated`: requires `presentation_language_calibration_corpus` maturity validated; reason: Presentation learning needs a validated corpus before feedback changes policy.
        - **Presentation language calibration corpus** (`presentation_language_calibration_corpus`) - slice; status: planned; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: semantic understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: safe; delivery: proposed; acceptance: proposed; maturity: captured
          Depends on: `first_semantic_session_inferences`
          Parallel with: `human_readable_semantic_messaging`
          Expected contract domains: `presentation_language_corpus`, `semantic_message_calibration`
          Expected code areas: `Tests/ProvenanceEngineTests`, `docs/session-work-model.md`, `calibration fixtures`
          Likely conflict domains: `presentation_language_corpus`, `semantic_message_calibration`
          Contract dependencies: `semantic_session_inferences`
          Worktree required: true
          Conflict note: Safe with human-readable messaging only when corpus edits do not change the semantic message contract.
    - **Three-view Coding Session Experience** (`three_view_coding_session_experience`) - phase; status: active; owner: Bmux; repositories: Bmux, Provenance Engine; concept: semantic understanding; layer: consumer presentation; execution: current / Bmux; parallelism: safe
      Depends on: `factual_projection_consumer_shape_followup`
      Rationale: Make the three distinct user-facing views durable in Project Truth: Native preserves provider-native fidelity, Terminal is the bmux React live interaction surface, and Session is a separate React smart summary surface backed by PE factual and semantic models.
      - **Coding Session View Surfaces** (`coding_session_view_surfaces`) - milestone; status: active; owner: Bmux; repositories: Bmux, Provenance Engine; concept: semantic understanding; layer: consumer presentation; execution: current / Bmux; parallelism: safe
        Rationale: Groups bmux-owned presentation and navigation work that keeps Native, Terminal, and Session as separate views over one underlying coding-agent session identity.
        - **Factual agent session view** (`factual_agent_session_view`) - slice; status: implemented; owner: Bmux; repositories: Bmux, Provenance Engine; concept: evidence and factual state; layer: consumer presentation; execution: complete / Bmux; parallelism: conditional; delivery: merged; acceptance: implemented
          Depends on: `factual_projection_consumer_shape_followup`
          Enables: `react_smart_session_foundation`
          Expected contract domains: `factual_session_projection`, `bmux_factual_session_view`
          Expected code areas: `Sources/Panels/AgentSessionFactualProjectionView.swift`, `Sources/Panels/TerminalPanelView.swift`, `Sources/WorkProvenance/AgentSessionFactualProjectionStore.swift`, `future React Smart Session factual data bridge`, `bmux factual projection consumers`
          Likely conflict domains: `bmux_factual_session_view`, `bmux_panel_ui`, `factual_session_projection_consumer`
          Contract dependencies: `factual_session_projection`, `deterministic_current_state_api`
          Worktree required: true
          Conflict note: Merged bmux PR #49 preserves factual Swift/native Session UI only. Treat it as factual consumer groundwork and diagnostic scaffolding, not the final React Smart Session product.
          Execution notes: PR #49 is factual-only Swift/native UI and should not be counted as satisfying React Smart Session or clickable semantic explanation behavior.
          Evidence: BrianBusby/bmux@6fe54d5411fe, BrianBusby/bmux@1c1281d7b58d, BrianBusby/bmux#49 by [BrianBusby](https://github.com/BrianBusby)
          Rationale: Records the completed bmux factual Session view work as a prerequisite PE factual-projection consumer. The native view is useful inspection/debug scaffolding and data-access foundation, but the intended user-facing Smart Session surface is React and remains separate from the React Terminal transcript/live interaction surface.
        - **React Terminal live interaction productization** (`react_terminal_productization`) - slice; status: planned; owner: Bmux; repositories: Bmux; concept: execution telemetry; layer: consumer presentation; execution: planned / Bmux; parallelism: safe; delivery: proposed; acceptance: proposed; maturity: captured
          Enables: `three_view_session_navigation`
          Expected contract domains: `agent_chat_live_event_schema`, `provider_runtime_identity`, `native_webview_surface_lifecycle`
          Expected code areas: `agent-chat`, `Sources/Panels/AgentSessionWebRenderer.swift`, `Sources/Panels/AgentSessionWebRendererCoordinator.swift`, `Sources/Panels/AgentSessionPanel.swift`, `Sources/Panels/BrowserPanelView.swift`
          Likely conflict domains: `agent_chat_surface_lifecycle`, `provider_runtime_controls`, `browser_surface_integration`
          Contract dependencies: `codex_app_server_live_events`, `bmux_browser_surface_hosting`
          Worktree required: true
          Conflict note: Can proceed in parallel with PE semantic work when it remains focused on live interaction, provider controls, runtime identity, and surface lifecycle rather than Smart Session inference.
          Rationale: Productize the existing agent-chat React surface as bmux's Terminal view for live conversation, streaming, tool lifecycle, controls, interrupts, and provider-normalized interaction. It must not become the Smart Session semantic summary surface or duplicate PE inference.
        - **React Smart Session foundation** (`react_smart_session_foundation`) - slice; status: implemented; owner: Bmux; repositories: Bmux, Provenance Engine; concept: semantic understanding; layer: consumer presentation; execution: complete / Bmux; parallelism: conditional; delivery: merged; acceptance: under observation; maturity: validated
          Depends on: `factual_agent_session_view`, `human_readable_semantic_messaging`
          Enables: `clickable_semantic_explanation_ui`, `react_smart_session_initial_work_model_consumer`, `react_smart_session_work_model_consumer`, `three_view_session_navigation`
          Expected contract domains: `factual_session_projection`, `semantic_message_contract`, `react_smart_session_data_bridge`
          Expected code areas: `agent-chat shared React shell and primitives`, `React Smart Session surface`, `Sources/Panels/AgentSessionPanel.swift`, `Sources/WorkProvenance`, `docs/provenance-integration.md`
          Likely conflict domains: `react_session_presentation`, `factual_session_projection_consumer`, `semantic_message_consumer`
          Contract dependencies: `factual_session_projection`, `semantic_message_contract`, `bmux_panel_surface_identity`
          Worktree required: true
          Conflict note: Start after factual Session UI lands so the React surface can reuse proven factual consumer shape. Keep the presentation summary-oriented and PE-backed rather than transcript-oriented.
          Evidence: BrianBusby/bmux@1a9f01708b55, BrianBusby/bmux#56 by [BrianBusby](https://github.com/BrianBusby)
          Rationale: Establish a separate React Session surface that consumes PE factual projections and existing semantic messages through a typed revision-safe bridge. This foundation must not infer session meaning from raw provider events inside bmux and must not define the future PE-owned SessionWorkModel contract.
          Acceptance reason: PR #56 merged the React Smart Session foundation delivery. Acceptance remains under observation after PR #58 validated the first SessionWorkModel-backed consumer path.
        - **React Smart Session initial SessionWorkModel consumer** (`react_smart_session_initial_work_model_consumer`) - slice; status: implemented; owner: Bmux; repositories: Bmux, Provenance Engine; concept: structured work understanding; layer: consumer presentation; execution: complete / Bmux; parallelism: serial; delivery: merged; acceptance: under observation; maturity: validated
          Depends on: `react_smart_session_foundation`, `session_work_model_contract_foundation`
          Enables: `react_smart_session_work_model_consumer`
          Expected contract domains: `session_work_model_contract`, `react_smart_session_data_bridge`
          Expected code areas: `React Smart Session surface`, `bmux SessionWorkModel client`, `Sources/WorkProvenance`, `Sources/ProvenanceEngineContracts`
          Likely conflict domains: `session_work_model_projection`, `react_session_presentation`, `project_truth_manifest`
          Contract dependencies: `session_work_model_contract`, `react_smart_session_surface_identity`
          Worktree required: true
          Conflict note: This is the narrow first consumer proving SessionWorkModel -> bridge -> React rendering. It must not claim the later milestone/blocker-gated Smart Session consumer complete.
          Evidence: BrianBusby/bmux@000468433cc4, BrianBusby/bmux@335237bf8680, BrianBusby/bmux#58 by [BrianBusby](https://github.com/BrianBusby)
          Rationale: Replace the Slice 1 disposable Smart Session bridge composition with the first PE-owned SessionWorkModel consumer path for supported fields only, while leaving milestone, blocker, approach-change, progress, and architecture semantics gated for later work.
          Acceptance reason: PR #58 merged the initial React Smart Session SessionWorkModel consumer for supported intent, activity, phase, factual evidence, revision, and provenance fields. The broader Smart SessionWorkModel consumer remains gated because milestone and blocker/approach-change semantics are still intentionally gated.
        - **React Smart SessionWorkModel consumer** (`react_smart_session_work_model_consumer`) - slice; status: planned; owner: Bmux; repositories: Bmux, Provenance Engine; concept: structured work understanding; layer: consumer presentation; execution: planned / Bmux; parallelism: serial; delivery: proposed; acceptance: proposed; maturity: gated
          Depends on: `react_smart_session_initial_work_model_consumer`, `react_smart_session_foundation`, `session_work_model_contract_foundation`, `milestone_inference`, `blocker_approach_change_semantics`
          Enables: `continuous_presentation_learning`
          Expected contract domains: `session_work_model_contract`, `milestone_semantics`, `blocker_approach_change_semantics`, `semantic_explanation_provenance`
          Expected code areas: `React Smart Session surface`, `bmux SessionWorkModel client`, `Sources/WorkProvenance`, `Sources/ProvenanceEngineContracts`
          Likely conflict domains: `session_work_model_projection`, `react_session_presentation`, `semantic_message_contract`
          Contract dependencies: `session_work_model_contract`, `milestone_semantics`, `semantic_message_contract`
          Worktree required: true
          Conflict note: Wait for PE to own richer progress, blocker, approach-change, and milestone semantics before presenting them as Smart Session truth in bmux.
          Gate `milestone_semantics_validated`: requires `milestone_inference` maturity validated; reason: Smart Session must not present progress or milestone structure until PE milestone semantics are validated.
          Gate `blocker_approach_semantics_validated`: requires `blocker_approach_change_semantics` maturity validated; reason: Smart Session blocker and approach-change presentation must be backed by validated PE semantics.
          Rationale: Consume the PE SessionWorkModel for completed-turn summaries, current-turn state, plan/progress, blockers, approach changes, validations, and richer session-level synthesis once those contracts exist.
        - **Clickable semantic explanation UI** (`clickable_semantic_explanation_ui`) - slice; status: planned; owner: Bmux; repositories: Bmux, Provenance Engine; concept: semantic understanding; layer: consumer presentation; execution: planned / Bmux; parallelism: serial; delivery: proposed; acceptance: proposed; maturity: captured
          Depends on: `react_smart_session_foundation`, `human_readable_semantic_messaging`
          Expected contract domains: `semantic_explanation_provenance`, `bmux_semantic_presentation`
          Expected code areas: `React Smart Session evidence drill-down`, `bmux semantic presentation consumers`, `Sources/ProvenanceEngineContracts`
          Likely conflict domains: `bmux_semantic_presentation`, `semantic_message_contract`
          Contract dependencies: `semantic_message_contract`, `session_work_model_presentation`
          Worktree required: true
          Rationale: Add clickable/expandable explanations inside the React Smart Session surface after the summary surface exists, preserving provenance boundaries between observed evidence, deterministic projection, semantic interpretation, and presentation text.
        - **Three-view session navigation** (`three_view_session_navigation`) - slice; status: planned; owner: Bmux; repositories: Bmux, Provenance Engine; concept: semantic understanding; layer: consumer presentation; execution: planned / Bmux; parallelism: conditional; delivery: proposed; acceptance: proposed; maturity: gated
          Depends on: `react_terminal_productization`, `react_smart_session_foundation`
          Expected contract domains: `provider_thread_identity`, `bmux_session_identity`, `worktree_identity`, `surface_restore_state`
          Expected code areas: `Sources/Panels/AgentSessionPanel.swift`, `Sources/Panels/TerminalPanelView.swift`, `Sources/Panels/AgentSessionWebRenderer.swift`, `agent-chat`, `bmux surface routing and restoration`
          Likely conflict domains: `session_surface_identity`, `provider_native_terminal_hosting`, `browser_webview_surface_lifecycle`
          Contract dependencies: `react_terminal_surface_identity`, `react_smart_session_surface_identity`, `provider_thread_identity`
          Worktree required: true
          Conflict note: Depends on productized Terminal and Smart Session foundations so switching preserves one underlying agent session instead of creating separate conceptual sessions.
          Gate `terminal_productized`: requires `react_terminal_productization` maturity validated; reason: Three-view navigation should preserve identity across a productized Terminal surface, not an unfinished live-interaction direction.
          Rationale: Provide coherent switching among Native, Terminal, and Session views while preserving provider thread/session identity, working directory/worktree identity, active view restoration, and the provider-native escape hatch.
    - **Structured Work Understanding** (`structured_work_understanding`) - phase; status: planned; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: structured work understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: safe; maturity: ready
      Depends on: `first_semantic_session_inferences`
      - **Milestone Semantics and Relationships** (`semantic_milestone_relationships`) - milestone; status: planned; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: structured work understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: safe; maturity: ready
        - **Milestone inference** (`milestone_inference`) - slice; status: planned; owner: Provenance Engine; repositories: Provenance Engine; concept: structured work understanding; layer: inference session work projections; execution: selected next / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed; maturity: ready
          Depends on: `first_semantic_session_inferences`
          Enables: `milestone_to_code_relationships`, `milestone_to_architecture_relationships`
          Expected contract domains: `milestone_semantics`, `session_work_model_milestones`
          Expected code areas: `Sources/ProvenanceEngineCore`, `Tests/ProvenanceEngineTests`
          Likely conflict domains: `milestone_semantics`, `session_work_model_projection`
          Contract dependencies: `semantic_session_inferences`
          Worktree required: true
        - **Blocker and approach-change semantics** (`blocker_approach_change_semantics`) - slice; status: planned; owner: Provenance Engine; repositories: Provenance Engine; concept: structured work understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: safe; delivery: proposed; acceptance: proposed; maturity: ready
          Depends on: `semantic_inference_framework`
          Parallel with: `milestone_inference`
          Expected contract domains: `blocker_semantics`, `approach_change_semantics`
          Expected code areas: `Sources/ProvenanceEngineCore`, `Tests/ProvenanceEngineTests`
          Likely conflict domains: `blocker_semantics`, `approach_change_semantics`
          Contract dependencies: `semantic_inference_records`
          Worktree required: true
          Conflict note: Safe only if blocker and approach-change records stay independent from milestone hierarchy writes.
        - **Milestone-to-code relationships** (`milestone_to_code_relationships`) - slice; status: planned; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: structured work understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed; maturity: gated
          Depends on: `milestone_inference`, `richer_coding_agent_evidence_foundation`
          Expected contract domains: `milestone_code_relationships`, `file_change_attribution`
          Expected code areas: `Sources/ProvenanceEngineCore`, `Sources/ProvenanceEngineContracts`, `Tests/ProvenanceEngineTests`
          Likely conflict domains: `milestone_relationships`, `file_change_attribution`
          Contract dependencies: `milestone_semantics`, `richer_coding_agent_evidence`
          Worktree required: true
          Gate `milestone_semantics_validated`: requires `milestone_inference` maturity validated; reason: Code relationships need validated milestone identity and hierarchy before attribution can be trusted.
    - **Architecture Understanding** (`architecture_understanding`) - phase; status: planned; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: architecture understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: safe; maturity: gated
      Depends on: `first_semantic_session_inferences`
      Gate `milestone_code_relationships_validated`: requires `milestone_to_code_relationships` maturity validated; reason: Architecture understanding should build after milestone-to-code relationships can anchor architecture claims to real work evidence.
      - **Scoped Architecture Understanding** (`scoped_architecture_understanding`) - milestone; status: planned; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: architecture understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: serial; maturity: gated
        - **Scoped architecture projection** (`scoped_architecture_projection`) - slice; status: planned; owner: Provenance Engine; repositories: Provenance Engine; concept: architecture understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed; maturity: gated
          Depends on: `first_semantic_session_inferences`, `milestone_to_code_relationships`
          Enables: `milestone_to_architecture_relationships`
          Expected contract domains: `scoped_architecture_projection`, `architecture_evidence_relationships`
          Expected code areas: `Sources/ProvenanceEngineCore`, `Sources/ProvenanceEngineContracts`, `Tests/ProvenanceEngineTests`
          Likely conflict domains: `scoped_architecture_projection`, `architecture_relationships`
          Contract dependencies: `semantic_session_inferences`, `file_change_attribution`
          Worktree required: true
          Gate `milestone_code_relationships_validated`: requires `milestone_to_code_relationships` maturity validated; reason: Scoped architecture projection should be designed against validated milestone-to-code evidence relationships.
        - **Milestone-to-architecture relationships** (`milestone_to_architecture_relationships`) - slice; status: planned; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: architecture understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed; maturity: gated
          Depends on: `scoped_architecture_projection`, `milestone_inference`
          Expected contract domains: `milestone_architecture_relationships`, `scoped_architecture_projection`
          Expected code areas: `Sources/ProvenanceEngineCore`, `Tests/ProvenanceEngineTests`
          Likely conflict domains: `milestone_relationships`, `architecture_relationships`
          Contract dependencies: `scoped_architecture_projection`, `milestone_semantics`
          Worktree required: true
          Gate `scoped_architecture_validated`: requires `scoped_architecture_projection` maturity validated; reason: Milestone-to-architecture links require validated scoped architecture projections.
          Gate `milestone_semantics_validated`: requires `milestone_inference` maturity validated; reason: Milestone-to-architecture links require validated milestone identity and hierarchy.
    - **Durable Knowledge** (`durable_knowledge`) - phase; status: deferred; owner: Provenance Engine; repositories: Provenance Engine; concept: durable knowledge; layer: knowledge compiler; execution: deferred / Provenance Engine; parallelism: serial; maturity: gated
      Depends on: `milestone_to_code_relationships`, `milestone_to_architecture_relationships`
      Expected contract domains: `knowledge_compiler_outputs`, `retrieval_context_packages`
      Expected code areas: `Sources/ProvenanceEngineCore`, `Sources/ProvenanceEngineContracts`, `Tests/ProvenanceEngineTests`, `docs/reference-architecture.md`
      Likely conflict domains: `knowledge_compiler`, `retrieval_contracts`
      Contract dependencies: `milestone_code_relationships`, `milestone_architecture_relationships`
      Worktree required: true
      Gate `milestone_code_relationships_validated`: requires `milestone_to_code_relationships` maturity validated; reason: Durable knowledge compilation depends on validated milestone-to-code evidence relationships.
      Gate `milestone_architecture_relationships_validated`: requires `milestone_to_architecture_relationships` maturity validated; reason: Durable knowledge compilation depends on validated milestone-to-architecture relationships.
      - **Knowledge Compiler and Validation** (`knowledge_compiler_later`) - milestone; status: deferred; owner: Provenance Engine; repositories: Provenance Engine; concept: durable knowledge; layer: knowledge compiler; execution: deferred / Provenance Engine; parallelism: serial; maturity: gated
        - **Local Knowledge Compiler** (`knowledge_compiler_outcomes`) - slice; status: deferred; owner: Provenance Engine; repositories: Provenance Engine; concept: durable knowledge; layer: knowledge compiler; execution: deferred / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed; maturity: gated
          Depends on: `milestone_to_code_relationships`, `milestone_to_architecture_relationships`
          Gate `milestone_code_relationships_validated`: requires `milestone_to_code_relationships` maturity validated; reason: The compiler should consume validated milestone-to-code relationships rather than infer from branch existence.
          Gate `milestone_architecture_relationships_validated`: requires `milestone_to_architecture_relationships` maturity validated; reason: The compiler should consume validated milestone-to-architecture relationships before producing reusable knowledge.
          Rationale: Durable Knowledge Compiler artifacts remain intentionally later than live session evidence, inference, milestone-code relationships, and architecture projection validation.
        - **Validate compiled knowledge usefulness** (`compiled_knowledge_validation`) - slice; status: deferred; owner: Provenance Engine; repositories: Provenance Engine; concept: durable knowledge; layer: knowledge compiler; execution: deferred / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed; maturity: gated
          Depends on: `knowledge_compiler_outcomes`
          Gate `compiler_implementation_available`: requires `knowledge_compiler_outcomes` maturity active; reason: Usefulness validation needs real compiler output to evaluate.
          Rationale: Validate that compiler output is useful, evidence-linked, rebuildable, and scoped before retrieval designs depend on it.
      - **Evidence-Aware Retrieval** (`evidence_aware_retrieval`) - milestone; status: deferred; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: retrieval; layer: retrieval engine; execution: deferred / Provenance Engine; parallelism: serial; maturity: gated
        - **Evidence-aware knowledge retrieval** (`evidence_aware_knowledge_retrieval`) - slice; status: deferred; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: retrieval; layer: retrieval engine; execution: deferred / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed; maturity: gated
          Depends on: `compiled_knowledge_validation`
          Gate `compiled_knowledge_validated`: requires `knowledge_compiler_outcomes` maturity validated; reason: Retrieval should be designed against real useful compiled knowledge.
          Gate `compiler_usefulness_validated`: requires `compiled_knowledge_validation` maturity validated; reason: Retrieval should wait until compiled-knowledge usefulness has been observed.
          Rationale: Evidence-aware retrieval remains gated until Knowledge Compiler output and its usefulness are validated.
        - **Validate context effectiveness** (`validate_context_effectiveness`) - slice; status: deferred; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: retrieval; layer: retrieval engine; execution: deferred / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed; maturity: gated
          Depends on: `evidence_aware_knowledge_retrieval`
          Gate `retrieval_implementation_available`: requires `evidence_aware_knowledge_retrieval` maturity active; reason: Context effectiveness validation needs a retrieval implementation to measure.
          Rationale: Validate that retrieved context reduces rediscovery and preserves citation quality before specialist-agent work depends on it.
      - **PE-Backed Agents and Shared Knowledge** (`pe_agent_shared_knowledge`) - milestone; status: deferred; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: shared evidence; layer: knowledge store; execution: deferred / Provenance Engine; parallelism: serial; maturity: gated
        - **PE-backed specialist agent** (`pe_backed_specialist_agent`) - slice; status: deferred; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: deployment; layer: retrieval engine; execution: deferred / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed; maturity: gated
          Depends on: `validate_context_effectiveness`
          Gate `context_effectiveness_validated`: requires `validate_context_effectiveness` maturity validated; reason: Specialist agents should use retrieval only after context effectiveness has been validated.
          Rationale: Specialist-agent behavior remains future work until retrieval quality is validated and evidence boundaries are proven.
        - **Shared knowledge** (`shared_knowledge`) - slice; status: deferred; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: shared evidence; layer: knowledge store; execution: deferred / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed; maturity: gated
          Depends on: `pe_backed_specialist_agent`
          Gate `specialist_agent_validated`: requires `pe_backed_specialist_agent` maturity validated; reason: Shared knowledge should wait until PE-backed specialist-agent consumption proves the local retrieval path.
          Rationale: Shared knowledge remains a later capability and must not be inferred from local architecture documentation alone.
        - **Shared retrieval** (`shared_retrieval`) - slice; status: deferred; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: retrieval; layer: retrieval engine; execution: deferred / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed; maturity: gated
          Depends on: `shared_knowledge`
          Gate `shared_knowledge_validated`: requires `shared_knowledge` maturity validated; reason: Shared retrieval requires validated shared-knowledge storage and evidence boundaries.
          Rationale: Shared retrieval is gated behind validated shared knowledge.
        - **Curated training corpus** (`curated_training_corpus`) - slice; status: deferred; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: durable knowledge; layer: knowledge store; execution: deferred / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed; maturity: gated
          Depends on: `pe_backed_specialist_agent`
          Gate `specialist_agent_validated`: requires `pe_backed_specialist_agent` maturity validated; reason: Training corpus curation should wait for validated PE-backed specialist-agent behavior and evidence selection.
          Rationale: PE-derived training remains captured as a future capability and is not authorized for implementation in this governance slice.
        - **PE-trained behavior layer** (`pe_trained_behavior_layer`) - slice; status: deferred; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: deployment; layer: retrieval engine; execution: deferred / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed; maturity: gated
          Depends on: `curated_training_corpus`
          Gate `training_corpus_validated`: requires `curated_training_corpus` maturity validated; reason: PE-trained behavior requires a validated, curated, evidence-safe corpus first.
          Rationale: Model or behavior training is a future capability and remains gated behind corpus validation.
        - **Organization-specific engineering intelligence** (`organization_specific_engineering_intelligence`) - slice; status: deferred; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: deployment; layer: retrieval engine; execution: deferred / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed; maturity: gated
          Depends on: `shared_retrieval`, `pe_trained_behavior_layer`
          Gate `shared_retrieval_validated`: requires `shared_retrieval` maturity validated; reason: Organization-specific intelligence requires validated shared retrieval.
          Gate `trained_behavior_validated`: requires `pe_trained_behavior_layer` maturity validated; reason: Organization-specific intelligence should only combine with PE-trained behavior after that layer is validated.
          Rationale: Organization-scale intelligence is the downstream convergence point and remains gated by both shared retrieval and PE-derived behavior validation.

## Parallel Worktree Preflight

Active assignments are derived from roadmap slice nodes with `status: active` or `execution.assignment: current`.

| Slice | Parallelism | Worktree | Branch | Agent/session | Conflict domains | Contract dependencies | Safety |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Project Truth dependency and capability frontier governance (`project_truth_capability_frontier_governance`) | safe | /Users/brianbusby/repos/bmux-project-truth-capability-frontier-governance | project-truth-capability-frontier-governance | Codex | `project_docs_generation`, `project_truth_manifest`, `roadmap_schema` | `project_docs_validation`, `project_truth_generated_docs` | single active assignment |

### Dependency-Ready Preflight

| Slice | Selection | Dependency status | Parallelism | Worktree required | Conflict domains | Contract dependencies | Expected contract domains | Expected code areas |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Milestone inference (`milestone_inference`) | selected next | ready | serial | true | `milestone_semantics`, `session_work_model_projection` | `semantic_session_inferences` | `milestone_semantics`, `session_work_model_milestones` | `Sources/ProvenanceEngineCore`, `Tests/ProvenanceEngineTests` |
| Blocker and approach-change semantics (`blocker_approach_change_semantics`) | planned | ready | safe | true | `blocker_semantics`, `approach_change_semantics` | `semantic_inference_records` | `blocker_semantics`, `approach_change_semantics` | `Sources/ProvenanceEngineCore`, `Tests/ProvenanceEngineTests` |

## Dependency-Ready Work

- Milestone inference (`milestone_inference`) - selection: selected next; depends on: `first_semantic_session_inferences`
- Blocker and approach-change semantics (`blocker_approach_change_semantics`) - selection: planned; depends on: `semantic_inference_framework`

## Selected Next Work

- Milestone inference (`milestone_inference`) - dependency status: ready; depends on: `first_semantic_session_inferences`

## Dependency-Ready But Not Selected

- Blocker and approach-change semantics (`blocker_approach_change_semantics`) - depends on: `semantic_inference_framework`

## Deferred Or Blocked Work

- Durable Knowledge (`durable_knowledge`) - status: deferred; depends on: `milestone_to_code_relationships`, `milestone_to_architecture_relationships`
- Knowledge Compiler and Validation (`knowledge_compiler_later`) - status: deferred; depends on: None
- Local Knowledge Compiler (`knowledge_compiler_outcomes`) - status: deferred; depends on: `milestone_to_code_relationships`, `milestone_to_architecture_relationships`
- Validate compiled knowledge usefulness (`compiled_knowledge_validation`) - status: deferred; depends on: `knowledge_compiler_outcomes`
- Evidence-Aware Retrieval (`evidence_aware_retrieval`) - status: deferred; depends on: None
- Evidence-aware knowledge retrieval (`evidence_aware_knowledge_retrieval`) - status: deferred; depends on: `compiled_knowledge_validation`
- Validate context effectiveness (`validate_context_effectiveness`) - status: deferred; depends on: `evidence_aware_knowledge_retrieval`
- PE-Backed Agents and Shared Knowledge (`pe_agent_shared_knowledge`) - status: deferred; depends on: None
- PE-backed specialist agent (`pe_backed_specialist_agent`) - status: deferred; depends on: `validate_context_effectiveness`
- Shared knowledge (`shared_knowledge`) - status: deferred; depends on: `pe_backed_specialist_agent`
- Shared retrieval (`shared_retrieval`) - status: deferred; depends on: `shared_knowledge`
- Curated training corpus (`curated_training_corpus`) - status: deferred; depends on: `pe_backed_specialist_agent`
- PE-trained behavior layer (`pe_trained_behavior_layer`) - status: deferred; depends on: `curated_training_corpus`
- Organization-specific engineering intelligence (`organization_specific_engineering_intelligence`) - status: deferred; depends on: `shared_retrieval`, `pe_trained_behavior_layer`
