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

## Bundled CLI artifact verification

The CLI is distributed inside the app (including the installed CLI symlink).
Private dynamic frameworks are permitted only when their complete dependency
closure is shipped at helper-visible bundle paths. The historical Sentry dyld
regression must still fail; a blanket ban on every private `@rpath` framework
also rejects valid Xcode app-host products.

`scripts/verify-bundled-cli.py` is the shared artifact check used by
`BundledCLILinkageTests`, the existing unsigned universal `release-build`, and
`bundled-cli-artifacts`. It inspects every architecture's dependency closure,
rejects private dependencies outside the app, verifies present CLI/framework
signatures, copies that closure without changing executable bytes, and runs
`--version` with a temporary home and no ambient socket or dyld environment.
The final release signing script retains its separate deep/strict signed-app
verification. Pre-sign Release CI legitimately permits unsigned objects; this
check does not claim Developer ID or notarization verification.

One app-host shard and the Release lane upload three-day artifacts containing
only the CLI, Info.plist, and dependency frameworks. The separate macOS 26 job
uses the existing `MACOS_RUNNER_26` routing and downloads both artifacts; it does
not build an app. Before launching, it fails if any original external private
runpath still exists. This explicit check matters even on a new job because
self-hosted runners may reuse build directories. No source directory is renamed,
no binary is patched or re-signed, and no running app is touched. `ci-status`
requires this gate. A same-runner launch alone is not proof that dyld avoided a
build-directory fallback.

`tests/test_bundled_cli_artifact.py` builds small real Mach-O fixtures. It checks
static and transitive dynamic relocation, preserved archived bytes, missing
direct/transitive dependencies (including a live original-build fallback),
missing architecture slices, invalid existing signatures, unsigned pre-sign inspection, native exit failure,
missing CLI, and rejection of surviving original runpaths.

Maintenance record: base `ce17e9888`, historical contract commits `d3695c102`
and `915c01f9d`; retained baseline CI run `38072470965` shard 3 actually failed
`testBundledCLIDoesNotDependOnPrivateRPathFrameworks` on six frameworks that the
same build embedded and signed. This is the existing red evidence for correcting
the fixture policy, rather than introducing another known-wrong assertion.
Ownership follows AGENTS.md, continuous-code-quality, bmux-testing's executable
artifact policy, bmux-architecture's test ownership rules, and the existing
`sign-bmux-bundle.sh` signing lifecycle. No production linking policy changes.
Local ten-case fixture verification and static build 773 relocation pass;
its minimum archive is 16 MB. Actual dynamic app-host and unsigned Release
artifact results, transfer size/time, and final CI remain pending.


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

## Codex Stop hook fixture coverage

App-host shard 4 runs `CodexStopPayloadFailureTests`,
`CodexStopTranscriptFailureTests`, and `CodexStopTurnScopeTests` in a focused
invocation before the unchanged full shard coverage. These cover 13 existing
Stop-hook scenarios (nine Swift Testing methods, one with five parameterized
payload cases). The focused invocation uses the same app-host wrapper, runner,
and deadlines as its sibling regression steps. Its native CI result remains
pending; local executable verification is not a full app-host pass.

The fixtures describe a live workspace/surface membership response instead of
returning an empty object to every JSON-RPC request. They preserve the original
transcript/payload, notification, status, and output assertions, including
current-turn error suppression. Notification assertions use the current
`notify_target_async` command. Unknown mock methods fail the test.

Each fixture owns its HOME, CFFIXED_USER_HOME, CODEX_HOME, hook-state directory,
Unix socket, and input/output files. `CodexStopMockServer` bridges nonblocking
socket readiness into one async capture task; it awaits descriptor cancellation
before removing the socket. `CodexStopHookFixture` uses the existing
`CommandRunner` for exit/deadline handling and positional shell `exec`
redirection for exact non-TTY input/output. It reads captured output only after
a native process exit. These fixtures do not build, launch, or contact a user's
running app.

A controlled local comparison exposed a separate existing limitation in
`CommandRunner`: its detached blocking stdout/stderr readers can exhaust the
cooperative executor while parallel socket fixtures await responses. Stack
sampling confirmed workers in `CommandRunner.readToEnd`; the unchanged pipe
variant passed serially, while owned-file capture passed all 13 cases in
parallel. The production runner remains unchanged and that concurrency risk
is recorded as an open Project Truth caveat. Restoring the empty topology in
the file-capture variant still fails all 13 scenarios, independently confirming
the routing repair. Local checks also preserved a child's native exit 65 and
exercised socket disconnection cleanup without ignoring SIGPIPE globally.


### Browser legacy-theme migration regression

Baseline app-host logs show BrowserThemeSettingsTests failing the legacy
force-dark migration. A native probe against unchanged build 773 confirms the
startup path: BrowserPanel.normalizeBrowserDefaults registers `browserThemeMode`
as System before BrowserThemeSettings reads the legacy boolean, so migration
mistakes a fallback for an explicit choice. The migrated Swift Testing suite
retains the old direct-access assertions and adds startup, repeat-normalization,
implicit-default and explicit-mode cases. Its focused CI selector runs alongside
the browser proxy regression to preserve native failure reporting independently
of the legacy broad-suite summary handling.

Ownership remains unchanged: BrowserPanel owns process-once defaults bootstrap;
BrowserThemeSettings owns legacy migration, canonical values and its System
fallback; BrowserPanelView's AppStorage owns the same declared fallback for view
binding. The bounded correction removes the redundant theme fallback
registration that masks migration. Explicit System/Light/Dark choices must retain
precedence. Other normalization keys and browser behavior are outside this fix.
No new package, state owner, setting or UI string is needed.

Guidance: root AGENTS, continuous-code-quality, bmux-testing (Swift Testing,
behavioral coverage, two-commit regression evidence and target wiring),
bmux-architecture (ownership and file discipline), bmux-shared-behavior and
bmux-dev-workflow. Patterns inspected: the complete BrowserThemeSettings owner,
BrowserPanel bootstrap/normalization and BrowserPanelView's AppStorage consumers;
existing BrowserDefaultsNormalizationTests retain separate canonicalization
coverage. Local test-only evidence on macOS 26.3 is six functions (ten cases),
with four expected migration assertions failing and all other checks passing.
Actual test-only CI job 114950761885 reproduced those four expected assertions
on commit 9a9b2e1cb. The isolated tagged build 774 succeeds, and the same six
functions (ten cases) pass against its native app module with no focused compiler
warnings. This exercises startup normalization and persistence in unique temporary
defaults suites. Fixed app-host CI and the full suite remain pending; the canonical
and local verification caveat stays open. Build 773 and real user defaults are
untouched. No shipped text or
translation keys change. Other baseline failures remain separate maintenance PRs.


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

## CLI baseline failure classification (2026-10-12)

Read-only audit of 38 `CLINotifyProcessIntegrationRegressionTests` methods failed
on feature base `ce17e9888a6dce4d2e5755795946b68cf52f0329`. Evidence is retained in
`/tmp/matte-baseline-failure-index.json` and `/tmp/matte-base-apphost{1,2,3,4}.log`.
These are historical failures, not a claim that current maintenance branches pass.
The audit inspected complete process/socket helpers and the relevant production
routing, cleanup, resize, auto-naming and SSH agent-resolution paths. No test or
app execution was performed for this classification.

Categories: 14 concrete fixture/expectation mismatches, 13 lifecycle/process
candidates, 5 production candidates (only sanitizer confirmed), and 6 unresolved
timing/environment cases. A candidate is not a proven cause and does not authorize
relaxing assertions or excluding a test.

### Concrete fixture/expectation mismatches (14)

- Seven startup-signal cases call `SSHStartupSignalLifecycleTests.generatedVMSSHInitialStartupCommand`
  (737–810), whose mock accepts `vm.attach_info`; the real CLI requests `vm.ssh_info`.
  Logs fail at helper809 with `Unexpected method vm.ssh_info` before shell behavior.
- The stale-control-socket startup fixture omits initial surface identity and
  `surface.list`; its primary error is inability to resolve the initial terminal
  surface, followed by an unsupported rollback `workspace.close` request.
- Respawn expects `surface.send_text`, while the maintained command uses
  `surface.respawn` (`CLI/bmux.swift:24036`). Preserve window/command payload checks.
- Both Claude notification routing cases target the correct workspace/surface;
  their generic heartbeat produces `Idle`, while assertions demand `Needs input`.
  The production generic-idle classifier is at `CLI/bmux.swift:24672`.
- Codex hook install counts inline `hooks codex prompt-submit` in wrapper paths;
  the same test already has `commandBodies` to inspect the installed wrappers.
- Auto-naming prompt cache injects a logger with `BMUX_BUNDLED_CLI_PATH`, but the
  maintained launcher prefers absolute executable argv[0] over that fallback
  (`CLI/BMUXCLI+AutoNamingHooks.swift:168`). This does not establish failed caching.
- Tmux compat builds a 108-byte socket path against 104-byte `sun_path` and gets
  bind/listen -1. The legacy helper asserts length then continues copying; fix
  fixture path ownership and fail invalid prerequisites before memory writes.

### Lifecycle/process candidates (13)

Nine generic-hook cases time out (Antigravity, six Grok, Hermes finalize, Kiro),
and four wait for mock completion (three Claude lifecycle cases, Hermes extra
payload). Shared `CLIMockSocketServerSupport` queues 80/128 blocking accept/read
blocks on global user-initiated workers without joined listener cancellation.
`CLINotifyProcessTestSupport.runProcess` queues process waiting on the same QoS,
output drains on utility workers, then blocks on a semaphore. Some tests read
`state.commands` outside its lock instead of `snapshot()`.

Antigravity's baseline has repeated timedOut=true with empty stdout and status0
(no status assertion failure), suggesting waiter/drain scheduling rather than
proving a child hang. This requires a controlled reproduction/stack capture;
do not increase deadlines. `startMockServer` fulfills on the first disconnect,
not after all four accepted connections.

A separate newer async Codex fixture measured cooperative-executor pipe starvation
in `CommandRunner` (two detached blocking reads), recorded by its owner in
`/tmp/codex-stop-pipe-stacks.txt` and `/tmp/codex-stop-fixtures-handoff.md`.
That is **not** proof of the legacy GCD helper hypothesis above.

### Production candidates (5)

- **Confirmed sanitizer defect:** cleanup locally creates `persistent SSH PTY
  session is no longer running` at `CLI/bmux.swift:12101`, then sanitizes it again
  at12208. Both CLI and app sanitizers only match `not running`, which does not
  match `no longer running`; the CLI reports generic failure. Baseline apphost1
  at2026-10-10T18:05:24.777 fails line5291, while exit1, no close and session-ID
  assertions pass. Other canonical diagnostics also need round-trip coverage.
- Cloud retry mock returns typed `vm_cloud_service_unavailable`, but classifier
  at10925 recognizes other text/codes; one RPC instead of two is observed. Inspect
  the documented typed retry contract before changing any retry policy.
- Invalid/foreign Codex surface cases actually set running/resume metadata on
  focused/mapped surfaces. `resolveAgentHookTarget` at30666 falls through preferred,
  mapped and default surface; stale-ambient recovery documentation at30460 says
  TTY/PID ground truth. Preserve wrong-target assertions and empirically inspect
  identity provenance before correcting the shared resolver.
- Stale Claude SessionEnd clears the consumed stale workspace. The fixture seeds
  an active workspace/session map and sends SessionEnd with missing ID; actual
  clear_agent_pid/clear_notifications target the stale workspace. Store-schema
  compatibility and intended consumed-workspace ownership remain unverified.

### Timing/environment unresolved (6)

- Four attach tests miss only `workspace.remote.pty_resize`; the mock closes the
  bridge immediately after ready. `SSHPTYResizeMonitor` schedules initial resize
  asynchronously and cancellation on EOF can precede the drain. Determine the
  initial-size handshake contract, preserve resize assertions, use causal signals.
- Two agent-socket tests override HOME but inherit CFFIXED_USER_HOME/SSH_AUTH_SOCK;
  Foundation tilde expansion and caller socket fallback may escape fixture home.
  The second also observes nonnil ssh_options. Exact option/config provenance
  and controlled-home proof are pending; neither is called a production defect.

### Exact case index

All rows belong to `CLINotifyProcessIntegrationRegressionTests`; log names resolve
under `/tmp` in the retained audit environment.

| Case | Classification | Baseline log |
| --- | --- | --- |
| `testAntigravityStopAndNotificationsUseGenericNotificationPath` | lifecycle / process candidate | `matte-base-apphost3.log` |
| `testClaudeNotificationFallsBackToLiveWorkspaceInsteadOfFocusedTab` | fixture / expectation | `matte-base-apphost2.log` |
| `testClaudeNotificationHonorsExplicitWorkspaceHandleRef` | fixture / expectation | `matte-base-apphost3.log` |
| `testClaudePromptSubmitFromNewSessionCanReplaceStoppedSession` | lifecycle / process candidate | `matte-base-apphost3.log` |
| `testClaudeSessionEndChecksConsumedWorkspaceBeforeClearingVisibleState` | production candidate | `matte-base-apphost1.log` |
| `testClaudeSessionStartRecordIsNotRestorableUntilPrompt` | lifecycle / process candidate | `matte-base-apphost1.log` |
| `testClaudeStopFromPreviousSessionDoesNotClobberClearRunningStatus` | lifecycle / process candidate | `matte-base-apphost3.log` |
| `testCodexHookInstallPrefersLaunchingAppBundledCLI` | fixture / expectation | `matte-base-apphost1.log` |
| `testCodexPromptSubmitCachesPromptForAutoNaming` | fixture / expectation | `matte-base-apphost2.log` |
| `testCodexPromptSubmitWithForeignBmuxEnvIgnoresStaleMappedSession` | production candidate | `matte-base-apphost1.log` |
| `testCodexPromptSubmitWithInvalidSurfaceDoesNotFallbackToFocusedSurface` | production candidate | `matte-base-apphost2.log` |
| `testDefaultFreestyleSSHAttachHonorsGenericCloudRetryEnvironment` | production candidate | `matte-base-apphost3.log` |
| `testGrokCompletionDoesNotResetStatusWhileSiblingSessionRuns` | lifecycle / process candidate | `matte-base-apphost1.log` |
| `testGrokNotificationHookUsesPayloadMessageAndStopDoesNotSendGenericNotification` | lifecycle / process candidate | `matte-base-apphost1.log` |
| `testGrokNotificationStillFiresOnRepeatedPromptWhenFeedTelemetryDoesNotReply` | lifecycle / process candidate | `matte-base-apphost4.log` |
| `testGrokSessionEndDoesNotDropRoutingForLaterChatMessages` | lifecycle / process candidate | `matte-base-apphost4.log` |
| `testGrokStopFallbackCompletionsFireForTwoConcurrentThreads` | lifecycle / process candidate | `matte-base-apphost1.log` |
| `testGrokStopNotificationFallsBackWhenTranscriptCwdIsUnavailable` | lifecycle / process candidate | `matte-base-apphost3.log` |
| `testHermesAgentNotificationsUseShellHookExtraPayload` | lifecycle / process candidate | `matte-base-apphost4.log` |
| `testHermesAgentSessionEndIsTurnBoundaryButFinalizeTearsDown` | lifecycle / process candidate | `matte-base-apphost1.log` |
| `testKiroFeedDenyUsesPreToolUseExitCodeTwo` | lifecycle / process candidate | `matte-base-apphost2.log` |
| `testRespawnPaneWindowFlagDoesNotBecomePositionalCommandText` | fixture / expectation | `matte-base-apphost2.log` |
| `testSSHForwardAgentTildeSocketPathExpandsSocketPath` | unresolved timing / environment | `matte-base-apphost1.log` |
| `testSSHPTYAttachBridgeEOFWhenSessionGoneClearsLocalState` | unresolved timing / environment | `matte-base-apphost3.log` |
| `testSSHPTYAttachBridgeEOFWhileSessionRunsExitsWithoutSSHRetryStatus` | unresolved timing / environment | `matte-base-apphost3.log` |
| `testSSHPTYAttachBridgeResetWhenSessionGoneClearsLocalState` | unresolved timing / environment | `matte-base-apphost4.log` |
| `testSSHPTYAttachWithoutSurfaceDoesNotSendLocalAttachEnd` | unresolved timing / environment | `matte-base-apphost3.log` |
| `testSSHPaneCloseSignalDoesNotReportSessionEndToSharedTransport` | fixture / expectation | `matte-base-apphost3.log` |
| `testSSHPaneCloseSignalDoesNotTerminateWrappedSSHChild` | fixture / expectation | `matte-base-apphost3.log` |
| `testSSHPreservesCallerAgentSocketForOpenSSHConfigResolution` | unresolved timing / environment | `matte-base-apphost1.log` |
| `testSSHSessionCleanupAllWorkspacesSessionIDReportsNotFound` | production candidate | `matte-base-apphost1.log` |
| `testSSHSignalDerivedChildExitReportsSessionEnd` | fixture / expectation | `matte-base-apphost1.log` |
| `testSSHSignalDuringReconnectDelayDoesNotStartAnotherSSH` | fixture / expectation | `matte-base-apphost2.log` |
| `testSSHStartupDoesNotRetryNonTransientSSHExit` | fixture / expectation | `matte-base-apphost2.log` |
| `testSSHStartupPrintsFinalErrorBannerWhenStderrIsCaptured` | fixture / expectation | `matte-base-apphost1.log` |
| `testSSHStartupRemovesStaleBmuxControlSocketBeforeLaunchingPaneSSH` | fixture / expectation | `matte-base-apphost3.log` |
| `testSSHStartupStopsAtConfiguredReconnectLimit` | fixture / expectation | `matte-base-apphost4.log` |
| `testTmuxCompatEnvStampsLaunchSurfaceNotFocusedPane` | fixture / expectation | `matte-base-apphost3.log` |

### Authorized next bounded slice

Only the cleanup error idempotency repair is selected for this branch; other
categories remain diagnosis and separately owned maintenance work. Proposed owner:
pure Sendable remote-error value in `BmuxCore/Remote`, with existing app/CLI adapters
and unchanged stable protocol diagnostics. Preserve CLI-only capability aliases
and allocation-detail disclosure policy. No retry or routing change in this slice.
Parent confirmed this plan. The new executable Swift Testing regression runs
against unchanged build773 CLI and records seven expected diagnostic failures
across fourteen parameter cases; native compile is warning-free. The shared
`CLISocketFixture` follows the reviewed PR146 readiness/cancel-join design, with
checked socket flags, unique readiness tokens, partial writes, owned file output,
and joined cleanup. Test-only CI red, shared Core implementation/package tests,
parent isolated build and final native/CI green remain pending.
Project Truth caveat `ssh_cleanup_error_idempotency_verification` stays open.

Guidance: root/personal AGENTS, continuous-code-quality, bmux-shared-behavior,
bmux-architecture (package DAG, file/API discipline, concurrency), bmux-testing,
bmux-socket-policy, bmux-dev-workflow and bmux-localization. Existing remote core
value `RemoteDropUploadError` separates protocol values from app-localized display;
actual ownership/localization decisions must remain explicit during implementation.
No active user build may be rebuilt or replaced; parent owns a new isolated tag
before a production push. PR144 packaging artifact verification is separate and
still awaits real dynamic Debug plus unsigned Release CI proof.

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
