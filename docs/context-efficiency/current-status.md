# Bmux Context Efficiency: Current Status

Last updated: 2026-07-24

This file is the live handoff index for context-efficiency, provenance, and
handoff work. Keep it concise; move slice history and detailed findings into
topic documents.

## Read Order

1. `AGENTS.md`
2. `docs/roadmap.md`
3. `docs/provenance-integration.md`
4. `docs/context-efficiency/current-status.md`
5. `docs/context-efficiency/roadmap.md`
6. `docs/context-efficiency/milestones.md`
7. `docs/context-efficiency/adr-001-provenance-engine-extraction.md`
8. `docs/context-efficiency/provenance-engine-phase3-plan.md`
9. `docs/context-efficiency/provenance-engine-phase4-reconnect-plan.md`
10. `docs/context-efficiency/integration/provenance-engine-adoption.md`
11. Relevant bmux skills for Swift/package/build/test/localization work.

## Active State

The standalone Provenance Engine is the accepted provenance storage/query
boundary. Slice C session-tree read migration and Slice D file-explanation read
migration are accepted. Both bmux PRs used explicit GitHub Actions waivers
because the Blacksmith-backed workflows did not produce usable CI evidence; the
infrastructure issue remains tracked separately in bmux issue 8.

bmux consumer adoption merged through PR 7
(`https://github.com/BrianBusby/bmux/pull/7`) using the normal GitHub merge
method at merge commit `08763dd0d3256989180dcc04f426da1f24369175` on
2026-07-24T17:20:04Z. The final PR head was
`322629bf0fa0bd19367f090bdfcf1bc21c6a1e95`.

Provenance Engine PR 5 (`https://github.com/BrianBusby/provenance-engine/pull/5`)
merged on 2026-07-24T20:38:37Z at merge commit
`126afde36671f53a137953200e7883e6b4093ac3`. bmux now pins that merged engine
revision from `git@github.com:BrianBusby/provenance-engine.git`; the temporary
Slice D readiness pin `384026e36087dda576e25343907c3e06d8a4d594` was removed
from the Xcode project, workspace lockfile, fixture packages, fixture lockfiles,
and dynamic CLI test seeder fallback.

bmux now consumes provenance-engine as an external Swift package. The Xcode
project links the public products `ProvenanceEngineContracts` and
`ProvenanceEngineSDK`.

The first external query path is complete: `bmux provenance worktrees list`
constructs an in-process SQLite-backed engine client through
`ProvenanceEngineClientFactory().sqliteClient(databaseURL:)` and calls
`ProvenanceEngineClient.worktrees(ProvenanceWorktreeListRequest())`.

The second external query path is complete in bmux: `bmux provenance sessions
tree <session-id>` constructs an in-process SQLite-backed engine client through
`ProvenanceEngineClientFactory().sqliteClient(databaseURL:)` and calls
`ProvenanceEngineClient.sessionTree(ProvenanceSessionTreeRequest(...))`.

The third external query path is accepted: `bmux provenance explain <path>`
still resolves Git paths and renders output in bmux, then resolves the engine
worktree through
`ProvenanceEngineClient.worktrees(ProvenanceWorktreeListRequest())` and calls
`ProvenanceEngineClient.fileExplanation(ProvenanceFileExplanationRequest(...))`.

CLI presentation and compatibility remain owned by bmux. The worktree-list JSON
shape, text shape, missing-database behavior, empty-database behavior,
newest-first ordering, and the 25-row text cap were preserved.

The project is now in controlled incremental migration from bmux-local
provenance storage/query code to the external engine. This is a transitional
state, not a target architecture.

## Current Boundary

Externalized work includes the worktree-list read path, the session-tree read path, the accepted Slice D file-explanation read path, engine package pin, public SDK client construction for those paths, and migrated test seeding through public engine APIs.

Slice B clarified the legacy boundary: the bmux-local contract-shaped seam is now `BmuxLegacyProvenanceClient`, while the external `ProvenanceEngineContracts.ProvenanceEngineClient` remains untouched. The complete remaining consumer inventory lives in `docs/context-efficiency/integration/provenance-engine-adoption.md`.

Still bmux-local: legacy SQLite schema ownership, event/projection storage used by unmigrated paths, current-context reads, lifecycle/capture recording, observability tracing, presentation, command parsing, fallback messages, and output formatting.

Do not add engine features speculatively. Engine expansion is frozen until a real bmux migration slice proves a concrete missing contract or correctness defect.

## Next Target

Active milestone: none selected after Slice D acceptance.

Slice D migrated only `bmux provenance explain <path>` to the external SQLite-backed engine client and `ProvenanceEngineClient.fileExplanation(...)`; preserved existing CLI compatibility; seeded the file-explanation fixture through public engine APIs; removed only file-explanation legacy code that became unused; and merged through bmux PR 9 (`https://github.com/BrianBusby/bmux/pull/9`) at merge commit `c1c5fce0eb7526d321dbed6c8a6f25f0d9aaf374` on 2026-07-24T21:54:46Z.

The next migration slice is now safe to select, but no next slice is active in this handoff. Do not begin current-context migration, lifecycle writes, capture migration, data migration, semantic retrieval, daemon transport, UI work, observability expansion, or unrelated refactoring until a new slice is explicitly chosen.

## Canonical Details

bmux product roadmap: `docs/roadmap.md`.

bmux-local provenance integration notes: `docs/provenance-integration.md`.

Canonical shared integration roadmap: `https://github.com/BrianBusby/provenance-engine/blob/main/docs/bmux-integration-roadmap.md`.

Migration state and plan: `docs/context-efficiency/integration/provenance-engine-adoption.md`.

Slice history: `docs/context-efficiency/integration/provenance-engine-adoption-history.md`.

Findings template: `docs/context-efficiency/integration/provenance-engine-integration-findings-template.md`.

Durable roadmap: `docs/context-efficiency/roadmap.md`.

Phase 4 migration plan: `docs/context-efficiency/provenance-engine-phase4-reconnect-plan.md`.

## Validation Notes

Slice C acceptance validation completed on 2026-07-24:

- `./scripts/reload.sh --tag slice-c-main`: passed and built the tagged Debug app plus bundled CLI.
- `BMUX_BUNDLED_CLI_PATH=... python3 tests/test_provenance_cli.py`: passed against the tagged bundled CLI.
- `xcodebuild -project bmux.xcodeproj -scheme bmux-unit -configuration Debug -destination 'platform=macOS' -derivedDataPath /Users/brianbusby/Library/Developer/Xcode/DerivedData/bmux-slice-c-main BMUX_SKIP_ZIG_BUILD=1 -only-testing:bmuxTests/WorkProvenanceStoreTests -only-testing:bmuxTests/SubsessionProvenanceTests test`: passed 31 tests.
- `scripts/check-pbxproj.sh`: passed.
- `python3 scripts/check-package-resolved-policy.py`: passed.
- `python3 scripts/check-workspace-package-groups.py --check`: passed.
- `git diff --check`: passed.
- Scans confirmed no `ProvenanceEngineSQLite` import and no direct session-tree table reads in the migrated CLI path.
- GitHub Actions waiver: bmux PR 7 Actions did not complete because PR-event
  runs for CI and Activation performance remained pending with zero jobs/check
  runs, while manually dispatched runs queued without runner assignment on
  `blacksmith-4vcpu-ubuntu-2404`. No failing CI result was observed, `main`
  had no required status-check branch protection, and acceptance relied on the
  local validation suite above. This waiver applies only to Slice C and does
  not permanently remove CI expectations; runner or workflow scheduling should
  be tracked separately as repository infrastructure work in
  `https://github.com/BrianBusby/bmux/issues/8`.

Slice D acceptance validation completed locally on 2026-07-24 against provenance-engine revision `126afde36671f53a137953200e7883e6b4093ac3`:

- File-explanation fixture `swift package resolve`: passed.
- Session-tree fixture `swift package resolve`: passed.
- `xcodebuild -resolvePackageDependencies -project bmux.xcodeproj -scheme bmux -derivedDataPath /Users/brianbusby/Library/Developer/Xcode/DerivedData/bmux-slice-d-acceptance`: passed.
- `./scripts/reload.sh --tag slice-d-acceptance`: passed and built the tagged Debug app plus bundled CLI.
- `BMUX_BUNDLED_CLI_PATH=... python3 tests/test_provenance_cli.py`: passed against the tagged bundled CLI.
- Targeted `xcodebuild ... -only-testing:bmuxTests/WorkProvenanceStoreTests -only-testing:bmuxTests/WorkProvenanceObserverTests test`: passed 17 tests.
- `scripts/check-pbxproj.sh`: passed.
- `python3 scripts/check-package-resolved-policy.py`: passed.
- `python3 scripts/check-workspace-package-groups.py --check`: passed.
- `git diff --check`: passed.
- Scans confirmed no old engine feature commit in dependency files, no `ProvenanceEngineSQLite` imports in CLI/Sources/Packages/tests/bmuxTests, and no direct file-explanation table reads in the migrated CLI path.
- GitHub Actions waiver: bmux PR 9 final head `ea72bfd7dc28cd60b093b5a4d0bebc5853c32f59` created PR-event CI run `30129193072` and Activation performance run `30129193044`, both pending with zero jobs materialized at final inspection. Earlier PR-head runs materialized queued jobs without runner assignment on `blacksmith-4vcpu-ubuntu-2404`: CI run `30123744339` jobs `89582203845` and `89582203944`, and Activation performance run `30123744296` job `89582203380`. No failing CI result or logs existed, `main` had no required status-check branch protection, and acceptance relied on the local validation suite above. This waiver applies only to Slice D; runner scheduling remains tracked in `https://github.com/BrianBusby/bmux/issues/8`.
