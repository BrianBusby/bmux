# Post-Merge Project Truth Reconciliation Audit

This audit records the Process Integrity slice for Project Truth delivery reconciliation. Generated status remains canonical in `docs/generated/project-status.md`; this document explains the lifecycle and ownership boundary that produces it.

## Current Lifecycle

The repository already has canonical Project Truth manifests, generated docs, named invariants, GitHub evidence validation, and capability-frontier reporting. Before this slice, the end-to-end delivery lifecycle still had a manual gap:

1. A slice was selected by setting roadmap execution to `current` and repo-local `current_work.active_slice` to the same slice.
2. A branch/worktree recorded implementation ownership in `project/project-state.yaml` and `project/repo-status.yaml`.
3. The implementation PR could record open PR evidence, but it could not know its future merge commit or merge timestamp.
4. After merge, a human had to open a follow-up metadata PR to mark delivery merged, add merge evidence, clear the active assignment, regenerate docs, and expose newly ready candidates.

PRs #81, #83, and #86 were examples of this repair path. PR #95 later showed the same shape: the implementation merged, but Project Truth required an additional reconciliation step before current status and generated frontier output matched repository reality. After PR #97 merged on September 5, 2026, `main` again contained a merged active branch while generated Project Truth still presented `deterministic_app_runtime_composition` as active/current.

## Canonical Owner And Source Of Truth

`project/project-state.yaml` remains the canonical shared Project Truth manifest for roadmap, dependency, delivery, acceptance, caveat, ownership, and evidence state. `project/repo-status.yaml` remains the canonical repo-local execution and capability manifest. The existing `tools/project-docs/project_docs.py` tool is the only Project Truth reconciliation owner; generated docs remain derived output and must not be edited directly.

## Mechanical Facts

The reconciliation tool can safely derive these facts from GitHub and the manifests:

- A recorded pull request exists, is open, is closed, or merged.
- A merged pull request has a merge commit and merged timestamp.
- A recorded active branch maps to exactly one repository PR.
- A recorded implementation commit is reachable from the repository default branch.
- A delivery previously marked `open` or `draft` is now merged.
- Active branch/worktree metadata points to completed delivery and can be cleared.
- A gated candidate has all declared dependencies and readiness gates satisfied and can advance to `ready`.

## Human Decisions

The tool must not infer these decisions:

- A merged implementation is accepted.
- An observation period is sufficient.
- A caveat can close.
- A closed-unmerged PR is superseded, abandoned, replaced, or should reopen.
- A ready candidate is the next priority.
- A planned slice remains desirable after product direction changes.

For that reason, reconciliation can move `delivery_status` to `merged`, record merge evidence, move active implementation execution to `complete`, and expose ready candidates. It does not set `accepted_at`, `acceptance_reason`, close caveats, or select a next slice.

## Edge Cases

Closed-unmerged PRs are reported as explicit planning decisions. Superseded or replaced PRs are reconciled only when Project Truth already records the replacement relationship through current delivery evidence. Observation remains separate from implementation: a slice can have merged delivery and remain `under_observation`, but repo-local active implementation should not keep pointing at it. Multiple independent merged slices are applied in deterministic manifest order and then the capability frontier is recalculated from the resulting graph.

Generated documentation could previously be fresh relative to manifests while stale relative to GitHub reality, because CI validated declared evidence but did not discover that an active branch had already merged. The new reconciliation command closes that gap without creating a second source of truth.

## Selected Boundary

The selected boundary is `./scripts/project-docs reconcile --check|--apply` in the existing Project Docs tool. Check mode is read-only and reports safe mechanical changes, human decisions, and evidence/provider failures separately. Apply mode updates canonical manifests, regenerates derived docs, validates in a temporary repository copy, and then copies the validated files back atomically.

## CI And Automation

Project Truth CI remains read-only. It now fails when recorded evidence implies a safe reconciliation change is required and tells maintainers to run `./scripts/project-docs reconcile --apply`. A separate post-merge workflow runs on `main`, applies safe reconciliation on a dedicated branch, verifies `main` did not advance during the run, and opens or updates one bounded reconciliation PR. It requires `contents: write` and `pull-requests: write` only for the dedicated reconciliation branch; it does not bypass branch protection or push directly to `main`.

## Transitional Mechanisms

Historical commit-only delivery records are reconciled by default-branch commit reachability when they already declare implementation complete. This compatibility path should be removed once all delivered Project Truth slices record pull request evidence or an explicit direct-to-main delivery policy. Existing commit-only accepted history may remain as archival evidence and is not automatically assigned merge timestamps.

## Next Candidate

After this slice, the next Process Integrity candidate exposed by the reconciled frontier is `app_runtime_service_lifecycle_migration`, the follow-up migration of additional background service families behind deterministic runtime composition.
