<!--
GENERATED FILE. DO NOT EDIT MANUALLY.
Sources:
- project/project-state.yaml
- project/repo-status.yaml
Regenerate with: ./scripts/project-docs generate
-->


# Nested Roadmap

This view is generated from `project/project-state.yaml` and preserves the roadmap hierarchy, sequencing, and evidence references.

## Roadmap Tree

- **Bmux and Provenance Engine** (`bmux_provenance_platform`) - project; status: active; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: platform; layer: platform; execution: current / Shared; parallelism: safe
  Rationale: Canonical cross-repository roadmap root for Provenance Engine-owned evidence/current-state work and bmux-owned observation/presentation work.
  - **V1 Foundation and Bmux Adoption** (`v1_foundation_and_adoption`) - program; status: accepted; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: v1 adoption; layer: platform; execution: complete / Shared; parallelism: serial
    Rationale: Records the accepted V1 package and first bmux adoption path without expanding the legacy flat milestone list.
    - **V1 Baseline** (`v1_baseline`) - phase; status: accepted; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: v1 adoption; layer: evidence store; execution: complete / Shared; parallelism: serial
      - **V1 Package and Slice E Adoption** (`v1_package_and_slice_e`) - milestone; status: accepted; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: v1 adoption; layer: platform; execution: complete / Shared; parallelism: serial
        - **Provenance Engine V1 package** (`provenance_engine_v1`) - slice; status: accepted; owner: Provenance Engine; repositories: Provenance Engine; concept: v1 adoption; layer: evidence store; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: accepted; mirrors: `provenance_engine_v1`
          Enables: `bmux_slice_e_adoption`
          Evidence: BrianBusby/provenance-engine@18f5511a7c83, BrianBusby/provenance-engine@0ed9f68b6612
        - **Bmux Provenance Engine Slice E adoption** (`bmux_slice_e_adoption`) - slice; status: accepted; owner: Bmux; repositories: Bmux, Provenance Engine; concept: v1 adoption; layer: consumer presentation; execution: complete / Bmux; parallelism: serial; delivery: merged; acceptance: accepted; mirrors: `bmux_slice_e_adoption`
          Depends on: `provenance_engine_v1`
          Evidence: BrianBusby/bmux@3cbacd150176, BrianBusby/provenance-engine@0ed9f68b6612
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
          Evidence: BrianBusby/provenance-engine@bdf81ae0454f, BrianBusby/bmux@543161954689
  - **Project Truth Governance** (`project_truth_governance`) - program; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: project truth; layer: project truth; execution: complete / Provenance Engine; parallelism: safe
    Rationale: Maintains canonical structured project state, generated status, and read-only CI checks that prevent authored documentation drift.
    - **Canonical Project Truth State** (`canonical_project_truth_state`) - phase; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: project truth; layer: project truth; execution: complete / Provenance Engine; parallelism: serial
      - **Project Truth Manifest and CI** (`project_truth_manifest_and_ci`) - milestone; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: project truth; layer: project truth; execution: complete / Provenance Engine; parallelism: serial
        - **Canonical project truth manifest and generated docs** (`canonical_project_truth_manifest`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: project truth; layer: project truth; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented
          Enables: `read_only_project_truth_ci_gate`
          Evidence: BrianBusby/provenance-engine@88a9b4e175d4
        - **Read-only Project Truth CI gate** (`read_only_project_truth_ci_gate`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: project truth; layer: cross repository workflow; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented
          Depends on: `canonical_project_truth_manifest`
          Evidence: BrianBusby/provenance-engine@df3866f697a9
        - **Phase 0A Canonical Nested Roadmap and Concept Classification** (`phase_0a_canonical_nested_roadmap`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: project truth; layer: project truth; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented
          Depends on: `read_only_project_truth_ci_gate`
          Enables: `phase_0b_current_target_architecture`
          Expected contract domains: `roadmap_hierarchy`, `roadmap_dependency_validation`
          Expected code areas: `project/project-state.yaml`, `project/schema/project-state.schema.json`, `tools/project-docs`, `docs/generated`
          Likely conflict domains: `project/project-state.yaml`, `project/schema`, `tools/project-docs`, `docs/generated`
          Contract dependencies: `project_truth_generated_docs`, `project_docs_validation`
          Worktree required: true
          Evidence: BrianBusby/provenance-engine@e278a4423f15, BrianBusby/provenance-engine#21 by [BrianBusby](https://github.com/BrianBusby)
          Rationale: Establishes the nested dependency-aware roadmap and generated nested-roadmap view that later planning and architecture slices build on.
        - **Phase 0B Current-and-Target Architecture** (`phase_0b_current_target_architecture`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: project truth; layer: project truth; execution: complete / Provenance Engine; parallelism: safe; delivery: merged; acceptance: implemented
          Depends on: `phase_0a_canonical_nested_roadmap`
          Enables: `phase_0c_parallel_worktree_metadata`
          Expected contract domains: `current_target_architecture_status`
          Expected code areas: `docs/current-and-target-architecture.md`, `tools/project-docs`
          Likely conflict domains: `project/project-state.yaml`, `docs/generated`
          Contract dependencies: `project_truth_generated_docs`
          Worktree required: true
          Evidence: BrianBusby/provenance-engine@533567ead8c6, BrianBusby/provenance-engine#22 by [BrianBusby](https://github.com/BrianBusby)
          Rationale: Records the living current-and-target architecture guide and its generated status block as project-truth infrastructure without changing product implementation sequencing.
        - **Phase 0C Parallel Slice Planning and Worktree Safety Metadata** (`phase_0c_parallel_worktree_metadata`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: project truth; layer: cross repository workflow; execution: complete / Provenance Engine; parallelism: safe; delivery: merged; acceptance: implemented
          Depends on: `phase_0b_current_target_architecture`
          Expected contract domains: `roadmap_parallelism_metadata`, `active_worktree_preflight`
          Expected code areas: `project/project-state.yaml`, `project/schema/project-state.schema.json`, `project/schema/repo-status.schema.json`, `tools/project-docs`, `docs/generated`
          Likely conflict domains: `project/project-state.yaml`, `project/schema`, `tools/project-docs`, `docs/generated`
          Contract dependencies: `project_truth_generated_docs`, `project_docs_validation`
          Worktree required: true
          Evidence: BrianBusby/provenance-engine@6fee11b0fa40, BrianBusby/provenance-engine#23 by [BrianBusby](https://github.com/BrianBusby)
          Rationale: Adds manifest-only parallel slice planning metadata, active worktree and branch safety validation, and generated preflight visibility without assigning future work automatically.
  - **Richer Session Understanding** (`richer_session_understanding`) - program; status: active; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: inference session work projections; execution: current / Shared; parallelism: safe
    Depends on: `workspace_display_durable_context`
    Rationale: Richer coding-agent evidence and session projections are the active direction after V1 adoption and workspace-display observation.
    - **Evidence and Factual State** (`richer_session_evidence_and_factual_state`) - phase; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: deterministic current state; execution: complete / Provenance Engine; parallelism: serial
      - **Richer Coding-Agent Evidence Foundation** (`richer_session_observable_evidence`) - milestone; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: evidence store; execution: complete / Provenance Engine; parallelism: serial
        Enables: `factual_session_projection_read_contract`
        - **Richer coding-agent evidence foundation** (`richer_coding_agent_evidence_foundation`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: evidence store; execution: complete / Provenance Engine; parallelism: serial; delivery: open; acceptance: implemented; mirrors: `richer_session_work_model`
          Enables: `factual_session_projection_foundation`
          Evidence: BrianBusby/provenance-engine@9e69452a2ec2
          Acceptance reason: Completed-unit coding-agent evidence exists below the semantic layer; raw provider streams, private reasoning, approvals, validation, errors, and compaction remain gated follow-ups.
      - **Factual Session Projection Read Contract** (`factual_session_projection_read_contract`) - milestone; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: deterministic current state; execution: complete / Provenance Engine; parallelism: serial
        Depends on: `richer_session_observable_evidence`
        - **Factual session projection foundation** (`factual_session_projection_foundation`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: evidence and factual state; layer: deterministic current state; execution: complete / Provenance Engine; parallelism: serial; delivery: open; acceptance: implemented; mirrors: `richer_session_work_model`
          Depends on: `richer_coding_agent_evidence_foundation`
          Enables: `factual_projection_consumer_shape_followup`
          Evidence: BrianBusby/provenance-engine@2add52c611e2, BrianBusby/provenance-engine@a0f8c1fa2d0e
          Acceptance reason: First revisioned factualSessionProjection read contract returns observed thread/turn evidence without semantic inference.
        - **Factual projection consumer shape follow-up** (`factual_projection_consumer_shape_followup`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: deterministic current state; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented
          Depends on: `factual_session_projection_foundation`
          Enables: `semantic_inference_framework`
          Sequence before: `semantic_inference_framework`
          Expected contract domains: `factual_session_projection`, `deterministic_current_state`
          Expected code areas: `Sources/ProvenanceEngineContracts`, `Sources/ProvenanceEngineCore`, `Tests/ProvenanceEngineTests`, `bmux factual projection consumers`
          Likely conflict domains: `factual_session_projection_contract`, `deterministic_current_state_projection`, `bmux_consumer_contract_shape`
          Contract dependencies: `factual_session_projection_foundation`, `deterministic_current_state_api`
          Worktree required: true
          Evidence: BrianBusby/provenance-engine@db5f21f4bb56, BrianBusby/provenance-engine#24 by [BrianBusby](https://github.com/BrianBusby)
          Rationale: Confirmed the PE-owned consumer shape before semantic inference depends on the factual session projection.
          Acceptance reason: The public factual projection now exposes a detailed latest-turn snapshot, compact prior-turn references, compact provider-thread identities, and independent factual turn-detail retrieval while preserving deterministic evidence-only semantics and v1 decoding compatibility.
          Acceptance criteria: Confirm the factual projection shape needed by early consumers before semantic SessionWorkModel inference begins.; Preserve the boundary that deterministic Current State contains observed facts only.
    - **Semantic Understanding** (`semantic_understanding`) - phase; status: active; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: semantic understanding; layer: inference session work projections; execution: current / Provenance Engine; parallelism: serial
      Depends on: `factual_projection_consumer_shape_followup`
      - **Semantic SessionWorkModel Projection** (`semantic_session_work_model_projection`) - milestone; status: active; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: semantic understanding; layer: inference session work projections; execution: current / Provenance Engine; parallelism: serial
        - **Semantic inference framework** (`semantic_inference_framework`) - slice; status: planned; owner: Provenance Engine; repositories: Provenance Engine; concept: semantic understanding; layer: inference session work projections; execution: next eligible / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed
          Depends on: `factual_projection_consumer_shape_followup`
          Enables: `first_semantic_session_inferences`, `blocker_approach_change_semantics`
          Expected contract domains: `semantic_inference_records`, `session_work_model_semantics`
          Expected code areas: `Sources/ProvenanceEngineContracts`, `Sources/ProvenanceEngineCore`, `Tests/ProvenanceEngineTests`
          Likely conflict domains: `semantic_inference_schema`, `session_work_model_projection`
          Contract dependencies: `factual_session_projection`, `evidence_reference_identity`
          Worktree required: true
          Acceptance criteria: Inference records carry supporting evidence, producer version, confidence, and supersession state.; Model-derived fields remain out of deterministic Current State.
        - **First semantic session inferences** (`first_semantic_session_inferences`) - slice; status: planned; owner: Provenance Engine; repositories: Provenance Engine; concept: semantic understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed
          Depends on: `semantic_inference_framework`
          Enables: `human_readable_semantic_messaging`, `milestone_inference`, `scoped_architecture_projection`
          Expected contract domains: `semantic_session_inferences`, `session_work_model_semantics`
          Expected code areas: `Sources/ProvenanceEngineCore`, `Tests/ProvenanceEngineTests`
          Likely conflict domains: `semantic_inference_schema`, `session_work_model_projection`
          Contract dependencies: `semantic_inference_records`, `factual_session_projection`
          Worktree required: true
          Acceptance criteria: Thread intent, turn intent, session phase, and current activity are evidence-backed.
        - **Human-readable semantic messaging** (`human_readable_semantic_messaging`) - slice; status: planned; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: semantic understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: safe; delivery: proposed; acceptance: proposed
          Depends on: `first_semantic_session_inferences`
          Enables: `clickable_semantic_explanation_ui`, `presentation_language_calibration_corpus`
          Parallel with: `presentation_language_calibration_corpus`
          Expected contract domains: `semantic_message_contract`, `session_work_model_presentation`
          Expected code areas: `Sources/ProvenanceEngineCore`, `docs/session-work-model.md`, `bmux semantic presentation consumers`
          Likely conflict domains: `semantic_message_contract`, `session_work_model_projection`
          Contract dependencies: `semantic_session_inferences`
          Worktree required: true
          Conflict note: Safe with the calibration corpus only when messaging edits stay in presentation contract code and corpus edits stay in example data.
        - **Clickable semantic explanation UI** (`clickable_semantic_explanation_ui`) - slice; status: planned; owner: Bmux; repositories: Bmux, Provenance Engine; concept: semantic understanding; layer: consumer presentation; execution: planned / Bmux; parallelism: serial; delivery: proposed; acceptance: proposed
          Depends on: `human_readable_semantic_messaging`
          Expected contract domains: `semantic_explanation_provenance`, `bmux_semantic_presentation`
          Expected code areas: `bmux UI semantic explanation surfaces`, `Sources/ProvenanceEngineContracts`
          Likely conflict domains: `bmux_semantic_presentation`, `semantic_message_contract`
          Contract dependencies: `semantic_message_contract`, `session_work_model_presentation`
          Worktree required: true
        - **Continuous presentation learning** (`continuous_presentation_learning`) - slice; status: planned; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: semantic understanding; layer: inference session work projections; execution: planned / Shared; parallelism: safe; delivery: proposed; acceptance: proposed
          Depends on: `clickable_semantic_explanation_ui`, `presentation_language_calibration_corpus`
          Expected contract domains: `presentation_feedback_events`, `semantic_message_calibration`
          Expected code areas: `Sources/ProvenanceEngineCore`, `bmux semantic feedback surfaces`
          Likely conflict domains: `presentation_feedback_events`, `semantic_message_calibration`
          Contract dependencies: `semantic_explanation_provenance`, `presentation_language_corpus`
          Worktree required: true
        - **Presentation language calibration corpus** (`presentation_language_calibration_corpus`) - slice; status: planned; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: semantic understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: safe; delivery: proposed; acceptance: proposed
          Depends on: `first_semantic_session_inferences`
          Parallel with: `human_readable_semantic_messaging`
          Expected contract domains: `presentation_language_corpus`, `semantic_message_calibration`
          Expected code areas: `Tests/ProvenanceEngineTests`, `docs/session-work-model.md`, `calibration fixtures`
          Likely conflict domains: `presentation_language_corpus`, `semantic_message_calibration`
          Contract dependencies: `semantic_session_inferences`
          Worktree required: true
          Conflict note: Safe with human-readable messaging only when corpus edits do not change the semantic message contract.
    - **Structured Work Understanding** (`structured_work_understanding`) - phase; status: planned; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: structured work understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: safe
      Depends on: `first_semantic_session_inferences`
      - **Milestone Semantics and Relationships** (`semantic_milestone_relationships`) - milestone; status: planned; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: structured work understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: safe
        - **Milestone inference** (`milestone_inference`) - slice; status: planned; owner: Provenance Engine; repositories: Provenance Engine; concept: structured work understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed
          Depends on: `first_semantic_session_inferences`
          Enables: `milestone_to_code_relationships`, `milestone_to_architecture_relationships`
          Expected contract domains: `milestone_semantics`, `session_work_model_milestones`
          Expected code areas: `Sources/ProvenanceEngineCore`, `Tests/ProvenanceEngineTests`
          Likely conflict domains: `milestone_semantics`, `session_work_model_projection`
          Contract dependencies: `semantic_session_inferences`
          Worktree required: true
        - **Blocker and approach-change semantics** (`blocker_approach_change_semantics`) - slice; status: planned; owner: Provenance Engine; repositories: Provenance Engine; concept: structured work understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: safe; delivery: proposed; acceptance: proposed
          Depends on: `semantic_inference_framework`
          Parallel with: `milestone_inference`
          Expected contract domains: `blocker_semantics`, `approach_change_semantics`
          Expected code areas: `Sources/ProvenanceEngineCore`, `Tests/ProvenanceEngineTests`
          Likely conflict domains: `blocker_semantics`, `approach_change_semantics`
          Contract dependencies: `semantic_inference_records`
          Worktree required: true
          Conflict note: Safe only if blocker and approach-change records stay independent from milestone hierarchy writes.
        - **Milestone-to-code relationships** (`milestone_to_code_relationships`) - slice; status: planned; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: structured work understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed
          Depends on: `milestone_inference`, `richer_coding_agent_evidence_foundation`
          Expected contract domains: `milestone_code_relationships`, `file_change_attribution`
          Expected code areas: `Sources/ProvenanceEngineCore`, `Sources/ProvenanceEngineContracts`, `Tests/ProvenanceEngineTests`
          Likely conflict domains: `milestone_relationships`, `file_change_attribution`
          Contract dependencies: `milestone_semantics`, `richer_coding_agent_evidence`
          Worktree required: true
    - **Architecture Understanding** (`architecture_understanding`) - phase; status: planned; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: architecture understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: safe
      Depends on: `first_semantic_session_inferences`
      - **Scoped Architecture Understanding** (`scoped_architecture_understanding`) - milestone; status: planned; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: architecture understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: serial
        - **Scoped architecture projection** (`scoped_architecture_projection`) - slice; status: planned; owner: Provenance Engine; repositories: Provenance Engine; concept: architecture understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed
          Depends on: `first_semantic_session_inferences`
          Enables: `milestone_to_architecture_relationships`
          Expected contract domains: `scoped_architecture_projection`, `architecture_evidence_relationships`
          Expected code areas: `Sources/ProvenanceEngineCore`, `Sources/ProvenanceEngineContracts`, `Tests/ProvenanceEngineTests`
          Likely conflict domains: `scoped_architecture_projection`, `architecture_relationships`
          Contract dependencies: `semantic_session_inferences`, `file_change_attribution`
          Worktree required: true
        - **Milestone-to-architecture relationships** (`milestone_to_architecture_relationships`) - slice; status: planned; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: architecture understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed
          Depends on: `scoped_architecture_projection`, `milestone_inference`
          Expected contract domains: `milestone_architecture_relationships`, `scoped_architecture_projection`
          Expected code areas: `Sources/ProvenanceEngineCore`, `Tests/ProvenanceEngineTests`
          Likely conflict domains: `milestone_relationships`, `architecture_relationships`
          Contract dependencies: `scoped_architecture_projection`, `milestone_semantics`
          Worktree required: true
    - **Durable Knowledge** (`durable_knowledge`) - phase; status: deferred; owner: Provenance Engine; repositories: Provenance Engine; concept: durable knowledge; layer: knowledge compiler; execution: deferred / Provenance Engine; parallelism: serial
      Depends on: `milestone_to_code_relationships`, `milestone_to_architecture_relationships`
      Expected contract domains: `knowledge_compiler_outputs`, `retrieval_context_packages`
      Expected code areas: `Sources/ProvenanceEngineCore`, `Sources/ProvenanceEngineContracts`, `Tests/ProvenanceEngineTests`, `docs/reference-architecture.md`
      Likely conflict domains: `knowledge_compiler`, `retrieval_contracts`
      Contract dependencies: `milestone_code_relationships`, `milestone_architecture_relationships`
      Worktree required: true
      - **Knowledge Compiler Later** (`knowledge_compiler_later`) - milestone; status: deferred; owner: Provenance Engine; repositories: Provenance Engine; concept: durable knowledge; layer: knowledge compiler; execution: deferred / Provenance Engine; parallelism: serial
        - **Knowledge Compiler work later** (`knowledge_compiler_outcomes`) - slice; status: deferred; owner: Provenance Engine; repositories: Provenance Engine; concept: durable knowledge; layer: knowledge compiler; execution: deferred / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed
          Depends on: `milestone_to_code_relationships`, `milestone_to_architecture_relationships`
          Rationale: Durable Knowledge Compiler artifacts remain intentionally later than live session evidence, inference, and architecture projection validation.

## Parallel Worktree Preflight

Active assignments are derived from roadmap slice nodes with `status: active` or `execution.assignment: current`.

- Active implementation assignments: none selected.

### Next Eligible Preflight

| Slice | Parallelism | Worktree required | Conflict domains | Contract dependencies | Expected contract domains | Expected code areas |
| --- | --- | --- | --- | --- | --- | --- |
| Semantic inference framework (`semantic_inference_framework`) | serial | true | `semantic_inference_schema`, `session_work_model_projection` | `factual_session_projection`, `evidence_reference_identity` | `semantic_inference_records`, `session_work_model_semantics` | `Sources/ProvenanceEngineContracts`, `Sources/ProvenanceEngineCore`, `Tests/ProvenanceEngineTests` |

## Next Eligible Work

- Semantic inference framework (`semantic_inference_framework`) - depends on: `factual_projection_consumer_shape_followup`

## Deferred Or Blocked Work

- Durable Knowledge (`durable_knowledge`) - status: deferred; depends on: `milestone_to_code_relationships`, `milestone_to_architecture_relationships`
- Knowledge Compiler Later (`knowledge_compiler_later`) - status: deferred; depends on: None
- Knowledge Compiler work later (`knowledge_compiler_outcomes`) - status: deferred; depends on: `milestone_to_code_relationships`, `milestone_to_architecture_relationships`
