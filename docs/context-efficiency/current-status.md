# Bmux Context Efficiency: Current Status

Last updated: 2026-07-18

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

Phase 3 is active. Phase 2 closed on 2026-07-17 with local, read-only telemetry ingestion and diagnostics.

Allowed work:

- Derive command execution candidates from existing Codex rollout tool-call/tool-output facts.
- Classify bounded command summaries into deterministic command categories.
- Attribute tool calls to tool outputs using exact Codex call IDs when present.
- Attribute command outputs to subsequent model calls as temporal candidates.
- Preserve raw evidence by source path, byte offset, line number, parser version, and bounded output-reference counts.
- Keep reports bounded and clearly distinguish exact links from temporal candidates.

Do not start:

- Live terminal/PTTY command interception unless explicitly scoped and tested as a Phase 3 capture slice.
- Lifecycle policy, warnings, handoff recommendations, or intervention logic.
- Output filtering or live Codex execution changes.
- UI changes.
- Automatic compression, omission, or mutation of agent context.

Do not add lifecycle policy, warnings, handoff recommendations, output filtering, UI, or automatic context mutation until the relevant later phase opens.

## Current Branch State

Expected branch:

- `context-efficiency-wip-20260715`

Latest completed implementation HEAD:

- `6279c8abdaf2a1d461e86f10a41e1c145229b3d1`

The current branch tip may include docs-only handoff maintenance commits. Run `git rev-parse HEAD` when an exact checkout hash is needed.

Latest completed implementation slice:

- `6279c8abd Add context efficiency repeated command facts`

Behavior in that slice:

- Thread inspection reports include `repeatedCommandFacts` derived from existing command execution candidates.
- `inspect-thread --json` emits top-level `repeated_command_facts` rows.
- Repeated facts distinguish exact repeated commands, repeated source-search commands, and repeated file-reading commands.
- Repeated facts expose only bounded summaries and stable references: kind, category, normalized executable, representative bounded command summary, normalized command fingerprint, occurrence count, capped sample command execution IDs, and first/last source references.
- No schema migration was added; repeated facts are derived report facts, not persisted rows.
- No lifecycle policy, scoring, warnings, or intervention logic was added.

Files changed in the latest implementation slice:

- `CLI/BMUXCLI+ContextEfficiency.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Model/ContextEfficiencyCommandRepetitionKind.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Model/ContextEfficiencyRepeatedCommandFact.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Reports/ContextEfficiencyRepeatedCommandDetector.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Reports/ContextEfficiencyThreadInspection.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Store/ContextEfficiencyStore.swift`
- `Packages/macOS/BmuxContextEfficiency/Tests/BmuxContextEfficiencyTests/ContextEfficiencyStoreTests.swift`
- `tests/test_context_efficiency_cli.py`

Previous completed implementation slice:

- `e6461738d Add context efficiency command category counts`

Behavior in the previous completed slice:

- Thread inspection reports include count-only `commandCategoryCounts` derived from existing command execution candidates.
- Day summary reports include count-only `commandCategoryCounts` scoped by dated `tool_calls.timestamp` rows in the requested UTC day.
- `inspect-thread --json` emits top-level `command_category_counts`, and `summarize-day --json` emits `summary.command_category_counts`.
- Aggregate rows expose only category and command count. They do not include command summaries, normalized executables, source references, raw output references, arguments, lifecycle labels, or efficiency inferences.
- No schema migration was added; command category counts are derived report facts, not persisted rows.

Files changed in the previous completed slice:

- `CLI/BMUXCLI+ContextEfficiency.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Reports/ContextEfficiencyCommandCategoryCount.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Reports/ContextEfficiencyCommandCategoryCounter.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Reports/ContextEfficiencyDaySummary.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Reports/ContextEfficiencyThreadInspection.swift`
- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Store/ContextEfficiencyStore.swift`
- `Packages/macOS/BmuxContextEfficiency/Tests/BmuxContextEfficiencyTests/ContextEfficiencyStoreTests.swift`
- `tests/test_context_efficiency_cli.py`

Latest completed CLI verification:

- `tests/test_context_efficiency_cli.py` covers the context-efficiency CLI round trip for missing rollout timestamps, bounded parser diagnostics, incremental imports, cursor resets, invalid UTF-8, derived command execution JSON, and work-item reference JSON.
- Validated on 2026-07-18 against the isolated compiled CLI at `/tmp/bmux-context-efficiency-cli-check/Build/Products/Debug/bmux`; the tagged `context-efficiency` app was not reloaded because the user was actively using a build.

Behavior in that verification slice:

- `bmux context-efficiency import --json` reports bounded missing-timestamp parser diagnostics while still importing compact token facts.
- `import --json --codex-home` exposes bounded Codex state metadata such as model, cwd, approval, sandbox, branch, and token totals.
- `inspect-thread --json` keeps the missing-timestamp model call timestampless, updates thread totals from compact facts, and does not leak raw rollout payload markers.
- `summarize-day --json` keeps dated model-call totals scoped to dated rows while reporting bounded parser diagnostic counts for the source.
- An unchanged rollout re-import reports zero new rows across import counts.
- An appended rollout re-import reports only the newly appended row and preserves prior model-call facts.
- Invalid UTF-8 rollout lines report one bounded parser diagnostic while valid surrounding rows continue importing.
- A shrunk rollout source reports `reset_cursor: true`, imports the replacement rows, and removes stale source facts from day summaries.
- `inspect-thread --json` reports command category, normalized executable, exact output-link confidence, raw-output reference count, and `work_item_references` without leaking raw output or source messages.
- `inspect-thread --json` and `summarize-day --json` report count-only `command_category_counts`; reset-cursor cleanup removes stale day counts.

Latest validation on 2026-07-18:

- `swift test --package-path /private/tmp/context-efficiency-wip-20260715/Packages/macOS/BmuxContextEfficiency` passed with 26 Swift Testing tests.
- `python3 scripts/check-workspace-package-groups.py --check` passed.
- `scripts/check-pbxproj.sh` passed.
- `git diff --check` passed.
- `./scripts/reload.sh --tag context-efficiency` produced the tagged Debug app and bundled CLI at `/Users/brianbusby/Library/Developer/Xcode/DerivedData/bmux-context-efficiency/Build/Products/Debug/bmux DEV context-efficiency.app`.
- `BMUX_CLI="$HOME/Library/Developer/Xcode/DerivedData/bmux-context-efficiency/Build/Products/Debug/bmux DEV context-efficiency.app/Contents/Resources/bin/bmux" python3 tests/test_context_efficiency_cli.py` passed.
- `git add` and `git commit` succeeded after rerunning with explicit `git -C /private/tmp/context-efficiency-wip-20260715`.

## Phase 3 Next Targets

Stay narrow and read-only. Prefer package-level Swift tests unless a CLI regression is specifically exercising the built binary.

Decisions:

1. Markdown/CSV export formatting is deferred. JSON diagnostics are the Phase 2 read-only report contract.
2. `codex-token-audit` remains a legacy command for now. Replacement/removal is deferred to a cleanup slice after Phase 2 closure.
3. Phase 3 command attribution starts from existing rollout tool facts before adding live PTY/OSC 133 capture.
4. Active PR or ticket detection should be represented as evidence-backed work item or PR reference facts, not a single scalar, because related PRs and stacked branches can appear in the same thread.

Good next targets:

1. Link `work_item_references` to future `WorkProvenance` work items or delegation inputs through stable IDs instead of copying telemetry rows.
2. Evaluate OSC 133 parsing for non-Codex terminal attribution in a separate capture slice.
3. Persist command execution candidates only if derived reports prove insufficient.

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
- If git resolves the wrong checkout or cannot create the worktree index lock, run git commands with explicit `git -C /private/tmp/context-efficiency-wip-20260715`.

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

The repeated-facts slice added package/report models and CLI JSON fields only. No CLI help, human-readable CLI output, UI, menus, settings, alerts, or other user-facing localized strings changed.

This file and the other `docs/context-efficiency/*` planning files are internal development documentation and are not mirrored into localized docs. If a future slice adds or edits CLI/UI/user-facing strings, use `bmux-localization` and update every supported locale.
