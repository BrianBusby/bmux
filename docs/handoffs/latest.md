# Latest Handoff

## Active Slice

- Slice: `cross_session_work_awareness_foundation`
- Branch: `cross-session-work-awareness-foundation`
- Worktree: `/Users/brianbusby/repos/.bmux-worktrees/cross-session-work-awareness-foundation`
- PR: https://github.com/BrianBusby/bmux/pull/80
- Status: implemented and open for review; do not merge automatically

## Current Generated Truth

- [Project status](../generated/project-status.md)
- [Nested roadmap](../generated/nested-roadmap.md)
- [Repository status](../generated/repository-status.md)

## What Changed

Provenance Engine now owns a read-only related-session awareness foundation.
`ProvenanceEngineClient.relatedSessions(...)` returns bounded related-session
briefs for a target PE session with deterministic typed reasons, compact Session
Outcome facts, exact Session Outcome and SessionWorkModel revision metadata,
freshness/source-watermark metadata, evidence/projection references, and
explicit completeness state.

Implemented relationship reasons:

- same repository
- same worktree
- same branch
- session-tree ancestor
- session-tree descendant
- session-tree sibling
- shared provider thread
- shared external identity
- shared changed artifact path inside shared repository/worktree context

Ordering is deterministic by strongest relationship reason, then freshness, then
stable PE session id. Result-limit and recent-time omissions are bounded by
`exclusionLimit` and explained with reason codes such as `result_limit` and
`outside_recent_boundary`.

## Boundaries

This slice is PE package contract/storage/docs work only. It does not add bmux
UI or CLI consumption, prompt/context injection, agent coordination, automatic
interruption, proactive notification, raw transcript retention, hidden reasoning
storage, LLM-authored cross-session summaries, artifact-collision warnings,
Knowledge Compiler integration, organization-scale storage, or new semantic
milestone/blocker/decision/risk/architecture inference.

Existing SessionWorkModel semantic fields may appear in related-session briefs,
but only with their original semantic provenance. They are not relationship
reasons.

## Validation

Passed on 2026-08-29:

- `swift test --package-path Packages/macOS/ProvenanceEngine --filter 'RelatedSessionProjectionTests|RelatedSessionProjectionRevisionTests|RelatedSessionMigrationTests|RelatedSessionContractTests'` - 15 tests / 4 suites
- `swift test --package-path Packages/macOS/ProvenanceEngine` - 186 tests / 23 suites
- `swift test --package-path Packages/macOS/ProvenanceEngine --filter 'SessionOutcomeProjectionTests|TurnOutcomeProjectionTests|SessionWorkModelFoundationTests|ProjectionRebuildValidationTests|ProvenanceEngineClientFactoryTests'` - 35 tests / 5 suites
- `./scripts/project-docs validate && ./scripts/project-docs generate && ./scripts/project-docs check`
- `GITHUB_TOKEN=$(gh auth token) ./scripts/project-docs ci`
- `python3 scripts/swift_file_length_budget.py --repo-root . --base-ref origin/main`
- `./scripts/lint-pbxproj-test-wiring.sh`
- `git diff --check`

No tagged app build or reload was run because no production bmux runtime/UI code
changed.

## Known Limitations

Provider-thread and external-identity reasons appear only when accepted current
state preserves shareable identity records for both sessions.

Shared changed artifact is only a factual same-path relationship inside shared
repository/worktree context. It is not rename tracking, diff-hunk identity,
component inference, or collision analysis.

`project-docs ci` should be run with `GITHUB_TOKEN=$(gh auth token)` in this
local environment; without an explicit token it hit GitHub rate-limit responses.

## Next Ready Work

Generated Project Truth now lists `cross_session_artifact_collision_awareness`
as the ready but unselected next cross-session slice. Rich cross-session
work-state semantics remain gated on validated milestone and
blocker/approach-change semantics.
