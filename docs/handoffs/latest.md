# Latest Handoff

## Active Slice

- Slice: `blocker_approach_change_semantics`
- Branch: `session-blocker-approach-semantics`
- Worktree: `/Users/brianbusby/repos/.bmux-worktrees/session-blocker-approach-semantics`
- Base: `origin/main` containing merged milestone-inference PR #84, merge commit `cd59ec10b27500a4c0dc0954bd1da9f7fed44de8`
- PR: https://github.com/BrianBusby/bmux/pull/85
- Implementation commit: `2cc991cae7a7b6306a24e19811fe0d5edc0527c4`
- Status: implemented and open for review; do not merge automatically

## Current Generated Truth

- [Project status](../generated/project-status.md)
- [Nested roadmap](../generated/nested-roadmap.md)
- [Repository status](../generated/repository-status.md)

## What Changed

Provenance Engine now exposes bounded blocker and approach-change semantics
through the existing semantic inference record framework and `SessionWorkModel`
composition path. The rule-produced records are `coding_agent.blockers` and
`coding_agent.approach_changes`, and the public model schema now includes
session-level `blockers` and `approachChanges` semantic fields alongside
milestones and session phase.

The v1 producer consumes supported explicit marker statements from accepted
visible assistant output and visible reasoning summaries. It preserves source
evidence references, reported provider/source attribution, identity basis,
state basis, factual projection revision, producer version, confidence,
specificity, source-history state, ambiguity reasons, omission reasons, and
existing semantic supersession metadata.

## Semantics

Supported blocker statements use `Blocker:` or `Blocker resolved:` markers with
structured fields such as `activity`, `condition`, `description`, `outcome`,
and optional exact `milestone` id. Supported states are reported open, cleared,
bypassed, and no-longer-applicable. A command failure, warning, completed turn,
successful later command, clean worktree, or missing statement is not treated as
proof of a blocker or resolution.

Supported approach-change statements use `Approach change:` markers with
`objective`, `prior`, `state`, optional `replacement`, optional `reason`, and
optional exact `milestone` id. Supported states are reported replaced,
abandoned, deferred, and failed. Replacement requires an explicit replacement
approach. Reordered plans, routine retries, another command, and changed files
do not imply a strategy change.

Milestone relationships are attached only when the statement supplies an exact
same-session milestone id from the current milestone payload. Title matching,
foreign ids, duplicate titles, ordering, indentation-like prose, and
cross-session relationships are omitted with bounded reasons instead of being
guessed.

## Boundaries

This slice does not add cross-session semantic propagation, agent retrieval,
automatic context injection, coordination, notifications, Smart Session UI,
progress percentages, milestone hierarchy rewrites, milestone-to-code or
architecture relationships, GitHub ingestion, Knowledge Compiler behavior, raw
transcript persistence, hidden reasoning access, or a general failure taxonomy.

The inference remains above deterministic factual Current State. The tests
verify that semantic blockers and approach changes do not enter factual Current
State, Turn Outcome, or Session Outcome projections.

## Validation

Passed locally on 2026-08-30:

- `swiftc -parse-as-library -typecheck /Users/brianbusby/repos/.bmux-worktrees/session-blocker-approach-semantics/Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineContracts/*.swift`
- `swift test --package-path /Users/brianbusby/repos/.bmux-worktrees/session-blocker-approach-semantics/Packages/macOS/ProvenanceEngine --filter BlockerApproachChange` - 9 tests / 2 suites
- `swift test --package-path /Users/brianbusby/repos/.bmux-worktrees/session-blocker-approach-semantics/Packages/macOS/ProvenanceEngine --filter SemanticMilestoneMessageTests` - 2 tests / 1 suite
- `swift test --package-path /Users/brianbusby/repos/.bmux-worktrees/session-blocker-approach-semantics/Packages/macOS/ProvenanceEngine` - 228 tests / 33 suites
- `./scripts/project-docs validate`
- `./scripts/project-docs generate`
- `./scripts/project-docs check`
- `GITHUB_TOKEN=$(gh auth token) ./scripts/project-docs ci`
- `git diff --check`
- `python3 scripts/check-package-resolved-policy.py`
- `python3 scripts/check-workspace-package-groups.py --check`
- `scripts/lint-pbxproj-test-wiring.sh`

The Swift file-length budget check was run and remains blocked by pre-existing
repository-wide budget debt. After splitting the new parser and tests, no new
blocker/approach file appears in the failure list; the remaining failures are
existing over-budget files such as `CLI/BMUXCLI+Provenance.swift`,
`bmuxTests/WorkProvenanceObserverTests.swift`, and other unrelated files.

The new blocker/approach tests use synthetic sanitized accepted evidence only.
They cover assistant-output and reasoning-summary markers, abstention for
commands/warnings/reordered plans/unsupported prose, negated/hypothetical/quoted
and code-fenced contexts, independent blockers, reported bypass, recurrence,
partial source history retention, exact milestone links and rejected title or
foreign links, legacy SessionWorkModel decoding, public SDK reads, restart
durability, semantic message rendering, and factual-projection separation. No
real private session transcript validation is claimed.

No tagged app build or reload was run because this slice changes PE package
contracts, semantic producer logic, SQLite composition, tests, and documentation
only; no bmux app/runtime path changed.

## Known Limitations

The v1 language contract is intentionally narrow. Unsupported wording abstains
rather than trying to perform broad natural-language understanding. The producer
does not infer blockers from failed commands, approvals, idle state, final
assistant messages, or clean worktrees; does not infer approach changes from
ordinary retries or file edits; and does not prove correctness, validation,
merge, acceptance, or real resolution from provider claims.

When bounded reads omit earlier turns, PE preserves existing active blocker or
approach-change records instead of silently clearing them; consumers must inspect
semantic record source revisions and source-history/omission metadata for
freshness. Richer recurrence grouping, root-cause taxonomy, and cross-session
work-state propagation remain out of scope.

## Next Ready Work

The recommended next slice is `rich_cross_session_work_state_semantics` only
after milestone inference and blocker/approach semantics are delivered through
merged PRs and their validation evidence remains accepted. PR #85 is still open,
so downstream consumer gates should remain closed until that delivery decision
is made.
