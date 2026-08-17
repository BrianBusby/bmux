# Project Truth Handoff

## Slice

- ID: `three_view_coding_session_planning`
- Title: Three-view coding-session planning and Project Truth update
- Repositories: `BrianBusby/provenance-engine`, `BrianBusby/bmux`
- PE branch: `project-truth-eligibility-reconciliation`
- PE worktree: `/Users/brianbusby/repos/provenance-engine-project-truth-eligibility`
- bmux branch: `project-truth-bmux-state-reconciliation`
- bmux worktree: `/Users/brianbusby/repos/bmux-project-truth-reconciliation`

Generated authoritative status:

- [Project status](../generated/project-status.md)
- [Nested roadmap](../generated/nested-roadmap.md)
- [Repository status](../generated/repository-status.md)
- [Ownership boundary](../generated/ownership-boundary.md)

## Three-view Architecture

One coding-agent session should support three distinct views over the same
underlying provider/session identity:

- Native: provider-native fidelity, debugging, provider capability escape hatch.
- Terminal: bmux React live interaction surface for streaming conversation,
  tools, commands, controls, approvals, interrupts, skills, modes, and cwd.
- Session: bmux React smart summary surface backed by PE factual and semantic
  models for goal, completed/current turns, activity, plans, outcomes, risks,
  blockers, validations, and progress.

## React Presentation Decision

Terminal and Session are both React surfaces, but they are not one product.
Terminal may consume live provider/runtime events directly. Session should
consume PE factual projection, semantic inference records, semantic messages,
and future `SessionWorkModel` contracts instead of reconstructing meaning from
raw provider events.

## Existing Slices Reused

- `richer_coding_agent_evidence_foundation`
- `factual_session_projection_foundation`
- `factual_projection_consumer_shape_followup`
- `semantic_inference_framework`
- `first_semantic_session_inferences`
- `human_readable_semantic_messaging`
- active bmux `factual_agent_session_view` PR #49 as factual consumer
  groundwork, not final Smart Session UI

## New Slices Introduced

- `session_work_model_contract_foundation`
- `three_view_coding_session_experience`
- `coding_session_view_surfaces`
- `react_terminal_productization`
- `react_smart_session_foundation`
- `react_smart_session_work_model_consumer`
- `three_view_session_navigation`

## Dependencies Added Or Changed

- `react_smart_session_foundation` depends on `factual_agent_session_view` and
  `human_readable_semantic_messaging`; it is explicitly selected next but not
  dependency-ready until the factual Session view lands.
- `clickable_semantic_explanation_ui` now depends on
  `react_smart_session_foundation` instead of directly following the factual
  native UI.
- `react_smart_session_work_model_consumer` depends on Smart Session
  foundation, PE SessionWorkModel contract foundation, milestone inference, and
  blocker/approach-change semantics.
- `three_view_session_navigation` depends on React Terminal productization and
  React Smart Session foundation.

## Dependency-ready Work

Generated Project Truth currently derives these as ready:

- `session_work_model_contract_foundation`
- `react_terminal_productization`
- `presentation_language_calibration_corpus`
- `milestone_inference`
- `blocker_approach_change_semantics`
- `scoped_architecture_projection`

## Selected Next Work

- `react_smart_session_foundation` is selected next, but blocked by active
  `factual_agent_session_view`.
- Active work remains bmux PR #49: `factual_agent_session_view` on branch
  `clickable-semantic-explanation-ui`.

## Safe Parallel Work

- `react_terminal_productization` can proceed independently from PE semantic
  enrichment if it stays focused on live interaction and surface lifecycle.
- `session_work_model_contract_foundation` can proceed on the PE side from the
  implemented semantic-message foundation.
- PE calibration, milestone, blocker/approach-change, and scoped-architecture
  slices are dependency-ready but not selected by this handoff.

## Work Intentionally Deferred

- Full Smart SessionWorkModel consumer presentation.
- Three-view navigation/switching.
- Clickable semantic explanation drilldown.
- Milestone-to-code, milestone-to-architecture, Git/GitHub attribution,
  Knowledge Compiler, retrieval, and broad UI/runtime implementation.

## Treatment Of Current Native Factual Session UI

bmux PR #49 remains useful as factual projection consumer validation,
data-access groundwork, and diagnostic/inspection UI. Because it is
Swift/native and factual-only, it should not be counted as the final React
Smart Session surface or semantic explanation feature.

## Implementation Gaps

- bmux does not yet have a first-class React Smart Session host/surface.
- Native/Terminal/Session switching does not yet preserve one session identity
  as an explicit product workflow.
- PE does not yet expose a full `SessionWorkModel` snapshot contract.
- Milestone, validation, blocker, approach-change, and richer progress
  semantics remain planned.

## Validation

Passed:

- PE: `./scripts/project-docs validate`
- PE: `./scripts/project-docs generate`
- PE: `./scripts/project-docs check`
- bmux: `PROJECT_TRUTH_TOOL_ROOT=/Users/brianbusby/repos/provenance-engine-project-truth-eligibility/tools/project-docs PROJECT_TRUTH_SHARED_STATE=/Users/brianbusby/repos/provenance-engine-project-truth-eligibility/project/project-state.yaml ./scripts/project-docs validate`
- bmux: same environment with `./scripts/project-docs generate`
- bmux: same environment with `./scripts/project-docs check`
- PE: `git diff --check`
- bmux: `git diff --check`
- PE: `GH_TOKEN=$(gh auth token) ./scripts/project-docs ci --peer-repo-root /Users/brianbusby/repos/bmux-project-truth-reconciliation`
- bmux: `GH_TOKEN=$(gh auth token) PROJECT_TRUTH_TOOL_ROOT=/Users/brianbusby/repos/provenance-engine-project-truth-eligibility/tools/project-docs PROJECT_TRUTH_SHARED_STATE=/Users/brianbusby/repos/provenance-engine-project-truth-eligibility/project/project-state.yaml ./scripts/project-docs ci --peer-repo-root /Users/brianbusby/repos/provenance-engine-project-truth-eligibility`
