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
