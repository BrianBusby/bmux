# Latest Handoff

## Active Slice

- Slice: `milestone_inference`
- Branch: `session-milestone-inference`
- Worktree: `/Users/brianbusby/repos/.bmux-worktrees/session-milestone-inference`
- PR: https://github.com/BrianBusby/bmux/pull/84
- Implementation commit: `baa432af4141126f47abf65c6cc66c713b24bf8d`
- Status: implemented and open for review; do not merge automatically

## Current Generated Truth

- [Project status](../generated/project-status.md)
- [Nested roadmap](../generated/nested-roadmap.md)
- [Repository status](../generated/repository-status.md)

## What Changed

Provenance Engine now exposes conservative coding-agent milestone semantics
through the existing semantic inference record framework and `SessionWorkModel`
composition path. The built-in rule materializes plan-derived milestones from
accepted structured plan-update evidence, falls back to one prompt-scoped active
milestone only when no usable plan exists, and publishes unknown milestone
claims rather than inventing work when evidence is insufficient.

Milestones now carry session-scoped identity basis, reported state basis,
source evidence references, optional description, supported parent id,
ambiguity reasons, omission reasons, producer version, confidence, specificity,
supporting factual revision, and existing semantic supersession metadata.
Provider-reported completion remains distinct from validation, correctness,
merge, or acceptance.

## Boundaries

This slice does not add blocker, failed-approach, approach-change, progress,
validation, milestone-to-code, milestone-to-architecture, GitHub/PR, Knowledge
Compiler, Smart Session UI, agent retrieval, context injection, notifications,
or cross-session milestone merging behavior.

The built-in plan rule emits a flat milestone collection because current plan
step evidence has no parent field. Supported hierarchy can pass through the
payload contract only when parent ids are acyclic, resolvable, and scoped to the
same payload; unsupported relationships are omitted with bounded reasons.

## Validation

Passed locally on 2026-08-29:

- Focused PE filters: milestone inference plus SDK SessionWorkModel - 15 tests / 2 suites
- Full PE package suite - 217 tests / 31 suites
- `./scripts/project-docs validate`
- `./scripts/project-docs generate`
- `./scripts/project-docs check`
- `GITHUB_TOKEN=$(gh auth token) ./scripts/project-docs ci`
- `python3 scripts/swift_file_length_budget.py --repo-root . --base-ref origin/main`
- `git diff --check`
- `./scripts/lint-pbxproj-test-wiring.sh`
- `python3 scripts/check-package-resolved-policy.py`

The exact commands were:

```bash
swift test --package-path /Users/brianbusby/repos/.bmux-worktrees/session-milestone-inference/Packages/macOS/ProvenanceEngine --filter MilestoneInferenceTests --filter ProvenanceEngineSessionWorkModelClientFactoryTests
swift test --package-path /Users/brianbusby/repos/.bmux-worktrees/session-milestone-inference/Packages/macOS/ProvenanceEngine
```

The new milestone tests use synthetic accepted evidence only. They cover
multi-step plans, provider-reported completion, provider step id continuity
through reorder/insertion, missing step ids, repeated titles, unsupported
provider statuses, successful commands and completed turns not proving
completion, unsupported hierarchy markers, supported hierarchy payloads,
missing/cyclic/duplicate parent relationships, bounded output, legacy payload
decoding, SDK reads, restart durability, and idempotent materialization.

No tagged app build or reload was run because this slice changes PE package
contracts, semantic producer logic, tests, and documentation only.

## Known Limitations

Milestone identity is session-scoped. Provider plan step ids are the strongest
continuity anchor; text-derived identities are explicitly marked with their
weaker basis and omission reasons. Repeated text without stable ids remains
ambiguous. The implementation does not validate real private session corpora and
does not infer hierarchy from ordering, indentation, adjacent turns, shared
files, or presentation wording.

## Next Ready Work

The recommended next slice is blocker and approach-change semantics. Richer
cross-session semantics, Smart Session consumers, retrieval, and
milestone-to-code/architecture relationships should remain gated until their
own prerequisites are implemented and validated.
