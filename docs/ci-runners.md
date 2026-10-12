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
