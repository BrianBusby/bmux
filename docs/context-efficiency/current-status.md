# Bmux Context Efficiency: Current Status

Last updated: 2026-07-20

This file is the live handoff index for the context-efficiency roadmap. Read it before choosing work, and update it at the end of every context-efficiency slice.

## Read Order

1. `AGENTS.md`
2. `docs/context-efficiency/current-status.md`
3. `docs/context-efficiency/roadmap.md`
4. `docs/context-efficiency/subsession-delegation-integration-plan.md`
5. `docs/context-efficiency/agent-retrieval-knowledge-projection-plan.md`
6. `docs/context-efficiency/provenance-observability-integration-plan.md`
7. `docs/context-efficiency/subsession-delegation-phase-a-report.md`
8. `docs/context-efficiency/milestones.md`
9. Relevant bmux skills:
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

Provenance observability has been merged as a cross-cutting roadmap track with its own authoritative plan:

- `docs/context-efficiency/provenance-observability-integration-plan.md`
- `docs/context-efficiency/provenance-observability-phase-o0-report.md`

Observability must not become a parallel provenance system. `WorkProvenance` remains the authoritative semantic history of engineering work, `BmuxContextEfficiency` remains read-only imported telemetry/evidence, and `ProvenanceObservability.sqlite` may hold operational traces, quality telemetry, feedback, evaluation, and shadow-comparison data only as roadmap phases explicitly allow. Phase O0 architecture investigation is complete in `docs/context-efficiency/provenance-observability-phase-o0-report.md`. O1 lifecycle-ingestion tracing is complete, and O2 identity-resolution observability is complete only for the existing lifecycle-ingestion path. Do not start broad observability implementation or O3+ work from this slice.

Phase A investigation is complete in `docs/context-efficiency/subsession-delegation-phase-a-report.md`. Phase B read-only subsession lifecycle persistence is now implemented through the WorkProvenance store foundation plus the `AgentSubsessionLifecycleChange` adapter/runtime wiring. Do not treat subsession/delegation as a separate subagent manager; it must extend `WorkProvenance` and link to `BmuxContextEfficiency` telemetry later through stable identities.

Allowed original-plan Phase 3 work:

- Derive command execution candidates from existing Codex rollout tool-call/tool-output facts.
- Classify bounded command summaries into deterministic command categories.
- Attribute tool calls to tool outputs using exact Codex call IDs when present.
- Attribute command outputs to subsequent model calls as temporal candidates.
- Keep command facts bounded and source-referenced.
- Add behavior-level Swift package tests and CLI regression coverage for existing read-only diagnostics.

Allowed subsession/delegation work right now:

- Phase B read-only subsession lifecycle diagnostics and query polish in `WorkProvenance`.
- Use `AgentSubsessionLifecycleChange` as the authoritative lifecycle source.
- Use the existing persisted session, session relationship, and external identity projections before delegation contracts.
- Keep capture/query only; no orchestration, recommendations, or quality scoring.

Allowed observability work right now:

- Phase O0 architecture investigation is complete; keep the report as the O1 gate.
- O1 lifecycle-ingestion pipeline tracing is complete for `AgentSubsessionLifecycleChange -> WorkProvenance event append -> projection update`.
- O2 identity-resolution observability is complete only for the lifecycle-ingestion path.
- Keep observability best-effort, bounded, and separate from authoritative WorkProvenance facts.
- Do not add O3+ projection lineage, retrieval traces, feedback, dashboards, quality scoring, shadow evaluation, automatic correction, lifecycle policy, or orchestration in the next slice.

Do not start:

- Lifecycle policy, warnings, handoff recommendations, or intervention logic.
- Output filtering or live Codex execution changes.
- UI changes.
- Automatic compression, omission, or mutation of agent context.
- Delegation contracts, reconciliation tables, parent disposition, completion reports, or telemetry-derived quality metrics before Phase B lifecycle persistence has read-only query coverage.
- Retrieval knowledge projections, FTS, semantic records, provenance edges, context package generation, or semantic-search adapters before the retrieval Phase R0 report is complete and lifecycle/delegation prerequisites are satisfied.
- Observability dashboards, learned quality models, semantic evaluation, outcome claims, broad sampling infrastructure, automatic correction, automatic algorithm promotion, or every proposed observability table before O0/O1 foundations are complete.

Keep all tracks observation-first. Provenance work may capture and query facts, but must not add automatic delegation decisions, task decomposition, prompt mutation, child launch, merge behavior, automatic correction, algorithm promotion, or quality scoring.

## Current Branch State

Current checkout:

- Branch: `context-efficiency-phase-b-lifecycle`
- HEAD observed before the latest slice on 2026-07-19: `109bb7910`
- Contains committed workspace work-context projection, late-subsession-start suppression, context-efficiency planning docs, Phase B WorkProvenance session relationship projection foundation, and observability plan integration.

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
- `docs/context-efficiency/provenance-observability-integration-plan.md` records the cross-cutting observability plan and O0 investigation gate.
- `docs/context-efficiency/current-status.md` and `docs/context-efficiency/milestones.md` record that Phase B lifecycle persistence remains the next provenance implementation target, with O0 observability investigation as the next observability planning target.

Latest completed provenance implementation slice:

- Working tree slice on 2026-07-19 adds bounded read-only `bmux provenance sessions tree <session-id> --json` diagnostics over the existing `sessions`, `session_relationships`, and `session_external_identities` projections. It keeps `WorkProvenance` as the authoritative store and adds no orchestration, policy, delegation contracts, observability schema, UI, or lifecycle mutation. `bmux-cli` built successfully and `tests/test_provenance_cli.py` passed against that built binary. The full `bmux-unit` app-target test run was attempted but blocked before tests by an unrelated Ghostty CLI helper Zig link failure.

Latest completed observability planning slice:

- `docs/context-efficiency/provenance-observability-phase-o0-report.md` completes Phase O0 investigation and documents the narrow O1 lifecycle-ingestion trace design. No observability schema or runtime code was added.

Latest completed observability implementation slice:

- `6ceb48ccafc698f1ee16984455f26e18c81efe7a Add lifecycle identity observability traces`
- This O2 slice adds `identity_resolution_attempts` to the separate `ProvenanceObservability.sqlite` store, migrating the observability schema to version 2 while keeping `WorkProvenance` authoritative.
- It records identity-resolution attempts only for the lifecycle-ingestion path and correlates each attempt to the O1 `pipeline_run_id`.
- It explains how `AgentSubsessionLifecycleChange` was resolved into child session ID, lifecycle event ID, relationship session ID, and external identity ID.
- It stores bounded inputs and outcomes only: phase, agent kind, parent session ID, presence flags for optional lifecycle fields, selected identity kind/value category, hashed input identity value, candidate count, confidence, fallback/unresolved state, unresolved reason, conflict reason, selected authoritative IDs, timestamps, and resolver version.
- Native subsession IDs record high-confidence resolved identity; missing native identifiers record low-confidence fallback-unresolved identity; duplicate append conflicts record a bounded conflict reason without blocking provenance persistence.
- The existing `bmux provenance traces lifecycle-ingestion --json` output now includes bounded `identity_resolutions` rows and `identity_resolution_count`. Text output is unchanged.
- Observability writes remain best-effort/non-blocking and separate from authoritative WorkProvenance writes.
- It does not add O3+ projection lineage, retrieval, delegation contracts, feedback, dashboards, quality scoring, shadow evaluation, automatic correction, lifecycle policy, orchestration, or a parallel semantic provenance source.
- Validation: focused `SubsessionProvenanceTests` passed with `BMUX_SKIP_ZIG_BUILD=1`; `bmux-cli` built successfully; `tests/test_provenance_cli.py`, `scripts/check-pbxproj.sh`, `python3 scripts/check-workspace-package-groups.py --check`, and `git diff --check` passed.

Files changed in the working tree slice:

- `CLI/BMUXCLI+Provenance.swift`
- `CLI/CLIProvenanceLifecycleTraceList.swift`
- `CLI/CLIProvenanceObservabilitySQLiteReader.swift`
- `Sources/WorkProvenance/ProvenanceIdentityResolutionRecord.swift`
- `Sources/WorkProvenance/ProvenanceObservabilityStore.swift`
- `Sources/WorkProvenance/WorkProvenanceSubsessionLifecycleRecorder.swift`
- `bmux.xcodeproj/project.pbxproj`
- `bmuxTests/SubsessionProvenanceTests.swift`
- `tests/test_provenance_cli.py`

Previous completed provenance implementation slice:

- `Add provenance subsession lifecycle recorder`

Behavior in that slice:

- `WorkProvenanceSubsessionLifecycleRecorder` converts `AgentSubsessionLifecycleChange` into append-only `subsession_started` / `subsession_stopped` events.
- Child session IDs, external identity IDs, and lifecycle event IDs are deterministic through `WorkProvenanceStableIDFactory`.
- Runtime wiring records lifecycle changes from the existing `registry.onSubsessionLifecycleChanged` path while preserving ephemeral child workspace behavior.
- Existing `WorkProvenanceRuntime.live()` now shares one store between workspace Git observation and subsession lifecycle persistence.
- Swift Testing coverage verifies start/stop projection replay, nested root/depth derivation, missing-identifier fallback confidence, and stop-before-start persistence.
- No CLI, UI, lifecycle policy, delegation contracts, reconciliation, parent disposition, quality scoring, or observability schema was added.

Files changed in that slice:

- `Sources/WorkProvenance/WorkProvenanceSubsessionLifecycleRecorder.swift`
- `Sources/WorkProvenance/WorkProvenanceStableIDFactory.swift`
- `Sources/WorkProvenance/WorkProvenanceRuntime.swift`
- `Sources/Mobile/AgentChat/AgentChatTranscriptService.swift`
- `Sources/AppDelegate.swift`
- `Sources/bmuxApp.swift`
- `bmuxTests/SubsessionProvenanceTests.swift`
- `bmux.xcodeproj/project.pbxproj`

Previous provenance implementation slice:

- `b875eb837 Add provenance session relationship projections`

Behavior in that slice:

- `WorkProvenanceStore` schema version is now 3.
- New projection tables record session parent/root relationships and session external identities.
- Event payload replay/upsert/query support now covers parent lookup, direct children, external identities, and bounded session trees.
- Store tests cover relationship and identity replay/idempotency.
- No adapter, runtime wiring, CLI, UI, lifecycle policy, warnings, delegation contracts, or parent disposition was added.

Files changed in that slice:

- `Sources/WorkProvenance/WorkProvenanceExternalIdentityRecord.swift`
- `Sources/WorkProvenance/WorkProvenanceSessionRelationshipRecord.swift`
- `Sources/WorkProvenance/WorkProvenanceSessionTree.swift`
- `Sources/WorkProvenance/WorkProvenanceEventPayload.swift`
- `Sources/WorkProvenance/WorkProvenanceEventType.swift`
- `Sources/WorkProvenance/WorkProvenanceStore.swift`
- `bmuxTests/WorkProvenanceStoreTests.swift`
- `bmux.xcodeproj/project.pbxproj`

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

1. Phase B read-only lifecycle persistence and session-tree query coverage are proven against a narrow rebuilt `bmux-cli`; do not expand into delegation contracts until a separate Phase C/D slice.
2. Keep `AgentSubsessionLifecycleChange` as the authoritative lifecycle source; use `BmuxContextEfficiency` only later for telemetry identity links.
3. Do not start delegation contracts, reconciliation, child reports, parent disposition, UI, or lifecycle policy until read-only lifecycle persistence and query coverage are proven.

Retrieval/knowledge-projection target:

1. Keep retrieval as planning/investigation only until subsession lifecycle persistence and the next semantic provenance prerequisites are proven.
2. When explicitly starting retrieval work, begin with Phase R0 from `agent-retrieval-knowledge-projection-plan.md`: current stores, projection/migration patterns, retrieval capabilities, FTS support, schemas, invalidation design, roadmap insertion points, first migration, and first fixture.
3. Do not start embeddings, context-package generation, UI, automatic prompt injection, or orchestration in the first retrieval slice.

Observability target:

1. Use `provenance-observability-phase-o0-report.md` as the completed O0 gate.
2. Treat O1 lifecycle-ingestion traces and O2 lifecycle identity-resolution traces as complete for the current narrow path.
3. The next observability implementation, if explicitly requested, should start from O3 projection lineage and remain scoped to existing lifecycle-ingestion projections unless the user changes the roadmap.
4. Do not add broad observability tables, retrieval traces, dashboards, feedback, quality scoring, shadow evaluation, automatic correction, lifecycle policy, warnings, intervention logic, prompt mutation, or orchestration.

Avoid broad CLI/app integration unless the slice is explicitly scoped to read-only diagnostics and includes localization work for any new command/help/error text.

## Verification For The Next Slice

For docs-only context-efficiency roadmap updates, run:

```bash
git diff --check
```

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

Build policy update from 2026-07-19: do not run full tagged builds as routine validation for this provenance/context-efficiency project. Build again only for a compiler-level reason or when the user explicitly asks.

Latest Phase B query-diagnostics validation on 2026-07-19:

- `xcodebuild -project bmux.xcodeproj -scheme bmux-cli -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/bmux-context-eff-phase-b-cli build` passed.
- `BMUX_BUNDLED_CLI_PATH=/tmp/bmux-context-eff-phase-b-cli/Build/Products/Debug/bmux python3 tests/test_provenance_cli.py` passed.
- `scripts/check-pbxproj.sh`, `python3 scripts/check-workspace-package-groups.py --check`, and `git diff --check` passed.
- Focused `bmux-unit` testing was attempted with `SubsessionProvenanceTests`, `AgentChatSessionRegistryLifecycleTests`, and `WorkProvenanceStoreTests`, but the app-target build failed before tests in the Ghostty CLI helper Zig build script with undefined symbols such as `__availability_version_check`; this was outside the Phase B Swift/CLI changes.

Latest Phase 3 salvage validation on 2026-07-19:

- `swift test --package-path /private/tmp/context-efficiency-phase3-salvage/Packages/macOS/BmuxContextEfficiency` passed 26 Swift Testing tests.
- `xcodebuild -project bmux.xcodeproj -scheme bmux-cli -configuration Debug -destination platform=macOS -derivedDataPath /tmp/bmux-context-eff-phase3-salvage-cli build` passed.
- `BMUX_BUNDLED_CLI_PATH=/tmp/bmux-context-eff-phase3-salvage-cli/Build/Products/Debug/bmux python3 tests/test_context_efficiency_cli.py` passed.
- `scripts/check-pbxproj.sh`, `python3 scripts/check-workspace-package-groups.py --check`, and `git diff --check` passed.

Latest Phase B foundation validation on 2026-07-18:

- `scripts/check-pbxproj.sh` passed.
- `python3 scripts/check-workspace-package-groups.py --check` passed.
- `git diff --check` passed.
- `./scripts/reload.sh --tag context-eff-phase-b` passed and built `bmux DEV context-eff-phase-b.app`.
- Focused `xcodebuild test -only-testing:bmuxTests/WorkProvenanceStoreTests/persistsSessionRelationshipsAndExternalIdentitiesAcrossReplay` reached compilation of the new WorkProvenance files, then failed later with the known local Zig/Ghostty undefined-symbol linker issue before running tests.

Latest Phase B lifecycle adapter validation on 2026-07-19:

- `scripts/check-pbxproj.sh` passed.
- `python3 scripts/check-workspace-package-groups.py --check` passed.
- `git diff --check` passed.
- `xcodebuild test -project bmux.xcodeproj -scheme bmux-unit -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/bmux-context-provenance-test -only-testing:bmuxTests/SubsessionProvenanceTests` initially failed at the known local Ghostty CLI helper Zig link step before test execution.
- `BMUX_SKIP_ZIG_BUILD=1 xcodebuild test -project bmux.xcodeproj -scheme bmux-unit -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/bmux-context-provenance-test -only-testing:bmuxTests/SubsessionProvenanceTests` passed 4 Swift Testing tests.
- `./scripts/reload.sh --tag context-provenance` passed and built `bmux DEV context-provenance.app`.

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

The O2 implementation changed provenance trace JSON fields only (`identity_resolution_count` and `identity_resolutions`) and did not add or edit CLI help, CLI text output, UI strings, command text, error text, or localized user-facing prose. No `Resources/Localizable.xcstrings` update was needed.

This file and the other `docs/context-efficiency/*` planning files are internal development documentation and are not mirrored into localized docs. If a future slice adds or edits CLI/UI/user-facing strings, use `bmux-localization` and update every supported locale.
