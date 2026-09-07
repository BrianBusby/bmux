# Monorepo Migration Ledger

This ledger records open branch/PR disposition at the time the monorepo branch
was created. It should be updated when branches are rebased, superseded, merged,
or closed.

## Closure Tracking

Project Truth now captures the remaining evidence-based closure work as
`monorepo_migration_ledger_disposition_closure`. The entries marked `awaiting
closure slice` below are deliberately unresolved: a future slice must inspect
current GitHub and local repository state, then rebase and preserve, recreate,
close as superseded, or archive each item. This planning update does not delete
local worktrees, branches, repositories, or user changes.

## Repository Migration

| Area | Old location | New location | Status |
| --- | --- | --- | --- |
| PE Swift package | `BrianBusby/provenance-engine` root | `Packages/macOS/ProvenanceEngine` | merged in PR #53 with history |
| PE Project Truth manifest/schema/tool | PE `project/`, `tools/project-docs` | monorepo root `project/`, `tools/project-docs` | moved |
| bmux PE dependency | remote Git revision pin | local Xcode package reference | migrated |
| Generated Project Truth docs | duplicated bmux/PE generated docs | root `docs/generated` | consolidated |
| PE CI Project Truth workflow | PE `.github/workflows/project-truth.yml` | root `.github/workflows/project-truth.yml` | consolidated |

## Open PR Disposition

| Old repo | Branch / PR | New monorepo disposition | Status |
| --- | --- | --- | --- |
| bmux | `project-truth-bmux-state-reconciliation` / PR #52 | merged into migration branch before PE import | incorporated |
| provenance-engine | `project-truth-eligibility-reconciliation` / PR #33 | imported by subtree into `Packages/macOS/ProvenanceEngine`, then root Project Truth reconciled | incorporated |
| bmux | `clickable-semantic-explanation-ui` / PR #49 | recreated on monorepo `main` and merged as factual/native Session groundwork, not final React Smart Session | merged |
| bmux | `workspace-tab-card-cleanup` / PR #47 | rebase after migration if still desired | awaiting closure slice |
| bmux | `fix-workspace-tab-prompt-links` / PR #37 | rebase or close if superseded by newer workspace tab work | awaiting closure slice |
| bmux | `remove-live-pr-sidebar-row` / PR #33 | rebase only if still product-relevant; base branch is non-main | awaiting closure slice |
| bmux | `workspace-display-current-state-projection` / PR #32 | re-evaluate against imported PE Current State and workspace display implementation | awaiting closure slice |
| bmux | `fix-prompt-nav-buttons` / PR #21 | rebase or close if superseded | awaiting closure slice |
| bmux | `fix-react-submit-bar-photo-drop-v2` / PR #10 | rebase if still desired | awaiting closure slice |
| bmux | `context-efficiency-phase-b-lifecycle` / PR #5 | likely superseded by later PE and Project Truth work; confirm before closing | awaiting closure slice |

## Local Worktree Disposition

| Worktree | Branch | Disposition | Status |
| --- | --- | --- | --- |
| `/Users/brianbusby/repos/bmux` | `fix-workspace-tab-link-ordering` | original checkout restored and left clean | safe |
| `/Users/brianbusby/repos/bmux-monorepo-provenance-engine` | `monorepo-provenance-engine` | migration worktree for PR #53 | merged |
| `/Users/brianbusby/repos/bmux-clickable-semantic-explanation-ui` | `clickable-semantic-explanation-ui` | historical PR #49 source branch; useful work was recreated on monorepo `main` and merged | merged |
| `/Users/brianbusby/repos/provenance-engine` | `main` | archival/source reference; do not delete | preserve |
| `/Users/brianbusby/repos/provenance-engine-project-truth-eligibility` | `project-truth-eligibility-reconciliation` | incorporated by subtree; can close after migration PR lands | awaiting closure slice |
| `/Users/brianbusby/repos/bmux-pe-current-state` | `subscribe-pe-current-state` | upstream gone; inspect before discarding | awaiting closure slice |
| `/Users/brianbusby/repos/bmux-linear-ticket-evidence` | `fix-linear-ticket-evidence-sources` | inspect/rebase if still product-relevant | awaiting closure slice |
| `/Users/brianbusby/repos/bmux-project-truth-generated-docs-sync` | local branch | likely superseded by root Project Truth consolidation | awaiting closure slice |
| `/Users/brianbusby/repos/bmux-project-truth-reconciliation` | `project-truth-bmux-state-reconciliation` | incorporated into migration branch | incorporated |
| `/Users/brianbusby/repos/bmux-prompt-nav` | local branch | inspect/rebase if still relevant | awaiting closure slice |
| `/Users/brianbusby/repos/bmux-provenance-sidecar-lifecycle` | main behind | likely historical; inspect before deleting | awaiting closure slice |

## Merge Guidance

Do not merge or close old PRs only because the monorepo exists. Remaining
awaiting-closure branches should either be rebased into the monorepo, replaced
by an equivalent monorepo branch, explicitly closed as superseded with a pointer
to the monorepo change, or preserved as intentional archival/recovery reference.
