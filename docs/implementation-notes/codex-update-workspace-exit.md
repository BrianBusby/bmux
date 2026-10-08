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
- The user approved a separate codex-update-fix build/launch after reviewing
  the committed patch. Build719 must remain untouched.

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
  test failed two assertions about the still-live sibling. An exact-base attempt
  stopped at the Ghostty CLI Zig linker before tests ran. Unchanged Workspace
  disconnect code clears all sibling remote IDs, explaining the assertions by
  source inspection; an empirical base test result remains unverified.
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
- Build719 remains running unchanged. The user explicitly approved the isolated
  tagged build and launch; native results are below.


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


## Native acceptance: build 720

`reload.sh --tag codex-update-fix --launch --no-global-cli-links
--swift-disable-global-isel` succeeded on runtime commit `00ce0570d`, using the
existing resolved packages and `BMUX_SKIP_ZIG_BUILD=1`. The user approved this
fresh isolated build. Its app, bundle ID, socket and derived data are distinct
from build719; global CLI links were preserved.

Using the real AI Repo Launcher → companycam-mobile (Codex) → Launch Normally:

- New workspace reached connected Chat without an update prompt.
- A Chat-only prompt (“Reply exactly: Ready. Do not use tools or change files.”)
  completed with “Ready.”; the native Terminal showed Codex v0.161.0 and the
  identical prompt/reply. Current workspace styling is retained.
- `/exit` ended the original TUI. The workspace and terminal stayed present;
  switching Chat/Terminal showed the retained provider output plus Ghostty's
  “Process exited. Press any key to close the terminal.” message.
- Chat retained the conversation and reported the shared connection unavailable
  after exit. Tagged CLI input independently returned `process_exited`.
- Tag log at13:06:37.256 recorded showChildExited then
  `surface.exit.preserve ... reason=waitAfterCommand` for the exact same surface.

Native accessibility trees and screenshots were inspected in CUA. No video,
light/Japanese acceptance or actual package-manager update was performed. The
installed CLI was already0.161.0; preserving the updater's exit path is covered
by command-exit regression plus this native original-TUI exit check. Broader
remote lifecycle and interrupt controls remain outside this acceptance.


## Review follow-up after build 720

Codex review identified two shell-resolution edge cases. A captured PATH that
omits Codex must fail instead of searching stale home/runtime or system fallback
directories. Connected launches now disable both fallback groups in the existing
resolver; other resolver callers retain their existing defaults. A shell's
basename is no longer an allowlist: ksh and renamed compatible shells can run
the same fixed probe. csh/tcsh use interactive `-i -c` because macOS rejects
login mode with a command; this reads their rc file, not their login-only file.
Unknown incompatible shell command forms still fail closed, without selecting a
different shell or an unrelated installation.

The new runtime regressions reproduced all five expected failures before the fix:
PATH omission selected the stale executable, and alternate/custom shell names
were rejected (including a real macOS tcsh startup fixture). After the fix, all
42 tests in ConnectedCodexExecutableResolverTests, ConnectedSessionOwnershipTests
and AgentExecutableResolverTests passed. Project-docs validate/generate/check and
diff checks passed. No new user-facing strings were introduced; existing localized
resolution/startup errors are retained. Build 720 predates
these follow-up changes; the review loop does not rebuild or replace it.

CI's workflow guard failed on the inherited 851-line
`AgentSessionFactualProjectionView.swift`, whose blob is identical to the stacked
base 802f15cce. The review loop leaves PR132 and file budgets untouched. Claude
review could not start because its GitHub App is not installed on this repository;
Codex review supplied the two addressed findings. Project Truth and package
conventions passed on b7755b36f.
