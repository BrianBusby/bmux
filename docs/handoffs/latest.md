# Latest Handoff

## Completed and Merged Slice

- Slice: `agent_accessible_cross_session_retrieval`
- Branch: `agent-accessible-cross-session-retrieval`
- Worktree: `/Users/brianbusby/repos/.bmux-worktrees/agent-accessible-cross-session-retrieval`
- Base: `origin/main` at `e90cbf54e7bcc75c9103c664143f03baabd20cb0`
- PR: https://github.com/BrianBusby/bmux/pull/88
- Tagged build: `agent-accessible-cross-session-retrieval`, local build number 509
- Merge: `5db53927906a83677e1bebbc2f04680af10b5055`
- Status: merged and accepted in Project Truth after resolved review findings and recorded validation

## Current Generated Truth

- [Project status](../generated/project-status.md)
- [Nested roadmap](../generated/nested-roadmap.md)
- [Repository status](../generated/repository-status.md)

## What Changed

The bmux provenance CLI now exposes two explicit, bounded agent-facing reads:

```bash
bmux provenance sessions related <pe-session-id> [options] [--json]
bmux provenance sessions collisions <pe-session-id> [options] [--json]
```

`sessions related` calls the public PE
`ProvenanceEngineClient.relatedSessions(...)` contract. `sessions collisions`
calls `ProvenanceEngineClient.artifactCollisions(...)`. Both commands support
explicit `--database`, bounded `--limit` and `--exclusion-limit`, recent-time
filters, exact `--revision`, localized text output, and stable JSON output.
Collision reads also support `--artifact-path`, `--related-session-limit`, and
`--stale-before`.

The existing `sessions tree`, `turn outcome`, `session outcome`, context,
worktree, import, trace, and diagnostic commands are preserved.

## Retrieval Semantics

The commands require an explicit PE session id. They do not infer the caller
from focused windows, provider thread ids, workspace ids, or the first available
session. They can run without a live app socket when the selected PE database
exists, and a missing database is reported as a distinct no-database result.

Text output keeps the result compact while retaining target/source ids,
relationship reasons, repository/worktree/branch/HEAD boundaries, outcome
revision ids, work-model revision ids, semantic field state, semantic record
identity, producer/version, confidence, factual support, evidence-reference
counts, freshness, completeness, and omissions. JSON preserves the public
contract payload shape using existing snake-case and epoch timestamp
conventions.

The collision command preserves the PE limitation: candidates start from the
target session's recorded changed artifacts, and `--artifact-path` only narrows
those overlap candidates. An empty result is not arbitrary file-history search
and does not prove nobody else has worked on the path. Same relative paths in
different repositories are not collisions.

Retrieved blockers, approach replacements, validations, milestones, and prose
remain historical evidence. They are not current instructions, verified
failures, proof of success, merge state, acceptance, or coordination policy.

## Demo

`ProvenanceRetrievalDemoSeed` seeds an isolated PE SQLite database through the
public SDK with two sessions:

- Session A records a plan milestone, an explicit reported blocker, an approach
  replacement, validation/file evidence, and a change to `Sources/Shared.swift`.
- Session B records a separate PE identity and a change to the same
  repository-relative path from a different worktree/branch/HEAD.

The tagged app bundle CLI was then run with an explicit `--database` and a
forced nonexistent socket. Observed output sizes were 3,844 bytes for related
text, 79,859 bytes for related JSON with `--limit 1`, 1,175 bytes for collision
text, and 5,548 bytes for untouched-path collision JSON. Observed timings were
`real 4.70s` for related text and `real 0.05s` for collision text.

The untouched-path collision query returned a valid empty result for
`Sources/Untouched.swift`, demonstrating that the target-artifact limitation is
visible instead of being advertised as generic file-history search.

Full reproduction details and sanitized excerpts live in
[agent-accessible-cross-session-retrieval-demo.md](../context-efficiency/agent-accessible-cross-session-retrieval-demo.md).

## Validation

Passed locally on 2026-08-31:

- `BMUX_SKIP_ZIG_BUILD=1 xcodebuild test -project bmux.xcodeproj -scheme bmux-unit -configuration Debug -destination 'platform=macOS' -derivedDataPath /Users/brianbusby/Library/Developer/Xcode/DerivedData/bmux-agent-accessible-cross-session-retrieval-tests -only-testing:bmuxTests/CLIProvenanceSessionOutcomeCommandTests`
- `swift test --package-path Packages/macOS/ProvenanceEngine`
- `BMUX_CLI_BIN=/Users/brianbusby/Library/Developer/Xcode/DerivedData/bmux-agent-accessible-cross-session-retrieval-tests/Build/Products/Debug/bmux python3 tests/test_cli_contract_help.py`
- `xcrun xcstringstool compile --output-directory /tmp/bmux-retrieval-xcstrings-check Resources/Localizable.xcstrings`
- `./scripts/reload.sh --tag agent-accessible-cross-session-retrieval`
- Tagged app bundle CLI dogfood against `/tmp/bmux-provenance-retrieval-demo.kFEzkQ/provenance.sqlite`
- `./scripts/lint-pbxproj-test-wiring.sh`
- `python3 scripts/check-package-resolved-policy.py`
- `python3 scripts/check-workspace-package-groups.py --check`
- `python3 scripts/swift_file_length_budget.py --repo-root . --base-ref origin/main`

`./scripts/project-docs validate`, `./scripts/project-docs generate`,
`./scripts/project-docs check`, authenticated `./scripts/project-docs ci`, and
`git diff --check` passed during the final guard pass.

Localization audit: new bmux provenance CLI help, argument errors, and text
presentation strings were added to `Resources/Localizable.xcstrings` with
English and Japanese values. The Xcode string catalog compiler accepted the
catalog. Machine JSON field names and enum values remain locale-independent.

## Known Limitations

This slice does not add automatic prompt/context injection, proactive UI,
alerts, locks, reassignment, agent messaging, coordination policy, arbitrary
pre-edit file-history search, broader natural-language inference,
cross-session milestone unification, semantic conflict detection, embeddings,
graph storage, Knowledge Compiler integration, shared/team databases, or
remote/mobile retrieval.

Automatic caller resolution remains out of scope for v1. Agents must supply the
PE session id and database explicitly or discover them through existing public
context/session reads.

## Current Slice

`proactive_bmux_cross_session_awareness` is implemented on branch
`proactive-cross-session-awareness`. The existing React Smart Session refresh
now performs bounded PE reads for at most five related sessions and five
possible artifact collisions, then presents relationship reasons,
lifecycle/freshness state, normalized paths, and collision state in a separate
Related work section. Failed awareness reads degrade to unavailable without
hiding the existing Smart Session snapshot.

This slice does not inject prompt context, send notifications outside the
Session surface, lock or block files, interrupt or reassign agents, share raw
transcripts, or introduce coordination policy. Project Truth records the slice
as implemented with delivery open until its PR merges.

## Next Candidate

After proactive presentation is reviewed, merged, and observed with real
sessions, reassess `cross_session_context_assembly_experiment`. It remains
planned and gated; this handoff does not authorize automatic prompt injection.
