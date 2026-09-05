# Project Truth

This directory contains the canonical Project Truth graph for the bmux
monorepo.

## Canonical State

`project/project-state.yaml` is the source of truth for project, program,
phase, milestone, slice, ownership, policy, caveat, dependency, selected-next,
active-work, and evidence state across the bmux product and the Provenance
Engine component.

`project/repo-status.yaml` records monorepo-local execution state, release
state, and component capability state. It is not a separate bmux-only copy of
shared state.

The old `project/shared-project-source.yaml` pointer is obsolete. Project Truth
validation fails if a shared-state pointer is reintroduced.

## Commands

```bash
./scripts/project-docs validate
./scripts/project-docs generate
./scripts/project-docs check
./scripts/project-docs reconcile --check
./scripts/project-docs reconcile --apply
./scripts/project-docs ci
```

Generated files live under `docs/generated/` and must not be edited manually.
The authoritative generated status starts at
[`docs/generated/project-status.md`](../docs/generated/project-status.md).

`ci` is deterministic and read-only. It validates schemas, generated-document
freshness, named invariants, bounded authored-document drift, and GitHub
evidence for referenced repositories, commits, pull requests, issues, tags, and
releases. It uses `GITHUB_TOKEN` or `GH_TOKEN` when available. Missing evidence,
contradictory GitHub state, authentication failures, rate limits, and network
failures fail with separate categories.

This validation does not write manifests, edit documentation automatically,
synchronize through a GitHub App, or persist GitHub responses as project state.

## Delivery Lifecycle

Project Truth delivery state follows this lifecycle:

```text
planned
-> selected/current
-> implementation active
-> implementation complete
-> delivery merged
-> observation/acceptance
-> active assignment cleared
-> frontier recalculated
```

The canonical reconciliation owner is `tools/project-docs`. It derives only
mechanical facts from GitHub: PR existence/state, merge commit, merged timestamp,
active branch to PR identity when exactly one PR matches, recorded commit
reachability from the repository default branch, stale active assignments, and
readiness changes under declared dependency policy. It does not accept work,
close caveats, supersede abandoned work, or select the next priority.

Run `./scripts/project-docs reconcile --check` to inspect stale delivery state
without writing files. It exits nonzero when safe changes or explicit planning
decisions remain, and reports GitHub authentication, rate-limit, network,
missing-evidence, and contradictory-state failures separately.

Run `./scripts/project-docs reconcile --apply` after reviewing check output. It
updates only `project/project-state.yaml` and `project/repo-status.yaml`, records
verified merge evidence, clears completed active-work metadata when safe,
advances newly ready candidates, regenerates generated docs through the existing
generator, and validates the result in a temporary copy before writing back. A
second apply against unchanged GitHub state should produce no diff.

Post-merge automation may open or update a single bounded reconciliation PR from
these safe changes. If automation fails, maintainers recover by running check and
apply locally, reviewing the generated diff, and opening the reconciliation PR
manually. Closed-unmerged, superseded, replaced, abandoned, or still-observed
work remains explicit Project Truth planning state.
