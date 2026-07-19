# Bmux Context Efficiency: Current Status

Last updated: 2026-07-18

This file is the live handoff index for the context-efficiency roadmap. Read it before choosing work, and update it at the end of every context-efficiency slice.

## Read Order

1. `AGENTS.md`
2. `docs/context-efficiency/current-status.md`
3. `docs/context-efficiency/roadmap.md`
4. `docs/context-efficiency/subsession-delegation-integration-plan.md`
5. `docs/context-efficiency/agent-retrieval-knowledge-projection-plan.md`
6. `docs/context-efficiency/subsession-delegation-phase-a-report.md`
7. `docs/context-efficiency/milestones.md`
8. Relevant bmux skills:
   - `bmux-architecture` before Swift package/API changes.
   - `bmux-dev-workflow` before tagged builds or project wiring.
   - `bmux-testing` before test changes or verification decisions.
   - `bmux-localization` only if changing CLI, UI, docs, help, or other user-facing strings.

## Active Phase

Original roadmap Phase 3 is active: read-only command and output attribution from already-imported telemetry facts. Phase 2 closed on 2026-07-17 with local telemetry ingestion, Codex state metadata, SQLite persistence, bounded JSON diagnostics, and CLI regression coverage.

Subsession/delegation provenance has been merged into the roadmap as a Phase 3-adjacent provenance integration track with its own authoritative plan:

- `docs/context-efficiency/subsession-delegation-integration-plan.md`

Agent retrieval and knowledge projection has been merged as a Milestone 5.5 track with its own authoritative plan:

- `docs/context-efficiency/agent-retrieval-knowledge-projection-plan.md`

Retrieval must build on reliable lifecycle capture, session/delegation identity, and semantic provenance. Do not start retrieval implementation before Phase R0 investigation and do not let retrieval create parallel stores, task models, child-session records, or raw-evidence copies.

Phase A investigation is complete in `docs/context-efficiency/subsession-delegation-phase-a-report.md`. The next subsession/delegation slice may start Phase B: read-only subsession lifecycle persistence in `WorkProvenance`. Do not treat subsession/delegation as a separate subagent manager; it must extend `WorkProvenance` and link to `BmuxContextEfficiency` telemetry later through stable identities.

Allowed original-plan Phase 3 work:

- Derive command execution candidates from existing Codex rollout tool-call/tool-output facts.
- Classify bounded command summaries into deterministic command categories.
- Attribute tool calls to tool outputs using exact Codex call IDs when present.
- Attribute command outputs to subsequent model calls as temporal candidates.
- Keep command facts bounded and source-referenced.
- Add behavior-level Swift package tests and CLI regression coverage for existing read-only diagnostics.

Allowed subsession/delegation work right now:

- Phase B read-only subsession lifecycle persistence in `WorkProvenance`.
- Use `AgentSubsessionLifecycleChange` as the authoritative lifecycle source.
- Add session relationship and external identity projections before delegation contracts.
- Keep capture/query only; no orchestration, recommendations, or quality scoring.

Do not start:

- Lifecycle policy, warnings, handoff recommendations, or intervention logic.
- Output filtering or live Codex execution changes.
- UI changes.
- Automatic compression, omission, or mutation of agent context.
- Delegation contracts, reconciliation tables, parent disposition, completion reports, or telemetry-derived quality metrics before Phase B lifecycle persistence is proven.
- Retrieval knowledge projections, FTS, semantic records, provenance edges, context package generation, or semantic-search adapters before the retrieval Phase R0 report is complete and lifecycle/delegation prerequisites are satisfied.

Keep both tracks observation-first. Provenance work may capture and query facts, but must not add automatic delegation decisions, task decomposition, prompt mutation, child launch, merge behavior, or quality scoring.

## Current Branch State

Current checkout:

- Branch: `repo-launcher-custom-params`
- HEAD observed on 2026-07-18: `baff09910b`
- Contains committed workspace work-context projection and late-subsession-start suppression work, plus documentation-only context-efficiency planning edits pending commit.

Active context-efficiency worktree:

- Branch: `context-efficiency-wip-20260715`
- Path: `/private/tmp/context-efficiency-wip-20260715`
- HEAD observed on 2026-07-18: `ca1266ebb`

Latest completed implementation HEAD for original-plan Phase 3:

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

Latest completed provenance planning slice:

- `docs/context-efficiency/subsession-delegation-phase-a-report.md` records the Phase A architecture report required before subsession/delegation schema or implementation changes.
- `docs/context-efficiency/current-status.md` and `docs/context-efficiency/milestones.md` record that Phase B lifecycle persistence is now the next provenance implementation target.

## Phase 2 Closure Note

- `b194b8b1 Add missing timestamp rollout regression`
- `f90790b0 Report missing rollout timestamps`

That closure slice kept missing-timestamp facts importable, reported bounded `missing rollout event timestamp` parser diagnostics, and kept unknown scalar payload imports non-fatal.

## Good Next Targets

Stay narrow and read-only. Prefer package-level Swift tests unless a CLI regression is specifically exercising the built binary.

Original-plan Phase 3 targets:

1. Link `work_item_references` to future `WorkProvenance` work items or delegation inputs through stable IDs instead of copying telemetry rows.
2. Evaluate OSC 133 parsing for non-Codex terminal attribution in a separate capture slice.
3. Persist command execution candidates only if derived reports prove insufficient.

Subsession/delegation provenance target:

1. Start Phase B: read-only subsession lifecycle persistence in `WorkProvenance`.
2. Follow `docs/context-efficiency/subsession-delegation-phase-a-report.md` for the authoritative lifecycle source, schema map, migration strategy, and first test fixture.
3. Do not start delegation contracts, reconciliation, child reports, parent disposition, UI, or lifecycle policy until Phase B is implemented and tested.

Retrieval/knowledge-projection target:

1. Keep retrieval as planning/investigation only until subsession lifecycle persistence and the next semantic provenance prerequisites are proven.
2. When explicitly starting retrieval work, begin with Phase R0 from `agent-retrieval-knowledge-projection-plan.md`: current stores, projection/migration patterns, retrieval capabilities, FTS support, schemas, invalidation design, roadmap insertion points, first migration, and first fixture.
3. Do not start embeddings, context-package generation, UI, automatic prompt injection, or orchestration in the first retrieval slice.

Avoid broad CLI/app integration unless the slice is explicitly scoped to read-only diagnostics and includes localization work for any new command/help/error text.

## Verification For The Next Slice

After context-efficiency package or CLI report changes, run:

```bash
swift test --package-path /private/tmp/context-efficiency-wip-20260715/Packages/macOS/BmuxContextEfficiency
python3 scripts/check-workspace-package-groups.py --check
scripts/check-pbxproj.sh
git diff --check
./scripts/reload.sh --tag context-efficiency
```

Then run the context-efficiency CLI regression against the rebuilt tagged CLI if the slice touches CLI behavior or report output.

After WorkProvenance/subsession Phase B code changes, run the relevant Swift Testing/Xcode unit coverage for `WorkProvenanceStore`, `AgentChatSessionRegistryLifecycleTests`, and any new lifecycle adapter tests, then run `scripts/check-pbxproj.sh`, `python3 scripts/check-workspace-package-groups.py --check`, `git diff --check`, and a tagged reload if app runtime wiring changed.

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
5. Update phase status and next targets if priorities changed.
6. Update verification commands or known quirks if they changed.
7. State whether localization was needed.

Do not let one-off chat handoffs become the only record of current status.

## Localization

The latest completed provenance planning slice changed internal development docs only. No CLI, UI, help, command, or user-facing app strings changed.

This file and the other `docs/context-efficiency/*` planning files are internal development documentation and are not mirrored into localized docs. If a future slice adds or edits CLI/UI/user-facing strings, use `bmux-localization` and update every supported locale.
