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

- Primary Capability Frontier: Process Integrity (`process_integrity`)
- Active or selected slices in the frontier: none

### Active Implementation

- Shared-session Chat and permanent Terminal (`shared_session_chat`) - maturity: active; status: active; selection: current; owner: Bmux

### Selected Next

- None.

### Ready Candidates

- React Smart SessionWorkModel consumer (`react_smart_session_work_model_consumer`) - maturity: ready; status: planned; selection: planned; owner: Bmux
- Cross-session context assembly experiment (`cross_session_context_assembly_experiment`) - maturity: ready; status: planned; selection: planned; owner: Bmux
- Milestone-to-code relationships (`milestone_to_code_relationships`) - maturity: ready; status: planned; selection: planned; owner: Provenance Engine

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

## Shared Milestones

| Milestone | Owner | Delivery | Acceptance | Evidence |
| --- | --- | --- | --- | --- |
| Provenance Engine V1 package (`provenance_engine_v1`) | Provenance Engine | merged | accepted | BrianBusby/bmux@18f5511a7c83, BrianBusby/bmux@0ed9f68b6612 |
| Bmux Provenance Engine Slice E adoption (`bmux_slice_e_adoption`) | Bmux | merged | accepted | BrianBusby/bmux@3cbacd150176, BrianBusby/bmux@0ed9f68b6612 |
| Provider-neutral execution telemetry foundation (`execution_telemetry_foundation`) | Bmux | merged | implemented | BrianBusby/bmux@c32ed93989c8, BrianBusby/bmux@9d7fefacbb40, BrianBusby/bmux#12 by [BrianBusby](https://github.com/BrianBusby) |
| Claude lifecycle telemetry migration (`claude_lifecycle_telemetry`) | Bmux | merged | implemented | BrianBusby/bmux@5a4a463f17e0, BrianBusby/bmux@3f49c5d5abbe, BrianBusby/bmux#13 by [BrianBusby](https://github.com/BrianBusby) |
| Workspace Display Durable Context and Reconciliation (`workspace_display_durable_context`) | Bmux | merged | accepted | BrianBusby/bmux@bdf81ae0454f, BrianBusby/bmux@543161954689 |
| Richer Coding-Agent Evidence and Factual Session Projection (`richer_session_work_model`) | Provenance Engine | merged | implemented | BrianBusby/bmux@9e69452a2ec2, BrianBusby/bmux@2add52c611e2, BrianBusby/bmux@a0f8c1fa2d0e, BrianBusby/bmux@45b7188ea62d, BrianBusby/bmux@c11d54c3f8e3, BrianBusby/bmux#48 by [BrianBusby](https://github.com/BrianBusby) |

## Open Shared Caveats

| Caveat | Owner | Status | Issue |
| --- | --- | --- | --- |
| Claude notification full-suite process timeouts remain unresolved despite focused app-host completion (`claude_notification_target_fixture_verification`) | Bmux | open |  |
| Focused Hermes startup and stale-PID suites pending actual app-host verification (`resume_policy_execution_fixture_verification`) | Bmux | open |  |
| Focused browser profile and remote store move suite pending actual app-host verification (`browser_remote_store_fixture_verification`) | Bmux | open |  |
| Focused Cloud attach retry contract suite pending actual app-host verification (`cloud_attach_retry_fixture_verification`) | Bmux | open |  |
| Focused managed appearance startup suite pending actual app-host verification (`managed_appearance_startup_fixture_verification`) | Bmux | open |  |
| Broad legacy bmux-local storage migration (`broad_legacy_storage_migration`) | Bmux | open |  |
| Residual app-runtime lifecycle ownership outside BmuxAppRuntimeServices (`residual_app_runtime_lifecycle_ownership`) | Bmux | open |  |
| Workspace Display file-watcher SQLite churn (`workspace_display_file_watcher_churn`) | Bmux | open |  |
| Local PE SQLite multi-writer policy (`pe_shared_sqlite_multi_writer_policy`) | Bmux | open |  |
| Historical Codex transcript import startup boundary (`codex_historical_import_startup_boundary`) | Bmux | monitoring |  |
| Test determinism allowlist debt (`test_determinism_allowlist_debt`) | Bmux | open |  |
| Config workspace-launch mutation-path bypass (`config_workspace_launch_mutation_bypass`) | Bmux | open |  |
| Monorepo migration ledger pending dispositions (`monorepo_migration_ledger_pending_dispositions`) | Bmux | open |  |
| Observability trace API boundary (`observability_trace_api`) | Provenance Engine | open |  |
| GitHub Actions runner reliability (`github_actions_runner_reliability`) | Bmux | open | BrianBusby/bmux#8 |
| Mixed-signature regressions failed in actual D2 CI and all14 fixed artifact tests pass locally; full Release and fresh-runner validation pending (`bundled_cli_mixed_signature_regression_verification`) | Bmux | open |  |
| Bundled CLI dynamic and Release artifact relocation verification (`bundled_cli_artifact_relocation_verification`) | Bmux | open |  |
| Focused browser app-host gate includes discard policy tests; local native cases pass and pushed-head CI remains pending (`browser_discard_policy_focused_gate_verification`) | Bmux | open |  |
| Codex Stop focused app-host passes nine functions in three suites; full-suite verification remains pending (`codex_stop_fixture_app_host_verification`) | Bmux | open |  |
| CommandRunner blocking pipe readers can exhaust the cooperative executor during parallel socket tests (`command_runner_parallel_pipe_capture`) | Bmux | open |  |
| Browser legacy theme startup migration focused gate awaits fixed app-host CI (`browser_legacy_theme_startup_migration_verification`) | Bmux | open |  |
| Focused browser app-host gate includes background compositing tests; local native cases pass and pushed-head CI remains pending (`browser_background_compositing_focused_gate_verification`) | Bmux | open |  |
| Right sidebar shortcut fixture repair passes local flag-state coverage; focused app-host CI verification remains pending (`right_sidebar_shortcut_fixture_app_host_verification`) | Bmux | open |  |
| CI app-host Option/Alt step selects nine SSH lifecycle tests plus managed attach cleanup fixture; pushed-head verification pending (`ssh_startup_lifecycle_focused_gate_verification`) | Bmux | open |  |
| SSH manual reconnect has actual CI red and native 779 green; fixed-head app-host and runtime acceptance remain pending (`ssh_manual_reconnect_handoff_regression`) | Bmux | open |  |
| Browser discard initial-navigation readiness timed out on macOS 15 CI; bounded fixture diagnostics await app-host evidence (`browser_discard_restore_focused_gate_verification`) | Bmux | open |  |
| Focused app-host gate includes default and configured sidebar width policy tests; local native cases pass and pushed-head CI remains pending (`sidebar_width_persistence_focused_gate_verification`) | Bmux | open |  |
| Claude replaced-session cleanup fixture focused gate awaits app-host CI (`claude_session_end_scope_focused_gate_verification`) | Bmux | open |  |
| Published maintenance fixes are composed for CI; full authoritative native and artifact gates remain pending (`maintenance_combined_validation_pending`) | Bmux | open |  |
| Agent launch environment fixture focused gate awaits app-host CI (`agent_launch_environment_fixture_focused_gate_verification`) | Bmux | open |  |
| SSH workspace creation fixture focused gate awaits app-host CI (`ssh_workspace_creation_fixture_focused_gate_verification`) | Bmux | open |  |
| SSH agent environment fixture focused gate awaits app-host CI (`ssh_agent_environment_fixture_focused_gate_verification`) | Bmux | open |  |
| Foreign workspace close reproduces destructive teardown; owned-instance guard awaits fixed native and app-host verification (`workspace_close_ownership_verification`) | Bmux | open |  |
| Antigravity hook fixture joins request producers without blocked accept workers; full app-host verification pending (`antigravity_hook_lifecycle_fixture_verification`) | Bmux | open |  |
| Initial-input and command fixtures await native readiness without user-window attachment; full app-host verification pending (`terminal_initial_runtime_readiness_verification`) | Bmux | open |  |
| Workspace close uses a real ready runtime and coordinator owns injected-free scheduling coverage; full app-host verification pending (`workspace_runtime_close_fixture_verification`) | Bmux | open |  |
| Grok hook fixtures drain RPC and one-way telemetry through the full notification payload lifecycle; app-host verification pending (`grok_hook_connection_fixture_verification`) | Bmux | open |  |
| Persistent SSH child exit reproduces sibling tracking loss; last-surface guard awaits fixed native and app-host verification (`persistent_pty_child_exit_verification`) | Bmux | open |  |
| SSH PTY initial resize acknowledgement CI timeouts remain unresolved (`ssh_pty_lifecycle_fixture_verification`) | Bmux | open |  |
| CI Option/Alt step selects CodexMonitorLeaseTests sequential and nested controls; actual app-host verification pending (`codex_monitor_lease_fixture_verification`) | Bmux | open |  |
| Respawn window protocol fixture focused gate awaits app-host CI (`respawn_window_protocol_fixture_focused_gate_verification`) | Bmux | open |  |
| Workspace fallback regression test red and production fix verification pending (`workspace_fallback_regression_verification`) | Bmux | open |  |
| Portal geometry and workspace creation/publication fixture corrections await fixed-head app-host verification (`native_portal_workspace_contract_fixture_verification`) | Bmux | open |  |
| Completed-close history and batched mobile response fixture corrections await fixed-head app-host verification (`native_history_and_batched_frame_fixture_verification`) | Bmux | open |  |
| Retained Markdown rendering windows and event-driven fixture await fixed-head app-host verification (`markdown_window_retained_fixture_verification`) | Bmux | open |  |
| Notification-record restore fixtures await fixed-head app-host verification (`notification_record_restore_fixture_verification`) | Bmux | open |  |
| Retained Welcome shortcut window fixture awaits fixed-head app-host verification (`welcome_window_retained_fixture_verification`) | Bmux | open |  |
| Browser inspector window-close runtime fixture correction awaits fixed-head app-host verification (`browser_inspector_window_ownership_verification`) | Bmux | open |  |
| Remote agent restore directory guard passes native build 783; full app-host verification pending (`remote_restore_working_directory_regression`) | Bmux | open |  |
| Focused global search configured-conflict priority suite awaits app-host verification (`global_search_shortcut_conflict_verification`) | Bmux | open |  |
| Opt-in app-host sampler completion and private output controls pass locally; macOS 15 graph capture remains pending (`focused_app_host_process_diagnostics_verification`) | Bmux | open |  |
| Remote tmux CRLF record correction passes isolated artifact checks; full CI pending (`remote_tmux_crlf_record_parsing_verification`) | Bmux | open |  |
| Quarantine outbound metadata and native readback contract pass local checks; app-host verification remains pending (`browser_download_quarantine_boundary_verification`) | Bmux | open |  |
| Configured and chorded file preview save fixtures await fixed-head app-host verification (`file_preview_save_shortcut_fixture_verification`) | Bmux | open |  |
| Panel clear-content and opaque chrome compositing suite awaits fixed-head app-host verification (`panel_appearance_compositing_fixture_verification`) | Bmux | open |  |
| Narrow titlebar reservation fix preserves offscreen reference layout; integrated app verification remains pending (`titlebar_narrow_window_layout_verification`) | Bmux | open |  |
| Claude resume and disabled git-watch contract migrations pass native 786; fixed-head app-host verification pending (`claude_resume_and_no_git_watch_fixture_verification`) | Bmux | open |  |
| Titlebar hit-target sizing and search metadata fixture migrations pass native 786; app-host and Swift 6 shortcut-store isolation remain open (`titlebar_search_metadata_fixture_verification`) | Bmux | open |  |
| Closed-peer receive regression awaits execution after bundled CLI build prerequisite; D2 setup ran zero socket tests (`cli_closed_peer_receive_regression_verification`) | Bmux | open |  |
| Three tagged CLI fixtures use short owned homes; native 786 exposes a separate multiline receive-timeout error in two cases (`cli_socket_home_fixture_verification`) | Bmux | open |  |
| Native titlebar default-width and voice-control fixture corrections pass locally; app-host verification remains pending (`titlebar_product_contract_fixture_verification`) | Bmux | open |  |
| CLI socket capture completion focused gate and shared-caller verification (`cli_socket_capture_completion_verification`) | Bmux | open |  |
| Remote tmux LF and CRLF parser focused gate awaits fixed-head CI verification (`remote_tmux_parser_focused_gate_verification`) | Bmux | open |  |
| Per-descriptor native readiness is bounded locally; final app-host timeout attribution and verification remain pending (`cli_socket_readiness_coalescing_verification`) | Bmux | open |  |
| Sidebar pointer fixture exercises the actual four-point content overlap; full app-host verification remains pending (`sidebar_terminal_hit_boundary_verification`) | Bmux | open |  |
| Browser portal resize, reveal, and transient rebind contracts pass native 786; integrated app-host verification remains pending (`browser_portal_presentation_fixture_verification`) | Bmux | open |  |
| Native project parsing and D2 build gates pass after quoting extension filenames; final integrated checks remain pending (`native_xcode_project_parse_verification`) | Bmux | open |  |
| Native input, IME and focus-recovery fixtures require bounded runtime readiness; integrated macOS app-host verification remains pending (`terminal_native_input_delivery_fixture_verification`) | Bmux | open |  |
| Remote agent fork fixture owns its existing agent path and passes native checks; app-host verification remains pending (`remote_agent_fork_fixture_verification`) | Bmux | open |  |
| Default cloud proxy retry correction passes native build787 original and five preserved controls; integrated CI remains pending (`default_cloud_proxy_retry_state_verification`) | Bmux | open |  |
| Deleted agent-hook cwd correction passes native build787 regression and nine directory controls; integrated app-host verification pending (`deleted_agent_hook_cwd_regression`) | Bmux | open |  |
| Resume cwd and captured Codex fork-tag fixtures follow shared command policy; fixed-head app-host verification pending (`session_resume_fork_contract_fixture_verification`) | Bmux | open |  |
| Sidebar PR aggregate and focused projection fixture correction awaits fixed-head app-host verification (`sidebar_pr_focus_contract_fixture_verification`) | Bmux | open |  |
| Notification focus fixture awaits the existing event flush and passes native proof; fixed-head app-host remains pending (`notification_focus_event_fixture_verification`) | Bmux | open |  |
| Keydown notification fixture isolates runtime and surface-flash preferences; fixed-head app-host remains pending (`notification_keydown_fixture_verification`) | Bmux | open |  |

## Automatic Checkpoints

- Implementation status: not implemented
- Selected for implementation: false
- Operational statement: automatic diagnostic checkpoints are not operational.
