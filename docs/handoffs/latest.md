# bmux Handoff

## Slice

- ID: `three_view_coding_session_planning`
- Title: Three-view coding-session planning and Project Truth update
- bmux branch: `project-truth-bmux-state-reconciliation`
- bmux worktree: `/Users/brianbusby/repos/bmux-project-truth-reconciliation`
- PE branch: `project-truth-eligibility-reconciliation`
- PE worktree: `/Users/brianbusby/repos/provenance-engine-project-truth-eligibility`

Generated authoritative status:

- [Project status](../generated/project-status.md)
- [Nested roadmap](../generated/nested-roadmap.md)
- [Repository status](../generated/repository-status.md)
- [Ownership boundary](../generated/ownership-boundary.md)

## Three-view Architecture

One coding-agent session should have three distinct views:

- Native: provider-native surface and escape hatch.
- Terminal: bmux React live interaction surface, building from `agent-chat`.
- Session: bmux React smart summary surface backed by PE factual and semantic
  models.

Native answers what the provider natively exposes. Terminal answers what is
happening live and how the user interacts with the agent. Session answers what
the work means and how the session is progressing.

## React Presentation Decision

Terminal and Session are both React, but they should not collapse into one
conceptual interface. Terminal may consume live provider/runtime events. Session
should consume PE factual projection, semantic inference records, semantic
messages, and future `SessionWorkModel` snapshots.

## Existing Slices Reused

- `agent-chat` is the React Terminal foundation.
- Existing provider-native terminal/session surfaces remain the Native view.
- `factual_agent_session_view` remains active bmux PR #49 as factual consumer
  groundwork and diagnostics.
- Implemented PE factual projection, semantic inference, and semantic messaging
  slices remain the Smart Session substrate.

## New Slices Introduced

- `react_terminal_productization`
- `react_smart_session_foundation`
- `react_smart_session_work_model_consumer`
- `three_view_session_navigation`
- PE-owned `session_work_model_contract_foundation`
- grouping nodes `three_view_coding_session_experience` and
  `coding_session_view_surfaces`

## Dependencies Added Or Changed

- `react_smart_session_foundation` is selected next but blocked by active
  `factual_agent_session_view`.
- `clickable_semantic_explanation_ui` now follows React Smart Session
  foundation instead of directly following factual native UI.
- Smart SessionWorkModel consumer waits for PE SessionWorkModel contract,
  milestone inference, and blocker/approach-change semantics.
- Three-view navigation waits for Terminal productization and Smart Session
  foundation.

## Dependency-ready Work

Generated Project Truth currently derives these as dependency-ready:

- `session_work_model_contract_foundation`
- `react_terminal_productization`
- `presentation_language_calibration_corpus`
- `milestone_inference`
- `blocker_approach_change_semantics`
- `scoped_architecture_projection`

## Selected Next Work

- `react_smart_session_foundation` is selected next but blocked by
  `factual_agent_session_view`.
- Active work remains PR #49, `factual_agent_session_view`, on branch
  `clickable-semantic-explanation-ui`.

## Safe Parallel Work

- React Terminal productization can proceed independently if it stays in live
  interaction, provider controls, and surface lifecycle.
- PE SessionWorkModel contract foundation can proceed independently from bmux
  UI once coordinated against Smart Session consumer needs.
- PE calibration, milestone, blocker/approach-change, and scoped-architecture
  slices are technically ready but not selected here.

## Work Intentionally Deferred

- Broad implementation of Smart Session UI.
- Native/Terminal/Session switching and restore behavior.
- Clickable semantic explanation detail UI.
- Full `SessionWorkModel` consumer, milestone-to-code relationships,
  Git/GitHub attribution, Knowledge Compiler, retrieval, and broader runtime
  work.

## Treatment Of Current Native Factual Session UI

The current native factual Session UI should be treated as factual projection
consumer validation, data-access groundwork, and diagnostics. It should not grow
into a parallel Swift Smart Session product. Future slices should either keep it
as inspection support or migrate the user-facing summary presentation into
React.

## Implementation Gaps

- React Smart Session surface/host does not exist yet.
- `agent-chat` is not yet productized as a first-class Terminal surface.
- Session identity preservation across Native, Terminal, and Session is not yet
  implemented.
- PE does not yet expose full progress, blocker, validation, milestone, or
  approach-change semantics through a `SessionWorkModel` snapshot.

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
