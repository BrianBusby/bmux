# Codex update and workspace retention

## Sources and baseline

User reported build719 closes a new workspace when accepting Codex Update Now,
and still requests the update after running the advertised Bun command elsewhere.
Base is pushed build719 commit802f15cce (itself based on verified build715), not
origin/main. Original checkout and running builds are untouched.

Read CLAUDE.md; continuous-code-quality; bmux architecture, testing, debugging,
shared-behavior, dev-workflow and localization; Superpowers systematic-debugging
and test-driven-development. Ownership: Ghostty owns PTY exit rendering; bmux
owns the host-close decision; the existing configured-command wait flag is the
source of truth. Remote demotion/recovery paths must retain their established
behavior. Ordinary shell exit must still close its panel/workspace.

## Evidence and plan

- Tagged build719 debug log10:48:06.353 records showChildExited, immediately
  followed by close.childExited and panel.close for the last workspace surface.
- ConfiguredCodexLaunchCoordinator requests waitAfterCommand=true. Ghostty
  Surface.zig childExited calls SHOW_CHILD_EXITED before honoring that flag;
  bmux's callback currently queues unconditional host close and returns handled.
- Add runtime regression through the real TabManager child-exit action, both a
  last panel and a multi-panel workspace. Preserve normal shell and remote tests.
- Share one local-command retention decision between callback return semantics
  and TabManager's direct child-exit entrypoint; keep close asynchronous to avoid
  deinitializing inside Ghostty dispatch. Extract cohesive child-exit handling
  from oversized owner files rather than increasing their responsibilities.
- Installed executable evidence: ~/.local/bin/codex resolves to standalone0.154.0;
  ~/.bun/bin/codex reports0.161.0; Homebrew reports0.152.1. Login-interactive zsh
  selects the Bun binary0.161.0. Build719 GUI PATH is system-only. Composition
  explicitly prefers ~/.local, bypassing shell selection. Connected host permits
  only0.154.0. User explicitly requested connected0.161.0 validation. Retain an
  exact version gate; do not modify installed executables or global settings.
- No fresh dogfood build/launch is currently authorized by the repository's
  active-dogfood rule. Prepare a concrete tested patch first; request permission
  for a separate tag if needed. Never replace build719.

## Implementation and verification

- New host launches resolve the login-interactive shell PATH using a fixed,
  bounded-time script and the existing AgentExecutableResolver. Startup output
  precedes a NUL marker; only PATH is captured. Resolution happens per launch,
  and failures retain the existing startup error/retry path instead of choosing
  an old installation silently. Custom/compound/resume commands retain the
  existing ordinary-terminal routing.
- CommandRunner now supplies its configured environment to Process as well as
  executable lookup. Existing production callers otherwise use the default
  process environment. The original TUI also exports the same resolved PATH,
  so an env-based shebang works even with a GUI-only inherited PATH. The real
  launcher fixture reproduced missing-interpreter failure before that export.
  This seam matters for Bun's node shebang and configured
  shell environment. A real subprocess regression failed before the fix; all
  95 BmuxFoundation tests passed after it.
- Child-exit policy remains owned by TabManager; Ghostty callback delegates to
  that same policy and validates surface identity before deferred teardown.
  Local waitAfterCommand output stays open; ordinary-shell and remote recovery
  paths retain their existing ownership. No provider command is replayed.
- Workspace retention regression failed on the base in both last-panel and
  multi-panel cases before the fix (test-only ba828cb45). Callback coverage now
  verifies Ghostty fallback and retired-surface suppression. The final three focused
  Swift Testing suites passed 29 tests (xcodebuild TEST SUCCEEDED); existing XCTest remote/close coverage
  ran 16 tests in the same run: 15 passed, one existing split-persistent-remote
  test failed two assertions about the still-live sibling. A baseline reproduction
  is in progress; this is not being labeled a green full run.
- Exact provider version is retained on ConnectedCodexHost and projected into
  runtime control metadata. Fixture tests cover 0.154.0, 0.161.0, and fail-closed
  rejection of 0.162.0. Real 0.161.0 native transport and transcript parser
  passed in isolated scratch probes. The stricter no-thread/resume recheck passed:
  initial blank TUI, sole-thread adoption, first queued prompt, stale/current
  steering, queue survival through reconnect and another follow-up. All five
  accepted IDs occurred once across four completed turns, with replies in the
  original TUI; rejected steering was absent. No turn/start or interrupt request.
  Sanitized report: /private/tmp/bmux-codex161-compatibility/report-no-resume.json.
  Native transport/parser report: sibling report.json. GUI, interrupt, approvals,
  settings, restart and arbitrary versions remain outside this evidence.
- Localization audit: no new bmux labels, dialogs, buttons, help text, or
  message keys. Uses Ghostty's existing process-exited renderer and existing
  localized startup errors. Provider version is literal evidence. English/
  Japanese UI rendering and native updater interaction remain unverified.
- Build719 remains running unchanged. Fresh isolated tagged build and native
  dogfood await explicit approval under CLAUDE.md's active-dogfood rule.


## Reproduction commands and operational limits

- `swift test --package-path Packages/macOS/BmuxFoundation`: 95 tests passed.
- `BMUX_SKIP_ZIG_BUILD=1 xcodebuild test -project bmux.xcodeproj -scheme bmux-unit
  -configuration Debug -destination 'platform=macOS,arch=arm64'
  -derivedDataPath /Users/brianbusby/Library/Developer/Xcode/DerivedData/bmux-codex-update-tests`
  with `-only-testing:bmuxTests/ConfiguredCodexLaunchTests`,
  `-only-testing:bmuxTests/ConnectedCodexExecutableResolverTests`, and
  `-only-testing:bmuxTests/ConnectedSessionOwnershipTests`.
- Existing remote/ordinary exit suite: add
  `-only-testing:bmuxTests/TabManagerChildExitCloseTests` (see failure above).
- `scripts/lint-pbxproj-test-wiring.sh`: all 428 test files wired;
  `scripts/check-pbxproj.sh`, workspace package grouping and resolved-policy
  checks passed; `git diff --check` passed.
- `scripts/project-docs validate`, `generate`, and `check` passed. Generated
  files were regenerated from the manifest, not hand edited.
- Build-cache caveat: a baseline DerivedData clone retained absolute SwiftPM
  artifact paths. Missing Sentry/Sparkle build output copies were restored from
  the existing resolved macOS slices; the baseline clone
  was isolated by clearing its copied build/cache directories and rewriting its
  SwiftPM artifact paths. Never reuse copied absolute build metadata across
  concurrently tested worktrees.
  No production source change was made to work around this cache issue.
- Existing compiler warnings include inconsistent XCTest implementation-only
  imports and the parser's unused index; no claim that broader warning debt is
  resolved. There are no new UI text keys or translations in this slice.
