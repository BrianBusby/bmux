<!--
GENERATED FILE. DO NOT EDIT MANUALLY.
Sources:
- BrianBusby/provenance-engine:project/project-state.yaml
- project/shared-project-source.yaml
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
    Rationale: Richer coding-agent evidence and session projections are the active direction after V1 adoption and workspace-display observation. Local usage found that normal bmux/Codex terminal sessions still need a canonical ingestion path so the implemented factual and semantic layers receive representative evidence outside Agent Chat.
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
          Enables: `codex_transcript_canonical_evidence_import`, `semantic_inference_framework`
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
    - **Normal Coding-Agent Ingestion Foundation** (`normal_coding_agent_ingestion_foundation`) - phase; status: active; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: evidence adapters; execution: current / Shared; parallelism: serial
      Depends on: `factual_projection_consumer_shape_followup`
      Expected contract domains: `canonical_execution_evidence`, `transcript_evidence_import`, `evidence_source_reconciliation`
      Expected code areas: `Sources/ProvenanceEngineContracts`, `Sources/ProvenanceEngineCore`, `bmux Codex transcript/session observation adapters`, `bmux WorkProvenance coding-agent evidence producer`
      Likely conflict domains: `coding_agent_evidence_contracts`, `provider_session_identity`, `transcript_ingestion_policy`
      Contract dependencies: `factual_session_projection`, `accepted_coding_agent_evidence_records`
      Worktree required: true
      Rationale: Treats ordinary coding-agent session ingestion as a data-foundation dependency for representative factual projection, semantic inference, SessionWorkModel, Smart Session, retrieval, and cross-session-awareness validation.
      - **Normal Coding-Agent Evidence Ingestion** (`normal_coding_agent_evidence_ingestion`) - milestone; status: active; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: evidence adapters; execution: current / Shared; parallelism: serial; delivery: open; acceptance: under observation; mirrors: `normal_coding_agent_evidence_ingestion`
        Depends on: `factual_projection_consumer_shape_followup`
        Enables: `presentation_language_calibration_corpus`, `milestone_inference`, `scoped_architecture_projection`, `clickable_semantic_explanation_ui`
        Expected contract domains: `canonical_execution_evidence`, `codex_transcript_adapter`, `normal_terminal_live_ingestion`, `source_reconciliation`
        Expected code areas: `Sources/ProvenanceEngineContracts`, `Sources/ProvenanceEngineCore`, `bmux Codex transcript/session observation adapters`, `bmux WorkProvenance coding-agent evidence producer`, `docs/session-work-model.md`
        Likely conflict domains: `coding_agent_evidence_contracts`, `provider_thread_turn_identity`, `transcript_retention_policy`
        Contract dependencies: `factual_session_projection`, `semantic_inference_input_packets`, `accepted_coding_agent_evidence_records`
        Worktree required: true
        Evidence: None recorded
        Rationale: Normal bmux/Codex terminal sessions must populate the same canonical PE evidence model as structured Agent Chat sessions; Agent Chat remains high-fidelity but must not be the required gateway for rich session evidence.
        Acceptance reason: Historical Codex JSONL import now exists as the first implemented slice; live terminal ingestion and overlapping-source reconciliation remain planned before the initiative can be accepted.
        Acceptance criteria: Starting ordinary Codex in a bmux terminal, without Agent Chat, can produce PE session, provider thread, turn, prompt, command/tool, plan, visible reasoning-summary, and file-change evidence where Codex exposes those facts.; Historical Codex JSONL import exercises substantially the same canonical durable evidence path and can be rerun without duplicate evidence.; Factual projection, semantic inference, SessionWorkModel consumers, Smart Session consumers, and later cross-session-awareness experiments do not need to special-case the ingestion surface.; Evidence provenance remains queryable so consumers can distinguish provider-live, provider-transcript, native-hook, git-observer, or future equivalent origins.
        - **Codex Transcript to Canonical Evidence Import** (`codex_transcript_canonical_evidence_import`) - slice; status: implemented; owner: Bmux; repositories: Bmux, Provenance Engine; concept: evidence and factual state; layer: evidence adapters; execution: complete / Bmux; parallelism: serial; delivery: open; acceptance: implemented
          Depends on: `factual_projection_consumer_shape_followup`
          Enables: `live_terminal_codex_evidence_ingestion`, `presentation_language_calibration_corpus`, `milestone_inference`, `scoped_architecture_projection`
          Expected contract domains: `codex_jsonl_transcript_adapter`, `canonical_execution_evidence`, `idempotent_import_cursors`
          Expected code areas: `bmux Codex transcript/session observation adapters`, `Sources/WorkProvenance`, `Sources/ProvenanceEngineContracts`
          Likely conflict domains: `codex_transcript_parsing`, `evidence_idempotency`, `privacy_retention_policy`
          Contract dependencies: `accepted_coding_agent_evidence_records`, `factual_session_projection`
          Worktree required: true
          Evidence: BrianBusby/bmux@2a1259f37bae
          Rationale: Deterministic historical importer for Codex JSONL transcripts such as `~/.codex/sessions`; it feeds canonical execution evidence and PE append contracts rather than writing projection tables directly.
        - **Live Terminal Codex Evidence Ingestion** (`live_terminal_codex_evidence_ingestion`) - slice; status: planned; owner: Bmux; repositories: Bmux, Provenance Engine; concept: evidence and factual state; layer: evidence adapters; execution: next eligible / Bmux; parallelism: serial; delivery: proposed; acceptance: proposed
          Depends on: `codex_transcript_canonical_evidence_import`
          Enables: `coding_agent_evidence_source_reconciliation`
          Expected contract domains: `live_transcript_tailer`, `session_lifecycle_identity`, `canonical_execution_evidence`
          Expected code areas: `bmux Codex hook/session monitor`, `bmux Codex transcript/session observation adapters`, `Sources/WorkProvenance`
          Likely conflict domains: `codex_session_identity`, `lifecycle_recording`, `transcript_tail_cursors`
          Contract dependencies: `codex_jsonl_transcript_adapter`, `producer_neutral_lifecycle_recording`
          Worktree required: true
          Rationale: Tail active ordinary Codex terminal transcripts through the same normalization path while existing bmux lifecycle/workspace/worktree observation remains authoritative for those facts.
        - **Coding-Agent Evidence Source Reconciliation** (`coding_agent_evidence_source_reconciliation`) - slice; status: planned; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: evidence and factual state; layer: evidence store; execution: planned / Shared; parallelism: serial; delivery: proposed; acceptance: proposed
          Depends on: `live_terminal_codex_evidence_ingestion`
          Enables: `clickable_semantic_explanation_ui`, `continuous_presentation_learning`, `milestone_to_code_relationships`
          Expected contract domains: `provider_identity_reconciliation`, `evidence_origin_taxonomy`, `duplicate_evidence_policy`
          Expected code areas: `Sources/ProvenanceEngineContracts`, `Sources/ProvenanceEngineSQLite`, `Sources/WorkProvenance`
          Likely conflict domains: `evidence_origin_scope`, `provider_thread_identity`, `projection_rebuild_idempotency`
          Contract dependencies: `live_terminal_codex_evidence_ingestion`, `agent_chat_structured_evidence`, `producer_neutral_lifecycle_recording`
          Worktree required: true
          Rationale: Reconcile overlapping Agent Chat, transcript, hook, and Git observations so evidence remains idempotent and queryable by source without forcing consumers to know the ingestion surface.
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
          Evidence: BrianBusby/provenance-engine@d66e847c5cb7, BrianBusby/provenance-engine#26 by [BrianBusby](https://github.com/BrianBusby)
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
          Evidence: BrianBusby/provenance-engine@50a4fb58a114, BrianBusby/provenance-engine#28 by [BrianBusby](https://github.com/BrianBusby)
          Acceptance reason: First concrete rule-produced semantic records now materialize thread intent, turn intent, session phase, and current activity from factual session projections with structured payloads, evidence references, factual revision, producer metadata, confidence, specificity, and supersession while keeping deterministic Current State factual only.
          Acceptance criteria: Thread intent, turn intent, session phase, and current activity are evidence-backed.
        - **Human-readable semantic messaging** (`human_readable_semantic_messaging`) - slice; status: implemented; owner: Provenance Engine; repositories: Provenance Engine; concept: semantic understanding; layer: inference session work projections; execution: complete / Provenance Engine; parallelism: safe; delivery: merged; acceptance: implemented
          Depends on: `first_semantic_session_inferences`
          Enables: `clickable_semantic_explanation_ui`, `presentation_language_calibration_corpus`
          Parallel with: `presentation_language_calibration_corpus`
          Expected contract domains: `semantic_message_contract`, `session_work_model_presentation`
          Expected code areas: `Sources/ProvenanceEngineCore`, `docs/session-work-model.md`, `bmux semantic presentation consumers`
          Likely conflict domains: `semantic_message_contract`, `session_work_model_projection`
          Contract dependencies: `semantic_session_inferences`
          Worktree required: true
          Conflict note: Safe with the calibration corpus only when messaging edits stay in presentation contract code and corpus edits stay in example data.
          Evidence: BrianBusby/provenance-engine@ec0baa4b0d83, BrianBusby/provenance-engine#30 by [BrianBusby](https://github.com/BrianBusby)
          Acceptance reason: Human-readable semantic message contracts, deterministic default rendering for first coding-agent semantic kinds, SQLite message cache/history persistence, public publish/query/materialization APIs, and coverage for wording, policy separation, supersession, rollback, retrieval, and Current State separation are implemented.
          Acceptance criteria: Semantic inference records can be rendered into cached concise and expanded messages.; Message records preserve structured semantic meaning, provenance, confidence, specificity, producer, policy, history, and supersession.; Presentation wording remains separate from semantic inference truth and deterministic Current State.
        - **Clickable semantic explanation UI** (`clickable_semantic_explanation_ui`) - slice; status: planned; owner: Bmux; repositories: Bmux, Provenance Engine; concept: semantic understanding; layer: consumer presentation; execution: planned / Bmux; parallelism: serial; delivery: proposed; acceptance: proposed
          Depends on: `human_readable_semantic_messaging`, `coding_agent_evidence_source_reconciliation`
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
          Depends on: `first_semantic_session_inferences`, `codex_transcript_canonical_evidence_import`
          Parallel with: `human_readable_semantic_messaging`
          Expected contract domains: `presentation_language_corpus`, `semantic_message_calibration`
          Expected code areas: `Tests/ProvenanceEngineTests`, `docs/session-work-model.md`, `calibration fixtures`
          Likely conflict domains: `presentation_language_corpus`, `semantic_message_calibration`
          Contract dependencies: `semantic_session_inferences`
          Worktree required: true
          Conflict note: Safe with human-readable messaging only when corpus edits do not change the semantic message contract.
    - **Structured Work Understanding** (`structured_work_understanding`) - phase; status: planned; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: structured work understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: safe
      Depends on: `first_semantic_session_inferences`, `codex_transcript_canonical_evidence_import`
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
          Depends on: `milestone_inference`, `coding_agent_evidence_source_reconciliation`
          Expected contract domains: `milestone_code_relationships`, `file_change_attribution`
          Expected code areas: `Sources/ProvenanceEngineCore`, `Sources/ProvenanceEngineContracts`, `Tests/ProvenanceEngineTests`
          Likely conflict domains: `milestone_relationships`, `file_change_attribution`
          Contract dependencies: `milestone_semantics`, `richer_coding_agent_evidence`
          Worktree required: true
    - **Architecture Understanding** (`architecture_understanding`) - phase; status: planned; owner: Provenance Engine; repositories: Provenance Engine, Bmux; concept: architecture understanding; layer: inference session work projections; execution: planned / Provenance Engine; parallelism: safe
      Depends on: `first_semantic_session_inferences`, `codex_transcript_canonical_evidence_import`
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
  - **Remote Bmux Sessions and React Native Mobile Access** (`remote_bmux_mobile_access`) - program; status: planned; owner: Bmux; repositories: Bmux, Provenance Engine; concept: platform; layer: platform; execution: planned / Bmux; parallelism: conditional; delivery: proposed; acceptance: proposed; mirrors: `remote_bmux_mobile_access`
    Depends on: `workspace_display_durable_context`
    Expected contract domains: `local_session_host`, `remote_session_protocol`, `device_pairing_authorization`, `mobile_terminal_rendering`
    Expected code areas: `bmux session and terminal runtime`, `remote-session protocol contracts`, `React Native mobile app`, `mobile transport and pairing storage`
    Likely conflict domains: `terminal_runtime_lifecycle`, `mobile_connectivity`, `project_truth_generated_docs`
    Contract dependencies: `workspace_display_durable_context`
    Worktree required: true
    Rationale: Secure phone/tablet access is a bmux runtime and product concern. PE can later enrich mobile session cards through SessionWorkModel, but PE must not carry terminal bytes, remote-control traffic, or Codex credentials.
    - **Remote Session Foundation** (`remote_session_foundation`) - phase; status: planned; owner: Bmux; repositories: Bmux; concept: platform; layer: platform; execution: planned / Bmux; parallelism: serial
      Rationale: Build the UI-independent session-host and protocol base before exposing any remotely controllable local PTY to a network.
      - **Session Host, Protocol, and Device Authorization** (`remote_session_host_protocol_and_auth`) - milestone; status: planned; owner: Bmux; repositories: Bmux; concept: platform; layer: platform; execution: planned / Bmux; parallelism: serial
        - **Remote Mobile Planning Reconciliation** (`remote_mobile_planning_reconciliation`) - slice; status: planned; owner: Bmux; repositories: Bmux, Provenance Engine; concept: platform; layer: project truth; execution: planned / Bmux; parallelism: safe; delivery: proposed; acceptance: proposed
          Expected contract domains: `project_truth_remote_mobile_roadmap`, `bmux_pe_ownership_boundary`
          Expected code areas: `docs/remote-sessions-react-native-plan.md`, `docs/ios-swift-mobile-plan.md`, `docs/remote-daemon-spec.md`, `project/project-state.yaml`, `project/repo-status.yaml`, `docs/generated`
          Likely conflict domains: `project_truth_generated_docs`, `mobile_architecture_docs`
          Contract dependencies: `project_truth_generated_docs`
          Worktree required: true
          Acceptance criteria: The canonical docs identify React Native as the production iPhone/iPad architecture and mark the Swift-owned mobile plan superseded.; The shared roadmap names the bmux-owned session-host, protocol, pairing, transport, React Native app, terminal, lifecycle, notification, PE-smart-session, and general-connectivity slices.; The docs distinguish the mobile-to-Mac data plane from the existing SSH-to-remote-machine daemon direction.
        - **Local Session Host Contract** (`remote_local_session_host_contract`) - slice; status: planned; owner: Bmux; repositories: Bmux; concept: platform; layer: platform; execution: next eligible / Bmux; parallelism: serial; delivery: proposed; acceptance: proposed
          Enables: `remote_session_protocol_loopback`
          Sequence after: `remote_mobile_planning_reconciliation`
          Expected contract domains: `ui_independent_terminal_attachment`, `session_lifecycle`, `terminal_snapshot_boundary`
          Expected code areas: `Packages/macOS/BmuxTerminalCore`, `Packages/macOS/BmuxTerminal`, `Sources/Workspace.swift`, `Sources/GhosttyTerminalView.swift`, `bmuxTests`
          Likely conflict domains: `terminal_runtime_lifecycle`, `workspace_panel_lifecycle`, `ghostty_surface_snapshot`
          Contract dependencies: `terminal_surface_hosting`
          Worktree required: true
          Rationale: First implementation slice; prove an existing local bmux PTY can gain a second attachment with snapshot, live output, input, and detach through an in-process loopback contract without networking.
        - **Versioned Remote-Session Protocol Loopback** (`remote_session_protocol_loopback`) - slice; status: planned; owner: Bmux; repositories: Bmux; concept: platform; layer: platform; execution: planned / Bmux; parallelism: serial; delivery: proposed; acceptance: proposed
          Depends on: `remote_local_session_host_contract`
          Enables: `remote_device_identity_pairing`, `remote_react_native_app_foundation`
        - **Secure Device Identity and Pairing** (`remote_device_identity_pairing`) - slice; status: planned; owner: Bmux; repositories: Bmux; concept: platform; layer: platform; execution: planned / Bmux; parallelism: serial; delivery: proposed; acceptance: proposed
          Depends on: `remote_session_protocol_loopback`
          Enables: `remote_first_transport`, `remote_react_native_app_foundation`
          Rationale: Do not expose remotely controllable local PTYs until trusted-device pairing, host identity verification, revocation, replay protection, and application-layer authorization exist.
        - **First Remote Transport** (`remote_first_transport`) - slice; status: planned; owner: Bmux; repositories: Bmux; concept: platform; layer: platform; execution: planned / Bmux; parallelism: serial; delivery: proposed; acceptance: proposed
          Depends on: `remote_device_identity_pairing`
          Enables: `remote_mobile_terminal_vertical_slice`
          Rationale: Select the lowest-risk first dogfood transport after rechecking the existing Iroh/Tailscale work; transport details must not leak into the remote-session protocol or mobile app domain model.
    - **React Native Mobile Client** (`remote_react_native_mobile_client`) - phase; status: planned; owner: Bmux; repositories: Bmux; concept: platform; layer: consumer presentation; execution: planned / Bmux; parallelism: conditional
      Depends on: `remote_session_protocol_loopback`
      Rationale: Build the production iPhone/iPad app in React Native while keeping native iOS modules limited to secure storage, networking, background behavior, keyboard, and terminal integration seams.
      - **React Native App and Mobile Terminal** (`remote_react_native_app_milestone`) - milestone; status: planned; owner: Bmux; repositories: Bmux; concept: platform; layer: consumer presentation; execution: planned / Bmux; parallelism: serial
        - **React Native Application Foundation** (`remote_react_native_app_foundation`) - slice; status: planned; owner: Bmux; repositories: Bmux; concept: platform; layer: consumer presentation; execution: planned / Bmux; parallelism: conditional; delivery: proposed; acceptance: proposed
          Depends on: `remote_session_protocol_loopback`, `remote_device_identity_pairing`
          Enables: `remote_mobile_terminal_vertical_slice`
        - **Mobile Terminal Vertical Slice** (`remote_mobile_terminal_vertical_slice`) - slice; status: planned; owner: Bmux; repositories: Bmux; concept: platform; layer: consumer presentation; execution: planned / Bmux; parallelism: serial; delivery: proposed; acceptance: proposed
          Depends on: `remote_react_native_app_foundation`, `remote_first_transport`
          Enables: `remote_terminal_fidelity_mobile_interaction`, `remote_session_control_lifecycle`
          Rationale: First product milestone; start Codex in bmux on the Mac, leave the Mac, open the iPhone app, attach to that exact session, see current terminal state, type another instruction, and observe the same process respond in both clients.
        - **Terminal Fidelity and Mobile Interaction** (`remote_terminal_fidelity_mobile_interaction`) - slice; status: planned; owner: Bmux; repositories: Bmux; concept: platform; layer: consumer presentation; execution: planned / Bmux; parallelism: serial; delivery: proposed; acceptance: proposed
          Depends on: `remote_mobile_terminal_vertical_slice`
        - **Session Control and Lifecycle** (`remote_session_control_lifecycle`) - slice; status: planned; owner: Bmux; repositories: Bmux; concept: platform; layer: platform; execution: planned / Bmux; parallelism: serial; delivery: proposed; acceptance: proposed
          Depends on: `remote_mobile_terminal_vertical_slice`
        - **Notifications and Background Behavior** (`remote_notifications_background_behavior`) - slice; status: planned; owner: Bmux; repositories: Bmux, Provenance Engine; concept: platform; layer: consumer presentation; execution: planned / Bmux; parallelism: conditional; delivery: proposed; acceptance: proposed
          Depends on: `remote_session_control_lifecycle`
    - **PE-Powered Mobile Smart Session Experience** (`remote_mobile_smart_session_experience`) - phase; status: deferred; owner: Bmux; repositories: Bmux, Provenance Engine; concept: semantic understanding; layer: consumer presentation; execution: deferred / Shared; parallelism: conditional
      Depends on: `remote_mobile_terminal_vertical_slice`, `coding_agent_evidence_source_reconciliation`
      Rationale: Mobile terminal control must work with bmux only. PE semantic data can enrich later session cards once representative normal-session evidence and SessionWorkModel contracts are ready.
      - **Mobile Smart Session Intelligence** (`remote_mobile_smart_session_milestone`) - milestone; status: deferred; owner: Bmux; repositories: Bmux, Provenance Engine; concept: semantic understanding; layer: consumer presentation; execution: deferred / Shared; parallelism: serial
        - **PE Smart Session Mobile Integration** (`remote_pe_smart_session_integration`) - slice; status: deferred; owner: Bmux; repositories: Bmux, Provenance Engine; concept: semantic understanding; layer: consumer presentation; execution: deferred / Shared; parallelism: serial; delivery: proposed; acceptance: proposed
          Depends on: `remote_mobile_terminal_vertical_slice`, `coding_agent_evidence_source_reconciliation`, `milestone_inference`, `scoped_architecture_projection`
          Rationale: Adds PE-backed current activity, milestones, blockers, relationships, summaries, and scoped architecture to mobile without coupling terminal attach/control to PE availability.
    - **General Internet Connectivity** (`remote_general_internet_connectivity`) - phase; status: deferred; owner: Bmux; repositories: Bmux; concept: deployment; layer: platform; execution: deferred / Bmux; parallelism: serial
      Depends on: `remote_mobile_terminal_vertical_slice`
      - **General Internet Connectivity Later** (`remote_general_connectivity_milestone`) - milestone; status: deferred; owner: Bmux; repositories: Bmux; concept: deployment; layer: platform; execution: deferred / Bmux; parallelism: serial
        - **General Internet Route** (`remote_general_internet_route`) - slice; status: deferred; owner: Bmux; repositories: Bmux; concept: deployment; layer: platform; execution: deferred / Bmux; parallelism: serial; delivery: proposed; acceptance: proposed
          Depends on: `remote_mobile_terminal_vertical_slice`
          Rationale: Evaluate whether Tailscale remains appropriate after dogfood and add Iroh/direct, rendezvous, or bmux-operated relay routes without replacing the protocol or React Native app architecture.

## Parallel Worktree Preflight

Active assignments are derived from roadmap slice nodes with `status: active` or `execution.assignment: current`.

- Active implementation assignments: none selected.

### Next Eligible Preflight

| Slice | Parallelism | Worktree required | Conflict domains | Contract dependencies | Expected contract domains | Expected code areas |
| --- | --- | --- | --- | --- | --- | --- |
| Live Terminal Codex Evidence Ingestion (`live_terminal_codex_evidence_ingestion`) | serial | true | `codex_session_identity`, `lifecycle_recording`, `transcript_tail_cursors` | `codex_jsonl_transcript_adapter`, `producer_neutral_lifecycle_recording` | `live_transcript_tailer`, `session_lifecycle_identity`, `canonical_execution_evidence` | `bmux Codex hook/session monitor`, `bmux Codex transcript/session observation adapters`, `Sources/WorkProvenance` |
| Local Session Host Contract (`remote_local_session_host_contract`) | serial | true | `terminal_runtime_lifecycle`, `workspace_panel_lifecycle`, `ghostty_surface_snapshot` | `terminal_surface_hosting` | `ui_independent_terminal_attachment`, `session_lifecycle`, `terminal_snapshot_boundary` | `Packages/macOS/BmuxTerminalCore`, `Packages/macOS/BmuxTerminal`, `Sources/Workspace.swift`, `Sources/GhosttyTerminalView.swift`, `bmuxTests` |

## Next Eligible Work

- Live Terminal Codex Evidence Ingestion (`live_terminal_codex_evidence_ingestion`) - depends on: `codex_transcript_canonical_evidence_import`
- Local Session Host Contract (`remote_local_session_host_contract`) - depends on: None

## Deferred Or Blocked Work

- Durable Knowledge (`durable_knowledge`) - status: deferred; depends on: `milestone_to_code_relationships`, `milestone_to_architecture_relationships`
- Knowledge Compiler Later (`knowledge_compiler_later`) - status: deferred; depends on: None
- Knowledge Compiler work later (`knowledge_compiler_outcomes`) - status: deferred; depends on: `milestone_to_code_relationships`, `milestone_to_architecture_relationships`
- PE-Powered Mobile Smart Session Experience (`remote_mobile_smart_session_experience`) - status: deferred; depends on: `remote_mobile_terminal_vertical_slice`, `coding_agent_evidence_source_reconciliation`
- Mobile Smart Session Intelligence (`remote_mobile_smart_session_milestone`) - status: deferred; depends on: None
- PE Smart Session Mobile Integration (`remote_pe_smart_session_integration`) - status: deferred; depends on: `remote_mobile_terminal_vertical_slice`, `coding_agent_evidence_source_reconciliation`, `milestone_inference`, `scoped_architecture_projection`
- General Internet Connectivity (`remote_general_internet_connectivity`) - status: deferred; depends on: `remote_mobile_terminal_vertical_slice`
- General Internet Connectivity Later (`remote_general_connectivity_milestone`) - status: deferred; depends on: None
- General Internet Route (`remote_general_internet_route`) - status: deferred; depends on: `remote_mobile_terminal_vertical_slice`
