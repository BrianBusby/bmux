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
  - **Project Truth Governance** (`project_truth_governance`) - program; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: project truth; layer: project truth; execution: complete / Provenance Engine; parallelism: safe
    Rationale: Maintains canonical structured project state, generated status, and read-only CI checks that prevent authored documentation drift.
    - **Canonical Project Truth State** (`canonical_project_truth_state`) - phase; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: project truth; layer: project truth; execution: complete / Provenance Engine; parallelism: serial
      - **Project Truth Manifest and CI** (`project_truth_manifest_and_ci`) - milestone; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: project truth; layer: project truth; execution: complete / Provenance Engine; parallelism: serial
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
  - **Richer Session Understanding** (`richer_session_understanding`) - program; status: active; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: inference session work projections; execution: current / Shared; parallelism: safe
    Depends on: `workspace_display_durable_context`
    Rationale: Richer coding-agent evidence and session projections are the active direction after V1 adoption and workspace-display observation. This program now explicitly supports bmux's three-view coding-session model: Native provider-native fidelity, React Terminal live interaction, and React Smart Session understanding backed by PE factual and semantic models.
    - **Evidence and Factual State** (`richer_session_evidence_and_factual_state`) - phase; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: deterministic current state; execution: complete / Provenance Engine; parallelism: serial
      - **Richer Coding-Agent Evidence Foundation** (`richer_session_observable_evidence`) - milestone; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: evidence store; execution: complete / Provenance Engine; parallelism: serial
        Enables: `factual_session_projection_read_contract`
        - **Richer coding-agent evidence foundation** (`richer_coding_agent_evidence_foundation`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: evidence store; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented; mirrors: `richer_session_work_model`
          Enables: `factual_session_projection_foundation`
          Evidence: BrianBusby/bmux@9e69452a2ec2, BrianBusby/bmux@45b7188ea62d, BrianBusby/bmux#48 by [BrianBusby](https://github.com/BrianBusby)
          Acceptance reason: Completed-unit coding-agent evidence exists below the semantic layer; raw provider streams, private reasoning, approvals, validation, errors, and compaction remain gated follow-ups.
      - **Factual Session Projection Read Contract** (`factual_session_projection_read_contract`) - milestone; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: deterministic current state; execution: complete / Provenance Engine; parallelism: serial
        Depends on: `richer_session_observable_evidence`
        - **Factual session projection foundation** (`factual_session_projection_foundation`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: evidence and factual state; layer: deterministic current state; execution: complete / Provenance Engine; parallelism: serial; delivery: open; acceptance: implemented; mirrors: `richer_session_work_model`
          Depends on: `richer_coding_agent_evidence_foundation`
          Enables: `factual_projection_consumer_shape_followup`
          Evidence: BrianBusby/bmux@2add52c611e2, BrianBusby/bmux@a0f8c1fa2d0e
          Acceptance reason: First revisioned factualSessionProjection read contract returns observed thread/turn evidence without semantic inference.
        - **Factual projection consumer shape follow-up** (`factual_projection_consumer_shape_followup`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: deterministic current state; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented
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
    - **Semantic Understanding** (`semantic_understanding`) - phase; status: active; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: semantic understanding; layer: inference session work projections; execution: current / Provenance Engine; parallelism: serial
      Depends on: `factual_projection_consumer_shape_followup`
      - **Semantic SessionWorkModel Projection** (`semantic_session_work_model_projection`) - milestone; status: active; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: semantic understanding; layer: inference session work projections; execution: current / Provenance Engine; parallelism: serial
        - **Semantic inference framework** (`semantic_inference_framework`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: semantic understanding; layer: inference session work projections; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented
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
        - **First semantic session inferences** (`first_semantic_session_inferences`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: semantic understanding; layer: inference session work projections; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented
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
        - **Human-readable semantic messaging** (`human_readable_semantic_messaging`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: semantic understanding; layer: inference session work projections; execution: complete / Provenance Engine; parallelism: safe; delivery: merged; acceptance: implemented
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
        - **SessionWorkModel contract foundation** (`session_work_model_contract_foundation`) - slice; status: planned; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: semantic understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed
          Depends on: `human_readable_semantic_messaging`
          Enables: `react_smart_session_work_model_consumer`
          Expected contract domains: `session_work_model_contract`, `factual_semantic_provenance`, `semantic_message_contract`
          Expected code areas: `Sources/ProvenanceEngineContracts`, `Sources/ProvenanceEngineCore`, `Tests/ProvenanceEngineTests`, `docs/session-work-model.md`
          Likely conflict domains: `session_work_model_projection`, `semantic_message_contract`, `factual_session_projection_contract`
          Contract dependencies: `factual_session_projection`, `semantic_message_contract`, `semantic_session_inferences`
          Worktree required: true
          Conflict note: Define the PE-owned contract before bmux builds richer Smart Session presentation so bmux consumes a revisioned model instead of composing its own semantic interpretation.
          Rationale: Introduce the first revisioned PE-owned SessionWorkModel snapshot contract for Smart Session consumers. The contract should preserve evidence references, deterministic factual projections, semantic inference records, semantic messages, and presentation boundaries.
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
        - **React Terminal live interaction productization** (`react_terminal_productization`) - slice; status: planned; owner: Bmux; repositories: Bmux; concept: execution telemetry; layer: consumer presentation; execution: planned / Bmux; parallelism: safe; delivery: proposed; acceptance: proposed
          Enables: `three_view_session_navigation`
          Expected contract domains: `agent_chat_live_event_schema`, `provider_runtime_identity`, `native_webview_surface_lifecycle`
          Expected code areas: `agent-chat`, `Sources/Panels/AgentSessionWebRenderer.swift`, `Sources/Panels/AgentSessionWebRendererCoordinator.swift`, `Sources/Panels/AgentSessionPanel.swift`, `Sources/Panels/BrowserPanelView.swift`
          Likely conflict domains: `agent_chat_surface_lifecycle`, `provider_runtime_controls`, `browser_surface_integration`
          Contract dependencies: `codex_app_server_live_events`, `bmux_browser_surface_hosting`
          Worktree required: true
          Conflict note: Can proceed in parallel with PE semantic work when it remains focused on live interaction, provider controls, runtime identity, and surface lifecycle rather than Smart Session inference.
          Rationale: Productize the existing agent-chat React surface as bmux's Terminal view for live conversation, streaming, tool lifecycle, controls, interrupts, and provider-normalized interaction. It must not become the Smart Session semantic summary surface or duplicate PE inference.
        - **React Smart Session foundation** (`react_smart_session_foundation`) - slice; status: planned; owner: Bmux; repositories: Bmux, Provenance Engine; concept: semantic understanding; layer: consumer presentation; execution: selected next / Bmux; parallelism: conditional; delivery: proposed; acceptance: proposed
          Depends on: `factual_agent_session_view`, `human_readable_semantic_messaging`
          Enables: `clickable_semantic_explanation_ui`, `react_smart_session_work_model_consumer`, `three_view_session_navigation`
          Expected contract domains: `factual_session_projection`, `semantic_message_contract`, `react_smart_session_data_bridge`
          Expected code areas: `agent-chat shared React shell and primitives`, `React Smart Session surface`, `Sources/Panels/AgentSessionPanel.swift`, `Sources/WorkProvenance`, `docs/provenance-integration.md`
          Likely conflict domains: `react_session_presentation`, `factual_session_projection_consumer`, `semantic_message_consumer`
          Contract dependencies: `factual_session_projection`, `semantic_message_contract`, `bmux_panel_surface_identity`
          Worktree required: true
          Conflict note: Start after factual Session UI lands so the React surface can reuse proven factual consumer shape. Keep the presentation summary-oriented and PE-backed rather than transcript-oriented.
          Rationale: Establish a separate React Session surface that summarizes goal, completed turns, current turn, activity, plan state, worked-on areas, validations, outcomes, and provenance using PE factual projections and semantic messages. This foundation must not infer session meaning from raw provider events inside bmux.
        - **React Smart SessionWorkModel consumer** (`react_smart_session_work_model_consumer`) - slice; status: planned; owner: Bmux; repositories: Bmux, Provenance Engine; concept: structured work understanding; layer: consumer presentation; execution: planned / Bmux; parallelism: serial; delivery: proposed; acceptance: proposed
          Depends on: `react_smart_session_foundation`, `session_work_model_contract_foundation`, `milestone_inference`, `blocker_approach_change_semantics`
          Enables: `continuous_presentation_learning`
          Expected contract domains: `session_work_model_contract`, `milestone_semantics`, `blocker_approach_change_semantics`, `semantic_explanation_provenance`
          Expected code areas: `React Smart Session surface`, `bmux SessionWorkModel client`, `Sources/WorkProvenance`, `Sources/ProvenanceEngineContracts`
          Likely conflict domains: `session_work_model_projection`, `react_session_presentation`, `semantic_message_contract`
          Contract dependencies: `session_work_model_contract`, `milestone_semantics`, `semantic_message_contract`
          Worktree required: true
          Conflict note: Wait for PE to own richer progress, blocker, approach-change, and milestone semantics before presenting them as Smart Session truth in bmux.
          Rationale: Consume the PE SessionWorkModel for completed-turn summaries, current-turn state, plan/progress, blockers, approach changes, validations, and richer session-level synthesis once those contracts exist.
        - **Clickable semantic explanation UI** (`clickable_semantic_explanation_ui`) - slice; status: planned; owner: Bmux; repositories: Bmux, Provenance Engine; concept: semantic understanding; layer: consumer presentation; execution: planned / Bmux; parallelism: serial; delivery: proposed; acceptance: proposed
          Depends on: `react_smart_session_foundation`, `human_readable_semantic_messaging`
          Expected contract domains: `semantic_explanation_provenance`, `bmux_semantic_presentation`
          Expected code areas: `React Smart Session evidence drill-down`, `bmux semantic presentation consumers`, `Sources/ProvenanceEngineContracts`
          Likely conflict domains: `bmux_semantic_presentation`, `semantic_message_contract`
          Contract dependencies: `semantic_message_contract`, `session_work_model_presentation`
          Worktree required: true
          Rationale: Add clickable/expandable explanations inside the React Smart Session surface after the summary surface exists, preserving provenance boundaries between observed evidence, deterministic projection, semantic interpretation, and presentation text.
        - **Three-view session navigation** (`three_view_session_navigation`) - slice; status: planned; owner: Bmux; repositories: Bmux, Provenance Engine; concept: semantic understanding; layer: consumer presentation; execution: planned / Bmux; parallelism: conditional; delivery: proposed; acceptance: proposed
          Depends on: `react_terminal_productization`, `react_smart_session_foundation`
          Expected contract domains: `provider_thread_identity`, `bmux_session_identity`, `worktree_identity`, `surface_restore_state`
          Expected code areas: `Sources/Panels/AgentSessionPanel.swift`, `Sources/Panels/TerminalPanelView.swift`, `Sources/Panels/AgentSessionWebRenderer.swift`, `agent-chat`, `bmux surface routing and restoration`
          Likely conflict domains: `session_surface_identity`, `provider_native_terminal_hosting`, `browser_webview_surface_lifecycle`
          Contract dependencies: `react_terminal_surface_identity`, `react_smart_session_surface_identity`, `provider_thread_identity`
          Worktree required: true
          Conflict note: Depends on productized Terminal and Smart Session foundations so switching preserves one underlying agent session instead of creating separate conceptual sessions.
          Rationale: Provide coherent switching among Native, Terminal, and Session views while preserving provider thread/session identity, working directory/worktree identity, active view restoration, and the provider-native escape hatch.
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

### Dependency-Ready Preflight

| Slice | Selection | Dependency status | Parallelism | Worktree required | Conflict domains | Contract dependencies | Expected contract domains | Expected code areas |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SessionWorkModel contract foundation (`session_work_model_contract_foundation`) | planned | ready | serial | true | `session_work_model_projection`, `semantic_message_contract`, `factual_session_projection_contract` | `factual_session_projection`, `semantic_message_contract`, `semantic_session_inferences` | `session_work_model_contract`, `factual_semantic_provenance`, `semantic_message_contract` | `Sources/ProvenanceEngineContracts`, `Sources/ProvenanceEngineCore`, `Tests/ProvenanceEngineTests`, `docs/session-work-model.md` |
| React Terminal live interaction productization (`react_terminal_productization`) | planned | ready | safe | true | `agent_chat_surface_lifecycle`, `provider_runtime_controls`, `browser_surface_integration` | `codex_app_server_live_events`, `bmux_browser_surface_hosting` | `agent_chat_live_event_schema`, `provider_runtime_identity`, `native_webview_surface_lifecycle` | `agent-chat`, `Sources/Panels/AgentSessionWebRenderer.swift`, `Sources/Panels/AgentSessionWebRendererCoordinator.swift`, `Sources/Panels/AgentSessionPanel.swift`, `Sources/Panels/BrowserPanelView.swift` |
| React Smart Session foundation (`react_smart_session_foundation`) | selected next | ready | conditional | true | `react_session_presentation`, `factual_session_projection_consumer`, `semantic_message_consumer` | `factual_session_projection`, `semantic_message_contract`, `bmux_panel_surface_identity` | `factual_session_projection`, `semantic_message_contract`, `react_smart_session_data_bridge` | `agent-chat shared React shell and primitives`, `React Smart Session surface`, `Sources/Panels/AgentSessionPanel.swift`, `Sources/WorkProvenance`, `docs/provenance-integration.md` |
| React Smart SessionWorkModel consumer (`react_smart_session_work_model_consumer`) | planned | blocked by `react_smart_session_foundation`, `session_work_model_contract_foundation`, `milestone_inference`, `blocker_approach_change_semantics` | serial | true | `session_work_model_projection`, `react_session_presentation`, `semantic_message_contract` | `session_work_model_contract`, `milestone_semantics`, `semantic_message_contract` | `session_work_model_contract`, `milestone_semantics`, `blocker_approach_change_semantics`, `semantic_explanation_provenance` | `React Smart Session surface`, `bmux SessionWorkModel client`, `Sources/WorkProvenance`, `Sources/ProvenanceEngineContracts` |
| Clickable semantic explanation UI (`clickable_semantic_explanation_ui`) | planned | blocked by `react_smart_session_foundation` | serial | true | `bmux_semantic_presentation`, `semantic_message_contract` | `semantic_message_contract`, `session_work_model_presentation` | `semantic_explanation_provenance`, `bmux_semantic_presentation` | `React Smart Session evidence drill-down`, `bmux semantic presentation consumers`, `Sources/ProvenanceEngineContracts` |
| Three-view session navigation (`three_view_session_navigation`) | planned | blocked by `react_terminal_productization`, `react_smart_session_foundation` | conditional | true | `session_surface_identity`, `provider_native_terminal_hosting`, `browser_webview_surface_lifecycle` | `react_terminal_surface_identity`, `react_smart_session_surface_identity`, `provider_thread_identity` | `provider_thread_identity`, `bmux_session_identity`, `worktree_identity`, `surface_restore_state` | `Sources/Panels/AgentSessionPanel.swift`, `Sources/Panels/TerminalPanelView.swift`, `Sources/Panels/AgentSessionWebRenderer.swift`, `agent-chat`, `bmux surface routing and restoration` |
| Continuous presentation learning (`continuous_presentation_learning`) | planned | blocked by `clickable_semantic_explanation_ui`, `presentation_language_calibration_corpus` | safe | true | `presentation_feedback_events`, `semantic_message_calibration` | `semantic_explanation_provenance`, `presentation_language_corpus` | `presentation_feedback_events`, `semantic_message_calibration` | `Sources/ProvenanceEngineCore`, `bmux semantic feedback surfaces` |
| Presentation language calibration corpus (`presentation_language_calibration_corpus`) | planned | ready | safe | true | `presentation_language_corpus`, `semantic_message_calibration` | `semantic_session_inferences` | `presentation_language_corpus`, `semantic_message_calibration` | `Tests/ProvenanceEngineTests`, `docs/session-work-model.md`, `calibration fixtures` |
| Milestone inference (`milestone_inference`) | planned | ready | serial | true | `milestone_semantics`, `session_work_model_projection` | `semantic_session_inferences` | `milestone_semantics`, `session_work_model_milestones` | `Sources/ProvenanceEngineCore`, `Tests/ProvenanceEngineTests` |
| Blocker and approach-change semantics (`blocker_approach_change_semantics`) | planned | ready | safe | true | `blocker_semantics`, `approach_change_semantics` | `semantic_inference_records` | `blocker_semantics`, `approach_change_semantics` | `Sources/ProvenanceEngineCore`, `Tests/ProvenanceEngineTests` |
| Milestone-to-code relationships (`milestone_to_code_relationships`) | planned | blocked by `milestone_inference` | serial | true | `milestone_relationships`, `file_change_attribution` | `milestone_semantics`, `richer_coding_agent_evidence` | `milestone_code_relationships`, `file_change_attribution` | `Sources/ProvenanceEngineCore`, `Sources/ProvenanceEngineContracts`, `Tests/ProvenanceEngineTests` |
| Scoped architecture projection (`scoped_architecture_projection`) | planned | ready | serial | true | `scoped_architecture_projection`, `architecture_relationships` | `semantic_session_inferences`, `file_change_attribution` | `scoped_architecture_projection`, `architecture_evidence_relationships` | `Sources/ProvenanceEngineCore`, `Sources/ProvenanceEngineContracts`, `Tests/ProvenanceEngineTests` |
| Milestone-to-architecture relationships (`milestone_to_architecture_relationships`) | planned | blocked by `scoped_architecture_projection`, `milestone_inference` | serial | true | `milestone_relationships`, `architecture_relationships` | `scoped_architecture_projection`, `milestone_semantics` | `milestone_architecture_relationships`, `scoped_architecture_projection` | `Sources/ProvenanceEngineCore`, `Tests/ProvenanceEngineTests` |

## Dependency-Ready Work

- SessionWorkModel contract foundation (`session_work_model_contract_foundation`) - selection: planned; depends on: `human_readable_semantic_messaging`
- React Terminal live interaction productization (`react_terminal_productization`) - selection: planned; depends on: None
- React Smart Session foundation (`react_smart_session_foundation`) - selection: selected next; depends on: `factual_agent_session_view`, `human_readable_semantic_messaging`
- Presentation language calibration corpus (`presentation_language_calibration_corpus`) - selection: planned; depends on: `first_semantic_session_inferences`
- Milestone inference (`milestone_inference`) - selection: planned; depends on: `first_semantic_session_inferences`
- Blocker and approach-change semantics (`blocker_approach_change_semantics`) - selection: planned; depends on: `semantic_inference_framework`
- Scoped architecture projection (`scoped_architecture_projection`) - selection: planned; depends on: `first_semantic_session_inferences`

## Selected Next Work

- React Smart Session foundation (`react_smart_session_foundation`) - dependency status: ready; depends on: `factual_agent_session_view`, `human_readable_semantic_messaging`

## Dependency-Ready But Not Selected

- SessionWorkModel contract foundation (`session_work_model_contract_foundation`) - depends on: `human_readable_semantic_messaging`
- React Terminal live interaction productization (`react_terminal_productization`) - depends on: None
- Presentation language calibration corpus (`presentation_language_calibration_corpus`) - depends on: `first_semantic_session_inferences`
- Milestone inference (`milestone_inference`) - depends on: `first_semantic_session_inferences`
- Blocker and approach-change semantics (`blocker_approach_change_semantics`) - depends on: `semantic_inference_framework`
- Scoped architecture projection (`scoped_architecture_projection`) - depends on: `first_semantic_session_inferences`

## Deferred Or Blocked Work

- Durable Knowledge (`durable_knowledge`) - status: deferred; depends on: `milestone_to_code_relationships`, `milestone_to_architecture_relationships`
- Knowledge Compiler Later (`knowledge_compiler_later`) - status: deferred; depends on: None
- Knowledge Compiler work later (`knowledge_compiler_outcomes`) - status: deferred; depends on: `milestone_to_code_relationships`, `milestone_to_architecture_relationships`
