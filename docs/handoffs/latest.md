# Project Truth Handoff

## Slice

- ID: `project_truth_dependency_readiness_reconciliation`
- Title: Project Truth dependency readiness and bmux state reconciliation
- Repositories: `BrianBusby/provenance-engine`, `BrianBusby/bmux`
- PE branch: `project-truth-eligibility-reconciliation`
- PE worktree: `/Users/brianbusby/repos/provenance-engine-project-truth-eligibility`
- bmux branch: `project-truth-bmux-state-reconciliation`
- bmux worktree: `/Users/brianbusby/repos/bmux-project-truth-reconciliation`

## What Changed

Generated authoritative status:

- [Project status](../generated/project-status.md)
- [Nested roadmap](../generated/nested-roadmap.md)
- [Repository status](../generated/repository-status.md)

- Dependency readiness is now derived from roadmap `depends_on` and
  `sequence_after` state for implementation candidate slices.
- Explicit next-work selection is represented with
  `execution.assignment: selected_next`.
- Active work remains represented by `status: active` or
  `execution.assignment: current` plus branch/worktree/agent metadata.
- The nested roadmap and architecture status generated blocks now show
  dependency-ready work, selected-next work, active assignments, and
  dependency-ready-but-not-selected work separately.
- bmux PR #49 is modeled as `factual_agent_session_view`, an active factual UI
  prerequisite, not as `clickable_semantic_explanation_ui`.
- The clickable semantic explanation UI remains explicitly selected next, but
  it is dependency-blocked on the factual Session view.
- The richer coding-agent evidence foundation and aggregate richer-session
  milestone now record both PE PR #19 and bmux PR #48 evidence.
- Repository status rendering is repository-aware; bmux now renders
  `Bmux repository state`.
- Authored-doc drift detection now rejects targeted volatile UI-selection
  claims and checks `docs/session-work-model.md`.
- `docs/session-work-model.md` now distinguishes semantic interpretation
  errors from presentation wording errors for future feedback learning.

## Important Decisions

- `next_eligible` is retired in favor of explicit `selected_next`; readiness is
  not stored in the manifest.
- Dependency readiness only considers implementation candidate slices, so
  project/program/phase/milestone nodes do not appear as work candidates.
- Implemented and accepted statuses, plus implemented/under-observation/
  accepted acceptance status, satisfy dependencies.
- Active repo-local `current_work.active_slice` must reference a roadmap slice
  that is actually active/current and must match declared active metadata.
- PR #49 keeps its existing branch name; Project Truth disambiguates that the
  branch is factual UI groundwork.

## Validation

Passed:

- `./scripts/project-docs validate`
- `./scripts/project-docs check`
- `GH_TOKEN=$(gh auth token) ./scripts/project-docs ci --peer-repo-root /Users/brianbusby/repos/bmux-project-truth-reconciliation`
- `PYTHONPATH=tools/project-docs python3 -m unittest tools/project-docs/tests/test_project_docs.py`
- `PROJECT_TRUTH_TOOL_ROOT=/Users/brianbusby/repos/provenance-engine-project-truth-eligibility/tools/project-docs PROJECT_TRUTH_SHARED_STATE=/Users/brianbusby/repos/provenance-engine-project-truth-eligibility/project/project-state.yaml ./scripts/project-docs validate`
- `PROJECT_TRUTH_TOOL_ROOT=/Users/brianbusby/repos/provenance-engine-project-truth-eligibility/tools/project-docs PROJECT_TRUTH_SHARED_STATE=/Users/brianbusby/repos/provenance-engine-project-truth-eligibility/project/project-state.yaml ./scripts/project-docs check`
- `GH_TOKEN=$(gh auth token) PROJECT_TRUTH_TOOL_ROOT=/Users/brianbusby/repos/provenance-engine-project-truth-eligibility/tools/project-docs PROJECT_TRUTH_SHARED_STATE=/Users/brianbusby/repos/provenance-engine-project-truth-eligibility/project/project-state.yaml ./scripts/project-docs ci`
- `git diff --check` in `BrianBusby/provenance-engine`
- `git diff --check` in `BrianBusby/bmux`

## Open Limitations

- Project Truth still does not auto-discover Git branches, worktrees, or open
  PRs; agents must record active assignments intentionally.
- `factual_agent_session_view` is active through bmux PR #49 but not merged.
- `clickable_semantic_explanation_ui` is selected next but not dependency-ready
  until the factual Session view lands.
- Dependency readiness is derived for slice candidates only; it is not an
  autonomous scheduler and does not mutate assignments.

## Dependency-Ready Slices

- `presentation_language_calibration_corpus`
- `milestone_inference`
- `blocker_approach_change_semantics`
- `scoped_architecture_projection`

## Selected Next Slices

- `clickable_semantic_explanation_ui` - selected next, blocked by
  `factual_agent_session_view`.

## Active Branch/Worktree Assignments

- `factual_agent_session_view` - bmux PR #49, branch
  `clickable-semantic-explanation-ui`, worktree
  `/Users/brianbusby/repos/bmux-clickable-semantic-explanation-ui`, agent
  `Codex`.

## Dependency-Ready But Not Selected

- `presentation_language_calibration_corpus`
- `milestone_inference`
- `blocker_approach_change_semantics`
- `scoped_architecture_projection`
