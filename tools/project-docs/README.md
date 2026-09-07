# Project Docs Tool

This is the canonical implementation for Project Truth manifest validation and
generated documentation.

## Setup

Install the pinned tool dependencies into a repository-local virtual
environment:

```bash
python3 -m venv .venv-project-docs
.venv-project-docs/bin/python -m pip install -r tools/project-docs/requirements.txt
```

The repository wrappers use `.venv-project-docs/bin/python` when it exists;
otherwise they use `python3` and fail clearly if dependencies are missing.

## Commands

```bash
./scripts/project-docs validate
./scripts/project-docs generate
./scripts/project-docs check
./scripts/project-docs next
./scripts/project-docs reconcile --check
./scripts/project-docs reconcile --apply
./scripts/project-docs ci
```

`validate` checks JSON Schemas plus semantic invariants that schemas cannot
express cleanly. `generate` validates first, then rewrites only files under
`docs/generated/`. `check` renders into a temporary directory and compares the
result with committed generated files without modifying the working tree.
`next` is read-only and prints the primary capability frontier, active
implementation slices, selected-next work, dependency-ready candidates, and
gated downstream work with blockers.

`reconcile --check` is read-only. It compares Project Truth delivery and active
work metadata with GitHub evidence, reports the exact safe changes that apply
mode would make, reports unresolved human decisions separately, and exits
nonzero when reconciliation is required. GitHub authentication, rate-limit,
network, missing-evidence, and contradictory-state failures remain distinct.

`reconcile --apply` applies only mechanically justified changes: merged/open PR
state, merge commit and merged timestamp evidence, default-branch reachability
for completed commit-only delivery, stale active-work clearing, and readiness
advancement when declared dependencies and gates are satisfied. It does not set
acceptance evidence, close caveats, supersede abandoned work, or select next
priority. Apply mode validates and regenerates documentation in a temporary repo
copy before writing the canonical manifests and generated files back.

`ci` is the non-interactive, read-only gate for GitHub Actions. It validates
schemas, named invariants, generated-document freshness, bounded authored-doc
drift, and read-only GitHub evidence. It exits nonzero for schema, generation,
invariant, GitHub, and authored-doc failures and prefixes each error with a
stable category such as `[schema:...]`, `[generation:...]`, `[invariant:...]`,
`[github:...]`, or `[authored-doc:...]`.

GitHub evidence verification uses `GITHUB_TOKEN` or `GH_TOKEN` when present and
falls back to unauthenticated public API reads. Missing evidence, contradictory
GitHub state, authentication failures, rate limits, and network failures are
reported distinctly. `--skip-github` is reserved for offline diagnosis and unit
tests, not CI.

The CI command includes a read-only reconciliation guard for already recorded
evidence. It fails when a PR would leave a merged delivery recorded as open,
missing merge metadata that can be filled safely, completed delivery still active,
or generated frontier output stale relative to canonical manifests. Pre-merge PRs
are not required to know their future merge commit or merged timestamp.

The bmux wrapper resolves this canonical tool from the monorepo root at
`tools/project-docs`. `PROJECT_TRUTH_TOOL_ROOT` remains available for local tool
development and may point either to a repository root containing
`tools/project-docs` or directly to a `tools/project-docs` directory.
