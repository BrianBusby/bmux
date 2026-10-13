# CI runners

Every CI/CD job that needs configurable routing picks its runner from a
repository variable instead of a hardcoded label. The variable value must match
runner providers that are actually installed for that repository. Some workflow
fallbacks use paid cloud labels, while iOS lanes deliberately fall back to
GitHub-hosted `macos-15` so PR CI and scheduled TestFlight cannot be left
permanently queued when Blacksmith is not connected.

| Variable            | Used by                                                    | Blacksmith (primary)        | Fallback baked into the workflow |
| ------------------- | ---------------------------------------------------------- | --------------------------- | -------------------------------- |
| `LINUX_RUNNER`      | every Linux job (`ci.yml` web/typecheck/db, presence, cloud-vm, nightly/ios decide jobs, claude, homebrew, tmux fuzz) | `blacksmith-4vcpu-ubuntu-2404` | `warp-ubuntu-latest-x64-4x`   |
| `MACOS_RUNNER_15`   | universal Release app builds: nightly, stable release, `release-ghostty-cli-helper`, most macOS defaults | `blacksmith-6vcpu-macos-15` | `warp-macos-15-arm64-6x`         |
| `MACOS_RUNNER_26`   | macOS 26 compat + jobs that do not need Zig                 | `blacksmith-6vcpu-macos-26` | `blacksmith-6vcpu-macos-26`      |
| `MACOS_RUNNER_26_RELEASE` | disk-heavy `release-build` universal app             | `blacksmith-6vcpu-macos-26` | `blacksmith-6vcpu-macos-26`      |
| `MACOS_RUNNER_IOS`  | iOS simulator tests + TestFlight upload (`test-ios.yml`, `ios-testflight.yml`) | repository-specific; `macos-15` in `BrianBusby/bmux` | `vars.MACOS_RUNNER_15` then `macos-15` |

Workflows reference them as `runs-on: ${{ vars.LINUX_RUNNER || 'warp-ubuntu-latest-x64-4x' }}`.
If a variable is unset the job uses the fallback, so CI is never broken by a
missing variable.

## Fork/local repository overrides

The table above is the canonical `manaflow-ai/bmux` policy. Forks or local
repository mirrors may need different repo-variable values when they do not
have the same paid runner providers connected. For example, `BrianBusby/bmux`
currently has no registered self-hosted runners, so `MACOS_RUNNER_26_RELEASE`
and `MACOS_RUNNER_26` must use the GitHub-hosted `macos-26` label there; both
`depot-macos-26` and `blacksmith-6vcpu-macos-26` queued the `release-build`
job with zero steps in that fork, while `macos-26` scheduled and completed the
Release build.
The same fork currently uses `MACOS_RUNNER_IOS=macos-15`; queued iOS jobs on
`blacksmith-6vcpu-macos-26` showed `runner_id: 0`, an empty runner name, and no
executed steps, which indicates the job never matched an available runner.

Treat those overrides as repository-local configuration, not upstream workflow
policy. Before changing a repository back to a documented Blacksmith value,
confirm the provider is actually connected for that repository. GitHub Actions
resolves repository variables when a workflow run is created, so changing a
variable does not fix jobs already queued inside an existing run; cancel/rerun
or dispatch a fresh CI run after changing the variable.

## Deliberate exceptions (not on Blacksmith)

Blacksmith macOS runners cannot initiate a testmanagerd control session (no GUI
login session / automation mode), so XCTest-driven and virtual-display jobs
hang at "Timed out 120s initiating control session with daemon" and never go
green there. These stay on Warp or Depot on purpose:

- `ci.yml` `tests` is hard-pinned to `warp-macos-15-arm64-6x` (see the comment at
  the job). Revert to `vars.MACOS_RUNNER_15` once Blacksmith macOS testmanagerd
  is repaired.
- `ci.yml` `tests-build-and-lag` and `ui-regressions`, `perf-activation.yml`
  PR runs, and the `virtual_display` compat row use `MACOS_RUNNER_DISPLAY`
  (Depot/Warp) because Cmd-Tab timing, virtual displays, and XCTest automation
  need a GUI-capable runner. A Depot identity guard validates these.

`MACOS_RUNNER_IOS` is the central override for iOS package tests, simulator
tests, and TestFlight upload. The baked-in fallback is
`vars.MACOS_RUNNER_15 || 'macos-15'`, not Blacksmith, because missing or
unavailable third-party runner integrations otherwise leave required PR checks
queued before checkout. `macos-15` is GitHub-hosted, has Xcode installed on the
standard image, and supports the Swift package and iOS simulator work used by
these lanes. If an iOS lane needs a different provider, set
`MACOS_RUNNER_IOS` explicitly and confirm a fresh workflow run is assigned a
real runner before relying on it. The iOS lanes also initialize only the
`ghostty` and `vendor/bonsplit` submodules they need for GhosttyKit and app
builds; they must not recursively clone release-only private submodules such as
`homebrew-bmux`.

## Break-glass: switch a runner type off Blacksmith

We do not auto-overflow except for the explicit iOS fallback described above.
If Blacksmith is genuinely down or queuing for minutes (not the sub-minute
queue we accept by default), manually flip the affected variable to its
fallback; revert it once Blacksmith recovers. In repositories with Blacksmith
installed, these are the canonical Blacksmith values:

```bash
gh variable set LINUX_RUNNER          --repo manaflow-ai/bmux -b blacksmith-4vcpu-ubuntu-2404
gh variable set MACOS_RUNNER_15       --repo manaflow-ai/bmux -b blacksmith-6vcpu-macos-15
gh variable set MACOS_RUNNER_26       --repo manaflow-ai/bmux -b blacksmith-6vcpu-macos-26
gh variable set MACOS_RUNNER_26_RELEASE --repo manaflow-ai/bmux -b blacksmith-6vcpu-macos-26
gh variable set MACOS_RUNNER_IOS      --repo manaflow-ai/bmux -b blacksmith-6vcpu-macos-26
```

Do not apply the macOS Blacksmith values to `BrianBusby/bmux` unless a fresh
test run proves Blacksmith jobs are assigned a real runner there. Its current
macOS values are:

```bash
gh variable set MACOS_RUNNER_26 --repo BrianBusby/bmux -b macos-26
gh variable set MACOS_RUNNER_26_RELEASE --repo BrianBusby/bmux -b macos-26
gh variable set MACOS_RUNNER_IOS --repo BrianBusby/bmux -b macos-15
```

Break-glass a type to WarpBuild only when Blacksmith is down or queuing for
minutes (as happened for macOS in https://github.com/manaflow-ai/bmux/pull/4926).
**Set an explicit cloud label.** Do not rely on deleting the variable: the
baked-in macOS-26 fallbacks are now `blacksmith-6vcpu-macos-26` (not Warp),
because `warp-macos-26-arm64-6x` collides with the self-hosted fleet, so
deleting `MACOS_RUNNER_26` just keeps the job on Blacksmith. Never set any
runner variable to a fleet/self-hosted label.

For iOS lanes, deleting `MACOS_RUNNER_IOS` falls back through
`MACOS_RUNNER_15` and then GitHub-hosted `macos-15`. Prefer setting
`MACOS_RUNNER_IOS` explicitly anyway, so the intended runner can be audited with
`gh variable list`.

```bash
gh variable set LINUX_RUNNER    --repo manaflow-ai/bmux -b warp-ubuntu-latest-x64-4x
gh variable set MACOS_RUNNER_15 --repo manaflow-ai/bmux -b warp-macos-15-arm64-6x
# macOS 26 has no Warp cloud fallback (warp-macos-26 collides with the fleet);
# break-glass to a GUI-capable cloud runner instead:
gh variable set MACOS_RUNNER_26 --repo manaflow-ai/bmux -b depot-macos-latest
```

Check current values:

```bash
gh variable list --repo manaflow-ai/bmux
```

## Manual runs

`perf-activation.yml` and `test-e2e.yml` keep a `runner` choice input that
defaults to `auto`. Manual `auto` runs follow `MACOS_RUNNER_15` then the Warp
fallback, so flipping the repo variable redirects those workflows. An explicit
manual choice wins over the variable; both dropdowns expose Blacksmith, Warp,
and `depot-macos-*` choices, with a Depot identity guard for GUI-activation
runs.

## Guard

`tests/test_ci_self_hosted_guard.sh` (run by the `workflow-guard-tests` job)
asserts that normal jobs do not pin a bare GitHub-hosted runner
(`ubuntu-*` / `macos-NN`) directly: jobs should route through runner repo
variables so provider changes stay centralized. It also asserts paid macOS jobs
reference `vars.MACOS_RUNNER_*` or an explicit Blacksmith/Warp/Depot label, and
asserts the iOS workflows keep their variable-routed `macos-15` fallback. Bare
paid-provider labels (`blacksmith-*`, `warp-*`, `depot-*`) stay allowed for
deliberate single-runner pins. Keep new paid-provider labels in
`.github/actionlint.yaml`.

## No self-hosted mac-mini fleet in CI

The canonical upstream repository does not use the self-hosted mac-mini fleet
(`bmux-mac-mini`, `studio1`, `mac4-bmuxvnc*`, `bmux-austin-mini-*`) for any CI
job. Those minis carry labels that collide with cloud labels (notably
`macos-26` and `warp-macos-26-arm64-6x`), and GitHub can prefer a matching
self-hosted runner in repositories where those runners are registered, so a
required job could silently land on a mini that cannot foreground a GUI app (it
stays `Running Background`, breaking key-window / pasteboard / IME / XCUITest).
Every non-iOS macOS fallback therefore routes to a paid cloud label, and
`check_no_self_hosted_fleet_runners` in `tests/test_ci_self_hosted_guard.sh`
fails CI if any workflow references a fleet/self-hosted label. In
`BrianBusby/bmux`, the repository runner list is empty, so bare GitHub-hosted
labels do not select a self-hosted runner; they select GitHub-hosted runners.

Residual: this guard checks workflow literals, not repo-variable values. Do not
set `MACOS_RUNNER_*` / `LINUX_RUNNER` to a self-hosted label; keep them on
available cloud providers. Fully closing the variable-value path requires
removing any colliding labels from self-hosted runners in repositories or orgs
that have them registered (runner-side, needs org/runner admin).


## Hidden browser discard policy test maintenance

The baseline `BrowserPanelWebViewLifecycleTests.testHiddenDiscardPolicyReadsUserDefaults`
expected a stored 7200-second delay to clamp to 3600. The policy introduced in
`69e6393db` deliberately rejects oversized values, and the JSON settings path
uses the same `resolvedHiddenDelay` validation. The native baseline log reports
300 versus 3600; this is a stale expectation, not a requested product change.

`BrowserHiddenWebViewDiscardPolicyTests` replaces only that touched XCTest case
with Swift Testing. It preserves enabled/default/valid-value checks and covers
both accepted endpoints, negative/oversized values, and nonfinite rejection.
Each defaults test owns a unique suite and removes it; environment overrides
explicitly disable the corresponding persisted-preference test, while pure
validation always runs. No process-wide environment mutation or app behavior
changes are introduced. The existing focused browser gate runs the new suite
without adding a runner, so an unrelated legacy app-host abort cannot conceal it.

Guidance: `AGENTS.md`, `skills/bmux-testing/SKILL.md` and its Swift Testing,
regression/quality, and local/CI references; `skills/bmux-architecture/SKILL.md`;
and the personal continuous-code-quality skill. Ownership stays in
`BrowserHiddenWebViewDiscardPolicy`, with the maintained JSON caller in
`KeyboardShortcutSettingsFileStore` and boundary coverage in `WorkspaceUnitTests`
as contract evidence. Native execution against build 774 passed four functions
and fourteen cases, with warning-free test compilation. This change adds no
shipped strings or localization keys. Actual focused CI and independent review
remain required; local success does not establish full-suite health.
## Browser background compositing test maintenance

Commit `379033c4bf` made `GhosttyBackgroundTheme` use the shared opaque window
compositing policy, but three theme tests and two WebKit under-page tests still
expected uncomposited RGB plus partial alpha. Baseline CI records those exact
component/alpha mismatches. The replacement Swift Testing suites preserve the
payload/fallback and native-notification assertions, exercise Aqua and Dark Aqua,
and check clamped endpoints against window/terminal colors. Payload tests compare
the wrapper with its shared compositing owner; under-page tests check the native
WebKit result after the real notification path, including NSNumber opacity.

The under-page fixture supplies a deferred `.test` page URL without navigation.
A blank page can correctly be clear when the window owns a transparent backdrop,
so it is not a reliable fixture for a real website's native fill. Each panel closes
synchronously on the main actor; drawing appearance is scoped to AppKit's native
`performAsCurrentDrawingAppearance`. Tests do not change user preferences, global
Ghostty settings, or terminal rendering. No app code or shipped strings change.

Governing sources: `AGENTS.md`, `skills/bmux-testing/SKILL.md` and its migration,
regression/quality and local/CI references; `skills/bmux-architecture/SKILL.md`;
continuous-code-quality. Ownership remains in `GhosttyBackgroundTheme`,
`WindowAppearanceSnapshot`/`WindowChromeColorResolver`, and BrowserPanel's existing
notification/background path. Native execution against build 774 passed four
functions/fourteen cases. The focused existing browser CI invocation runs both
suites; actual CI and independent review remain verification gates.
## Right sidebar shortcut fixture coverage

Shard 3 runs `RightSidebarModeAvailabilityShortcutTests` and the remaining
`RightSidebarModeShortcutHintTests` before the unchanged full app-host suite.
The focused invocation uses the existing console-session and app-host wrappers;
it does not change runner selection, retries, deadlines, or full-suite coverage.
Expect four Swift Testing tests containing thirteen cases, plus three XCTest
methods. Full app-host CI verification remains pending for this fixture repair.

The original three failing shortcut fixtures expected Feed/Dock routes without
enabling their beta flags. `RightSidebarMode.modeShortcut` correctly checks
`RightSidebarMode+Availability`, whose Feed and Dock defaults are disabled.
The corrected tests retain default/custom-file binding and action-gate assertions,
exercise each flag independently, and cover absent flags. They use the same real
shortcut owner as AppDelegate; no production shortcut behavior changes.

Fixture setup, assertions, and cleanup stay in one synchronous MainActor turn.
An owned JSON file, disabled fallbacks/watchers, and temporary removal of managed
settings bookkeeping prevent unrelated settings discovery or restoration. Cleanup
restores the original settings store and the exact persisted/registered defaults,
then notifies observers and removes the owned directory. This follows the
constructor pattern in `KeyboardShortcutTestSettingsIsolation` and the explicit
beta ownership in `RightSidebarCommandPaletteTests`, with the incremental Swift
Testing migration required by `skills/bmux-testing`.

Local verification used unchanged build 773 (`bcad95a88`) in an isolated native
executable with its own bundle ID and home; the six relevant production owners
match base `ce17e9888`. All thirteen cases and the three retained XCTest methods
passed. Removing only beta setup reproduced failures in the same three test
families. A seeded preservation probe also verified exact effective, persistent,
and registered defaults, store identity, and owned-directory cleanup. These
results do not establish that the broader app-host suite is green.
### Browser discard fixture readiness (2026-10-12)

Two legacy `BrowserPanelWebViewLifecycleTests` cases attempted discard after
polling only `WKWebView.isLoading`. Discard eligibility also checks the model's
loading/provisional state. A native probe against unchanged build 774 observed a
loading blocker at the old boundary; awaiting the model's loading-complete event
produced no blockers and allowed discard. Both complete discard/restore and
restored-history assertions pass against the unchanged artifact with that event
boundary. This proves the corrected fixture's behavior locally; it is not proof
that every earlier CI failure had the same timing.

`BrowserDiscardReadinessTests` migrates only those two cases to Swift Testing,
awaits the existing model publisher's async sequence, confirms WebKit completion,
and keeps the original one-second failure deadline. The deadline is injected as
a duration and canceled with the task group. The inherited synchronous lifecycle
subscription remains confined to tests: it captures every transient state during
synchronous restore and history navigation, which an unbuffered async sequence
could miss. No production propagation API, state owner or discard policy changes.
Panels close and subscriptions cancel through scoped cleanup.

Guidance: root AGENTS, continuous-code-quality, bmux-testing (migration,
regression quality and wiring), bmux-architecture (legacy boundary/concurrency),
and bmux-dev-workflow (project normalization). Owners inspected:
`BrowserPanel.noteWebViewVisibility`, `discardHiddenWebViewForMemory`,
`restoreDiscardedWebViewIfNeeded`, `goBack`, and
`BrowserHiddenWebViewDiscardManager.blockers`. Verification runs in an
isolated HOME against a native app artifact, without launching or replacing the
user's preview. The existing ReactGrab prefetch can still perform background
network activity; this fixture does not add it or claim a network-free app.
All prior webview identity, lifecycle, timestamp/reason, visibility and transient
new-tab assertions remain. The focused browser CI invocation includes the new
wired suite. No shipped text changed; English test diagnostics and contributor
verification notes are the only new prose. App-host CI remains required.
### Sidebar width policy fixture alignment (2026-10-12)

`SessionPersistenceTests.testSidebarWidthSanitizationClampsToPolicyRange` used the
old 240pt minimum constant even after commit `2c783a9ee` deliberately made the
unconfigured minimum 290pt. The policy's default width is 340pt, maximum 600pt;
explicit minimum overrides retain their separate 120...260pt allowed range.
`SidebarWidthPersistencePolicyTests` now exercises those observable defaults, numeric and
string overrides, finite clamping, and nil/nonfinite/invalid-value fallbacks with
unique UserDefaults suites and scoped persistent-domain cleanup. It replaces only
the three obsolete persistence/default-clamp tests; production policy, geometry and configuration remain unchanged.

Eighteen cases pass against unchanged native build 774 in an isolated
HOME, with warning-free focused compilation. The source owner is unchanged from
main. Xcode wiring, normalization, strict determinism, runner policy and Project
Truth checks pass. The existing focused browser invocation also runs this small
policy suite; no runner is added. Actual app-host CI remains the merge gate.
Guidance read: root AGENTS, continuous-code-quality, bmux-testing and migration/
quality references, bmux-architecture, bmux-dev-workflow and normalization.
Complete `SessionPersistencePolicy` and its width consumers were inspected; the
resolved minimum remains owned by persistence policy. No shipped text changes;
new prose is limited to test names and contributor verification notes.

The rest of the existing `SidebarWidthPolicyTests.swift` remains unchanged,
including right-sidebar, settings, titlebar and selection-color coverage. Two
additional baseline failures in that file had the same stale 240pt assumption;
the new suite preserves their default-constant and ContentView static-clamp
assertions at 290pt. A separate existing inconsistency remains unverified here:
the live @AppStorage path clamps its 290pt fallback through the configured
120...260pt range, unlike persistence's absent-key branch. These tests establish
the current persistence and static-clamp contracts, not live resize/default
consistency. Resolving that policy discrepancy would require a separate runtime
change and visual verification.
### Browser remote store profile fixture maintenance

Three `BrowserPanelRemoteStoreTests` assertions assumed every local browser used
`WKWebsiteDataStore.default()`. The current profile policy instead resolves an
unspecified profile from the selected/workspace/last-used profile. Moving out of
a remote workspace restores that panel's retained profile store. Actual baseline
CI failed only the hardcoded default assertions at GhosttyConfigTests lines 2357,
2487 and 2551; the surrounding remote sharing and move isolation assertions passed.

`BrowserRemoteStoreScopeTests` migrates exactly those three methods and executes
both an explicit built-in default and a deliberately selected named profile.
It preserves the original sharing, move-in replacement and move-out isolation
checks, and checks panel/profile identity, different remote workspace isolation,
and absent navigation. The fixture owns its profiles and unmounted panels,
snapshots/restores profile defaults and selection synchronously on the main actor,
and configures remote workspaces with `autoConnect: false`; no remote controller,
network navigation, user socket, or app launch is needed. Unrelated remote URL,
navigation and terminal tests remain byte-identical.

Unchanged build 773 passes all six parameter cases (three functions/one suite)
with warning-free native compilation. Reinstating the old always-default-store
expectation fails exactly the three named-profile cases while explicit-default
controls pass. This establishes fixture state omission, not a production fix.
The existing focused app-host browser gate includes the new suite without adding
a runner. Actual app-host CI remains pending, and the broader suite is not claimed
green. Canonical and local Project Truth caveats retain that verification gap.

Guidance and inspected owners: root/personal AGENTS, continuous-code-quality,
bmux-testing migration/behavioral/local-vs-CI references, architecture file/API/
concurrency guidance and shared-behavior. BrowserProfileRepository owns persisted
selection and profile stores; BrowserPanel init/reattach owns the active WebKit
store; Workspace's existing new-browser and detach/attach paths retain panel
identity and choose the destination scope. No production files, shipped strings,
or localization catalogs change; this is contributor test documentation only.
## Managed appearance startup fixture contract

Three legacy `KeyboardShortcutSettingsFileStoreStartupTests` methods expected
neither application appearance nor terminal synchronization during launch and
reload. The retained base app-host log reports 18 assertion failures across
those methods. Commit `e788e5606` intentionally applies application appearance
at launch while withholding terminal synchronization, then synchronizes on a
changed reload. The former global environment override also allowed unrelated
appearance observers to enter the fixture's recorded calls.

`ManagedAppearanceStartupContractTests` replaces only those three methods with
constructor-injected effects, a private notification center, disabled watchers
and an owned settings file. Each synchronous MainActor case restores the exact
four touched application-domain defaults values (including absent keys, without
promoting registered/global fallbacks); no global environment provider or settings-store
replacement is used. Dark, light and system launch cases assert one application
appearance, zero startup terminal synchronization, an inert deferred drain and
unchanged reload, then one changed-mode application and synchronization with the
exact source. Repeated reload/deferred calls add no effects. System startup uses
the injected system appearance; switching back to system clears the app override.
All other legacy methods remain byte-identical.

Focused Swift 6 compilation is warning-free against unchanged build 777. All
three native cases pass. Additional isolated-home native probes verify a persisted
legacy sidebar migration marker survives the suite and all four originally absent
application-domain keys stay absent when appearance and migration-marker
registration fallbacks exist. Registered fallbacks remain visible. The same seeded
marker probe against the uncorrected fixture exits 1: all three appearance cases
pass, but the persisted marker is removed by `saveImportedManagedDefaults`.
The temporary runner explicitly establishes each initial state in its own process
preferences domain and cleans it afterward; a fresh HOME alone does not clear
macOS preferences-daemon caching.

The first consolidated app-host run (`115049483591`) passed dark and light but
reported four missing initial-application callback assertions for system mode.
The fixture had seeded legacy `auto`, which the appearance owner normalizes to
`system`; that makes the subsequent system import a legitimate no-op. A controlled
native 777 probe calling the real resolver after the old seed reproduces the same
four failures. The fixture now seeds a different canonical mode and asserts that
resolution preserves it before importing the requested mode. All original
callback, terminal synchronization and no-op assertions remain. Both persisted
marker and registration-only native probes pass all three cases and preserve the
four application-domain keys. These controls establish the normalization cause;
they do not identify which live app-host reader normalized the original value.
Corrected app-host verification remains pending.

A temporary negative control reinstating the obsolete
no-launch-appearance and no-reload-sync expectations fails exactly six assertions
across those three cases. No app build, launch, user settings change or production
edit is required. The existing focused
browser app-host step includes the suite, tracked by matching canonical/local
Project Truth caveats. Broader legacy CI is not claimed green.

Guidance: root/personal AGENTS, continuous-code-quality, bmux-testing migration,
behavior and local/CI references, architecture ownership/file/concurrency rules,
and shared behavior. Reviewed owners are the file store's init/reload/managed
side-effect pipeline and AppearanceSettings' injected launch/live application.
The existing UserDefaults-backed production storage remains unchanged; synchronous
ownership avoids yielding while test defaults are installed. No shipped copy or
localization catalog changes are introduced.
## Native test result reporting

The macOS unit-test steps in `ci.yml`, `ci-macos-compat.yml`, `test-depot.yml`
and `tmux-corpus.yml` preserve the native runner's exit status. A zero exit is
success; assertion failures, crashes and timeouts remain failures. Pipelines
use `pipefail` so a failed log writer also fails the step. Existing bounded
SwiftPM dependency retries remain; the final attempt determines the result.

`xcodebuild_noninteractive.py` owns PTY output, crash-prompt dismissal and timeout
cleanup. Only an actual child exit of zero establishes success. A post-test
watchdog timeout returns 125 after a failed Selected-tests summary, otherwise
124. A passed XCTest summary can precede Swift Testing and cannot establish
completion. The cleanup deadline starts at the Selected-tests summary, suspends
when a fresh Swift Testing run (or restarted XCTest run) starts, and restarts at
the final framework summary. Lifecycle lines are consumed once, including lines
split across PTY reads. ANSI SGR styling is removed only from parser input, so
colored Swift Testing glyphs preserve the same lifecycle handling while stdout
and saved logs retain their original bytes. Unrelated app output cannot extend cleanup. A failed
Selected-tests result remains recorded across later successful restart summaries.
During active tests, the existing general output-idle watchdog and native test/job
time limits apply, so an individual test may legitimately exceed the cleanup
allowance. A noisy active test remains bounded by the native test/job limits.
Even a printed `TEST SUCCEEDED` marker cannot override a timeout.
The app-host wrapper retains its existing retry budget. The separately scoped
strict zero-failure cleanup fallback in `test-ios.yml` is unchanged.

Ordinary XCTest assertions can produce `(0 unexpected)` in summaries. Earlier
workflows treated that text as success even with failed assertions; their green
job statuses are not evidence of a clean app-host suite. `native_app_host_full_suite_failures`
in Project Truth remains open until real failures are separately triaged.

`tests/test_ci_xcodebuild_exit_reporting.py` executes all four workflow shell
steps in isolated subprocess sandboxes with controlled native-runner outcomes.
It verifies failure/signal/timeout propagation, misleading later zero-test
summaries, successful expected-failure runs, bounded retries and log-writer
failures. Native PTY tests execute real child processes, including incomplete
XCTest/Swift Testing runs and timeouts; no app or GUI is launched.

The test-only commit `6f46d5f22` failed the actual Linux guard with 40 assertions
([run38152397961](https://github.com/BrianBusby/bmux/actions/runs/38152397961/job/114508355015)).
The reporting fix passes the focused workflow and native-runner tests locally.
Final CI and broad app-host results remain verification gates, not assumptions.
This work follows root AGENTS, continuous-code-quality, bmux-testing and
bmux-shared-behavior: workflow steps own pipeline status; the existing shared
runner owns process lifecycle; no app test expectations are relaxed.

The framework-completion regression in the PTY helper test executes real child
processes: a silent Swift Testing test longer than the cleanup allowance must
reach its native success/failure exit, active silence must reach the existing idle
deadline, and completed-run chatter must still time out. Test-only `6d25320ae`
failed the exact-head workflow guard (run `38283073852`, job `114924791841`)
by killing an active Swift Testing run with exit 124. Local subprocess verification
passes with phase-aware cleanup; full native app-host completion remains subject
to the separately tracked suite failures.


### Consolidated native settings fixtures review boundary

This branch consolidates #145, #147, #149, #154, #156, #158, #161, preserving each published source commit in
its ancestry. Original branches remain available; superseded pull requests
link to their replacement. This changes review organization, not application
behavior. The preserved source heads are:

- #145: `b275c76c3d1a14aec865f07de8d7b2cfa96c92cc`
- #147: `537681592de0f1a51b00308a2fa3834f31959b49`
- #149: `2b8592920ed58232e9506c14ba6e4842d2982f14`
- #154: `b25ad79c66f064dfad82754642666b5fcf22a2a8`
- #156: `d5350d19b490fc1d3505dfeb635513be0d672c49`
- #158: `83ff7d17c9cefb5be4ca644c558ea60251b67073`
- #161: `c3644da9c64d4498dbe5d7cae855c17029773457`

The native-settings and SSH replacement PRs depend on #142 for authoritative
CI exit reporting. The agent-session replacement stacks on SSH to share one
reviewed socket fixture. Existing focused selectors, full-suite coverage and
canonical/local verification caveats remain intact. No failed, incomplete or
cancelled run is treated as green. The original combined validation branch
remains unchanged and does not verify these new heads.

Local consolidation checks cover source ancestry, test-content preservation,
Xcode wiring, selector discovery, determinism, file budgets and generated state.
Full app-host compilation/execution and required checks on the replacement heads
remain pending. No app build, launch, settings or localization catalog changes
are part of this consolidation.
## Browser inspector window ownership verification

The consolidated native app-host run for PR 170 at `45acbff54` still crashes in
browser inspector fixtures. Retained earlier logs identify ten cases that die
around native close/autorelease cleanup. An isolated native lifetime control
reproduces the default `NSWindow.isReleasedWhenClosed` ownership conflict; setting
that policy to false at construction avoids the control's crash. This supports
the fixture diagnosis, but does not establish that full WebKit behaviors pass.

Seventeen affected cases (sixteen direct-window cases and one adjacent synchronous
close observer) move incrementally to one serialized Swift Testing suite.
Directly owned windows use retained ownership from construction, including early
close actions. App-created main windows retain the existing application owner.
Teardown covers partial setup, panel/portal detachment, inspector associations and
windows. Original routing, visibility, inspector-call, parent-identity and geometry
assertions remain; untouched legacy case bodies remain in their original suite.
Temporary shortcut values preserve application-domain provenance and routing
captures end synchronously before an await.

A DEBUG-only per-panel lifecycle observation stream replaces the migrated cases'
run-loop polling. The stream reports completed synchronous mutations; consumers
recheck authoritative transition intent, pending intent, settle work and detached
close resolution. Existing transition/close decisions and timers are unchanged.
Subscriber removal and panel close finish streams; termination holds no strong
panel reference. The existing 2.85-second failure deadline is cancellable and is
not used to settle or poll state. Seven additional owner-level cases cover queued
replacement, no-change, close-resolution replacement, subscriber removal, consumer
cancellation, observation-owner deinitialization and panel close. Settled state covers
visibility transitions and detached-close resolution; it does not claim that all
WebKit restore or dock-normalization work is idle.
Explicit native layout calls replace fixed waits in portal/hosting cases.

The existing focused browser invocation includes
`BrowserInspectorWindowOwnershipTests` before unchanged full-suite coverage. Its
matching canonical/local caveat remains open until actual app-host execution
verifies all 24 cases and clean native teardown. No local foreground UI test or
app launch is authorized by this fixture work. The minimal ownership control and
compile/static checks must not be reported as full app-host verification.

The complete affected source compiles without warnings in the test target's
configured Swift 5 mode against the isolated `browser-inspector-readiness-repair`
DEBUG module. The new suite and fixtures also compile in Swift 6 with the unchanged
legacy hook prefix imported from a Swift 5 support module; the complete legacy
file still has four nonisolated mutable globals that prevent a full Swift 6 check.
Seven observation cases pass in an owned native harness with isolated HOME and
app activation prohibited. This exercises the actual built lifecycle owner; it
is not execution of the seventeen window/UI cases or full app-host coverage.

Guidance: root/personal AGENTS, continuous-code-quality, bmux-testing migration,
behavior and local/CI references, architecture ownership/file/concurrency rules,
debugging runtime pitfalls, shared behavior and native project wiring. No shipped
strings or localization catalogs change; this section is contributor verification
prose. This repair is integrated into PR 170; no separate PR is introduced.
