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
and deadlines as its sibling regression steps. Run 38440609968, job 115447587212,
completed all nine functions across three suites in 0.464 seconds, followed by
`TEST SUCCEEDED` at 19:05:35 UTC on October 13. The broader shard then started
and remains incomplete. The preceding run also passed this focused gate but
hit inspector assertions during its broader shard before being superseded. The focused gate is
recorded as completed while the shared canonical and local caveat remains open
for full-suite verification.

The fixtures describe a live workspace/surface membership response instead of
returning an empty object to every JSON-RPC request. They preserve the original
transcript/payload, notification, status, and output assertions, including
current-turn error suppression. Notification assertions use the current
`notify_target_async` command. Unknown mock methods fail the test.

Each fixture owns its HOME, CFFIXED_USER_HOME, CODEX_HOME, hook-state directory,
Unix socket, and input/output files. The shared `CLISocketFixture` bridges
nonblocking socket readiness into one async capture task; it awaits descriptor
cancellation before removing the socket. `CodexStopHookFixture` uses the existing
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
  bind/listen result -1. The legacy helper asserts length then continues copying; fix
  fixture path ownership and fail invalid prerequisites before memory writes.

### Lifecycle/process candidates (13)

Nine generic-hook cases time out (Antigravity, six Grok, Hermes finalize, Kiro),
and four wait for mock completion (three Claude lifecycle cases, Hermes extra
payload). Shared `CLIMockSocketServerSupport` queues 80/128 blocking accept/read
blocks on global user-initiated workers without joined listener cancellation.
`CLINotifyProcessTestSupport.runProcess` queues process waiting on the same QoS,
output drains on utility workers, then blocks on a semaphore. Some tests read
`state.commands` outside its lock instead of `snapshot()`.

Antigravity's baseline has repeated timedOut=true with empty stdout and status 0
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
  at 12208. Both CLI and app sanitizers only match `not running`, which does not
  match `no longer running`; the CLI reports generic failure. Baseline apphost1
  at 2026-10-10T18:05:24.777 fails line 5291, while exit 1, no close and session-ID
  assertions pass. Other canonical diagnostics also need round-trip coverage.
- Cloud retry mock returns typed `vm_cloud_service_unavailable`, but classifier
  at 10925 recognizes other text/codes; one RPC instead of two is observed. Inspect
  the documented typed retry contract before changing any retry policy.
- Invalid/foreign Codex surface cases actually set running/resume metadata on
  focused/mapped surfaces. `resolveAgentHookTarget` at 30666 falls through preferred,
  mapped and default surface; stale-ambient recovery documentation at 30460 says
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

The parent separately owns the eight startup protocol fixture repairs.
Only the cleanup error idempotency repair is selected for this branch; other
categories remain diagnosis and separately owned maintenance work. Proposed owner:
pure Sendable remote-error value in `BmuxCore/Remote`, with existing app/CLI adapters
and unchanged stable protocol diagnostics. Preserve CLI-only capability aliases
and allocation-detail disclosure policy. No retry or routing change in this slice.
Parent confirmed this plan. The new executable Swift Testing regression runs
against unchanged build 773 CLI and records seven expected diagnostic failures
across fourteen parameter cases; native compile is warning-free. The shared
`CLISocketFixture` follows the reviewed PR 146 readiness/cancel-join design, with
checked socket flags, unique readiness tokens, partial writes, owned file output,
and joined cleanup. Test-only commit `606e4e8b0` is pushed in PR 148. The local shared Core classifier
and adapters have independent review with no blockers; all 44 BmuxCore test
functions in nine suites pass, including 29 new parameter cases. Exact canonical
messages also survive the existing `remote_pty_error:` envelope. CLI-only aliases
and allocation-detail passthrough remain outside Core; the app retains its
stricter disclosure policy. The app's existing string adapter is internal solely
for direct native policy verification. Source budget, strict test determinism,
pbx wiring and Project Truth checks pass. The parent-built isolated tag `ssh-cleanup-idempotency`, build 776, succeeds
without launch. All 27 native parameter cases (five functions, two suites) pass
against that artifact's real bundled CLI and app dylib; fixture compilation is
warning-free. Evidence: `/tmp/ssh-cleanup-native-green.log` and
`/tmp/ssh-cleanup-native-fixed-compile.log`. Actual test-only CI job 114953934391 on commit 606e4e8b0 completed the
SSHCleanupErrorTests suite with the seven expected diagnostic issues before its
legacy wrapper truncated later output. The job badge incorrectly reports success
because of that separately repaired PR 142 reporting defect; the completed suite
log is the red evidence, not the badge. The production fix can now be pushed;
fixed app-host CI and the full-suite gate remain pending.
Localization/disclosure audit confirms all nine protocol diagnostics are
byte-identical to the pre-existing CLI strings. No new UI wording or catalog keys
are introduced; existing protocol text and CLI presentation remain English.
Project Truth caveat `ssh_cleanup_error_idempotency_verification` stays open.

Guidance: root/personal AGENTS, continuous-code-quality, bmux-shared-behavior,
bmux-architecture (package DAG, file/API discipline, concurrency), bmux-testing,
bmux-socket-policy, bmux-dev-workflow and bmux-localization. Existing remote core
value `RemoteDropUploadError` separates protocol values from app-localized display;
actual ownership/localization decisions must remain explicit during implementation.
No active user build may be rebuilt or replaced; parent owns a new isolated tag
before a production push. PR 144 packaging artifact verification is separate and
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

## SSH startup lifecycle fixture repair (2026-10-12)

The signal, retry, stdin and control-socket checks use the maintained CLI
protocol. `vm ssh` requests `vm.ssh_info` with only `id`, and workspace-create
replies include the created `surface_id`. The original mock rejected that
request or forced discovery/rollback before reaching the behavior under test.

Build 779 exposed a second fixture defect hidden by build 773's reusable-shell
exit-status bug: the stale control-socket test selected managed PTY attach but
mocked only shell SSH. Its generated command invoked the real `ssh-pty-attach`
against a nonexistent socket. Stale-path removal succeeded; attach failed.
The old wrapper masked that failure as exit 0, so the earlier ten-check baseline
pass (`/tmp/ssh-startup-lifecycle-green.log`) did not prove successful attach.
The observed build-779 failure is in `/tmp/ssh-lifecycle-779-native.log`, with the
actual generated attach command in `/tmp/ssh-stale-control-779-generated.sh`.

Only this touched case migrates to `SSHStaleControlSocketTests` (Swift Testing).
The other nine XCTest methods keep their existing assertions. The new
`SSHStaleControlSocketFixture` owns a short temporary home, stale UNIX socket,
fake SSH preflight, CLI command generation, owned output files and explicit
workspace/surface protocol replies. `SSHExitedPTYClient` supplies one exited
remote session to the existing production `RemotePTYBridgeServer`; no separate
TCP bridge implementation is introduced. Raw-SSH mode would skip the managed
attach boundary that exposed the false pass, so the fixture retains it.

The real bridge owns token validation, ready/EOF delivery and network lifetime.
Its legacy blocking listener-start API runs on a dedicated thread behind a
checked continuation; it never blocks Swift's cooperative executor. The fixture
awaits the bridge's stop signal and shared `CLISocketFixture` descriptor teardown
before deleting its owned files. Process output uses positional shell redirects
with existing `CommandRunner`; no new process transport or timeout is added.

`CLISocketFixture` is shared with notification fixtures. This use exposed a Darwin
peer-close edge: setting `SO_NOSIGPIPE` again on an accepted socket after its peer
has disconnected returns EINVAL. A native local probe confirmed accepted sockets
inherit the listener's value for live and closed peers. Set it on the listener
before accepting clients; keep nonblocking/CLOEXEC flags on every descriptor.
`/tmp/ssh-control-779-flags-trace.log` retains the original readiness failure.
`/tmp/ssh-control-nosigpipe-probe.log` also proves a closed-peer write returns
EPIPE with inherited protection, while its unprotected subprocess dies from
SIGPIPE; the correction does not disable signal protection.

The test retains exit 0, no timeout, stale-file removal and `-G`/`-O check`
assertions. It additionally requires removal before the managed attach request,
a successful real bridge attachment, and the exact ordered target-specific
bridge/session-query/attach-end/terminal-session-end requests. These checks catch
an omitted attach mock even when an older wrapper masks the native exit status.

All ten checks pass against both unchanged build 773 and fixed build 779
(`/tmp/ssh-lifecycle-repaired-773.log`, `/tmp/ssh-lifecycle-repaired-779.log`).
A temporary missing-attach mock control on 773 retains the misleading native
exit 0 but fails the new stderr, bridge-attachment and cleanup-sequence assertions
(`/tmp/ssh-control-773-missing-attach.log`). Actual pushed-head app-host CI remains
pending. The existing Option/Alt invocation selects the nine
legacy lifecycle methods and new managed cleanup suite without another runner
or changing full coverage. Canonical and local Project Truth caveat
`ssh_startup_lifecycle_focused_gate_verification` remains open.

Guidance: root/personal AGENTS, continuous-code-quality, testing (migration,
behavioral quality and wiring), architecture (file ownership and concurrency),
shared-behavior, socket policy and dev workflow. Maintained owners include
`BMUXCLI.runSSHWithOptions`, `runSSHPTYAttach`, `handleSSHPTYBridgeEOF`,
`RemotePTYBridgeServer`, `AppRemotePTYBridgeStrings` and the shared socket fixture.
The retained redundant Void-discard warning in `CLINotifyProcessTestSupport:54`
is outside this patch. No production code, shipped strings, localization catalogs,
app launches, builds or real app/socket state changes are part of this repair.
The separate manual reconnect production repair remains outside this PR.
## Browser initial lifecycle regression (2026-10-12)

A deferred URL or URLRequest is retained by `BrowserPanel.init`, and the panel
correctly avoids navigation and the new-tab UI, but its published lifecycle and
`webViewLifecycleTopPayload` remain `new_tab` until a visibility callback arrives.
The two existing failing deferred-URL XCTest methods are migrated to the wired
`BrowserInitialLifecycleTests` suite. It covers both URL and request construction,
new-tab controls with both render flags, initial wire payloads, and visibility
changes without triggering network navigation. Owned panels close synchronously.

Native tests against the existing build774 app dylib reproduce four initial-state
assertion failures across the two deferred cases; both empty-panel controls pass.
The initialization/lifecycle owners are unchanged from main in that artifact;
build774's unrelated theme-default migration does not modify them. Evidence:
`/tmp/browser-initial-native-red.log`; compilation has no warnings. Existing
baseline CI also records both deferred-URL failures. Actual new-test CI red is
required before pushing a fix. The focused browser gate selects this suite in
its existing runner. No production files are changed in the regression commit.

Planned correction belongs to the existing BrowserPanel initializer and its
`refreshWebViewLifecycleState` projection, after initial navigation intent is set,
including the deferred early-return branches. It must not navigate, defer state
writes to view rendering, add a second lifecycle owner, or change discard policy.
Rules: `AGENTS.md`, continuous-code-quality, `skills/bmux-architecture/` and
`skills/bmux-testing/`. Complete initializer, state projection, visibility and
socket payload callers are the review boundary. Existing discard/restore and
WebKit portal failures remain separate unresolved gates. No shipped text changes.

## Claude notification target fixture maintenance

Two baseline failures were stale status expectations, not wrong-target mutations:
`testClaudeNotificationFallsBackToLiveWorkspaceInsteadOfFocusedTab` and
`testClaudeNotificationHonorsExplicitWorkspaceHandleRef` in
`CLINotifyClaudeHookWorkspaceRoutingTests.swift`. Baseline logs
`/tmp/matte-base-apphost2.log` (2026-10-10 18:07:09Z) and
`/tmp/matte-base-apphost3.log` (18:01:58Z) show the correct target workspace/surface,
but `Idle` instead of the old expected `Needs input`.

Commit `f62cae83f` deliberately stopped treating generic Claude notification
heartbeats as blocked input. The maintained `classifyClaudeNotification` and
notification lifecycle owner keep plain heartbeats idle while explicit permission
prompts remain `Needs input`. The repaired fixtures retain the original generic
payload and add a permission payload to each of the same two routing scenarios.
Both status and notification must address the exact target workspace and surface;
stale and focused workspaces remain forbidden mutation targets.

The two routing methods migrate to `ClaudeNotificationTargetTests` (Swift Testing).
`ClaudeNotificationTargetFixture` owns each short temporary root, state file,
input/output files and isolated process environment. The shared `CLISocketFixture`
is byte-identical to the SSH cleanup maintenance fixture, with the same project
identity for later integration. Its native readiness stream joins descriptor
cancellation before removing files. The responder drains id-less `feed.push`
telemetry without replying, matching the production frame at `CLI/bmux.swift`.
Unexpected command mutations fail the test. No app or CLI production code changes.

Evidence against unchanged tagged build 773:

- The original `Needs input` expectation reproduces exactly two failures, one
  per generic-heartbeat routing case; permission variants and original forbidden
  target assertions pass. `/tmp/claude-target-native-old-expectation.log` preserves
  actual command traces.
- Corrected expectations pass all four payload/routing combinations in two test
  functions. `/tmp/claude-target-native-green.log`; compilation is warning-free.
- A separate temporary misrouting control redirects resolution to the focused
  workspace to verify the exact-target and forbidden-target assertions remain
  effective: all four combinations fail their exact-target and forbidden-target
  assertions (12 issues), `/tmp/claude-target-misroute.log`. The checked-in fixture
  is unchanged by this control.

The dedicated `ClaudeNotificationStatusLifecycleTests` now reuses the same async
fixture with an explicit agent PID and caller workspace/surface configuration.
Its heartbeat case expects `Idle`; its permission case expects `Needs input`.
Both require exactly one status with the exact target and PID, plus the matching
lifecycle command. The fixture reports an empty process inventory for the CLI's
PID lookup, leaving the explicit caller IDs responsible for routing. The original
four routing cases and their forbidden stale/focused target assertions remain.

The old lifecycle harness used blocking process/semaphore waits and a socket
responder that acknowledged even id-less telemetry; retained full-suite evidence
in `/tmp/matte-stage5-apphost4.log` (2026-10-11 05:44:39Z, lines 199587–199594)
records a socket wait timeout, process status 15 and missing status. Reusing the
joined async socket and owned-file capture removes those fixture paths without
increasing the five-second process deadline. This local proof does not establish
the cause of every historical full-suite timeout.

On unchanged build 773, the temporary old heartbeat expectation fails exactly
once with `Idle` and `--pid=42424` in the actual command; permission and all four
routing controls pass (`/tmp/claude-pid-native-old-expectation.log`). Corrected
source passes six parallel cases across three test functions in two suites
(`/tmp/claude-pid-native-green.log`), with warning-free native compilation. This
verifies PID metadata required by stale sweeping; it does not run the sweep or
claim full app-host execution.

The existing app-host shard 2 now runs both suites explicitly before broad legacy
tests. Actual focused app-host CI and broader suite results remain pending;
Project Truth caveat `claude_notification_target_fixture_verification` stays open.
No reload or app launch is needed for this test-only correction.

Guidance applied: root/personal AGENTS, continuous-code-quality,
bmux-testing (incremental Swift Testing, behavioral coverage, wiring and native
versus CI proof), architecture (file ownership and concurrency), shared-behavior,
socket-policy and dev-workflow. Independent review found no blocker. Localization
audit: test data and contributor diagnostics only; no shipped wording or catalogs
changed. The legacy ambiguous-TTY and active-pointer tests remain untouched.


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

## Codex rejected ambient identity regression

The focused `CodexRejectedAmbientTests` gate runs before the broad app-host suite
on shard 2. The shared generic-hook target resolver now retains rejected ambient
provenance: a rejected workspace or surface requires verified PID/TTY attribution
before any session, resume, status or feed mutation. Explicit invalid flags still
stop routing; valid remote-like ambient identity and valid saved mappings remain
supported. The stop branch also suppresses deferred generic feed telemetry when
target resolution rejects the event, so that fallback cannot resurrect a rejected
workspace. Successful stop publication and lease retirement keep their existing
owners and ordering.

The fixture owns an isolated HOME/session store, temporary socket, joined socket
lifecycle and file-backed process I/O. Its shared `CLISocketFixture` is the exact
reviewed PR 169 transport. Tests preserve every earlier assertion and cover sixteen
parameter cases: four prompt rejections, four stop rejections and eight recovery,
explicit-flag and valid-identity controls. No timing or assertion is relaxed.

Original actual CI job 114969430201 reproduced wrong-target commands and persisted
running state, alongside the accepted-socket EINVAL fixture race. Unchanged build
773 fails the four prompt cases with 22 assertions. Build 778, containing the held
prompt correction, passes twelve cases but fails the four new stop cases on
unexpected feed.push. Test-only commit 6968859d9 publishes that additional regression;
its actual app-host red remains required before publishing the complete fix.

Fresh isolated build 781 (`codex-routing-stop-recovery`) succeeds without launching
the app. Its actual bundled CLI passes all sixteen routing cases with warning-free
Swift 6 fixture compilation, plus thirteen valid stop payload/transcript/turn-scope
cases across nine functions. Independent review checked the resolver, stop path,
deferred telemetry and unchanged lifecycle ordering. The production correction is
committed locally and held for the regression gate. Full fixed-head app-host CI and
combined validation remain pending; these focused results are not broad-suite green.
The local Project Truth verification caveat stays open.

Source requirements: root/personal `AGENTS.md`, `continuous-code-quality`, and
`bmux-architecture`, `bmux-testing`, `bmux-shared-behavior`, `bmux-socket-policy`,
`bmux-dev-workflow` and `bmux-localization`. Maintained references are the verified
PID/TTY recovery regression, sibling rejected-target telemetry guards, joined
`CLISocketFixture`, and owned-file CLI capture. Localization audit: no shipped
strings or catalogs change. Running builds 773/775 remain untouched.

## Resume policy executable fixture maintenance

Five obsolete `SessionPersistenceTests` expectations are reconciled with current
shared owners. Commit `9374b139e1` deliberately retains a restorable/forkable
session when its saved PID has died, while clearing live process evidence. The
existing `RestorableAgentSessionStalePIDTests` already verifies that behavior and
live-record precedence, so the contradictory nil-snapshot test is removed rather
than duplicated with a different expected value.

Four Hermes tests previously compared raw shell substrings that changed when the
startup command acquired nested environment quoting. `HermesResumeExecutionTests`
executes the actual `Workspace.surfaceResumeStartupInput` output with owned fake
executables, a temporary HOME/configuration and an isolated inherited cwd. A
NUL-delimited recorder verifies exact argv and order, captured versus PATH
executable identity, cwd before every bootstrap step, provider/base URL/API mode/
model configuration, stale-provider rewrite, and explicit-provider no-bootstrap.
The guarded relative executable uses a directory containing spaces and an
apostrophe. A separate owned PATH executable catches captured-path substitution.
No network request or real Hermes process is involved.

Actual unchanged build 773 native execution passes four Hermes cases plus the two
existing stale-PID cases (three functions/two suites), with warning-free focused
compilation. The original five expectations have retained actual baseline CI red
logs; no synthetic production regression or link-policy change is introduced.
The existing focused browser gate also runs these two suites, without adding a
runner. Final app-host CI remains pending and the broad baseline is not claimed
green. The deleted-agent-cwd metadata test is untouched: its terminal-runtime
metadata policy remains a separate unresolved question, even though prior shell
execution probes passed.

Guidance: root/personal AGENTS, continuous-code-quality, bmux-testing and its
migration/behavioral/local-vs-CI references, architecture ownership/file/API/
concurrency guidance, shared-behavior and dev-workflow. Inspected owners include
Workspace's restore-policy composition, WorkspaceSessionRestorePolicyService,
WorkspaceHermesAgentCommandBootstrapper, SurfaceResumeBindingSnapshot/environment
rendering, HermesAgentCodexEnvironment and RestorableAgentSessionIndex. No shipped
strings, settings, production source, or localization catalogs change. All other
SessionPersistenceTests methods remain byte-identical to the feature baseline.

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

### Claude SessionEnd replacement scope fixture

The legacy consumed-workspace test seeded the active session in a sibling pane
while expecting it to suppress cleanup in the exiting pane. The maintained
ClaudeHookSessionStore.isCurrent policy explicitly permits independent sibling
panes (upstream issue 5908) and suppresses a replaced session in the same pane.
Actual baseline app-host logs fail only the two visible cleanup assertions;
consumption already succeeds. An isolated unchanged build 773 CLI probe reproduces
the distinction with both explicit session IDs and surface fallback routing.

The migrated Swift Testing suite seeds a replacement in the same pane. Its old
record is most recently updated, so fallback consumes that record; the explicit
active boundary still controls cleanup. Four cases cover legacy workspace-only
active state and current per-surface state, with and without an explicit session
ID. They retain the different caller/consumed workspace, consumed-record deletion,
and no PID/status/notification cleanup assertions, and add preservation of the
active record and both active boundaries plus exact resume-clear targeting.
The sibling-pane and stale-turn tests remain unchanged. No production policy or
routing changes are included; workspace-wide notification semantics are not
redesigned by this fixture repair.

Guidance: root AGENTS, continuous-code-quality, bmux-testing and migration/wiring
references, bmux-architecture, bmux-shared-behavior and bmux-socket-policy. Complete
consume/isCurrent/fallback/active-slot migration and SessionEnd caller paths were
inspected. The fixture owns temporary state and process I/O; it uses the shared
async CLISocketFixture transport from the notification fixture maintenance and
owned output files to avoid blocking cooperative pipe readers. It contacts no
real app socket and does not modify real preferences or hook state.

All four native cases pass against unchanged build 773, with warning-free focused
compilation. A temporary negative control restores the erroneous sibling-pane
active record and fails all four cases, preserving the protection being tested. Actual app-host CI and broad-suite integration remain pending in the
canonical/local focused-gate caveat. There are no shipped strings or catalog
changes; changed text is contributor verification documentation only.

### Cloud attach retry fixture contract

The old `testDefaultFreestyleSSHAttachHonorsGenericCloudRetryEnvironment` failed
because it promoted the backend's `vm_cloud_service_unavailable` to a top-level
socket error and expected obsolete `0s` wording. The current chain is HTTP 502
from the VM route, `VMClientError.httpStatus` formatting, then
`TerminalController.v2VmCall` wrapping that description with socket code
`vm_error`. HTTP status remains in the description and the CLI already retries
it. The introducing commit `bd0b24b74` also used the localized zero-delay label
`now`; this slice changes no retry or presentation policy.

`CloudAttachRetryContractTests` replaces only that legacy method. Its fixture
uses the actual native formatter and reviewed shared `CLISocketFixture` with
owned file capture. Twenty-one cases exercise SSH, PTY and session-PTY attach:
generic environment precedence, legacy fallback, zero retry limit, non-default
attach, reconnect notice suppression, permanent failure and missing VM. Requests
retain exact VM/session/attachment parameters; retries get fresh request IDs;
final errors and exit 1 remain observable. Missing VMs never trigger creation or
another mutation. Responses always fail, so no SSH or WebSocket connection starts.
All other methods in VMDefaultCloudCommandTests remain byte-identical.

Actual unchanged build 773 passes all 21 cases with warning-free focused compile.
A temporary negative-control fixture sets the generic limit to zero for the three
override cases: exactly those cases fail their count/notice assertions while the
other 18 pass. The original baseline failure and independent socket diagnosis are
retained. Actual app-host execution of the new suite remains pending; the broader
baseline suite is not claimed green. The existing focused browser app-host step
includes this suite without adding a runner; canonical/local Project Truth
caveats track the open verification gate.

Guidance: root/personal AGENTS, continuous-code-quality, bmux-testing migration/
behavior/local-CI references, architecture file/API/concurrency rules, shared
behavior, socket focus policy and observability error propagation/safe logging.
Inspected boundaries include both shared CLI attach retry loops, SocketClient
error formatting, VMClient HTTP errors, the socket VM adapter and VM route error
policy. Bare typed socket errors remain unsupported by the current classifier;
no new typed socket contract or production classifier expansion is introduced.
No shipped strings, localization catalogs, app settings or runtime files change.

## Local maintenance integration checkpoint (2026-10-12)

The isolated `maintenance-validation` branch composes the following published
heads from `ce17e9888a6dce4d2e5755795946b68cf52f0329`. This is a local validation
checkpoint, not a merge into main, a published CI result, or an app build.

| PR | Published source commit |
| --- | --- |
| #141 | `00b4a21d4069f53857fb0b87a17a347b4668d06e` |
| #142 | `5117031ee1f6054f5246de3f76ba6a5153bd2101` |
| #143 | `81cfc3b0369a74a0a42d92f1b84e1393eeaa2716` |
| #144 | `4b3c2a5314aad630c1429a32dac8a557b3c047b5` |
| #145 | `b275c76c3d1a14aec865f07de8d7b2cfa96c92cc` |
| #146 | `7f48a469821734062ad0c8de95da690cea3e5f4c` |
| #147 | `537681592de0f1a51b00308a2fa3834f31959b49` |
| #148 | `bcdee5e1638ba65e6c1d2af7bad6df533f6e0226` |
| #149 | `2b8592920ed58232e9506c14ba6e4842d2982f14` |
| #150 | `cf9e78dcb5df8dbc4dbadd82df673492ad33cbdf` |
| #151 | `6e366325cbcc173a2ae2f1ec58bb4979feccae3d` |
| #152 | `637ae2ede4f18445487574e29988b1aa1befca04` |
| #153 | `36114abc088693f49a5162089461e8eb76560a00` |
| #154 | `b25ad79c66f064dfad82754642666b5fcf22a2a8` |
| #155 | `950d8bbd4be55e5f31c09606a5997faf5c5ab039` |
| #156 | `d5350d19b490fc1d3505dfeb635513be0d672c49` |
| #157 | `78cbde9b63acb7ea92929ca17ce9e4bc73fd68fb` |
| #158 | `83ff7d17c9cefb5be4ca644c558ea60251b67073` |
| #159 | `994e34f6512abf871b839b7957d56f2739671314` |
| #160 | `d58ea8aaa63284b48302763446964f74cbd94524` |
| #161 | `93abeaa9bc8560190dc40b0464bfa1901eff73b7` |
| #162 | `90503d88c5f4cb0f69745dfb6b886755fe3ece12` |

PR142's authoritative framework-aware test runner is integrated before the
maintenance suites. All source-head focused selectors and the full legacy suite
remain enabled. Merge resolution unions test wiring and canonical/local caveats;
generated documents are regenerated. Repeated group references to the single
shared CLISocketFixture are removed without duplicating its source build entry.

The published PR143 and PR148 fixes follow actual test-only CI failures: browser
startup migration produced four issues in job 114950761885; SSH cleanup produced
seven diagnostic issues in job 114953934391. The latter suite completed before the
old runner terminated other active Swift Testing work and incorrectly returned
success. Its green job badge is not a passing-suite claim.

PR151, PR153 and PR155 contain only their published failing tests here. Their
reviewed production fixes remain excluded until actual red CI is captured. The
PR150 managed-attach fixture follow-up is included with its listener-only
SO_NOSIGPIPE correction in the one shared socket fixture. Ten lifecycle checks
pass on both 773 and 779, and missing-attach and unprotected-write negative
controls establish sensitivity. The targeted combined-source transport batch described below passes.
Existing user builds 773 and 775 remain untouched.

Local checks pass: framework-aware PTY helper behavior, four exit-reporting tests,
app-host retry/attempt guards, sharding coverage, Xcode normalization, test wiring
(479 files), strict determinism (zero findings), source budget against ce17, YAML
parsing, and focused-selector preservation across every listed input. The source
budget permits existing incidental growth of five MainWindowFocusController
lines; no budget waiver was added.
No full combined test-target compilation or suite execution, dynamic/Release
artifact verification, or complete authoritative CI run has occurred yet. These remain
required gates; separate local native results do not substitute for them.

Reassessment follows root/personal AGENTS, continuous-code-quality, bmux-testing,
architecture and shared-behavior guidance. The accumulated production changes
retain existing browser theme resolution, matte appearance ownership and the
shared safe PTY diagnostic classifier. Held initializer, reconnect and rejected
ambient-target changes have not been accepted implicitly through conflicts.
There are no new shipped strings in this integration-only resolution.

### Shared socket fixture integration check

The exact merged sources at `7e0a5f667` compile without warnings against the
existing isolated build 778 module and CLI. The batch passes 43 parameter cases
across nine test functions and five suites: Claude notification routing and PID
lifecycle, Codex rejected ambient recovery, Claude SessionEnd scope, and Cloud
attach retry contracts. The shared listener-only SO_NOSIGPIPE correction is used
by every case; no helper implementation is substituted. The only standalone
harness seams select the existing CLI path and invoke Swift Testing.

Logs: `/tmp/maintenance-shared-socket-compile.log` and
`/tmp/maintenance-shared-socket-native.log` (exit 0, 0.647 seconds). This is
combined test-source/transport proof, not full integration proof: build 778
contains the reviewed but still unpublished PR155 runtime correction, whereas
the local composition still includes that PR's test-only published head. No app
was built, launched, reloaded or quit. Complete combined compilation/runtime and
authoritative CI/artifact gates remain open.


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
three touched application-domain defaults values (including absent keys, without
promoting registered/global fallbacks); no global environment provider or settings-store
replacement is used. Dark, light and system launch cases assert one application
appearance, zero startup terminal synchronization, an inert deferred drain and
unchanged reload, then one changed-mode application and synchronization with the
exact source. Repeated reload/deferred calls add no effects. System startup uses
the injected system appearance; switching back to system clears the app override.
All other legacy methods remain byte-identical.

Focused Swift 6 compilation is warning-free against unchanged build 777. All
three native cases pass. An additional native runner registers a system fallback
and verifies all three originally absent application-domain keys stay absent
after the suite, while the registered fallback remains visible. Each case seeds
the legacy auto value before import so host registration cannot skip the import.
A temporary negative control reinstating the obsolete
no-launch-appearance and no-reload-sync expectations fails exactly six assertions
across those three cases. No app build, launch, user settings change or production
edit is required. Actual app-host execution remains pending; the existing focused
browser app-host step includes the suite, tracked by matching canonical/local
Project Truth caveats. Broader legacy CI is not claimed green.

Guidance: root/personal AGENTS, continuous-code-quality, bmux-testing migration,
behavior and local/CI references, architecture ownership/file/concurrency rules,
and shared behavior. Reviewed owners are the file store's init/reload/managed
side-effect pipeline and AppearanceSettings' injected launch/live application.
The existing UserDefaults-backed production storage remains unchanged; synchronous
ownership avoids yielding while test defaults are installed. No shipped copy or
localization catalog changes are introduced.

The reviewed PR161 fixture is now included: the same appearance owner is checked
through constructor-injected effects, with exact application-domain defaults
restored after each synchronous case. All 21 source-head selector sets remain
present; the final local wiring count is 479. Determinism, source budget, sharding,
normalization and Project Truth checks pass again after this addition. This
test-only integration does not alter the earlier shared-socket runtime result.

### Agent launch environment persistence fixture

The legacy session-start fixture rejected every socket request, including the
current `surface.list` identity validation. Its persisted-record assertion failed
on the base branch because the hook correctly ignored that inaccessible target.
The replacement models an accessible workspace and surface through the actual
bundled CLI. Two Swift Testing cases preserve the exact environment allowlist
assertion: `CODEX_HOME` survives, while `PATH`, `SHELL` and other fixture state do
not. A home path with spaces remains covered. Captured executable, launch cwd,
source and sanitized arguments are also checked.

This is a test-only baseline repair for the matte integration. Runtime routing,
launch capture trust and the environment policy are unchanged. All other legacy
tests in WorkspaceRemoteConnectionTests remain byte-for-byte unchanged. The
fixture owns its temporary directory, process environment, output files and
mock socket; shared CLISocketFixture owns asynchronous transport and cleanup.
No real app socket, preferences or running build is touched.

Guidance: root AGENTS, continuous-code-quality, bmux-testing with migration,
regression/wiring and local-vs-CI references, bmux-architecture file/API discipline,
and bmux-shared-behavior/socket policy. The session-start target validation,
AgentLaunchCaptureTrust, launch sanitizer and environment policy paths were
inspected. Both native cases pass unchanged build 773 with warning-free focused
compilation. A temporary negative control restoring the old rejecting mock fails
both persisted-session assertions. Actual app-host CI and combined full-suite
validation remain pending in the canonical/local focused-gate caveat. No shipped
strings or catalogs change; localization audit covers contributor notes only.

### First combined CI dispatch boundary

PR162's reviewed session-start environment fixture is included with the existing
shared socket helper. The composition now preserves all focused selectors from
22 exact published heads and wires 481 test files. The conflicting adjacent
legacy launch-environment and Codex Stop methods were both already migrated;
resolution removes only the former from the prior integrated file.

One ordinary push of this validation branch and manual dispatch of CI and
Project Truth is authorized. No PR or main merge is created, and no source PR
branch changes. The existing workflow runs all four full native shards, focused
gates, package tests, build/lag, Release and unchanged-artifact relocation checks.
It adds eight macOS jobs and ten Linux CI jobs, plus one Linux Project Truth job;
queue time and execution results are unknown. The dispatch uses its own branch
concurrency group with cancellation disabled. No existing run is canceled.
Held PR151/153/155 production fixes remain excluded; expected regression failures
are evidence to inspect, not a reason to weaken gates. Subsequent new PRs do not
supersede or silently rerun this exact batch. The separate native proof above
remains limited to its recorded source/artifact pairing.
### SSH workspace creation fixture

The legacy SSH creation test omitted the terminal surface ID from its
`workspace.create` response and rejected `surface.list`. Persistent SSH PTY
startup therefore correctly failed target resolution and attempted rollback,
instead of reaching the configuration assertions. The fixture now represents
the current create response. A second case exercises the supported fallback
where an older create response omits the surface but `surface.list` supplies it.

Both Swift Testing cases retain the original exit/output, ordered requests,
window selection, SSH destination/port/identity/options, relay/auth metadata and
nonempty startup-command assertions. Every other legacy test remains unchanged.
No production code, terminal rendering, network service or running app changes.
The fixture owns its process environment, state/output files and mock socket;
the reviewed shared CLISocketFixture owns asynchronous transport and cleanup.

Guidance: root AGENTS, continuous-code-quality, bmux-testing and migration/wiring/
local-vs-CI references, architecture file/API discipline and socket focus policy.
The complete workspace create/resolve/configure/select/rollback owner was
inspected. Both cases pass unchanged build 773 with warning-free focused
compilation. A temporary negative control restoring the omitted surface and
rejected lookup fails both cases on the original observable assertions.
App-host CI and combined full-suite verification remain pending under the
canonical/local focused-gate caveat. Localization audit: no shipped strings or
catalogs change; contributor verification documentation only.
### SSH agent environment fixtures

Two legacy SSH agent tests relied on obsolete fixture assumptions. The tilde
case changed `HOME` but not Foundation's home override, so the owned candidate
was not found and the inherited agent path won. The caller-socket case required
all `ssh_options` to be absent, although the CLI now adds multiplexing defaults.
Neither failure demonstrates a production forwarding defect.

The migrated Swift Testing cases own both `HOME` and `CFFIXED_USER_HOME`, the
caller agent path and the optional tilde candidate. They verify the exact path
in both workspace initial environment and remote configuration, preserve the
explicit tilde option, and check that the no-option path adds no ForwardAgent
override while permitting other defaults. A missing-candidate control verifies
fallback to the owned caller path. Every other legacy method remains unchanged.
The existence-only lookup uses owned empty files; no agent traffic is sent.

Guidance: root AGENTS, continuous-code-quality, bmux-testing with migration,
wiring and local-vs-CI references, architecture/file discipline and shared/socket
policy. Complete SSHAgentSocketResolver path resolution and the CLI forwarding
selection/create/configure owners were inspected. Process environment, outputs
and mock socket are isolated; transport uses the reviewed CLISocketFixture.
No production, OpenSSH policy, terminal renderer or running app changes.

Three native cases pass unchanged build 773 with warning-free compilation. A
temporary negative control restoring HOME-only isolation and the nil-options
assertion reproduces both original failures; the missing-candidate control
still passes. Actual app-host CI and combined full-suite verification remain
pending under the canonical/local focused-gate caveat. Localization audit: no
shipped strings or catalogs change; contributor verification notes only.

### SSH PTY bridge lifecycle fixtures

Four legacy CLI tests expected an initial resize before every bridge EOF/reset,
but their mock accepted only one RPC connection. Since `643906256`, resize uses
an independent bounded connection and pending resize may be cancelled by EOF.
The baseline app-host logs fail only that method-array expectation; the exit,
error, detach and local attach-end assertions pass.

`SSHPTYLifecycleContractTests` migrates those four methods to sixteen real-CLI
cases: running session, gone session, absent surface and reset, each with a pipe
(80×24) or PTY (132×43), and immediate or resize-acknowledged bridge closure.
Immediate closure preserves the exact lifecycle sequence and validates any
resize that wins cancellation. The second path closes only after the RPC mock
writes the complete resize reply and requires exactly one resize with the exact
workspace/session/attachment/token/dimensions before session reconciliation.
Running sessions still return 254 and detach; gone/reset sessions return zero
and clear the local surface; absent surfaces never detach or clear one.

Ownership follows `AGENTS.md`, the continuous-code-quality skill, bmux testing
migration/behavior/local-vs-CI references, architecture concurrency/file rules,
and socket focus policy. The maintained `643906256` adjacent cleanup test and
`CLISSHPTYResizeInputTests` establish the separate connection and native PTY
contracts. The shared `CLISocketFixture` retains its reviewed transport and
adds an optional response-written AsyncStream signal; the bridge and output
channel own and join their native readiness sources. These tests use only
owned loopback sockets, temporary homes, subprocesses and descriptors. No
production or renderer behavior changes, global settings, app launches or
new user-facing copy are involved.

Local native compilation against unchanged build 773 is warning-free; all
sixteen cases pass. A transport negative control suppressing resize requests
fails all eight acknowledgement-gated cases at the bounded process deadline,
while the eight immediate-close cases still pass. This demonstrates that
accepting cancellation does not remove positive resize coverage. The focused
browser-proxy app-host invocation includes this suite. Actual app-host CI
execution remains pending under `ssh_pty_lifecycle_fixture_verification`;
these local results do not establish full-suite acceptance.

The output-channel fixture resolves each PTY path with `ttyname_r` and an owned
buffer so parallel cases cannot race over `ttyname` static storage. A temporary
concurrent native probe retained eight PTYs at once across eight batches and
verified distinct paths plus exact marker delivery to each corresponding master.
The sixteen CLI cases and constructor-failure cleanup proof also pass after
this correction; app-host CI remains pending.
### Consolidated SSH transport fixtures review boundary

This branch consolidates #150, #160, #164, #167, #168, preserving each published source commit in
its ancestry. Original branches remain available; superseded pull requests
link to their replacement. This changes review organization, not application
behavior. The preserved source heads are:

- #150: `cf9e78dcb5df8dbc4dbadd82df673492ad33cbdf`
- #160: `d58ea8aaa63284b48302763446964f74cbd94524`
- #164: `d10e0deaa2e8d34e6f2f17057f43dd8a3d3021b5`
- #167: `0d1223d04ad3f65f95c280d8d60050f11b808a21`
- #168: `a289576a0c25890594493b489e43b8a0047c89cb`

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

A combined native run of the SSH and agent fixture sources against existing
build 773 executed 22 test functions in 14 suites and failed with three
fixture errors: one immediate-close SSH PTY case returned POSIX EIO; two Codex
Stop cases returned POSIX EINVAL. These are unresolved concurrency-sensitive
verification failures, not a green combined result. Compilation succeeded with
a non-Sendable callback warning inherited from the unchanged PR150
SSHExitedPTYClient fixture, whose callback crosses a legacy queue boundary. Prior isolated passes apply to their individual fixtures and artifacts;
they do not establish combined-suite success; neither the warning nor the new combined failures is waived.


### Consolidated socket cancellation follow-up

The first replacement run completed all four app-host jobs with failures; the
full-suite assertions and deadlines remain authoritative. The shared fixture
error was reproduced locally with the same 22 test functions and 14 suites:
operation-labelled diagnostics identified `EPIPE` when replying to a
`workspace.remote.pty_resize` that the CLI canceled after bridge closure. The
fixture now closes only that client connection, preserves the captured request,
and emits no response-written acknowledgment for the canceled reply. Other
write errors still fail. The eight resize-acknowledged cases and all lifecycle
assertions are unchanged.

The legacy RPC callback fixture now documents and narrows its immutable transfer
to the protocol-supplied delivery queue, matching the existing subscription
ownership contract. Swift 6 compilation is warning-free. The combined native
batch passes against the existing build 773 artifact after the shared fix and
the agent branch's duplicate-server removal. This is focused fixture evidence,
not proof that all replacement-head app-host tests pass.

Both inherited CI reporting capabilities are restored in Project Truth. The
new exact-head checks remain required. Existing broad failures, including
inspector crashes, terminal readiness assertions and a stale-control-socket
process deadline, are not waived by the focused result.
## Codex monitor lease fixture (2026-10-12)

The existing Option/Alt invocation also selects `CodexMonitorLeaseTests` before
unchanged full coverage. Canonical and local Project Truth caveat
`codex_monitor_lease_fixture_verification` tracks actual pushed-head app-host
verification as pending. No runner, retry or deadline policy changes.

The old `testCodexPromptSubmitRetiresPreviousMonitorLeaseForSameSession` submitted
two unfinished turns and expected the second to replace the first lease. That
fixture predates the nested-turn stack policy: lease coverage arrived in
`92c8229d6`, then `e43ac6dd3` made unfinished overlapping turns nested. Default
subagent suppression intentionally preserves the parent lease. Baseline CI
`/tmp/matte-base-apphost4.log:73562` records the stale expectation.

Only that method migrates to Swift Testing. A sequential case supplies an
authentic prior-turn `task_complete` transcript, verifies one new active lease,
exact session/workspace/surface/turn, depth one, and retirement of the former
lease. The monitor may already remove its retired record; if the record remains,
`retiredAt` must be set. Record removal is normal retirement completion, not a
persistence requirement. A separate unfinished nested case preserves the exact
first lease while recording depth two and both turn IDs.

`CodexMonitorLeaseFixture` owns the protocol, isolated child environment, files,
lease snapshots and detached monitor cleanup. It reuses the reviewed async
`CLISocketFixture`, including listener-inherited SIGPIPE protection, readiness
sources, partial writes and awaited descriptor teardown. `CommandRunner` uses
owned positional stdin/stdout/stderr files with the original five-second process
deadline. Snapshots occur after native hook completion; there is no test polling
or arbitrary accept count. Cleanup matches only the actual CLI plus this
fixture's unique lease path, including the transient nohup command, and joins
native process-exit observation before deleting owned files. DispatchSource
process observation is a narrow OS-lifecycle bridge behind an async method;
Foundation has no Process handle for these CLI-owned detached descendants.
No real app socket, user configuration or preferences are used.

Unchanged build 773 passes both cases in the native harness. A temporary control
replaces `task_complete` with `task_started` and produces five sequential-case
failures, including `retiredAt`; another disables subagent suppression and
produces two nested-lease failures. Logs are
`/tmp/codex-monitor-lease-native-green.log`,
`/tmp/codex-monitor-lease-negative-completion.log`, and
`/tmp/codex-monitor-lease-negative-nesting.log`. The earlier five-scenario native
diagnosis and history are in `/tmp/codex-monitor-lease-diagnosis.md`.
These are focused local results, not full app-host green. This correction changes
no production code, shipped strings or localization catalogs and requires no app
build or launch.

Guidance: root/personal AGENTS, continuous-code-quality, testing migration and
behavioral quality, architecture file/concurrency rules, shared behavior, socket
policy and Xcode wiring. Maintained behavioral references are
`testNestedCodexPromptAndStopDoNotReplaceParentResumeBinding` and
`testCodexStopAfterInterruptedPriorTurnStillNotifies`; lease mutation stays in the
CLI session/monitor owners. All other legacy methods remain byte-identical. Project normalization/wiring
(433 files), strict determinism (zero findings), base-aware source budgets, shard
coverage (2,006 selectors), shard tests, runner-policy guards and Project Truth
validation/generation/freshness pass. New fixture compilation is warning-free.
### Respawn window option protocol fixture

The legacy window-option regression expected `surface.send_text`; the maintained
`respawn-pane` path uses `surface.respawn` with both a shell command and the
original `tmux_start_command`. Consequently the old mock rejected the valid RPC
before it could check that `--window` stayed out of the command text.

The migrated Swift Testing case covers the window option before and after a
positional command, plus explicit `--command`. It preserves window lookup,
focused-surface targeting, request order and successful completion checks. It
asserts the original command is exactly `echo fresh`, then executes the emitted
shell command in the owned fixture environment and checks its output. Every
other legacy test remains unchanged. There is no runtime or terminal change.

Guidance: root AGENTS, continuous-code-quality, bmux-testing migration/wiring and
local-vs-CI references, architecture/file discipline, shared-behavior and socket
focus policy. The CLI option parser, respawn owner and shell-command builder were
inspected. The test owns temporary files/process state; the shared reviewed
CLISocketFixture provides joined asynchronous transport. No real app socket,
preference, window or surface is targeted.

All three cases pass unchanged build 773 with warning-free focused compilation.
A temporary negative control restoring the obsolete send-text mock fails all
three cases. Actual app-host CI and combined full-suite validation remain
pending under the canonical/local focused-gate caveat. Localization audit: no
shipped strings or catalogs change; contributor verification notes only.
### Consolidated agent session fixtures review boundary

This branch consolidates #146, #152, #157, #159, #162, #165, #166, preserving each published source commit in
its ancestry. Original branches remain available; superseded pull requests
link to their replacement. This changes review organization, not application
behavior. The preserved source heads are:

- #146: `7f48a469821734062ad0c8de95da690cea3e5f4c`
- #152: `637ae2ede4f18445487574e29988b1aa1befca04`
- #157: `78cbde9b63acb7ea92929ca17ce9e4bc73fd68fb`
- #159: `994e34f6512abf871b839b7957d56f2739671314`
- #162: `90503d88c5f4cb0f69745dfb6b886755fe3ece12`
- #165: `34f10e69b8fc9b554014ff830d775648dc0cb368`
- #166: `971a35dfc91986d943ca74a8485139c7f31d8ae7`

### Agent fixtures after shared transport correction

Codex Stop now uses `CLISocketFixture` with its existing response model and
unchanged transcript, status and notification assertions. The duplicate server
was removed from the test target. Controlled native diagnostics reproduced
`EINVAL` while that duplicate configured an accepted socket after its peer had
closed; the shared transport configures the inherited option only on its listener.
The corrected SSH transport and both inherited CI capability entries are merged
from the SSH replacement once.

The first agent replacement's focused invocation failed five issues across 41
test functions in 10 suites: two session-start process deadlines and three SSH
PTY fixture errors. The timeout cases do not reproduce in the focused native
batch; their existing deadline assertion now includes the owned request trace
for diagnosis. No deadline or behavior expectation is relaxed. The combined
22-function, 14-suite native batch against existing build 773 passes with
warning-free compilation after these corrections. Broader app-host assertions,
crashes and deadlines remain unresolved until new exact-head CI demonstrates
completion. No application or terminal-engine code changes.
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
### Deferred browser initialization verification (2026-10-12)

PR 151 test-only CI job 114962906951 reproduced all four deferred-state
assertions and ended with TEST FAILED. The one-line fix refreshes the existing lifecycle projection at
initializer exit, covering deferred URL and URLRequest early returns without
starting navigation or adding a state owner. Tagged build 777
(`browser-initial-lifecycle`) succeeds without launching or replacing an active
preview. The four focused cases pass against that native artifact in an isolated
HOME (two deferred constructors and two empty-panel controls); the same tests
report four initial-state issues against unchanged build 774. Focused compilation
is warning-free. The app build retains 149 warning lines, matching the previous
build, so this is not an app-wide warning-free claim. Unrelated discard/portal gates are outside this maintenance slice. Existing prewarmed adoption was inspected but not separately exercised by
these four cases. The same four cases were revalidated on October 13 against
the unchanged build 777 artifact. Exact fixed-head app-host CI remains pending.
No shipped strings changed.
## Rejected ambient workspace fallback regression

`WorkspaceFallbackContractTests` replaces only the legacy trigger-flash stale
caller test. Eighteen actual CLI cases cover trigger-flash and notify with an
explicit surface shorthand: stale/absent/valid ambient identity, validated TTY
recovery, explicit valid/invalid workspace targets, window targeting, missing
current selection and selection RPC failure. The socket fixture accepts exactly
the intended workspace/surface pair and notification payload, rejects unexpected
commands (including focus mutations), and checks explicit invalid requests fail
without falling back to a different target. Valid ambient and TTY recovery cases
return the intended identity at index 0 unfocused, alongside a different focused
surface at index 1. Flash must retain the identity surface; notify's explicit
`--surface 0` must retain index selection. Other fallback scenarios keep their
actual target focused. The reviewed shared CLISocketFixture is reused
byte-for-byte, with owned file capture and joined socket cleanup.

On unchanged build 773, six cases fail with 18 assertions: the two stale-ambient
success paths and their missing-current/server-error controls. Twelve controls
pass. Compilation is warning-free. The shared fallback owner rejects the stale
workspace through surface.list and tries a validated TTY binding, but then calls
resolveWorkspaceId(nil), which rereads that rejected BMUX_WORKSPACE_ID. The
correction at this exhausted fallback boundary reuses currentWorkspaceId with an
optional window context; the general omitted-selector policy stays unchanged.
Explicit target and window routing remain authoritative.

Test-only CI job 114995800376 reproduced the six affected cases with 18
assertion failures and TEST FAILED. Isolated build 780
(workspace-fallback-recovery, never launched) passes all 18 cases against its
actual CLI, including the focused decoys. An input-only negative control selects
decoy index 1 in the four ambient/TTY cases and fails exactly their identity
assertions. A wrong-current-workspace negative control also rejects incorrect
flash and notification targets. Native compiles are warning-free; the changed
CLI file has no compiler warnings. Existing app concurrency/deprecation,
optional cargo and asset warnings remain outside this repair. The new
missing-selection callsite preserves English wording and has parsed
English/Japanese catalog entries. Exact fixed-head app-host CI remains required.
The focused suite joins the existing browser app-host step without
an additional runner, tracked by matching canonical/local Project Truth caveats.
Broader legacy CI is not claimed green. Other WorkspaceRemoteConnectionTests
methods remain byte-identical.

Guidance: root/personal AGENTS, continuous-code-quality, architecture ownership,
file/API/concurrency rules, Swift Testing migration/behavior/local-CI guidance,
shared behavior and socket threading/focus policy. Relevant inspected owners are
both command branches, workspace/surface normalization, fallback selection,
validated TTY lookup and current-workspace query. No global environment mutation,
app focus operation, renderer edit or user app action is part of this slice.
No shipped strings or localization catalogs changed in the test-only commit.

The final source-budget check found the fallback repair grew the already oversized
CLI by three lines. The adjacent unused `resolveSurfaceIdForClaudeHook` private
forwarder was removed; repository-wide search confirmed it had no callers. The
shared `resolveSurfaceIdAllowingFallback` owner remains unchanged. This reduces
source size without moving responsibilities or raising the legacy budget.
Independent review cleared the removal. Final isolated build 782 succeeds, and
its actual bundled CLI passes all eighteen routing cases. Warning-free native
fixture compilation, the source budget and Project Truth validation/freshness
checks pass. Exact published-head app-host CI remains pending.

### Notification timeout evidence on the replacement head

Run 38416355276, job 115363087236, completed the focused Claude notification
suite in 0.256 seconds. In the full Swift Testing wave, three of its four cases
then failed the unchanged five-second process deadline; that suite took 19.129
seconds. Many unrelated process tests timed out in the same wave. Earlier
session-start failures occurred in a focused invocation, so broad concurrency
alone is not an established explanation for both failures.

Controlled native execution against unchanged build 773 passed the six launch
and notification cases, the same cases alongside seven original caller/Sentry
cases, and a MainActor caller control. These results do not reproduce the CI
failure or justify changing scheduling, process ownership, or deadlines. The
notification fixture now retains its owned request trace and output-file read
results on timeout. All success-path assertions remain unchanged. Four actual
notification cases pass locally; an owned fake child intentionally exceeding the
existing deadline fails all four cases and reports both output markers. This is
diagnostic coverage, not a timeout repair or a full-suite pass. No app behavior,
user preferences, localization strings, or active app builds changed.

### Initial resize acknowledgement diagnosis

Run 38415496749, focused app-host job 115360361616, completed 35 test functions
in five suites with eight failures: every acknowledged-resize SSH PTY case hit
its existing five-second process deadline. All eight immediate-close variants
passed. This is a remaining failure after the earlier per-client EPIPE fix.
The maintained CLI still requests its initial resize, using a single RPC with a
50-millisecond deadline; failure of that request is a candidate, not an established
cause. The run exposes no tested CLI artifact for an exact-binary local replay.

The fixture now reports its owned requests, handshake, bridge completion, existing
resize-observed/input-ended flags and output on failure. It adds no mutable state,
retry, signal, deadline or scheduling change. Sixteen cases pass against unchanged
build 773 with warning-free Swift 6 compilation. A temporary control suppressing
only the resize acknowledgement event fails the eight acknowledgement cases and
passes the eight immediate-close cases; diagnostics show the actual resize request,
handshake and missing observation. That demonstrates diagnostic sensitivity, not
that CI lost the same event. Actual CI traces and a causal correction remain required.

Normal completion now drains the finished response-observation stream before
finishing the bridge event stream. The sole caller joins and finishes its socket
producer before returning; canceling the consumer first could discard queued
observations from the diagnostic snapshot. Errors still cancel and join the
consumer, so a throw before producer startup cannot hang cleanup. This preserves
the existing bridge-close predicate and five-second CLI deadline. It guarantees
only consumed or queued observations, not delivery of every kernel EOF event.

All sixteen native CLI cases still pass, as do temporary finished-response and
pre-producer-error cleanup controls, with warning-free Swift 6 compilation. The
old race cannot be forced deterministically through the current fixture boundary
without an artificial scheduling hook; no source-shape test or timing assumption
was added. This diagnostic correction does not establish the CI timeout cause.

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

The focused app-host job `115430721439` ran 71 test functions across nine suites
and completed with exactly three issues in the window-close observer case: no
inspector close before `willClose`, no close count, and retained visible state.
XCTest composition disables `.browserAndDevTools`,
so this case now installs an explicitly enabled, scoped runtime only for the
synchronous close action and restores the original runtime after owned teardown.
It starts no background services and retains every original assertion. An owned,
offscreen control against the same built owner fails with the default disabled
capability, still fails after responder-swizzle installation, and passes when only
the browser capability is enabled. The actual main-window case still needs the
next app-host run; this control does not claim that foreground UI verification.

Guidance: root/personal AGENTS, continuous-code-quality, bmux-testing migration,
behavior and local/CI references, architecture ownership/file/concurrency rules,
debugging runtime pitfalls, shared behavior and native project wiring. No shipped
strings or localization catalogs change; this section is contributor verification
prose. This repair is integrated into PR 170; no separate PR is introduced.

## Maintenance validation refresh (2026-10-13)

This local composition replaces the earlier 87f0c2b5e candidate, retained on
`maintenance-validation-before-oct13`. The earlier CI run cannot verify this
composition. It includes the existing SSH and agent fixture diagnostics, the
browser inspector ownership/observation repair, the browser initializer lifecycle
fix, the workspace fallback fix and its source-budget cleanup, and the corrected
whole-suite SSH reconnect regression selector. Source ancestry and focused
selectors remain preserved; the obsolete reconnect method selector that ran zero
tests is deliberately replaced by its enclosing suite.

The complete Codex rejected-target and SSH manual-reconnect runtime corrections
are included after their test-only CI runs produced the expected nonzero
failures. The fixed Codex CLI passes sixteen routing cases and thirteen valid
Stop cases against isolated build 781; reconnect passes twenty-five cases against
unchanged isolated build 779. These native results do not replace fixed-head
app-host gates. Seven browser observation cases pass against the isolated DEBUG
module. Earlier focused app-host execution passed the migrated inspector cases
except one window-close case; its explicit capability fixture correction still
needs the fixed-head app-host run.
SSH resize-acknowledgement and shared CLI process timeouts remain unresolved:
added diagnostics preserve existing assertions, process deadlines and scheduling.

The final combined native and artifact gates remain open. No incomplete,
cancelled or older-head run is accepted as green, and no main-branch merge has
occurred. Running user builds 773/775 were not modified. These are contributor
verification notes; no shipped UI strings or localization catalogs change in
this integration.

## Global search shortcut conflict verification

PR 170 job `115525529711` failed the legacy configured Show/Hide collision case:
the recorder returned `conflictsWithAction(showHideAllWindows)`, while the test
expected `reservedBySystem`. The named-action rejection was introduced by
`1a95cbba8` for actionable recorder feedback and remains the shared validator's
policy. This correction changes only that legacy test, not shortcut policy or
Settings behavior.

`GlobalSearchShortcutConflictTests` exercises the real validator through an owned
managed settings file. It retains the exact configured target, adds a nil normalized
shortcut assertion, distinguishes a hardcoded system reservation, and checks
nonconflicting/unbound acceptance and configured-conflict precedence over the
later system-wide chord rejection. Setup and restoration run synchronously on
MainActor; managed-default metadata preserves persistent-domain provenance and
volatile domains are restored. The fixture never calls `resetAll`, persists a
shortcut, starts a watcher, or suspends with the scoped store installed.

The existing focused browser/settings invocation includes the new suite. Its
canonical/local caveat remains open until actual fixed-head app-host execution.
Native build 773 owner verification passes four functions/six parameter cases
in 0.046 seconds. Restoring the old generic expectation in a temporary control
fails exactly once; temporary success/throw controls also verify store identity,
persisted-key absence and volatile-domain restoration. These results do not
establish full-suite or CI success. The native harness uses the
target's Swift 5 mode without warnings; forcing Swift 6 exposes the retained
legacy owner's nonisolated mutable `settingsFileStore`, not a new concurrency
suppression. Governing sources are root/personal AGENTS, continuous-code-quality,
bmux-testing migration/behavior/local-CI, architecture and shared-behavior rules.
No production code or shipped strings change; localization catalogs are untouched.

### Opt-in focused process diagnostics

For one diagnostic dispatch, set `app_host_process_diagnostics` to true. Only the
focused shard 1 app-host invocation enables the observer, after acquiring the
existing GUI-host lock. Normal PR runs and broad tests are unchanged.

The observer starts numeric process snapshots at the Swift Testing start marker
and stops after 30 seconds. It records PID, parent PID, Darwin state, elapsed time,
cumulative CPU nanoseconds and thread count only for the exact DerivedData Debug
host and its bundled CLI descendants. It never reads arguments or environment.
CLI stack eligibility requires one observed second alive; the host requires two.
At most eight one-second samples run, at most two concurrently, at 10ms intervals.
This has diagnostic overhead and may perturb scheduling; it is not a timeout fix.

Raw samples use unlinked temporary files. Artifacts retain only counted stack
symbol frames, excluding dynamic thread/queue labels, headers, paths and binary
image inventories. Each invocation/attempt gets a unique directory, uploaded even
on failure. Missing logs are retried on the next observation tick. On test exit,
the observer receives EOF; bounded shutdown escalates only against its own process
group. Diagnostic errors never replace the test command's native exit status.

The actual PR171 focused failure (job 115488618879, 41 functions/10 suites, 19 issues)
remains unresolved. Local synthetic subprocess/filter/privacy checks do not prove
macOS 15 app-host capture or identify a missing CommandRunner callback. The next
combined dispatch must supply that evidence without changing test deadlines.

### Remote tmux CRLF record parsing

Current app-host job 115525529711 failed the existing
`preservesNameWhitespaceAndStripsLineTerminator` assertion. Swift Character
splitting treats CRLF as one grapheme, so splitting on an LF Character leaves
CRLF in a name and can merge several records. The shared parser now splits the LF
substring; its existing single trailing-CR removal and empty-line handling remain.
The transport, remote commands, malformed-record policy and name whitespace are
unchanged.

Test-only commit `b95727d60` adds LF/CRLF multi-record controls with blank lines,
Unicode/padded names, embedded colons and an unterminated final record. Against
the unchanged production parser, the complete suite compiled without warnings and
failed exactly two issues: the existing assertion and the new CRLF case. The
fix in `7f3c6513e` passes all nine functions (ten cases). These are actual compiled
parser/value sources with unchanged test assertions, not source-text tests.
The earlier actual CI failure supplies the existing regression red evidence;
no failing result was hidden or changed to an expected failure.

Root/personal AGENTS, continuous-code-quality, bmux-testing, architecture and
shared-behavior guidance were applied to the complete parser, session value,
transport caller and tests. The parser remains the single session-record owner;
no new state, dependencies, user-facing strings or localization keys are added.
A fresh isolated combined build and its native owner checks are required before
publishing this runtime correction. Full combined app-host CI remains open.


## Download quarantine boundary verification

PR 170's browser/settings job fails the two URL readback assertions in
`webDownloadQuarantineMetadataMarksRemoteDownloads`. LaunchServices preserves
quarantine type, agent and timestamp but can omit the optional URL fields. The
same result occurs with the unchanged writer in an owned native file and in a
bundled helper with `LSFileQuarantineEnabled`; it is not unique to an unbundled
command-line harness. The SDK's `LSQuarantine.h` documents these URLs as present
“if available”.

`BrowserDownloadQuarantineMetadata` owns the exact pure value submitted by the
existing URL writer. It preserves the existing HTTP(S) filter, credential/query/
fragment removal, type, timestamp, agent and optional bundle identifier. The
writer still owns native persistence and throws the same errors. Both session
and WKDownload callers retain their existing temp-file marking before move or
replacement and final-path marking. This extraction adds no settings, callbacks,
state owner, rendering changes or error suppression.

`BrowserDownloadQuarantineTests` checks exact outgoing sanitized URLs and all
other metadata, unsupported schemes, empty/absent bundle identifiers, actual
native quarantine persistence and nil/local-source bypass. Native readback must
still contain the type, agent and timestamp; any returned URL must be typed and
match the exact sanitized value. Outbound assertions use the actual resource
values passed to the writer, so optional OS readback cannot hide a sanitization
regression. The focused browser/settings invocation includes this suite, and the
existing filename-resolution suite retains its other assertions.

The extracted source and focused suite compile in Swift 6 without warnings.
Five functions/nine parameter cases pass locally on macOS 26. A temporary
control bypassing sanitization fails with ten exact URL assertions, while native
persistence checks still pass. The committed app
module and full app-host execution remain pending; the canonical/local caveat
stays open. Native readback evidence does not claim macOS 15 CI success.

Retained policy caveat: the existing writer sets origin equal to the sanitized
download URL. The SDK recommends a distinct referring page or no origin to avoid
redownloading when the origin is opened. This boundary correction deliberately
preserves that existing policy; choosing a referring page belongs to a separate
browser download behavior change.

Guidance: root/personal AGENTS, continuous-code-quality, bmux architecture
ownership/file/concurrency rules, bmux-testing behavior/migration/local-CI and
Xcode wiring rules, and the SDK quarantine contract. Complete shared writer and
both caller flows received independent review. No user-facing strings, settings,
menus or help text change; localization catalogs are untouched. This correction
is integrated into PR 170, with no new PR.

## File preview save-shortcut fixture verification

Actual app-host jobs `115439961432` and `115439961123` accept the configured and
chorded save events, but the two legacy tests write empty files. Both construct
`SavingTextView()` with a nil text container. Native build 773 reproduces the
failure before key dispatch: this view has no text storage or container and its
string stays empty after assignment. Production uses `makeFilePreviewTextView`,
the explicit TextKit 1 factory introduced by `a86c58363`; the factory preserves
text and both real shortcut/save paths write the expected content.

Only those two methods migrate to `FilePreviewSaveShortcutTests`. Storage and
content preconditions guard the native fixture. Original key handling, chord
prefix no-save and final file assertions remain, with an additional remapped
old-default negative control. The existing editing protocol's test adapter
captures the actual panel save Task so the test can await completion without the
legacy yield loop. No save, routing or timeout policy changes. Managed shortcut
setup/restoration is synchronous and finishes before any await; owned files and
panels are released afterward. Other legacy test bodies remain unchanged.

An owned native four-case control compares both constructors through the actual
panel save owner; requiring intended content fails exactly the two bare-editor
cases and passes both factory cases. The corrected two-case suite compiles
without warnings in target Swift 5 mode and passes against unchanged build 773.
The focused browser/settings gate includes it, and the canonical/local caveat
stays open pending fixed-head app-host CI. These local results do not claim
full-suite success or execution on CI's macOS 15 runner.

Guidance: root/personal AGENTS, continuous-code-quality, bmux-testing migration,
behavior and local/CI references, architecture/concurrency and shared-behavior
rules, and debugging runtime pitfalls. Production code and shipped strings are
unchanged; no localization catalog edits are required.


## Panel appearance compositing verification

App-host job `115439961299` fails the legacy transparent-opacity case because it
expects background alpha 0.42 while the shared chrome background is opaque.
Commit `379033c4b` intentionally changed `GhosttyBackgroundTheme.color` to
`WindowAppearanceSnapshot.compositedTerminalColor`; `WindowChromeColorResolver`
blends the terminal RGB over the resolved window background and returns alpha 1.
`PanelAppearance` independently preserves clear content for transparent terminals.

Only that method migrates to `PanelAppearanceCompositingTests`. Aqua and Dark Aqua
cases retain clear-content, disabled-fill and zero-content-alpha assertions with
the original tolerance. Expected RGB is calculated independently from the terminal
color, 0.42 opacity and the appearance-resolved window background. Scoped native
drawing appearance restores the previous appearance without changing application
or user settings. All other legacy methods remain unchanged.

The focused browser/settings gate includes the new suite. Unchanged build 773
native proof passes both appearances; restoring the original 0.42-alpha assertion
fails exactly both cases. The matching canonical/local caveat stays open until
fixed-head app-host CI verifies the migrated suite. No production policy, rendering
or shipped copy changes. Governing guidance is root/personal AGENTS,
continuous-code-quality, bmux-testing migration/behavior/local-CI, architecture,
shared behavior and OS-sensitive debugging; localization catalogs are untouched.
