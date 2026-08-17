# Latest Handoff

## Active Slice

- Slice: `monorepo_repository_consolidation`
- Branch: `monorepo-provenance-engine`
- Worktree: `/Users/brianbusby/repos/bmux-monorepo-provenance-engine`
- Status: active draft migration branch

## Current State

bmux is the canonical monorepo. Provenance Engine has been imported with history
under `Packages/macOS/ProvenanceEngine` and remains an independent SwiftPM
package boundary. Root Project Truth now lives under `project/`; generated status
lives under `docs/generated/`; architecture entrypoints begin at
`docs/architecture/README.md`.

The old `project/shared-project-source.yaml`, peer checkout CI, and per-feature
PE revision pinning are obsolete for normal development. Cross-component slices
should use one monorepo branch/worktree/PR while preserving PE package
boundaries.

## Read Next

1. `AGENTS.md`
2. `docs/README.md`
3. `docs/generated/project-status.md`
4. `docs/generated/nested-roadmap.md`
5. `docs/generated/repository-status.md`
6. `docs/architecture/README.md`
7. `docs/planning/monorepo-migration-ledger.md`

## Verification Commands

```bash
./scripts/project-docs validate
./scripts/project-docs generate
./scripts/project-docs check
./scripts/project-docs ci
python3 tools/project-docs/tests/test_project_docs.py
python3 scripts/check-workspace-package-groups.py --check
python3 scripts/check-package-resolved-policy.py
cd Packages/macOS/ProvenanceEngine && swift test
```

Run bmux focused build/tests after package resolution is stable and before
handoff or PR publication.

## Pending Product Branches

See `docs/planning/monorepo-migration-ledger.md`. The factual agent Session view
branch/PR is the most important product branch to rebase or supersede after the
migration lands.
