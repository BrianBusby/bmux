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

- Primary Capability Frontier: Process Integrity (`process_integrity`)
- Active or selected slices in the frontier:
  - Deterministic App Runtime Composition and App-Host Test Isolation (`deterministic_app_runtime_composition`) - maturity: active; status: active; selection: current; owner: Bmux

### Active Implementation

- Deterministic App Runtime Composition and App-Host Test Isolation (`deterministic_app_runtime_composition`) - maturity: active; status: active; selection: current; owner: Bmux

### Selected Next

- None.

### Ready Candidates

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

## Roadmap Tree

- **Bmux and Provenance Engine** (`bmux_provenance_platform`) - project; status: active; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: platform; layer: platform; execution: current / Shared; parallelism: safe
  Rationale: Canonical monorepo roadmap root for Provenance Engine-owned evidence/current-state work and bmux-owned observation/presentation work.
  - **Process Integrity** (`process_integrity`) - program; status: active; owner: Bmux; repositories: Bmux, Provenance Engine; concept: platform; layer: platform; execution: current / Bmux; parallelism: serial
    Expected contract domains: `project_truth_reconciliation`, `app_runtime_composition`, `app_host_test_isolation`
    Likely conflict domains: `active_work_selection`, `app_startup_lifecycle`
    Rationale: Tracks cross-cutting process-integrity slices that define a single owner, lifecycle, validation path, and completion step for failure classes that individual feature fixes exposed but should not keep repairing locally.
    - **App Runtime Composition and Test Isolation** (`app_runtime_composition_and_test_isolation`) - phase; status: active; owner: Bmux; repositories: Bmux, Provenance Engine; concept: platform; layer: platform; execution: current / Bmux; parallelism: serial
      Depends on: `workspace_coding_agent_session_linkage_hardening`
      Expected contract domains: `production_runtime_startup`, `explicit_test_runtime_capabilities`, `service_readiness_and_teardown`
      Expected code areas: `Sources/bmuxApp.swift`, `Sources/AppDelegate*.swift`, `Sources/App/BmuxAppRuntime*.swift`, `Sources/WorkProvenance/*.swift`, `bmuxTests/*RuntimeCompositionTests.swift`
      Rationale: Gives background app services explicit construction, startup, readiness, failure, and teardown ownership so production starts them deliberately and app-host tests activate only requested capabilities.
      - **App Runtime Composition Migration** (`app_runtime_composition_migration`) - milestone; status: active; owner: Bmux; repositories: Bmux, Provenance Engine; concept: platform; layer: platform; execution: current / Bmux; parallelism: serial
        Depends on: `workspace_coding_agent_session_linkage_hardening`
        Rationale: Milestone for migrating app background service lifecycle ownership from scattered app-host side effects into explicit production/test runtime composition.
        - **Deterministic App Runtime Composition and App-Host Test Isolation** (`deterministic_app_runtime_composition`) - slice; status: active; owner: Bmux; repositories: Bmux, Provenance Engine; concept: platform; layer: platform; execution: current / Bmux; parallelism: serial; delivery: open; acceptance: proposed; maturity: active
          Depends on: `workspace_coding_agent_session_linkage_hardening`
          Enables: `app_runtime_service_lifecycle_migration`
          Expected contract domains: `app_runtime_service_construction`, `production_startup_lifecycle`, `app_host_test_runtime_capabilities`, `work_provenance_runtime_readiness`, `deterministic_teardown`
          Expected code areas: `Sources/bmuxApp.swift`, `Sources/AppDelegate*.swift`, `Sources/App/BmuxAppRuntime*.swift`, `Sources/WorkProvenance/*.swift`, `Sources/Mobile/AgentChat/AgentChatTranscriptPromptEvidenceSeeder.swift`, `Sources/Mobile/AgentChat/AgentChatTranscriptService.swift`, `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineSQLite/ProvenanceSQLiteRepository*.swift`, `bmuxTests/AppRuntimeCompositionTests.swift`, `bmuxTests/AgentChatSessionRegistryLifecycleTests.swift`, `bmuxTests/PromptSessionLinkProductionLifecycleTests.swift`, `Packages/macOS/ProvenanceEngine/Tests/ProvenanceEngineSQLiteTests/TurnOutcomeProjectionTests.swift`
          Likely conflict domains: `app_startup`, `work_provenance_runtime_startup`, `agent_chat_telemetry_projection`, `app_host_test_bootstrap`
          Contract dependencies: `workspace_coding_agent_session_association`, `factual_session_projection`
          Worktree required: true
          Active assignment: worktree: `/Users/brianbusby/repos/.bmux-worktrees/process-integrity-runtime-composition`; branch: `process-integrity-runtime-composition`; agent: `codex`
          Rationale: Move WorkProvenanceRuntime construction/startup and related agent-chat PE projection startup behind one app-runtime composition owner so production starts PE deliberately, default app-host tests cannot open the production PE database, opted-in tests use isolated storage, and migrated services expose deterministic readiness/failure/teardown.
          Acceptance criteria: App runtime composition is the only production source path that constructs the live WorkProvenanceRuntime.; BmuxAppRuntimeServices is the only production source path that starts PE workspace observation and agent-chat execution telemetry projection.; Default app-host XCTest composition disables PE without opening the production PE database.; Tests can opt into PE with a temporary home directory and observe ready, failed, and stopped lifecycle states without sleeps or timing assertions.; Runtime shutdown cancels migrated observation work and releases owned lifecycle tasks.; A source guard prevents migrated app entrypoints from bypassing the composition boundary.; Existing Session-tab production lifecycle coverage still reaches PE readiness through deterministic task completion.; Production PE prompt evidence appends scope turn-outcome evidence acquisition to the affected session instead of scanning unrelated ledger history.; Agent-chat startup prompt seeding skips ended historical Codex hook-store records while preserving non-ended live startup backfill and live UserPromptSubmit prompt evidence.
        - **Background Service Lifecycle Migration** (`app_runtime_service_lifecycle_migration`) - slice; status: planned; owner: Bmux; repositories: Bmux; concept: platform; layer: platform; execution: planned / Bmux; parallelism: serial; delivery: proposed; acceptance: proposed; maturity: gated
          Depends on: `deterministic_app_runtime_composition`
          Expected contract domains: `browser_lifecycle`, `sidebar_git_observation`, `remote_session_presence`, `push_registration`, `notification_runtime_services`
          Likely conflict domains: `app_delegate_startup`, `app_host_test_side_effects`, `global_singletons`
          Gate `runtime_composition_validated`: requires `deterministic_app_runtime_composition` maturity validated; reason: Additional background services should migrate only after the first PE-backed production/test composition path is validated.
          Rationale: Follow-up Process Integrity slice to migrate the next background service family exposed by app-host side effects into explicit construction, readiness, and teardown ownership.
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
    - **Runtime Observation and Workspace Display** (`runtime_observation_and_workspace_display`) - phase; status: active; owner: Bmux; repositories: Bmux, Provenance Engine; concept: workspace display; layer: deterministic current state; execution: complete / Shared; parallelism: serial
      Depends on: `bmux_slice_e_adoption`
      Rationale: Captures the post-V1 adoption work that connected bmux runtime observation to Provenance Engine-owned durable context and deterministic display projections.
      - **Execution Telemetry Migration** (`execution_telemetry_migration`) - milestone; status: active; owner: Bmux; repositories: Bmux; concept: execution telemetry; layer: evidence sources; execution: complete / Bmux; parallelism: serial
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
        - **Workspace Display Durable Context and Reconciliation** (`workspace_display_durable_context`) - slice; status: implemented; owner: Bmux; repositories: Bmux, Provenance Engine; concept: workspace display; layer: deterministic current state; execution: complete / Shared; parallelism: serial; delivery: merged; acceptance: accepted; mirrors: `workspace_display_durable_context`
          Depends on: `claude_lifecycle_telemetry`
          Enables: `richer_session_understanding`
          Evidence: BrianBusby/bmux@bdf81ae0454f, BrianBusby/bmux@543161954689
          Acceptance reason: The durable workspace display context implementation is present on monorepo main with recorded implementation commits and has remained the accepted substrate for subsequent workspace resource and session-link slices.
        - **Workspace Display Prompt Resource Discovery** (`workspace_display_prompt_resource_discovery`) - slice; status: implemented; owner: Bmux; repositories: Bmux, Provenance Engine; concept: workspace display; layer: evidence sources; execution: complete / Bmux; parallelism: conditional; delivery: merged; acceptance: accepted; maturity: validated
          Depends on: `workspace_display_durable_context`
          Enables: `richer_session_understanding`
          Expected contract domains: `workspace_display_resource_evidence`, `provider_specific_extraction`, `optional_provider_resolution`, `idempotent_prompt_backfill`
          Expected code areas: `Sources/WorkProvenance/WorkProvenanceWorkspaceResourceDiscovery.swift`, `Sources/WorkProvenance/WorkProvenanceWorkspaceDisplayResourceLinker.swift`, `Sources/WorkProvenance/WorkProvenanceObservationService.swift`, `bmuxTests/WorkProvenanceWorkspaceResourceDiscoveryTests.swift`
          Likely conflict domains: `workspace_display_current_state`, `submitted_prompt_display_metadata`, `linear_ticket_resolution`
          Contract dependencies: `workspace_display_durable_context`
          Worktree required: true
          Evidence: BrianBusby/bmux@9fc7061ba353, BrianBusby/bmux#93 by [BrianBusby](https://github.com/BrianBusby)
          Acceptance reason: bmux now performs bounded prompt-derived Linear resource discovery in the workspace observation path, merges it with PR-derived evidence, and writes normalized durable workspace display facts to Provenance Engine.
          Acceptance criteria: Submitted workspace prompts produce normalized Linear ticket evidence when they contain explicit Linear issue URLs or known bare ticket IDs.; Prompt evidence, stored-prompt backfill, PR title evidence, and PR branch evidence merge without duplicate ticket, ticket-link, or project-link facts.; Linear lookup enriches resolved tickets and projects when available, while unavailable authentication or resolution failure preserves unresolved IDs and explicit URLs for retry.; Sidebar and row views continue to render normalized PE workspace display metadata without provider-specific parsing.
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
        - **Project Truth dependency and capability frontier governance** (`project_truth_capability_frontier_governance`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: project truth; layer: project truth; execution: complete / Provenance Engine; parallelism: safe; delivery: merged; acceptance: implemented; maturity: validated
          Depends on: `monorepo_repository_consolidation`
          Expected contract domains: `roadmap_capability_maturity`, `roadmap_readiness_gates`, `primary_capability_frontier`
          Expected code areas: `project/project-state.yaml`, `project/repo-status.yaml`, `project/schema/project-state.schema.json`, `tools/project-docs`, `docs/generated`, `AGENTS.md`
          Likely conflict domains: `project_truth_manifest`, `project_docs_generation`, `roadmap_schema`
          Contract dependencies: `project_truth_generated_docs`, `project_docs_validation`
          Worktree required: true
          Conflict note: Infrastructure-only governance slice. It may run beside semantic-session implementation work when it does not edit product contracts, runtime behavior, or downstream PE capability code.
          Evidence: BrianBusby/bmux@0ce21dfb424d, BrianBusby/bmux@8a8a4de3064c, BrianBusby/bmux#60 by [BrianBusby](https://github.com/BrianBusby)
          Rationale: Add explicit capability maturity, readiness gates, primary frontier reporting, and stricter validation so documented future architecture cannot become implementation-ready without Project Truth authorization.
          Acceptance reason: PR #60 merged capability maturity, readiness gates, primary frontier reporting, stricter validation, and generated preflight visibility.
  - **Richer Session Understanding** (`richer_session_understanding`) - program; status: active; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: inference session work projections; execution: current / Shared; parallelism: safe; maturity: validated
    Depends on: `workspace_display_durable_context`
    Rationale: Richer coding-agent evidence and session projections are the active direction after V1 adoption and workspace-display observation. This program now explicitly supports bmux's three-view coding-session model: Native provider-native fidelity, React Terminal live interaction, and React Smart Session understanding backed by PE factual and semantic models.
    - **Evidence and Factual State** (`richer_session_evidence_and_factual_state`) - phase; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: deterministic current state; execution: complete / Provenance Engine; parallelism: serial
      - **Richer Coding-Agent Evidence Foundation** (`richer_session_observable_evidence`) - milestone; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: evidence store; execution: complete / Provenance Engine; parallelism: serial
        Enables: `factual_session_projection_read_contract`
        - **Richer coding-agent evidence foundation** (`richer_coding_agent_evidence_foundation`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: evidence store; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented; mirrors: `richer_session_work_model`; maturity: complete
          Enables: `factual_session_projection_foundation`
          Evidence: BrianBusby/bmux@9e69452a2ec2, BrianBusby/bmux@45b7188ea62d, BrianBusby/bmux#48 by [BrianBusby](https://github.com/BrianBusby)
          Acceptance reason: Completed-unit coding-agent evidence exists below the semantic layer; raw provider streams, private reasoning, approvals, validation, errors, and compaction remain gated follow-ups.
      - **Normal Coding-Agent Evidence Ingestion** (`normal_coding_agent_evidence_ingestion`) - milestone; status: implemented; owner: Bmux; repositories: Bmux, Provenance Engine; concept: evidence and factual state; layer: evidence sources; execution: complete / Bmux; parallelism: serial; maturity: validated
        Depends on: `richer_coding_agent_evidence_foundation`
        Enables: `factual_projection_consumer_shape_followup`, `semantic_inference_framework`
        Rationale: Ordinary Codex CLI sessions in bmux converge into PE's canonical coding-agent evidence through hook observations plus Codex JSONL transcript adaptation, without requiring Agent Chat.
        - **Codex transcript canonical evidence import** (`codex_transcript_canonical_evidence_import`) - slice; status: implemented; owner: Bmux; repositories: Bmux, Provenance Engine; concept: evidence and factual state; layer: evidence sources; execution: complete / Bmux; parallelism: serial; delivery: merged; acceptance: implemented; maturity: validated
          Depends on: `richer_coding_agent_evidence_foundation`
          Enables: `live_terminal_codex_evidence_ingestion`
          Expected contract domains: `codex_jsonl_transcript_adapter`, `canonical_coding_agent_evidence`, `idempotent_evidence_import`
          Expected code areas: `CLI/CLIProvenanceCodexTranscriptImporter*.swift`, `CLI/BMUXCLI+ProvenanceImport.swift`, `bmuxTests/CLIProvenanceCodexTranscriptImporterTests.swift`
          Likely conflict domains: `codex_transcript_parsing`, `provenance_cli_import`
          Contract dependencies: `richer_coding_agent_evidence_foundation`, `provenance_engine_public_append_contract`
          Worktree required: true
          Evidence: BrianBusby/bmux@6329fe8ec849, BrianBusby/bmux#66 by [BrianBusby](https://github.com/BrianBusby)
          Acceptance reason: Historical Codex JSONL transcripts import into canonical PE thread, turn, prompt, plan, command, visible reasoning summary, and file-change attribution evidence with stable idempotent event IDs.
        - **Live terminal Codex evidence ingestion** (`live_terminal_codex_evidence_ingestion`) - slice; status: implemented; owner: Bmux; repositories: Bmux, Provenance Engine; concept: evidence and factual state; layer: evidence sources; execution: complete / Bmux; parallelism: serial; delivery: open; acceptance: implemented; maturity: validated
          Depends on: `codex_transcript_canonical_evidence_import`
          Enables: `coding_agent_evidence_source_reconciliation`
          Expected contract domains: `codex_jsonl_transcript_adapter`, `canonical_coding_agent_evidence`, `live_transcript_tail_progress`, `restart_replay_idempotence`
          Expected code areas: `CLI/CLIProvenanceCodexTranscriptImporter*.swift`, `CLI/bmux.swift`, `bmuxTests/CLIProvenanceCodexTranscriptImporterTests.swift`
          Likely conflict domains: `codex_hook_monitor`, `codex_transcript_parsing`, `provenance_cli_import`
          Contract dependencies: `codex_transcript_canonical_evidence_import`, `provenance_engine_public_append_contract`
          Worktree required: true
          Evidence: BrianBusby/bmux@29a5a5d1ea0a
          Acceptance reason: The existing Codex monitor now tails known session transcripts into PE via the shared importer, preserving partial-line safety and stable event IDs while leaving raw private reasoning/full stream persistence out of scope.
          Acceptance criteria: Active bmux-managed Codex transcript monitors append newly completed JSONL lines through the shared canonical transcript adapter.; Partial final lines remain buffered until newline completion.; Live ingestion followed by historical import is idempotent.; Restart/replay can reread existing transcript content without duplicating canonical PE events.
        - **Coding-agent evidence source reconciliation** (`coding_agent_evidence_source_reconciliation`) - slice; status: implemented; owner: Bmux; repositories: Bmux, Provenance Engine; concept: evidence and factual state; layer: deterministic current state; execution: complete / Bmux; parallelism: serial; delivery: open; acceptance: implemented; maturity: validated
          Depends on: `live_terminal_codex_evidence_ingestion`
          Enables: `semantic_inference_framework`, `react_smart_session_work_model_consumer`
          Expected contract domains: `provider_turn_identity`, `hook_transcript_reconciliation`, `factual_session_projection`, `provenance_event_sources`
          Expected code areas: `Sources/WorkProvenance/WorkProvenanceCodingAgentEvidenceRecorder+Support.swift`, `Sources/WorkspacePromptSubmit.swift`, `CLI/BMUXCLI hook feed payloads`, `bmuxTests/CLIProvenanceCodexTranscriptImporterTests.swift`, `bmuxTests/SessionProvenanceTests.swift`
          Likely conflict domains: `codex_hook_prompt_evidence`, `transcript_prompt_backfill`, `factual_session_projection_identity`
          Contract dependencies: `live_terminal_codex_evidence_ingestion`, `factual_session_projection`
          Worktree required: true
          Evidence: BrianBusby/bmux@29a5a5d1ea0a
          Acceptance reason: Hook feed payloads now forward Codex turn IDs, app-side hook evidence prefers provider turn identity, transcript prompt IDs canonicalize by provider turn when available, and focused SQLite projection coverage verifies hook-plus-live-transcript evidence appears as one factual turn.
          Acceptance criteria: Codex hook prompt evidence uses provider turn identity when the hook exposes it.; Hook and transcript prompt observations for one provider turn converge onto one canonical prompt record while preserving distinct ledger events.; Prompt-only transcript backfill does not create synthetic transcript turns that duplicate live transcript turns.; Factual session projection exposes one logical turn when hook and transcript sources observe the same Codex turn.
        - **Live Codex Evidence Convergence & Metadata Correctness** (`live_codex_evidence_convergence_correctness`) - slice; status: implemented; owner: Bmux; repositories: Bmux, Provenance Engine; concept: evidence and factual state; layer: deterministic current state; execution: complete / Bmux; parallelism: serial; delivery: open; acceptance: implemented; maturity: validated
          Depends on: `live_terminal_codex_evidence_ingestion`, `coding_agent_evidence_source_reconciliation`
          Enables: `milestone_inference`
          Expected contract domains: `codex_jsonl_transcript_adapter`, `live_transcript_tail_progress`, `canonical_coding_agent_evidence`, `factual_session_projection`, `session_surface_refresh`
          Expected code areas: `CLI/CLIProvenanceCodexTranscriptImporter*.swift`, `CLI/bmux.swift`, `Sources/Panels/AgentSessionFactualProjectionView.swift`, `bmuxTests/CLIProvenanceCodexTranscriptImporterTests.swift`
          Likely conflict domains: `codex_transcript_parsing`, `codex_hook_monitor`, `factual_session_projection_identity`, `session_factual_projection_consumer`
          Contract dependencies: `live_terminal_codex_evidence_ingestion`, `coding_agent_evidence_source_reconciliation`, `factual_session_projection`
          Worktree required: true
          Evidence: BrianBusby/bmux@69c1cf02314e
          Acceptance reason: Engineering Observation Period dogfood of PR
          Acceptance criteria: A long-running ordinary Codex CLI turn continues ingesting appended JSONL records while the turn is active.; Accepted live transcript evidence advances PE factual session projection revisions and factual reads.; Visible Codex commentary/progress summaries are imported only when they are completed provider-visible summary units, never from hidden reasoning content.; Provider/model/effort fields remain distinct and use authoritative Codex transcript/runtime sources.; Hook and transcript observations converge on one factual session/thread/turn without duplicate logical turns.; Historical transcript import remains idempotent after live ingestion.; An open Session surface refreshes revisioned factual state without requiring the tab to be reopened.
        - **Workspace Coding-Agent Session Linkage Hardening** (`workspace_coding_agent_session_linkage_hardening`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: deterministic current state; execution: complete / Shared; parallelism: serial; delivery: merged; acceptance: under observation; maturity: validated
          Evidence: BrianBusby/bmux@8a0163fe1b72, BrianBusby/bmux@c07b9f8bd852, BrianBusby/bmux#95 by [BrianBusby](https://github.com/BrianBusby), BrianBusby/bmux#96 by [BrianBusby](https://github.com/BrianBusby)
          Rationale: Harden the factual workspace to coding-agent session association below semantic inference so Session and Smart Session reads no longer depend on workspace display metadata as their only identity bridge.
          Acceptance reason: PR
          Acceptance criteria: Session identity is resolved through the durable PE workspace/session association read path rather than display metadata alone.; Hook-first, transcript-first, replay, restart, resume, and multiple concurrent sessions preserve deterministic workspace/session association.; User-facing Session readiness distinguishes unsupported, awaiting first prompt, association pending, projection pending, failure, and available states.
      - **Factual Session Projection Read Contract** (`factual_session_projection_read_contract`) - milestone; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: deterministic current state; execution: complete / Provenance Engine; parallelism: serial
        Depends on: `richer_session_observable_evidence`
        - **Factual session projection foundation** (`factual_session_projection_foundation`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: evidence and factual state; layer: deterministic current state; execution: complete / Provenance Engine; parallelism: serial; delivery: open; acceptance: implemented; mirrors: `richer_session_work_model`; maturity: validated
          Depends on: `richer_coding_agent_evidence_foundation`
          Enables: `factual_projection_consumer_shape_followup`
          Evidence: BrianBusby/bmux@2add52c611e2, BrianBusby/bmux@a0f8c1fa2d0e
          Acceptance reason: First revisioned factualSessionProjection read contract returns observed thread/turn evidence without semantic inference.
        - **Factual projection consumer shape follow-up** (`factual_projection_consumer_shape_followup`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: deterministic current state; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented; maturity: complete
          Depends on: `factual_session_projection_foundation`
          Enables: `deterministic_turn_outcome_projection`, `factual_agent_session_view`, `semantic_inference_framework`
          Sequence before: `deterministic_turn_outcome_projection`, `semantic_inference_framework`
          Expected contract domains: `factual_session_projection`, `deterministic_current_state`
          Expected code areas: `Sources/ProvenanceEngineContracts`, `Sources/ProvenanceEngineCore`, `Tests/ProvenanceEngineTests`, `bmux factual projection consumers`
          Likely conflict domains: `factual_session_projection_contract`, `deterministic_current_state_projection`, `bmux_consumer_contract_shape`
          Contract dependencies: `factual_session_projection_foundation`, `deterministic_current_state_api`
          Worktree required: true
          Evidence: BrianBusby/bmux@db5f21f4bb56
          Rationale: Confirmed the PE-owned consumer shape before semantic inference depends on the factual session projection.
          Acceptance reason: The public factual projection now exposes a detailed latest-turn snapshot, compact prior-turn references, compact provider-thread identities, and independent factual turn-detail retrieval while preserving deterministic evidence-only semantics and v1 decoding compatibility.
          Acceptance criteria: Confirm the factual projection shape needed by early consumers before semantic SessionWorkModel inference begins.; Preserve the boundary that deterministic Current State contains observed facts only.
        - **Deterministic Turn Outcome Projection** (`deterministic_turn_outcome_projection`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: deterministic current state; execution: complete / Provenance Engine; parallelism: serial; delivery: open; acceptance: implemented; maturity: validated
          Depends on: `factual_projection_consumer_shape_followup`, `live_codex_evidence_convergence_correctness`
          Enables: `session_outcome_aggregation`
          Sequence before: `session_outcome_aggregation`, `cross_session_work_awareness`
          Expected contract domains: `turn_outcome_projection`, `field_level_evidence_provenance`, `deterministic_projection_revisions`, `validation_command_classification`
          Expected code areas: `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineContracts`, `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineSQLite`, `Packages/macOS/ProvenanceEngine/Tests/ProvenanceEngineSQLiteTests`, `Packages/macOS/ProvenanceEngine/Tests/ProvenanceEngineSDKTests`, `CLI/BMUXCLI+Provenance.swift`, `Packages/macOS/ProvenanceEngine/docs`
          Likely conflict domains: `factual_session_projection_contract`, `coding_agent_turn_projection`, `sqlite_projection_revisions`, `project_truth_manifest`, `docs/generated`
          Contract dependencies: `factual_session_projection`, `factual_session_turn_detail`, `live_codex_evidence_convergence_correctness`
          Worktree required: true
          Conflict note: This slice is PE package work inside the bmux monorepo. It must reuse accepted evidence, projection, revision, SDK, CLI, and migration conventions and must not introduce semantic summaries, cross-session ranking, or raw transcript retention.
          Evidence: BrianBusby/bmux@ef1650a81456
          Acceptance reason: Deterministic Turn Outcome Projection is implemented as a schema-v21 SQLite projection and public PE read contract for turn-level factual outcomes. It remains below Session Outcome aggregation and semantic/cross-session context assembly.
          Acceptance criteria: Build a revisioned, rebuildable factual outcome projection for one coding-agent turn from accepted canonical evidence.; Preserve supporting evidence references at field or item level and record the source evidence watermark and projection rule identity.; Represent missing optional information through unavailable, unknown, partial, or not-observed states instead of inventing objective, decisions, blockers, or resume points.; Keep duplicate, overlapping, late, corrected, and out-of-order evidence idempotent and revisioned according to deterministic rules.; Expose latest and specific revisions through the public PE SDK and bmux CLI boundary.
        - **Session Outcome aggregation** (`session_outcome_aggregation`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: deterministic current state; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented; maturity: validated
          Depends on: `deterministic_turn_outcome_projection`
          Enables: `cross_session_work_awareness`, `react_smart_session_work_model_consumer`
          Expected contract domains: `session_outcome_projection`, `turn_outcome_revision_aggregation`, `factual_session_completion_state`
          Expected code areas: `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineContracts`, `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineSQLite`, `Packages/macOS/ProvenanceEngine/Tests`, `Packages/macOS/ProvenanceEngine/docs`
          Likely conflict domains: `turn_outcome_projection`, `session_work_model_projection`, `cross_session_work_awareness`, `project_truth_manifest`
          Contract dependencies: `deterministic_turn_outcome_projection`, `factual_session_projection`, `deterministic_current_state_api`
          Worktree required: true
          Conflict note: This slice aggregates factual turn outcomes into a session outcome without adding LLM-authored summaries, semantic ranking, cross-session injection, or Knowledge Compiler output.
          Evidence: BrianBusby/bmux@2a4f2d7bc43f, BrianBusby/bmux#78 by [BrianBusby](https://github.com/BrianBusby)
          Rationale: Aggregates evidence-backed TurnOutcome revisions into one factual session-level outcome boundary so later Smart Session and cross-session handoff work can consume bounded factual units before semantic enrichment.
          Acceptance reason: Session Outcome aggregation is implemented as a schema-v22 SQLite projection and public PE read contract for session-level factual outcomes. It aggregates exact TurnOutcome revisions and remains below semantic SessionWorkModel, Smart Session UI, cross-session retrieval, context injection, and Knowledge Compiler output.
          Acceptance criteria: Build a revisioned, rebuildable factual outcome projection for one coding-agent session from accepted TurnOutcome revisions.; Track ordered constituent turns and the exact TurnOutcome revision id, content fingerprint, and source watermark used for each turn.; Preserve session lifecycle, completion state, objectives, plan states, commands, changed artifacts, validation attempts, blockers, unresolved work, resume points, repository/worktree/branch/HEAD boundaries, completeness metadata, and supporting evidence references where accepted evidence supports them.; Keep duplicate, overlapping, late, corrected, and out-of-order evidence idempotent and revisioned according to deterministic rules.; Expose latest and specific revisions through the public PE SDK and bmux CLI boundary.
    - **Semantic Understanding** (`semantic_understanding`) - phase; status: active; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: semantic understanding; layer: inference session work projections; execution: current / Provenance Engine; parallelism: serial; maturity: active
      Depends on: `factual_projection_consumer_shape_followup`, `deterministic_turn_outcome_projection`
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
        - **Milestone inference** (`milestone_inference`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: structured work understanding; layer: inference session work projections; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented; maturity: validated
          Depends on: `first_semantic_session_inferences`, `live_codex_evidence_convergence_correctness`
          Enables: `milestone_to_code_relationships`, `milestone_to_architecture_relationships`
          Expected contract domains: `milestone_semantics`, `session_work_model_milestones`
          Expected code areas: `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineContracts`, `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineSQLite`, `Packages/macOS/ProvenanceEngine/Tests`
          Likely conflict domains: `milestone_semantics`, `session_work_model_projection`
          Contract dependencies: `semantic_session_inferences`
          Worktree required: true
          Execution notes: Milestone inference was delivered by PR #84, merged at 2026-08-30T02:11:31Z with merge commit cd59ec10b27500a4c0dc0954bd1da9f7fed44de8.
          Evidence: BrianBusby/bmux@baa432af4141, BrianBusby/bmux@7c0e7d7eb4af, BrianBusby/bmux@7ec92cde42c4, BrianBusby/bmux@b936f9539d9a, BrianBusby/bmux@cd59ec10b275, BrianBusby/bmux#84 by [BrianBusby](https://github.com/BrianBusby)
          Rationale: Add conservative coding-agent milestone semantics from existing accepted plan and prompt evidence without introducing a second inference pipeline, bmux-local semantic logic, raw transcript retention, or external model dependency.
          Acceptance reason: Milestone inference is implemented as a producer-versioned semantic record payload consumed by the existing SessionWorkModel path. The built-in rule materializes plan-derived milestones with explicit identity and state bases, treats bmux-generated plan-step record ids as source-only evidence rather than provider-stable continuity anchors, falls back to a prompt-scoped milestone only when no usable plan exists, validates supported hierarchy links in the payload contract, preserves omission and ambiguity reasons, bounds large plan output, remains idempotent for unchanged semantic content, and keeps milestone interpretation out of factual Current State.
          Acceptance criteria: Expose bounded milestone semantics through existing semantic inference records and SessionWorkModel composition.; Preserve session-scoped milestone identities, reported work state basis, source evidence references, factual projection revisions, producer version, confidence, specificity, and supersession metadata.; Support acyclic parent-child relationships in the payload contract while emitting a flat collection from current structured plan evidence unless hierarchy is explicitly supported.; Keep provider-reported completion distinct from verified correctness, validation, merge, or acceptance.; Preserve uncertainty through unknown states, ambiguity reasons, omission reasons, bounded output, and abstention when supported evidence is insufficient.; Keep semantic milestones above deterministic factual Current State and compatible with existing factual, outcome, related-session, collision, and SDK read APIs.
        - **Blocker and approach-change semantics** (`blocker_approach_change_semantics`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: structured work understanding; layer: inference session work projections; execution: complete / Provenance Engine; parallelism: safe; delivery: merged; acceptance: implemented; maturity: validated
          Depends on: `semantic_inference_framework`
          Parallel with: `milestone_inference`
          Expected contract domains: `blocker_semantics`, `approach_change_semantics`
          Expected code areas: `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineContracts`, `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineSQLite`, `Packages/macOS/ProvenanceEngine/Tests`, `Packages/macOS/ProvenanceEngine/docs`
          Likely conflict domains: `blocker_semantics`, `approach_change_semantics`
          Contract dependencies: `semantic_inference_records`
          Worktree required: true
          Conflict note: Safe only if blocker and approach-change records stay independent from milestone hierarchy writes.
          Execution notes: Blocker and approach-change semantics were delivered by PR #85, merged at 2026-08-30T18:46:46Z with merge commit 79d6cd404b98f63a10f6fcc7748a921c3efbf19b.
          Evidence: BrianBusby/bmux@2cc991cae7a7, BrianBusby/bmux@af91d9f09adc, BrianBusby/bmux@b0e34ad6bec4, BrianBusby/bmux@79d6cd404b98, BrianBusby/bmux#85 by [BrianBusby](https://github.com/BrianBusby)
          Rationale: Add conservative coding-agent blocker and approach-change semantics from accepted visible statements without introducing a new inference pipeline, bmux-local semantic logic, raw transcript retention, cross-session propagation, or an external model dependency.
          Acceptance reason: Blocker and approach-change semantics are implemented as producer-versioned PE semantic records selected into the existing SessionWorkModel read. The built-in rule consumes only supported explicit visible assistant-output and visible reasoning-summary marker statements, preserves reported-versus-observed basis and source evidence, handles independent blockers, reported resolution/bypass/no-longer-applicable states, recurrence, exact milestone-id links, partial source history, bounded output, supersession, and SDK decoding, and abstains on unsupported command/prose/quote/hypothetical evidence. Validation used synthetic sanitized PE fixtures and the full ProvenanceEngine package suite; no real private session transcript validation is claimed.
          Acceptance criteria: Expose bounded blocker and approach-change semantic records through the existing PE semantic inference framework and SessionWorkModel composition.; Preserve stable session-scoped identities, identity basis, reported state basis, source evidence references, factual projection revisions, producer version, confidence, specificity, source-history completeness, ambiguity, omission, and supersession metadata.; Distinguish reported open, cleared, bypassed, no-longer-applicable, replaced, abandoned, deferred, and failed states without treating command failures, completed turns, successful commands, reordered plans, or clean worktrees as proof.; Link blockers and approach changes to milestones only by exact same-session milestone id, preserving unresolved or unsupported relationships as omissions.; Keep inferred blocker and approach-change semantics above deterministic factual Current State, Turn Outcome, and Session Outcome.; Preserve existing factual reads, milestone inference, related-session awareness, artifact-collision awareness, semantic messages, SDK consumers, restart/rebuild behavior, and old SessionWorkModel decoding.
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
  - **Cross-Session Work Awareness** (`cross_session_work_awareness`) - program; status: active; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: semantic understanding; layer: inference session work projections; execution: current / Shared; parallelism: conditional; maturity: active
    Depends on: `session_work_model_contract_foundation`, `session_outcome_aggregation`
    Expected contract domains: `cross_session_relationships`, `related_session_briefs`, `session_outcome_projection`, `factual_semantic_provenance`
    Expected code areas: `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineContracts`, `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineSQLite`, `Packages/macOS/ProvenanceEngine/Tests`, `bmux cross-session presentation consumers`, `docs/planning/cross-session-work-awareness.md`
    Likely conflict domains: `session_work_model_projection`, `related_session_contract`, `project_truth_manifest`, `docs/generated`
    Contract dependencies: `session_work_model_contract`, `session_outcome_projection`, `semantic_inference_records`, `provider_runtime_identity`
    Worktree required: true
    Conflict note: Cross-session awareness must stay PE-owned for durable relationships and read models. bmux may present or ask for bounded results, but must not infer a separate semantic cross-session model from raw provider output.
    Rationale: Capture the long-term cross-session working-memory capability so related coding-agent sessions can discover bounded evidence-backed work state, relationships, blockers, artifacts, and outcomes without sharing raw transcripts or automatically injecting context.
    - **Cross-Session Awareness Read Models** (`cross_session_awareness_read_models`) - phase; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: semantic understanding; layer: inference session work projections; execution: complete / Provenance Engine; parallelism: serial; maturity: validated
      Depends on: `session_work_model_contract_foundation`, `session_outcome_aggregation`
      Rationale: Group PE-owned read models that derive related-session briefs from durable evidence and validated semantic records.
      - **Related Session Awareness Foundation** (`related_session_awareness_foundation`) - milestone; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: semantic understanding; layer: inference session work projections; execution: complete / Provenance Engine; parallelism: serial; maturity: validated
        Depends on: `session_work_model_contract_foundation`, `session_outcome_aggregation`
        Rationale: First milestone for deterministic related-session discovery and bounded PE-owned brief contracts.
        - **Cross-session work awareness foundation** (`cross_session_work_awareness_foundation`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: semantic understanding; layer: inference session work projections; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented; maturity: validated
          Depends on: `session_work_model_contract_foundation`, `session_outcome_aggregation`, `richer_coding_agent_evidence_foundation`
          Enables: `rich_cross_session_work_state_semantics`, `cross_session_artifact_collision_awareness`, `agent_accessible_cross_session_retrieval`
          Expected contract domains: `related_session_read_contract`, `related_session_reasons`, `relationship_freshness_revisions`, `factual_semantic_provenance`
          Expected code areas: `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineContracts`, `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineSQLite`, `Packages/macOS/ProvenanceEngine/Tests/ProvenanceEngineSQLiteTests`, `Packages/macOS/ProvenanceEngine/Tests/ProvenanceEngineSDKTests`, `docs/planning/cross-session-work-awareness.md`
          Likely conflict domains: `related_session_contract`, `session_work_model_projection`, `factual_session_projection_contract`, `project_truth_manifest`
          Contract dependencies: `session_work_model_contract`, `session_outcome_projection`, `richer_coding_agent_evidence`, `deterministic_current_state_api`
          Worktree required: true
          Conflict note: Slice 1 is read-only. It derives deterministic relationships from existing session, worktree, repository, branch, session-tree, provider identity, external identity, Session Outcome, and SessionWorkModel evidence, and does not introduce coordination policy, prompt injection, whole-transcript sharing, artifact-collision warnings, or speculative milestone/blocker/architecture inference.
          Evidence: BrianBusby/bmux@2ec30211c5ce, BrianBusby/bmux#80 by [BrianBusby](https://github.com/BrianBusby)
          Rationale: First implementation slice for deterministic related-session discovery and bounded PE-owned briefs over active or recent coding-agent sessions.
          Acceptance reason: Cross-session work awareness foundation is implemented as a schema-v23 PE read contract and SQLite projection. `relatedSessions(...)` returns bounded deterministic briefs with same-repository, same-worktree, same-branch, session-tree, provider-identity, external-identity, and shared changed-artifact relationship reasons; compact Session Outcome facts; exact Session Outcome and SessionWorkModel revision metadata; freshness/source-watermark metadata; and explicit availability/completeness states. The slice remains below richer cross-session semantics, collision awareness, explicit agent retrieval, bmux presentation, prompt/context injection, and Knowledge Compiler integration.
          Acceptance criteria: Expose a PE public read contract for bounded related-session briefs.; Preserve individually inspectable relationship reasons and deterministic ordering.; Keep observed facts, explicit plan evidence, and semantic inference distinguishable.; Return freshness/revision metadata and provenance references without raw transcript sharing.; Preserve exact Session Outcome and SessionWorkModel revision metadata used by every brief.; Keep the slice read-only with no prompt injection, coordination policy, bmux UI, or artifact-collision warning behavior.
      - **Cross-Session Semantics and Collision Awareness** (`cross_session_semantics_and_collisions`) - milestone; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: structured work understanding; layer: inference session work projections; execution: complete / Provenance Engine; parallelism: serial; maturity: validated
        Depends on: `cross_session_work_awareness_foundation`
        Gate `cross_session_foundation_validated`: requires `cross_session_work_awareness_foundation` maturity validated; reason: Richer cross-session semantics and collision explanations should build on a validated related-session foundation.
        Rationale: Adds richer work-state semantics and factual artifact-overlap explanations after the foundational related-session read model is validated.
        - **Rich cross-session work-state semantics** (`rich_cross_session_work_state_semantics`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: structured work understanding; layer: inference session work projections; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented; maturity: validated
          Depends on: `cross_session_work_awareness_foundation`, `milestone_inference`, `blocker_approach_change_semantics`
          Enables: `agent_accessible_cross_session_retrieval`
          Expected contract domains: `cross_session_semantic_briefs`, `milestone_semantics`, `blocker_semantics`, `approach_change_semantics`
          Expected code areas: `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineContracts`, `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineSQLite`, `Packages/macOS/ProvenanceEngine/Tests`
          Likely conflict domains: `session_work_model_projection`, `milestone_semantics`, `blocker_semantics`
          Contract dependencies: `related_session_read_contract`, `milestone_semantics`, `semantic_inference_records`
          Worktree required: true
          Execution notes: Rich cross-session work-state semantics were delivered by PR #87, merged at 2026-08-31T05:44:25Z with merge commit adf55adb8a81f77a5b07e8fd129ad0d9cce2e149. Gates were satisfied because cross_session_work_awareness_foundation, milestone_inference, and blocker_approach_change_semantics were already implemented with capability_maturity validated and merged delivery evidence. Foreground review findings around unknown semantic availability and public helper scope were addressed before merge.
          Gate `cross_session_foundation_validated`: requires `cross_session_work_awareness_foundation` maturity validated; reason: Rich cross-session briefs should build on a validated deterministic relationship/read foundation.
          Gate `milestone_semantics_validated`: requires `milestone_inference` maturity validated; reason: Cross-session milestone identity and hierarchy must come from validated PE milestone semantics.
          Gate `blocker_approach_semantics_validated`: requires `blocker_approach_change_semantics` maturity validated; reason: Cross-session blockers, failed attempts, and approach changes must be backed by validated PE semantic records.
          Evidence: BrianBusby/bmux@335d71518f94, BrianBusby/bmux@6022f6499f6a, BrianBusby/bmux@6936c97540ba, BrianBusby/bmux@adf55adb8a81, BrianBusby/bmux#87 by [BrianBusby](https://github.com/BrianBusby)
          Rationale: Add richer validated semantic information to related-session briefs only after PE owns the underlying milestone, blocker, validation, and approach-change semantics.
          Acceptance reason: Rich cross-session work-state semantics is implemented and merged through PR #87. Related-session rule version 2 carries existing SessionWorkModel milestones, blockers, approach changes, thread/turn intent, current activity, and session phase with source-session scope, semantic record identity, bounded payloads, evidence references, producer metadata, supporting factual revision, supersession metadata, explicit unknown/unavailable/partial availability, and deterministic content revision behavior. Validation used synthetic sanitized multi-session fixtures, public SDK reads, restart/rebuild and historical-revision coverage, focused related-session/blocker/approach suites, the full ProvenanceEngine package suite, foreground Codex review, and Project Truth gates. Agent-accessible retrieval is not selected or implemented by this slice.
          Acceptance criteria: Related-session public SDK reads carry supported SessionWorkModel milestones, blockers, and approach changes for related sessions with original semantic records, evidence references, producer/version, confidence, specificity, source-session attribution, and factual revision metadata intact.; Reported blocker transitions, approach replacements, supersession, semantic-only updates, late or corrected evidence, restart, and projection rebuild update related-session briefs and revisions according to the documented content-versus-freshness contract.; Same-named milestones or repeated session-scoped semantic ids from different sessions remain distinct, and one session's claims never clear, resolve, or supersede another session's blockers or approach history.; Partial history, unavailable semantic records, stale evidence, bounded omissions, and unknown older-model fields remain explicitly distinguishable from empty, complete, or resolved work state after encoding and decoding.; Large semantic payloads are bounded deterministically with omission reasons and counts while retained items keep enough provenance to interpret their original source records.; Semantic work-state fields remain separate from factual relationship reasons, Session Outcome, Turn Outcome, factual Current State, artifact-collision facts, prompt injection, coordination policy, and Knowledge Compiler behavior.; A public-read example demonstrates the carried cross-session work state and limitations using sanitized fixture data.
        - **Artifact and change collision awareness** (`cross_session_artifact_collision_awareness`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: structured work understanding; layer: deterministic current state; execution: complete / Provenance Engine; parallelism: serial; delivery: merged; acceptance: implemented; maturity: validated
          Depends on: `cross_session_work_awareness_foundation`, `richer_coding_agent_evidence_foundation`, `factual_session_projection_foundation`
          Enables: `agent_accessible_cross_session_retrieval`, `proactive_bmux_cross_session_awareness`
          Expected contract domains: `cross_session_file_overlap`, `worktree_branch_overlap`, `artifact_collision_explanations`
          Expected code areas: `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineContracts`, `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineSQLite`, `Packages/macOS/ProvenanceEngine/Tests`
          Likely conflict domains: `related_session_contract`, `file_change_attribution`, `current_context_projection`
          Contract dependencies: `related_session_read_contract`, `richer_coding_agent_evidence`, `factual_file_change_evidence`
          Worktree required: true
          Gate `cross_session_foundation_validated`: requires `cross_session_work_awareness_foundation` maturity validated; reason: Collision detection needs validated related-session relationships and bounded explanation semantics.
          Evidence: BrianBusby/bmux@a11e649812f7, BrianBusby/bmux#82 by [BrianBusby](https://github.com/BrianBusby)
          Rationale: Detect and explain possible parallel-work artifact collisions from factual worktree, branch, repository, change-set, and file-change evidence without automatically blocking or mutating another session.
          Acceptance reason: Artifact and change collision awareness is implemented as a schema-v24 PE read contract and SQLite projection. `artifactCollisions(...)` returns bounded exact-path artifact-overlap candidates for a target session and related sessions, with per-session participation, repository/worktree/branch/HEAD boundary comparison, temporal overlap state, freshness and stale classification, completeness metadata, Session Outcome and related-session projection revision references, accepted evidence references, stable ordering, bounded exclusions, and deterministic revision persistence. The slice remains a factual possible-collision read only: rename identity is unsupported without accepted deterministic evidence, similar paths do not collide, same relative paths in different repositories are excluded, and no semantic compatibility judgment, coordination policy, prompt injection, raw transcript sharing, bmux UI, proactive notification, retrieval integration, or Knowledge Compiler behavior is added.
          Acceptance criteria: Expose a PE public read contract for bounded artifact-collision awareness.; Detect exact normalized path overlaps only inside shared repository identity.; Preserve per-session participation, Session Outcome revisions, related-session projection revision metadata, and evidence references.; Report repository, worktree, branch, HEAD, temporal, freshness, and completeness boundaries deterministically.; Handle duplicate, late, corrected, and out-of-order evidence through revisioned deterministic projection semantics.; Keep rename identity unsupported unless accepted evidence can establish it deterministically.; Preserve factuality and non-coordination boundaries: no semantic conflict judgment, prompt injection, agent coordination, raw transcript sharing, proactive UI, or Knowledge Compiler behavior.
    - **Cross-Session Retrieval and Context** (`cross_session_awareness_retrieval_and_context`) - phase; status: active; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: retrieval; layer: retrieval engine; execution: current / Shared; parallelism: serial; maturity: active
      Depends on: `cross_session_work_awareness_foundation`
      Gate `cross_session_foundation_validated`: requires `cross_session_work_awareness_foundation` maturity validated; reason: Retrieval and context behavior should wait for a validated related-session read model.
      Rationale: Groups explicit agent retrieval, bmux presentation, and later measured context assembly over cross-session awareness.
      - **Cross-Session Retrieval and Presentation** (`cross_session_retrieval_and_presentation`) - milestone; status: active; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: retrieval; layer: retrieval engine; execution: current / Shared; parallelism: serial; maturity: active
        Depends on: `rich_cross_session_work_state_semantics`, `cross_session_artifact_collision_awareness`
        Gate `cross_session_semantics_validated`: requires `rich_cross_session_work_state_semantics` maturity validated; reason: Retrieval and presentation should use validated semantic brief fields for blockers, decisions, and outcomes.
        Gate `artifact_collision_awareness_validated`: requires `cross_session_artifact_collision_awareness` maturity validated; reason: Retrieval and presentation should use validated artifact collision explanations before surfacing file-overlap claims.
        Rationale: Makes cross-session awareness accessible to agents and bmux only after the relationship and brief semantics prove reliable.
        - **Agent-accessible cross-session retrieval** (`agent_accessible_cross_session_retrieval`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: retrieval; layer: retrieval engine; execution: complete / Shared; parallelism: serial; delivery: merged; acceptance: accepted; maturity: validated
          Depends on: `cross_session_work_awareness_foundation`, `rich_cross_session_work_state_semantics`, `cross_session_artifact_collision_awareness`
          Enables: `proactive_bmux_cross_session_awareness`, `cross_session_context_assembly_experiment`, `knowledge_compiler_cross_session_bridge`
          Expected contract domains: `cross_session_agent_query`, `bounded_evidence_backed_retrieval`, `related_session_briefs`
          Expected code areas: `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineContracts`, `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineSQLite`, `bmux agent retrieval integration points`, `docs/planning/cross-session-work-awareness.md`
          Likely conflict domains: `retrieval_contracts`, `related_session_contract`, `bmux_context_assembly`
          Contract dependencies: `related_session_read_contract`, `cross_session_semantic_briefs`, `artifact_collision_explanations`
          Worktree required: true
          Execution notes: Implemented after PR #87 merged and Project Truth validated rich_cross_session_work_state_semantics. Scope is explicit bounded agent-facing CLI retrieval over existing PE related-session and artifact-collision read contracts; no prompt injection, proactive UI, coordination policy, arbitrary file-history search, or new inference layer is in scope. Local validation covered focused bmux-unit CLI dispatch, the full PE package suite, no-socket help, localization, tagged build 509, and an isolated two-session demo.
          Gate `cross_session_foundation_validated`: requires `cross_session_work_awareness_foundation` maturity validated; reason: Agents should query cross-session state only after the relationship/read model is validated.
          Gate `cross_session_semantics_validated`: requires `rich_cross_session_work_state_semantics` maturity validated; reason: Agent questions about blockers, decisions, failed approaches, and validation require validated semantic brief fields.
          Gate `artifact_collision_awareness_validated`: requires `cross_session_artifact_collision_awareness` maturity validated; reason: Agent questions about file or component collisions need validated artifact-overlap explanations.
          Evidence: BrianBusby/bmux@6be29aaa60ff, BrianBusby/bmux@5db53927906a, BrianBusby/bmux#88 by [BrianBusby](https://github.com/BrianBusby)
          Rationale: Provide explicit bounded agent queries over PE-owned cross-session state instead of blindly injecting historical context or exposing full transcripts.
          Acceptance reason: Implemented as two explicit `bmux provenance sessions` retrieval operations backed by public PE `relatedSessions(...)` and `artifactCollisions(...)` reads. The commands require explicit PE session ids, accept explicit databases without a live app socket, enforce finite limits and timestamp/path validation, preserve exact revision reads and missing/empty/partial distinctions, render compact localized text, emit stable JSON, document the target-session changed-artifact collision limitation, and include deterministic fixtures plus a reproducible two-session demo. PR #88 merged as `5db53927906a83677e1bebbc2f04680af10b5055` after its review findings were resolved.
          Acceptance criteria: Expose explicit agent retrieval CLI commands over existing PE related-session and artifact-collision reads.; Require explicit PE session ids and selected local databases; do not infer from focus or require a live app socket.; Support bounded limits, recent-time filters, exact historical revisions, artifact-path filters, stale classification, and clear malformed-argument failures.; Preserve JSON contract fields for relationship reasons, repository/worktree/branch/HEAD boundaries, semantic claims, evidence references, revisions, freshness, completeness, stale/partial states, and omissions.; Preserve the collision limitation that discovery starts from the target session's recorded changed artifacts and never treats same-path different-repository work as a collision.; Keep the reads workflow-neutral: no ingestion, mutation, prompt/context injection, notification, raw transcript sharing, or unrelated secret access.; Verify through real command dispatch, deterministic PE fixtures, no-socket help, documentation, localization, and a reproducible two-session demonstration.
        - **Proactive bmux cross-session awareness** (`proactive_bmux_cross_session_awareness`) - slice; status: implemented; owner: Bmux; repositories: Bmux, Provenance Engine; concept: semantic understanding; layer: consumer presentation; execution: complete / Bmux; parallelism: serial; delivery: merged; acceptance: implemented; maturity: validated
          Depends on: `agent_accessible_cross_session_retrieval`, `cross_session_artifact_collision_awareness`
          Expected contract domains: `cross_session_notifications`, `bmux_cross_session_presentation`
          Expected code areas: `bmux notification surfaces`, `React Smart Session surface`, `bmux provenance consumers`
          Likely conflict domains: `bmux_session_presentation`, `notification_policy`, `context_assembly_policy`
          Contract dependencies: `cross_session_agent_query`, `artifact_collision_explanations`
          Worktree required: true
          Execution notes: Implemented as bounded related-session and possible artifact-collision presentation inside the existing React Smart Session refresh. It does not inject agent context, notify outside the Session surface, block work, coordinate agents, or share transcripts. PR #94 merged at 2026-09-01T19:08:35Z with merge commit 0400109c5ec0678c6e89bff0cc316b661a44f626.
          Gate `cross_session_retrieval_validated`: requires `agent_accessible_cross_session_retrieval` maturity validated; reason: Proactive presentation should depend on observed useful retrieval and relevance behavior.
          Evidence: BrianBusby/bmux@a2b88f2479f4, BrianBusby/bmux@0400109c5ec0, BrianBusby/bmux#94 by [BrianBusby](https://github.com/BrianBusby)
          Rationale: Surface especially relevant cross-session changes through bounded Smart Session presentation without silently mutating coding-agent context.
          Acceptance reason: The existing Smart Session refresh path now reads at most five related sessions and five possible collision candidates through PE public contracts and presents their factual boundaries separately from the session's own semantic work model.
          Acceptance criteria: React Smart Session refresh performs bounded PE related-session and artifact-collision reads for the linked PE session.; Presentation preserves relationship reasons, lifecycle/freshness state, normalized artifact paths, collision state, and bounded omission counts.; Failed awareness reads degrade to an explicit unavailable state without hiding the existing Smart Session snapshot.; No prompt injection, external notification, locking, interruption, reassignment, transcript sharing, or coordination policy is added.
        - **Cross-session context assembly experiment** (`cross_session_context_assembly_experiment`) - slice; status: planned; owner: Bmux; repositories: Bmux, Provenance Engine; concept: retrieval; layer: consumer presentation; execution: planned / Bmux; parallelism: serial; delivery: proposed; acceptance: proposed; maturity: gated
          Depends on: `agent_accessible_cross_session_retrieval`
          Expected contract domains: `context_assembly_policy`, `cross_session_effectiveness_metrics`, `bounded_context_pack`
          Expected code areas: `bmux context assembly`, `bmux agent launch/session orchestration`, `evaluation fixtures`
          Likely conflict domains: `prompt_context_assembly`, `retrieval_contracts`, `privacy_policy`
          Contract dependencies: `cross_session_agent_query`, `context_effectiveness_metrics`
          Worktree required: true
          Gate `cross_session_retrieval_validated`: requires `agent_accessible_cross_session_retrieval` maturity validated; reason: Automatic context assembly should be an experiment after explicit cross-session retrieval proves useful.
          Rationale: Measure whether bounded explainable cross-session context improves outcomes before making automatic context assembly a product behavior.
    - **Cross-Session Awareness Knowledge Bridge** (`cross_session_awareness_knowledge_bridge`) - phase; status: deferred; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: durable knowledge; layer: knowledge compiler; execution: deferred / Provenance Engine; parallelism: serial; maturity: gated
      Depends on: `agent_accessible_cross_session_retrieval`, `knowledge_compiler_outcomes`
      Gate `cross_session_retrieval_validated`: requires `agent_accessible_cross_session_retrieval` maturity validated; reason: The bridge should consume validated working-memory retrieval behavior, not transient session statements.
      Gate `compiler_implementation_available`: requires `knowledge_compiler_outcomes` maturity active; reason: Cross-session outcomes cannot be promoted into durable knowledge until the Knowledge Compiler exists.
      Rationale: Keeps short-lived cross-session working memory separate from durable compiled engineering knowledge until compiler behavior exists.
      - **Cross-Session Knowledge Compiler Bridge** (`cross_session_knowledge_bridge_milestone`) - milestone; status: deferred; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: durable knowledge; layer: knowledge compiler; execution: deferred / Provenance Engine; parallelism: serial; maturity: gated
        Depends on: `agent_accessible_cross_session_retrieval`, `knowledge_compiler_outcomes`
        Gate `cross_session_retrieval_validated`: requires `agent_accessible_cross_session_retrieval` maturity validated; reason: Bridge inputs should come from validated cross-session retrieval and outcome semantics.
        Gate `compiler_implementation_available`: requires `knowledge_compiler_outcomes` maturity active; reason: The Knowledge Compiler must exist before cross-session outcomes can feed durable knowledge.
        Rationale: Milestone for later promotion of stable cross-session outcomes into durable compiler inputs.
        - **Knowledge Compiler cross-session bridge** (`knowledge_compiler_cross_session_bridge`) - slice; status: deferred; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: durable knowledge; layer: knowledge compiler; execution: deferred / Provenance Engine; parallelism: serial; delivery: proposed; acceptance: proposed; maturity: gated
          Depends on: `agent_accessible_cross_session_retrieval`, `knowledge_compiler_outcomes`
          Expected contract domains: `knowledge_compiler_inputs`, `durable_session_outcomes`, `evidence_aware_retrieval`
          Expected code areas: `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineContracts`, `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineSQLite`, `docs/planning/cross-session-work-awareness.md`
          Likely conflict domains: `knowledge_compiler`, `retrieval_contracts`, `cross_session_semantics`
          Contract dependencies: `cross_session_agent_query`, `knowledge_compiler_outputs`
          Worktree required: true
          Gate `cross_session_retrieval_validated`: requires `agent_accessible_cross_session_retrieval` maturity validated; reason: The bridge should consume validated working-memory retrieval behavior, not transient session statements.
          Gate `compiler_implementation_available`: requires `knowledge_compiler_outcomes` maturity active; reason: Cross-session outcomes cannot be promoted into durable knowledge until the Knowledge Compiler exists.
          Rationale: Keep nearby active/recent cross-session working memory separate from long-lived compiled engineering knowledge, then bridge stable evidence-backed outcomes only after the Knowledge Compiler exists.

## Parallel Worktree Preflight

Active assignments are derived from roadmap slice nodes with `status: active` or `execution.assignment: current`.

| Slice | Parallelism | Worktree | Branch | Agent/session | Conflict domains | Contract dependencies | Safety |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Deterministic App Runtime Composition and App-Host Test Isolation (`deterministic_app_runtime_composition`) | serial | /Users/brianbusby/repos/.bmux-worktrees/process-integrity-runtime-composition | process-integrity-runtime-composition | codex | `agent_chat_telemetry_projection`, `app_host_test_bootstrap`, `app_startup`, `work_provenance_runtime_startup` | `factual_session_projection`, `workspace_coding_agent_session_association` | single active assignment |

### Dependency-Ready Preflight

None.

## Dependency-Ready Work

None.

## Selected Next Work

None.

## Dependency-Ready But Not Selected

None.

## Deferred Or Blocked Work

- Cross-Session Awareness Knowledge Bridge (`cross_session_awareness_knowledge_bridge`) - status: deferred; depends on: `agent_accessible_cross_session_retrieval`, `knowledge_compiler_outcomes`
- Cross-Session Knowledge Compiler Bridge (`cross_session_knowledge_bridge_milestone`) - status: deferred; depends on: `agent_accessible_cross_session_retrieval`, `knowledge_compiler_outcomes`
- Knowledge Compiler cross-session bridge (`knowledge_compiler_cross_session_bridge`) - status: deferred; depends on: `agent_accessible_cross_session_retrieval`, `knowledge_compiler_outcomes`
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
