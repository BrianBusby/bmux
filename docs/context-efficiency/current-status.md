# Bmux Context Efficiency: Current Status

Last updated: 2026-07-16

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

Phase 2 only: local, read-only telemetry ingestion and diagnostics.

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

Phase 3+ work starts only after a deliberate status update says Phase 2 is closed.

## Current Branch State

Expected branch:

- `context-efficiency-wip-20260715`

Latest completed implementation HEAD:

- `73b98ee9d32c4515647dca1a379a1af2d66fb87c`

The current branch tip may include docs-only handoff maintenance commits. Run `git rev-parse HEAD` when an exact checkout hash is needed.

Latest completed implementation slice:

- `ff8e024b5 Add string payload rollout regression`
- `73b98ee9d Import string encoded rollout payload objects`

Behavior in that slice:

- Codex rollout `payload` fields that arrive as JSON strings containing objects now import through the same compact fact path as object payloads.
- String-encoded function-call payloads now record tool name, call id, command summary, and serialized argument byte counts.
- String payloads that are not JSON objects remain non-fatal and do not create raw payload records.

Files changed in the latest slice:

- `Packages/macOS/BmuxContextEfficiency/Sources/BmuxContextEfficiency/Import/CodexRolloutTelemetryParser.swift`
- `Packages/macOS/BmuxContextEfficiency/Tests/BmuxContextEfficiencyTests/CodexRolloutTelemetryParserTests.swift`

## Good Next Phase 2 Targets

Stay narrow and read-only. Prefer package-level Swift tests unless a CLI regression is specifically exercising the built binary.

Good next targets:

1. Defensive parser behavior for unstable rollout fields:
   - array/scalar payload fallbacks that should remain bounded and non-fatal;
   - missing timestamp fallback/reporting behavior.
2. Import status and error-reporting edge cases:
   - bounded counts only;
   - no raw payload leakage;
   - JSON report shape coverage where it exercises runtime behavior.
3. Bounded CLI JSON shape coverage:
   - only when it exercises real CLI behavior from the rebuilt tagged binary;
   - avoid tests that merely assert source text or implementation shape.

Avoid broad CLI/app integration unless the slice is explicitly scoped to read-only diagnostics and includes localization work for any new command/help/error text.

## Verification For The Next Slice

After code changes, run:

```bash
swift test --package-path /private/tmp/context-efficiency-wip-20260715/Packages/macOS/BmuxContextEfficiency
python3 scripts/check-workspace-package-groups.py --check
scripts/check-pbxproj.sh
git diff --check
./scripts/reload.sh --tag context-efficiency
```

Then run the context-efficiency CLI regression against the rebuilt tagged CLI if the slice touches CLI behavior or report output.

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
5. Update `Good Next Phase 2 Targets` if priorities changed.
6. Update verification commands or known quirks if they changed.
7. State whether localization was needed.

Do not let one-off chat handoffs become the only record of current status.

## Localization

The latest completed slice changed package internals and package tests only. No CLI, UI, help, command, or user-facing app strings changed.

This file and the other `docs/context-efficiency/*` planning files are internal development documentation and are not mirrored into localized docs. If a future slice adds or edits CLI/UI/user-facing strings, use `bmux-localization` and update every supported locale.
