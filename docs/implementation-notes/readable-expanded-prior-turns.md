# Readable expanded prior turns implementation plan

Goal: present canonical historical evidence in Final output, Run, What was asked,
What it did, Reference IDs order. Native SwiftUI; unchanged current-turn UI.

## Governing sources and mapping (before implementation)

- `AGENTS.md` / `CLAUDE.md`, `skills/bmux-{architecture,testing,dev-workflow,debugging,localization}/SKILL.md`, continuous-code-quality, Superpowers planning/test-first/verification guidance.
- `docs/context-efficiency/current-status.md`, architecture overview and generated ownership/repository status: PE owns identity, evidence, reconciliation and projection; bmux owns presentation. User explicitly selected this presentation-only slice; broader Process Integrity frontier is unchanged.
- Branch `readable-expanded-prior-turns`, now based on verified build-715 source `db3c8c1c0`, isolated worktree. The initial `origin/main` base `ad34b6ad6` omitted the current styling and was rejected by the user. Original dirty checkout and all running apps are untouched.
- `AgentSessionFactualProjectionStore` reads public `factualSessionProjection` (12 detailed turns). `AgentSessionFactualProjectionEvidenceRows.priorTurnItems` joins references to snapshots by canonical PE turn ID and preserves established order. Prior card is the only replacement boundary; existing `TurnDetailView` remains for current turns.
- PE `factualTurnSnapshot` collects all recorded commands in canonical order by turn ID. No total/completeness/duration field or structured tool metadata exists here. Command `outputSummary` is the already-associated bounded/redacted result. Never retrieve hidden output.
- Objective is currently the submitted prompt, not separate semantic intent. Existing Summary chooses final assistant output then file-attribution/reasoning evidence. Adapter preserves that hierarchy but suppresses literal contained/equal summary; never promotes those fallbacks to final output.
- Last nonempty canonical assistant record is existing final-output selection. Preserve its exact string (the old helper trims it). Counts mean evidence records, including Files as attribution records, not paths. Empty unsupported-provider arrays cannot prove zero telemetry: display unavailable. Codex detailed arrays represent all recorded evidence, not all real-world activity.
- Reference-only turns have IDs/status/dates but no counts/model/prompt. Show unavailable evidence, no invented zero or finish. Public turn-detail API exists, but native card has no loading action; retain fetching/storage contracts and report reference-only limitation.
- Existing clipboard helper `WorkspaceSurfaceIdentifierClipboardText.copy` needs a discardable Bool return to report success. Native adaptive system styles match surrounding SwiftUI roles; do not copy mock colors/fonts. Existing collapsed card colors remain a known upstream dark-only issue.
- HTML source reviewed including disclosure/filter/copy JS. Browser attempt rejected local file protocol by browser security policy; no browser comparison claimed.

## Execution and verification

- [x] Test pure request envelope, literal deduplication, bounded shell interpretation, category partition, pagination and identity state before implementation.
- [x] Add immutable presentation values and section views, preserving session/turn identity and raw evidence.
- [x] Localize every added control/label in English/Japanese; wire all files into Xcode.
- [x] Run focused pure logic and Session/projection tests, wiring/length/project-truth checks and isolated tagged build.
- [x] Review accumulated diff and sources. Delivery follows the repository commit/push/PR and bounded background-review workflow.
- [x] Record actual visual evidence and remaining keyboard/VoiceOver checks separately; never infer acceptance from compilation. No running dogfood app replacement.

Command rule: bounded lexical tokenization only; unwrap literal sh/bash/zsh -c/-lc;
skip assignment-only and cd setup operations; classify first substantive operation.
Unsupported expansions/control flow/operators are Other. Never execute/decode evidence.

## Verification record

- Pure helpers: 9 Swift Testing functions, including 29 command cases and 7 invalid
  payload cases, passed in an isolated temporary package compiling the actual
  source files with PE contracts. Parser review cases first produced 11 failing
  assertions, then passed after correction. Unicode comparison is literal too.
- Xcode `bmux-unit`: 21 Swift Testing tests in ExpandedTurnPresentationTests and
  AgentSessionFactualProjectionStoreTests passed. Native AppKit hosting renders
  cover 320/800-point widths and light/dark appearances with 151 recorded commands,
  an initially expanded failed command with associated output, a reply envelope,
  a long unbroken evidence string, and wrapping final text. Images are in the
  test runner temporary directory under `bmux-expanded-native-snapshots`.
- Inspected the native fixture PNGs. Evidence wraps and timestamps/chips stack in
  the narrow rendering. This is fixture evidence, not the supplied live build-708
  turn; no live keyboard/VoiceOver, clipboard action, Japanese appearance, larger
  text, or workspace-scroll acceptance is claimed from static images.
- Tagged reload `readable-expanded-prior-turns` succeeded without launching.
  Global CLI links were preserved. The new worktree initializes the pinned
  Ghostty/Bonsplit submodules and uses the existing GhosttyKit xcframework cache;
  reload applies its documented macOS SDK/Zig CLI-helper skip. The active user
  app was never rebuilt, quit, replaced, or relaunched.
- Xcode project normalization, 423-file test-wiring check, Package.resolved policy,
  workspace package grouping, diff whitespace, and Project Truth validate /
  generate / check passed.
- Localization audit parses the catalog, verifies English/Japanese entries for
  all new keys and reused labels, and checks Swift UI literals. There are 35 new
  translated keys. Raw provider statuses, commands, IDs, model names and the
  request envelope type remain source evidence. Internal implementation notes
  are engineering documentation, not product copy.

## Retained limitations and baseline failures

- The native read path supplies 12 full turn snapshots; older references retain
  honest unavailable fields. There is no existing native per-card load action.
  No new fetching/storage contract or hidden-result retrieval was added.
- The contract has no total, completeness flag, separate objective, canonical
  duration, or structured tool metadata. Run counts retain the existing recorded
  array meanings; non-Codex empty telemetry is unavailable, not invented zero.
  All chip counts partition available records. Unsupported shell expansion /
  control-flow wrappers remain Other; literal bmux proxy invocations are bmux,
  always visibly abbreviated, and never decoded by this presentation.
- `SessionProvenanceTests.testHookPromptSubmitRecordsFactualSessionAndWorkspaceDisplayLink`
  fails at line 201 expecting `runtime-workspace`. Unchanged main source at
  `WorkProvenanceCodingAgentEvidenceRecorder+Support.swift:61` uses
  `stableWorkspaceID.uuidString`; neither that code nor its test changed here.
  The failure reproduced in both broader and isolated test selections. A separate
  baseline app build was not run; attribution is supported by unchanged source.
- The repository-wide Swift-length gate still fails because the prior main
  Session view has no budget entry. Main has 886 lines; this slice reduces it to
  866 by giving session-scoped historical disclosure its own small value-state
  view. No budget suppression or unrelated decomposition was introduced.
- Existing app compilation emits concurrency/deprecation warnings in unrelated
  AppDelegate and other retained modules; no new presentation-source warning was
  observed. These checks do not certify the wider Session lifecycle.
- Browser policy rejected the local HTML URL; browser exercise and direct visual
  comparison remain unverified. HTML source/interaction logic was inspected.
- Live interaction/VoiceOver, larger text, Japanese visual acceptance, absent /
  distinct summaries and missing-output/partial-provider visual variants remain
  dogfood checks. Pure logic covers malformed/missing request, literal Summary
  deduplication, unavailable/zero telemetry, negative/missing duration, identity
  disclosure, filtering before pagination, and batches beyond 143 commands.

The registered autoreview skill was not found in installed skills. The handoff
uses the repository's bounded background CI/review instructions directly; it
must not claim to have invoked a missing skill, merge, or rebuild the user's tag.

## Background review follow-up

- Deferred immutable evidence preparation until a card is expanded. Evidence
  refreshes while collapsed no longer tokenize command arrays; reopening updates
  the cache by canonical command ID/raw source and retains disclosure choices.
- Follow-up validation: all 21 focused presentation/projection tests passed,
  including native fixture rendering; Project Truth validate/check and diff
  whitespace checks passed. No UI strings or project wiring changed. Live
  collapsed-history performance and interaction still need dogfood verification.
- The earlier tagged build 717 remains on `8b4014718`; the background loop does
  not replace a user's build. Any later presentation commit needs a fresh
  isolated build and renewed dogfood through the main agent.
- CI confirmed the inherited missing Swift-length budget and additionally found
  stale `shared_session_chat` roadmap delivery metadata for merged PR #116.
  Downstream macOS test jobs were skipped by the preflight failure. No baseline
  gates or broader milestone metadata were changed.
- A review request to retain the former plan/reasoning/file-detail blocks remains
  a design follow-up: the supplied layout specifies command detail under What
  it did and a known-zero-command visibility rule. Those canonical records and
  their Run counters remain intact, but the old detail blocks are not rendered
  in the new expanded history. This is a retained presentation limitation, not
  evidence that all historical detail remains inspectable.


## Corrected build baseline (2026-10-08)

- The existing `/Applications/bmux DEV chat-default-711.app` reports
  `CFBundleVersion=715` and `BMUXCommit=db3c8c1c0`. The user explicitly requested
  carrying this feature onto that verified source after rejecting build717's
  missing styling. App directory/tag names are not authoritative build numbers.
- Rebased only the two presentation commits onto `db3c8c1c0`. A backup branch
  retains the original series. The PR is stacked on `new-workspace-chat-default`;
  its only commit after the verified source records release metadata, with no
  app-source change. Neither that branch nor its PR is modified.
- The Session-host conflict preserves the build715 per-workspace primary-tab
  selection and initial Chat behavior; only historical disclosure state moves
  into the existing feature's session-keyed history view. Project metadata keeps
  every baseline caveat and regenerates the derived document.
- `git range-diff` confirms that rebasing changed only integration context.
  Sidebar sources, ContentView, primary-tab mode, Session host caller, and terminal
  portal are byte-identical to the verified baseline. The final Session-host diff
  is limited to the three original prior-turn-history edits. This is source
  preservation evidence, not live visual or interaction acceptance.
- Use the fresh tag `readable-turns-build715`; both build715 and the now-running
  build717 remain untouched. The rebase includes deferred command preparation
  from the background follow-up. Existing visual/accessibility limitations above
  still apply until live dogfood confirms them.
- Corrected-baseline validation: all 21 focused presentation/projection tests
  passed, including native fixture renders. Inspected the regenerated narrow
  dark fixture; wrapping and stacked facts remain intact. The isolated tagged
  build succeeded without launch. All six bundled React/Solid Chat assets are
  byte-identical to the installed build715; SDK26.5 uses the reload script
  documented Zig-helper skip. Wiring (427 test files), project normalization, package
  policy/grouping, Project Truth validate/generate/check, whitespace, and all 35
  English/Japanese message pairs passed on the corrected baseline. The inherited
  Session-view size is now 851 lines versus 871 in build715; no budget exception
  was added. The full length scan also flags 15 other files; byte comparisons
  confirm all 15 and the budget file are unchanged from the verified baseline.

- Independent integration review found no regressions in the corrected range;
  per-workspace tab state, current-turn rendering and terminal portal callbacks
  were inspected, with no claim of live visual or interaction acceptance.
