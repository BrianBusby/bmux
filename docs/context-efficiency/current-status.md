# Bmux Context Efficiency: Current Status

Last updated: 2026-07-17

This file is the live handoff index for the context-efficiency roadmap. Read it before choosing work, and update it at the end of every context-efficiency slice.

## Read Order

1. `AGENTS.md`
2. `docs/context-efficiency/current-status.md`
3. `docs/context-efficiency/roadmap.md`
4. `docs/context-efficiency/milestones.md`
5. Relevant bmux skills:
   - `bmux-architecture` before Swift package/API changes.
   - `bmux-dev-workflow` before tagged builds or project wiring.
   - `bmux-testing` before test changes or verification decisions.
   - `bmux-localization` only if changing CLI, UI, docs, help, or other user-facing strings.

## Active Phase

Phase 2 is closed as of 2026-07-17. The completed scope is local, read-only telemetry ingestion and diagnostics.

Allowed work:

- Stream-parse Codex rollout JSONL defensively.
- Persist compact facts and source references in local SQLite.
- Preserve raw evidence by source path, byte offset, line number, and parser version.
- Improve import status, parser-error handling, and bounded diagnostic report shapes.
- Add behavior-level Swift package tests and CLI regression coverage for existing read-only diagnostics.

Do not start:

- Terminal command attribution beyond facts already present in rollout tool-call/tool-output rows.
- Lifecycle policy, warnings, handoff recommendations, or intervention logic.
- Output filtering or live Codex execution changes.
- UI changes.
- Automatic compression, omission, or mutation of agent context.

Phase 3 is the next phase and starts from command/output attribution. Do not add lifecycle policy, warnings, handoff recommendations, output filtering, UI, or automatic context mutation until the relevant later phase opens.

## Current Branch State

Expected branch:

- `context-efficiency-wip-20260715`

Latest completed implementation HEAD:

- `f90790b04e96c9ee6b775e484dc860fa4fd34f9c`

The current branch tip may include docs-only handoff maintenance commits. Run `git rev-parse HEAD` when an exact checkout hash is needed.

Latest completed implementation slice:

- `b194b8b1 Add missing timestamp rollout regression`
- `f90790b0 Report missing rollout timestamps`

Behavior in that slice:

- Rollout events that produce compact facts but have no usable timestamp now keep importing those facts with a nil event timestamp.
- The importer records a bounded parser diagnostic, `missing rollout event timestamp`, for missing-timestamp fact rows.
- Unknown scalar payload imports remain non-fatal and quiet, so they do not become parser errors solely because they lack timestamps.

Files changed in the latest slice:

- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Import/CodexRolloutTelemetryParser.swift`
- `Packages/macOS/BmuxContextEfficiency/Tests/BmuxContextEfficiencyTests/CodexRolloutTelemetryParserTests.swift`
- `Packages/macOS/BmuxContextEfficiency/Tests/BmuxContextEfficiencyTests/ContextEfficiencyStoreTests.swift`

Latest completed CLI verification slice:

- `tests/test_context_efficiency_cli.py` extends the context-efficiency CLI round-trip regression for missing rollout timestamps.
- Validated against the existing tagged `context-efficiency` build on 2026-07-17; no rebuild was run for this dogfood check.

Behavior in that verification slice:

- `bmux context-efficiency import --json` reports bounded missing-timestamp parser diagnostics while still importing compact token facts.
- `import --json --codex-home` exposes bounded Codex state metadata such as model, cwd, approval, sandbox, branch, and token totals.
- `inspect-thread --json` keeps the missing-timestamp model call timestampless, updates thread totals from compact facts, and does not leak raw rollout payload markers.
- `summarize-day --json` keeps dated model-call totals scoped to dated rows while reporting bounded parser diagnostic counts for the source.
- An unchanged rollout re-import reports zero new rows across import counts.
- An appended rollout re-import reports only the newly appended row and preserves prior model-call facts.
- Invalid UTF-8 rollout lines report one bounded parser diagnostic while valid surrounding rows continue importing.
- A shrunk rollout source reports `reset_cursor: true`, imports the replacement rows, and removes stale source facts from day summaries.

Latest validation: all validation commands passed on 2026-07-17.

## Phase 2 Closure Decisions

Stay narrow and read-only. Prefer package-level Swift tests unless a CLI regression is specifically exercising the built binary.

Decisions:

1. Markdown/CSV export formatting is deferred. JSON diagnostics are the Phase 2 read-only report contract.
2. `codex-token-audit` remains a legacy command for now. Replacement/removal is deferred to a cleanup slice after Phase 2 closure.
3. Phase 3 starts from command/output attribution, not more telemetry ingestion work.

Avoid broad CLI/app integration unless the slice is explicitly scoped to read-only diagnostics and includes localization work for any new command/help/error text.

## Verification For The Next Slice

After implementation or CLI behavior changes, run:

```bash
swift test --package-path /private/tmp/context-efficiency-wip-20260715/Packages/macOS/BmuxContextEfficiency
python3 scripts/check-workspace-package-groups.py --check
scripts/check-pbxproj.sh
git diff --check
./scripts/reload.sh --tag context-efficiency
```

Then run the context-efficiency CLI regression against the rebuilt tagged CLI if the slice touches CLI behavior or report output.

For docs/test-only status maintenance or dogfood of the already-built app, do not rebuild solely to inspect current behavior.

Current tagged app path pattern:

```text
/Users/brianbusby/Library/Developer/Xcode/DerivedData/bmux-context-efficiency/Build/Products/Debug/bmux DEV context-efficiency.app
```

Use the bundled CLI from that rebuilt app:

```text
/Users/brianbusby/Library/Developer/Xcode/DerivedData/bmux-context-efficiency/Build/Products/Debug/bmux DEV context-efficiency.app/Contents/Resources/bin/bmux
```

## Known Local Quirks

- The active WIP may be in a separate worktree outside `/Users/brianbusby/repos/bmux`. Confirm with `git branch --show-current` and the handoff context before editing.
- Worktree git metadata may live under `/Users/brianbusby/repos/bmux/.git/worktrees/`, outside some writable sandboxes.
- `git status --short` may be less useful in that setup. Prefer `git diff --name-status`, `git diff --stat`, `git branch --show-current`, and `git rev-parse HEAD`.
- `apply_patch` may default to `/Users/brianbusby/repos/bmux`. Use absolute paths when patching a `/private/tmp/...` worktree.
- `tests/test_context_efficiency_cli.py` has shown local-disk sensitivity. If needed, materialize the indexed test blob into a temporary file and run that copy against the rebuilt bundled CLI.

## Handoff Update Rules

At the end of every context-efficiency slice:

1. Update `Latest completed implementation HEAD` when the slice changes implementation behavior.
2. Record the completed commit or commits.
3. Summarize behavior changes in facts, not intentions.
4. List changed files.
5. Update phase status and next-phase entry points if priorities changed.
6. Update verification commands or known quirks if they changed.
7. State whether localization was needed.

Do not let one-off chat handoffs become the only record of current status.

## Localization

The latest completed slice changed package internals and package tests only. No CLI, UI, help, command, or user-facing app strings changed.

This file and the other `docs/context-efficiency/*` planning files are internal development documentation and are not mirrored into localized docs. If a future slice adds or edits CLI/UI/user-facing strings, use `bmux-localization` and update every supported locale.
