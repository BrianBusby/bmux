# Provenance Engine Handoff

## Project Truth CI and Read-Only Drift Verification

Project Truth read-only CI validation is the current completed infrastructure
slice for the bmux and Provenance Engine integration effort.

- Shared cross-repository facts live in `project/project-state.yaml` in this
  repository.
- Provenance Engine local facts live in `project/repo-status.yaml`.
- Generated current-status pages live under `docs/generated/`, starting with
  [`docs/generated/project-status.md`](../generated/project-status.md).
- Generated files must not be edited manually.
- The continuing project state remains the Engineering Observation Period;
  do not select a new product implementation slice from this handoff alone.

## Commands

```bash
./scripts/project-docs validate
./scripts/project-docs generate
./scripts/project-docs check
./scripts/project-docs ci
```

bmux consumes this repository's shared manifest through its
`project/shared-project-source.yaml` pointer and can override the path locally
with `PROJECT_TRUTH_SHARED_STATE=/path/to/project-state.yaml`.

For cross-repository local validation with sibling checkouts:

```bash
./scripts/project-docs ci --peer-repo-root ../bmux
```

`ci` is deterministic and read-only. It checks schema validity, generated-doc
freshness, named cross-repository invariants, bmux shared-source semantics when
run from bmux, bounded authored-doc drift, and GitHub evidence for referenced
repositories, commits, pull requests, issues, tags, and releases. It uses
`GITHUB_TOKEN` or `GH_TOKEN` when available. Network, auth, rate-limit, missing
resource, and contradictory-evidence failures are reported separately.

## Next Recommended Slice

Keep the read-only checks under observation as required branch-protection
candidates. A newly documented candidate is the bmux Workspace Display Current
State Projection planning and diagnostics slice: specify how workspace title,
branch, and PR metadata flow from bmux observations through durable PE evidence
into deterministic Current State, and how bmux verifies tab/sidebar/custom
sidebar display latency and stale-state correctness.

Do not mark that slice active, build GitHub App synchronization, automatic
manifest edits, provenance-backed project-state events, telemetry checkpoint
automation, or broad bmux UI migration until the observation gate produces a
specific follow-up decision.
