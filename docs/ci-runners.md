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

### Browser initial-navigation timeout diagnostics (2026-10-14)

Run `38509817630`, focused shard 1 job `115676261510`, failed both
`BrowserDiscardReadinessTests` cases in their initial `about:blank` readiness
wait on macOS 15.7.9. Neither reached discard or restored-history assertions.
The same cases pass against existing build 784 on macOS 26.3; a native KVO trace
showed WebKit progress/loading settling before the model completion event.
That local ordering does not explain or disprove the CI timeouts.

The fixture now attaches a bounded diagnostic recorder while retaining the
original one-second deadline, readiness predicate and assertions. It records up
to 64 model consumptions and WebKit loading/progress/URL-class changes,
plus an omitted-event count and an untruncated failure snapshot. URL values are
classified only as absent, `about:blank`, or other; arbitrary URLs and page
content are never reported. The original deadline task records its elapsed time
before throwing; the later MainActor failure snapshot has its own elapsed time.
This distinguishes deadline firing from delayed actor resumption. Diagnostic
observations do not wake or complete the readiness consumer and are removed
before panel teardown. No production navigation or discard owner changes.
Model values come from the existing readiness consumer; the recorder does not
add a model subscription or compare emitted versus consumed model values.

These diagnostics require macOS 15 app-host evidence before any missing-signal
or resource-timing cause can be assigned. Local green is not a CI repair claim.
No shipped wording or localization catalogs change; added strings are test
failure diagnostics and contributor verification notes.

## Codex rejected ambient identity regression

The focused `CodexRejectedAmbientTests` and `CLISocketFixtureCompletionTests` gate runs before the broad app-host suite
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
its actual app-host red was retained before publishing the complete fix.

Fresh isolated build 781 (`codex-routing-stop-recovery`) succeeds without launching
the app. Its actual bundled CLI passes all sixteen routing cases with warning-free
Swift 6 fixture compilation, plus thirteen valid stop payload/transcript/turn-scope
cases across nine functions. Independent review checked the resolver, stop path,
deferred telemetry and unchanged lifecycle ordering. The production correction is published in commit `214180692`. Full fixed-head app-host CI and
combined validation remain pending; these focused results are not broad-suite green.
The local Project Truth verification caveat stays open.

Source requirements: root/personal `AGENTS.md`, `continuous-code-quality`, and
`bmux-architecture`, `bmux-testing`, `bmux-shared-behavior`, `bmux-socket-policy`,
`bmux-dev-workflow` and `bmux-localization`. Maintained references are the verified
PID/TTY recovery regression, sibling rejected-target telemetry guards, joined
`CLISocketFixture`, and owned-file CLI capture. Localization audit: no shipped
strings or catalogs change. Running builds 773/775 remain untouched.


### Socket capture completion regression

Review identified a gap in the shared fixture: process completion does not imply
that DispatchSource has delivered readiness for every one-way `feed.push` frame.
Finishing the event stream first can discard already-written frames and let a
negative mutation assertion pass incorrectly. Source cancellation joins descriptor
closure but does not drain input; `responseWritten` cannot cover frames that have
no response.

The focused transport suite uses an immutable, constructor-owned native
readiness-delivery closure. Its default forwards events immediately; tests
withhold listener or client notifications without blocking the native queue, so
cancel handlers remain runnable. Real owned sockets fully write and close each
frame before the operation returns. Test-only commit `e8fb55995` records three
local missing-input issues across five cases; the no-client and operation-error
cleanup controls pass. Actual test-only CI run `38499804202`, job
`115644567245`, subsequently failed with the three expected missing-input issues.

The local correction keeps capture state and one parser inside the fixture's I/O
task. A private completion event drains queued accepts and available client bytes
before closing and joining sources. Normal operations must join their request
producers. Final-drain responses fail explicitly on would-block rather than await
future peer reads, and partial or failed writes never emit `responseWritten`.
An EPIPE still permits validation and capture of complete queued frames before
closing at EOF/EAGAIN. The listener's existing SO_NOSIGPIPE option now precedes
listen and producer start: a native probe confirmed accepted sockets inherit the
option at connect time, not accept time.

This does not make every capture shutdown globally bounded. Ordinary serving
retains its existing backpressure wait; that wait can already be active before
the completion event is processed. No CLI timeout or assertion is relaxed, and
no application/runtime code changes in this follow-up.

Final strict Swift 6 compilation is warning-free. The focused transport suite
passes six functions/seven cases, including a mixed response/one-way connection
whose prior parser dropped the second frame after EPIPE. Removing the final-drain
would-block guard causes the owned unread-peer control to fail at its existing
five-second failure deadline; cleanup closes the peer before joining the writer.
No sleep is used to synchronize readiness, and no wire sentinel is introduced.

The combined matrix uses validation commit `8ae32c8a8` shared caller sources and
existing build 784 CLI, with only this fixture substituted. Its 38 functions in
18 suites complete with five SSH acknowledged-resize timeouts; all other suites
pass. The same frozen callers with the pre-fix helper also reproduce that timeout
class (one case), while the final helper's isolated sixteen SSH lifecycle cases
pass. Those samples establish an existing integration limitation, not a timeout
frequency comparison or full-suite success. Actual fixed-head app-host CI and
combined validation remain open in the canonical and local Project Truth caveats.

Source rules and ownership: root/personal `AGENTS.md`, `continuous-code-quality`,
`bmux-architecture` concurrency/file discipline, `bmux-testing` regression and
local/CI references, shared-behavior and socket-policy guidance. Existing joined
DispatchSource cancellation, one-way feed telemetry, response-written observation
and owned-file CLI capture remain the maintained patterns. Localization audit:
only test diagnostics and contributor notes change; no shipped copy or catalogs.

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

The sample worker has five seconds to finish, including symbol processing after
the one-second capture. This allowance does not change native test deadlines, the
30-second observation window, sample count/concurrency, or the observer shutdown
bounds. The command explicitly directs its output to `/dev/stdout`, backed by an
unlinked temporary file, so `sample` does not also create its default raw report.
Artifacts retain only counted stack symbol frames, excluding dynamic thread/queue
labels, headers, paths and binary image inventories. Each invocation/attempt gets a unique directory, uploaded even
on failure. Missing logs are retried on the next observation tick. On test exit,
the observer receives EOF; bounded shutdown escalates only against its own process
group. Diagnostic errors never replace the test command's native exit status.

The actual PR171 focused failure (job 115488618879, 41 functions/10 suites, 19 issues)
remains unresolved. Local synthetic subprocess/filter/privacy checks do not prove
macOS 15 app-host capture or identify a missing CommandRunner callback. The next
combined dispatch must supply that evidence without changing test deadlines.

Published D2 diagnostic evidence showed the host sampler killed with status -9
at its previous two-second worker deadline, without a call graph. An owned ready
Python child sampled locally took 2.430 seconds including symbol processing.
Later warm runs with explicit stdout output finished in 1.257–1.634 seconds; these
do not reproduce the slower run. They did retain 15 sanitized symbol frames,
created no default raw report, and joined both the sampler and owned target.

A temporary controlled-worker proof exercised the actual observer with pipe
readiness and a virtual clock: at 2.5 seconds the old allowance killed the worker,
while five seconds allowed real output and successful completion. Overrun and
stop controls killed and joined the worker and closed its unlinked capture.
Existing status/forced-stop tests retain the native command's result. This repairs
diagnostic collection only; it does not identify the CLI failure cause. Actual
macOS 15 app-host graph collection remains pending. No app or user process was
sampled for local proof, and no arguments, environment, or raw payload entered
its artifacts.

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
Fresh isolated combined builds 783 and 784 succeeded without launch; build 783
executed all nine parser functions (ten cases) successfully with warning-free
focused compilation. The app/runtime source in this publication is unchanged
from that verified parser correction. Full combined app-host CI remains open.

### Remote tmux parser regression execution

The test-only CRLF coverage at `b95727d60` did not execute in broad shard 3:
job 115627514126 of run 38494255765 stopped after a 300-second idle deadline
with exit 124 during unrelated legacy XCTest execution. This is a coverage
blocker, not evidence that the parser regression failed.

The existing first focused app-host invocation now also selects
`RemoteTmuxSessionListParserTests`, so Swift Testing executes the LF/CRLF cases
before broad legacy XCTest work. The full shard selectors, runner count,
deadlines and assertions are unchanged. Test-only focused job 115650904190
of run 38501744697 then executed the parser suite and failed exactly the
existing whitespace assertion and new CRLF multi-record case, with exit 65.
The full focused invocation reported 44 functions / 6 suites / 20 issues: the
two parser failures plus 18 CLI deadline failures, which remain unresolved.
The reviewed parser correction is published with both source ancestries retained.
Fixed-head parser and full combined CI verification remain pending.

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
persistence checks still pass. Subsequent committed-module verification passed
as recorded below; full app-host execution remains pending and the canonical/local
caveat stays open. Native readback evidence does not claim macOS 15 CI success.

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

### Combined artifact 784 verification

The fresh isolated maintenance-integration build succeeded at combined source
`9a5f2cc88` without launch; its reviewed production sources match this PR.
Quarantine metadata and panel appearance passed six functions/eleven cases in
strict Swift 6 with no compiler warnings. The two FilePreview shortcut cases
passed in the actual Swift 5 test-target mode with no compiler warnings. The
existing mutable static settings owner prevents forcing that fixture into Swift 6,
as documented above. Build warning budget was 126/221; this is not a claim of a
warning-free app build. The earlier build 783 separately passed the parser,
Global Search, reconnect and remote-working-directory owner checks.

These focused native results do not replace macOS 15 app-host execution or the
full dependency-complete CI gates, which remain open. No active user app was
rebuilt, launched, quit or replaced.
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
without warnings in target Swift 5 mode and passes against unchanged build 773. Forced
Swift 6 compilation is blocked by the existing mutable static
`KeyboardShortcutSettings.settingsFileStore` owner, as in the Global Search
fixture; no suppression or new unsafe declaration is added. That legacy owner
migration remains outside this test-only correction.
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


## Titlebar product contract fixture verification

The remaining titlebar failures assume a default sidebar width equal to its
minimum and a control list without voice input. Commit `2c783a9ee` intentionally
increased the workspace-card default to 340pt while retaining the 240pt resize
minimum, and `d5c2a521f` added the voice-input control and its shortcut hint.
The shared padding owner follows the visible sidebar width and uses the minimum
when hidden; the control and minimal-mode routing both include voice input.
The old fixtures conflict with these maintained product changes.

`TitlebarProductContractTests` replaces only those two expectations. It checks
the existing width policy and the helper’s exact 352pt/252pt output for an
explicit 240pt absolute-minimum input, and
retains the full ordered hint-action assertion with voice input between
notifications and new workspace. Existing minimum-width no-shift, wider-sidebar,
fullscreen and other hint-policy tests remain unchanged. These controlled
helper inputs do not claim the live configured-minimum default, whose separate
policy caveat remains recorded. The new suite is wired
into the native test target and focused browser/settings gate. No production
layout, navigation, shortcuts, settings or strings change.

Both old expectations fail against the unchanged build 784 app module with
exactly two issues. The corrected two functions pass in Swift 6 without warnings
against that same module. This local macOS 26 evidence does not establish the
macOS 15 full app-host result; the canonical/local caveat stays open pending CI.
Governing sources are root/personal AGENTS, continuous-code-quality, bmux-testing
migration/behavior/local-CI/wiring rules, architecture ownership, and maintained
ContentView padding and UpdateTitlebarAccessory control/hint consumers. The
localization audit finds no changed shipped text or catalogs; this section is
contributor verification prose. This correction belongs to PR 170, not a new PR.


### Completed-close history and batched mobile frame fixtures

The PR 169 shard 2 run `115650904163` failed the existing repeated-close history
case with an empty shared store and the batched mobile frame case with a one-second
signal timeout. The history test now observes its exact tab's completed
`Workspace.didCloseTab` callback through a fully forwarding, per-controller
Bonsplit delegate. It captures the resulting history before another suite can
clear the shared store, then retains the original prompt, repeated-close,
panel-removal, title and detail assertions. It restores the original delegate
before tearing down its panels and isolated defaults. The ten-second deadline
remains, without polling.

The mobile fixture parks both callbacks with async streams before allowing the
first to close. A test-target extension enters the existing actor-owned response
drain before releasing that operation: this captures the task handles before
`close` clears them. Every success, timeout and cancellation path releases the
owned gates and joins those tasks. The original request payloads, exact
`["workspace.list"]` assertion and one-second signal deadlines remain. No
production owner, app-host selector or runtime deadline changes.

Both exact cases pass together against the unchanged build 784 module. A
controlled clear after the real close reproduces the old nil-history assertion,
while the completed-close snapshot passes. An authorization-tail control proves
that the old `isSubscribed` round-trip can return before authorization returns;
it does not establish which signal timed out on CI. Missing-first and
missing-second controls preserve the one-second failure and verify that the
fixture deallocates after joining callbacks. A temporary exact copy of the
mobile connection owner, with only its post-authorization close/cancellation
guard removed, causes the unchanged method assertion to detect the additional
`terminal.input` delivery. No repository production code is altered by that
negative control. Fixed-head app-host verification remains pending.

This bounded correction follows root/personal AGENTS, continuous-code-quality,
bmux-testing migration/behavior/local-CI guidance, architecture concurrency and
file ownership, and the real Workspace/Bonsplit and MobileHostConnection
completion boundaries. The localization audit finds no changed shipped strings,
settings, menus or catalogs; this section is contributor verification prose.


### Narrow titlebar reservations

The matte titlebar applied its leading-control reservation to both edges. Native
measurements at 600/700pt with the default 352pt reservation gave the title zero
width and moved the build badge beyond the trailing edge. `WorkspaceTitlebarLayout`
now reserves the existing leading width once and measures the optional badge.
It keeps the title centered in the titlebar band when it fits, otherwise truncates
within the actual interval between controls and badge. It uses only existing theme
gaps/insets and preserves the folder view, badge accessibility and control owner.

Offscreen native verification against build 784 covered 80 combinations per theme:
300/600/700/1092/1100pt, visible/hidden sidebar reservations, short/long titles,
100/200% fonts and badge presence/absence. The 1092/1100pt short-title light PNGs
remain byte-identical; at 600pt the default title is fully visible and the badge
has its original 8pt trailing inset. No measured title slot overlaps the reserved
controls or badge. The existing 300pt case with 352pt leading controls still has
no title interval; this correction does not redesign those controls. The existing
28pt band versus 30pt text at 200% is a separate vertical constraint, not a claim
of complete magnification support. The same horizontal matrix was inspected in
dark and light without ordering or activating a window.

Root/personal AGENTS, continuous-code-quality, architecture file/concurrency rules,
bmux-debugging runtime guidance and bmux-testing local/CI boundaries govern this
slice. No layout-mirroring test or new CI selector is introduced for this reversible
visual correction. Integrated tagged build and app-host verification remain pending.
The localization audit preserves the existing English/Japanese badge accessibility
key and folder tooltip; no shipped text or localization catalog changes.

### Native socket readiness under combined CLI load

Final carrier `95595b830` run `38509817630`, app-host shard one, failed with
fifteen CLI deadlines and two browser-readiness errors. The CLI failures include
all eight acknowledged-resize variants. These results remain failures; this
fixture correction does not establish that every timeout has the same cause.

A temporary per-instance event counter reproduced unbounded duplicate native
readiness delivery: level-triggered callbacks kept yielding while the async I/O
consumer had not yet drained the descriptor. On the same unlaunched build 785
and frozen 38-function/18-suite source matrix, the old helper emitted 1,467,210
notifications and reached 78,718 pending events in one fixture. The corrected
boundary emitted 1,028 notifications and peaked at three pending events per
fixture. Both same-artifact executions passed (old 5.469s, corrected 4.930s).
An earlier old-helper execution on build 784 failed eight resize cases. These
samples prove redundant queue growth, not deterministic timeout causality or a
failure-frequency comparison; counter instrumentation also adds overhead.

`CLISocketReadiness` owns one native descriptor/source lifetime. A synchronous
three-state guard only balances the native callback's suspend against the sole
I/O consumer's acknowledgement or cancellation. This is the architecture's
native-callback compare-and-set carve-out, not a lock over capture/parser state.
The handler yields once and suspends; the I/O task services its token and rearms
it. The completion event is separate and reliable, and the final pass still
accepts and reads all queued clients even when tests withhold native delivery.
Weak callback ownership prevents a source/owner cycle. Teardown installs the
cancel handler before cancel, balances a suspended source once, and joins its
file-descriptor close. The sole serving task owns teardown; acknowledgements
after closure are inert. Response parsing, complete-write acknowledgements,
EPIPE handling, final-drain backpressure errors and all deadlines are unchanged.

The seven existing transport cases pass with the proposed boundary, including
withheld listener/client delivery, one-way/mixed frames, operation failure and
backpressure. Three temporary native lifecycle controls verify armed/suspended
closure, descriptor invalidation, owner deallocation and rearming for subsequent
input. No source-shape test or new scheduling hook is added. The intermediate RPC-only non-instrumented source on build 785 completed all
38 functions/18 suites with one remaining acknowledged-resize timeout
(`running`, pipe stdout); the other seventeen suites and all seven transport
cases passed. The same shipping source passes all sixteen SSH lifecycle cases
in isolation (0.110s) and all three native source-lifecycle controls. Strict
Swift 6 compilation is warning-free. The full matrix is still red, and neither
the isolated result nor reduced queue growth resolves that timeout or proves
its cause. Actual fixed-head app-host verification remains required.
The independent CommandRunner blocking-reader caveat remains open.

Guidance: root/personal AGENTS, continuous-code-quality, bmux architecture
concurrency/file discipline, testing regression/local-CI rules, shared behavior
and socket policy. Only test infrastructure and contributor evidence change;
there are no production changes, new shipped strings or localization entries.


The remaining resize case prompted inspection of `SSHPTYLifecycleBridge`, which
had an independent level-triggered readiness stream. A temporary native counter
measured up to 13,407 pending events for one bridge's single accept, handshake and
EOF while the RPC fixture was already bounded; that matrix had two resize
failures. The bridge now reuses the same descriptor owner. Its listener stays
suspended after the single expected client is accepted; input rearms after a
read and remains suspended after EOF until joined closure. The synthetic resize
acknowledgement remains an independent reliable event. Existing SO_NOSIGPIPE
configuration precedes listen so accepted descriptors inherit it before any
producer connects. The close predicate and all lifecycle assertions are intact.

The resulting exact non-instrumented source passes all 38 functions in 18 suites
on build 785 (4.571s), including all sixteen SSH lifecycle and seven transport
cases; strict Swift 6 compilation is warning-free. This resolves both measured
unbounded queue owners, but does not prove the cause of every macOS 15 CI timeout.
The earlier failing matrices remain part of the evidence, and the final
combined app-host gate is still required. A temporary control that suppresses
only resize-response observations still fails exactly the eight acknowledgement
cases at the unchanged five-second deadline; all eight immediate-close controls
pass. This verifies that the new native-source lifecycle does not fabricate the
resize event or weaken the bridge completion predicate.


### Persistent SSH child-exit sibling tracking

Final C run `38509817630` shard 4 failed the existing split persistent-PTY
child-exit case: closing one child left both panels visible but cleared the
sibling's active-session tracking. The same case reproduces against unlaunched
native build 785, with only the active-count and sibling-tracking assertions
failing. Last-surface disconnect and already-ended-attach controls pass. The
sibling's saved PTY session ID and remote configuration remain unchanged.

`Workspace.markPersistentRemotePTYAttachFailed` now invokes workspace-wide
disconnect only when its active remote surface set is empty, matching the
existing session-ended owner. Per-panel cleanup, placeholder handling, browser
status and directory notifications remain on the same path. This preserves
last-surface teardown without stopping a sibling's shared remote controller.

The baseline probe used an owned HOME and XCTest environment established before
execution, no foreground windows, and the existing SSH cleanup override. Its
`autoConnect: false` fixture has no live controller, so live controller identity
preservation remains source-reviewed only. Source parsing and diff checks pass;
fixed-code native execution and actual macOS 15 app-host verification remain
pending. Shard 4 ended with exit 124, leaving full-suite coverage incomplete.
The canonical `persistent_pty_child_exit_verification` and existing full-suite
caveats remain open. No deadline, assertion or runner policy changed. The
localization audit finds no shipped string or catalog changes; this is
contributor verification prose.


### Workspace close ownership verification

Authoritative combined shard 2 failed the existing
`TabManagerWorkspaceOwnershipTests.testCloseWorkspaceIgnoresWorkspaceNotOwnedByManager`.
The exact test also fails against unlaunched native build 785: an external
workspace loses its panel and title map even though the manager's tab list and
selection remain unchanged. The owned-HOME native probe reports exactly these
two assertions; its focused compile is warning-free.

`TabManager.closeWorkspace` now requires the passed workspace instance to belong
to the manager before any coalescer, remote tmux, history, notification or teardown
side effects. The existing last-workspace protection is unchanged. Current
callers resolve owned model instances; checking reference identity prevents a
foreign object from being destroyed through this reference-taking API. Workspace
IDs are immutable and freshly allocated by the initializer, so no artificial
same-ID test seam was introduced.

The existing actual CI regression supplies the red evidence. Parsing and project
state checks pass; the fixed native artifact and complete app-host suite remain
pending under `workspace_close_ownership_verification`. No test assertion,
deadline, localization catalog or shipped wording changed.


### Portal geometry and workspace contract fixtures

Four legacy cases now use the current owners: hidden anchorless terminals are
pruned while visible entries remain available for drag recovery; typed terminal
subview counts exclude portal chrome; deferred external geometry explicitly uses
its two-hop queue path; workspace creation inherits font lineage into a clean
config; PR publication is observed through `workspaceDisplayMetadataDidChange`.
The four functions run as five Swift Testing cases, including both anchor-loss
visibility states. Only their legacy bodies and the moved config fixture were
removed; the remaining legacy cases are unchanged. Existing full app-host
coverage remains the gate, with no selector, runner or timeout changes.

The owned offscreen native harness against existing build 785 compiles these
sources in Swift 6. It never activates or opens an app, and sets test mode,
XCTest identity and isolated HOME/config paths before loading the module.
Original native probes failed; corrected cases pass locally. Input controls for
visible retention, immediate geometry delivery, wrong font lineage and changed
PR state exercise the retained count, hit-test, font and deduplication assertions.
Disabled-Sentry breadcrumb diagnostics are present in the standalone harness;
these are runtime diagnostics, not compiler warnings or a full app-host result.
Fixed-head app-host execution remains pending.
### Claude resume and disabled git-watch fixture contracts

Final C run `38509817630` shard 4 exposed three stale Claude command expectations
and two disabled-git-watch fixtures with overlong Unix socket paths. Unchanged
native build 785 reproduced all three command failures. The generated commands
correctly use sorted environment assignments and the maintained optional cwd
guard outside the portable `/bin/sh` wrapper. Owned executable probes verified
configuration selection, preserve-environment flags, cwd and resume/model/
permission arguments without changing production rendering.

The shell fixture's old bind helper silently truncated paths beyond Darwin's
104-byte `sun_path` capacity. An owned overlong-path probe reproduced all eight
failed assertions: the full path was absent, so both prompt hooks returned
before clearing git state. Shortening only the owned parent made both original
cases pass. The replacement uses a short owned `/tmp` directory and explicitly
checks UTF-8 byte capacity before binding.

`SessionIndexClaudeResumeCommandTests` migrates the three Claude cases into
actual command execution, including quoting and omitted unconfigured roots.
`NoGitWatchShellIntegrationTests` retains all six assertions for each interactive
shell. `NoGitWatchShellFixture` owns the socket and shell home;
`ShellContractProcess` observes native process termination before launch and
joins it before resources are released. Its original five-second shell deadline
is followed only on failure by the maintained 200ms owned-process termination
grace and escalation. All five migrated cases pass against native build 786 in
Swift 6 without warnings. Spawn-failure, timeout and cancellation controls retain
their original errors and verify that an owned child ignoring SIGTERM has exited
before return. Injected bind/fcntl failures each close the descriptor once and
remove the root; an overlong-path control fails before creating a descriptor.
Negative command copies detect incorrect preserve-environment flags and missing
cwd guards, and both shell cases reject enabled git watching. Actual fixed-head
macOS 15 app-host verification remains pending; the canonical/local
`claude_resume_and_no_git_watch_fixture_verification` caveat stays open. No
production policy, deadline extension, serialization or assertion weakening is
introduced. Shard 4's exit 124 still leaves full-suite coverage incomplete. The
localization audit finds only test diagnostics and contributor prose, with no
shipped strings or catalog changes.


## Welcome shortcut window ownership verification

The final C shard-3 run (38509817630, job 115676261545) twice crashed after
`testWelcomeWindowSidebarShortcutsUseSharedToggleCommands` in XCTest object
cleanup. The migrated `WelcomeWindowShortcutTests` retains its NSWindow from
construction through `performClose`, preserving all eight command metadata,
handler and visibility expectations. The real queued right-sidebar action is
observed through its FIFO event-delivery boundary, with the original one-second
failure deadline; no polling or settling delay remains in the migrated case.

The existing offscreen NSWindow lifetime control crashes with the default
release-on-close policy and exits cleanly with retained ownership. Exact new
sources typecheck without warnings against build 786 in the test target's Swift 5
mode. Swift 6 rejects the existing imported mutable `settingsFileStore` boundary;
no suppression or production ownership change was added. Actual Welcome window
routing remains an app-host CI gate; the primitive and typecheck do not establish
that result. Existing full shard coverage is unchanged. No local foreground
window, app launch or runtime build was used for this correction.




### Grok hook connection fixture correction

Combined run 38509817630, shard 3 job 115676261545, failed
`testGrokStopFallbackCompletionsFireForTwoConcurrentThreads`
and `testGrokNotificationStillFiresOnRepeatedPromptWhenFeedTelemetryDoesNotReply`.
Their mock accepted exactly one connection per invocation. Owned traces against
the unchanged 773 CLI show each hook also opens a separate one-way `feed.push`
connection. With the old per-invocation accept budget, the next server consumes
that queued telemetry connection while the next hook's RPC waits until its
unchanged five-second deadline. An unrestricted owned server runs the same
session-start and prompt in under 0.2 seconds each.

The two tests now use the shared `CLISocketFixture`, with no connection-count
limit, and the reviewed `ShellContractProcess` to join each owned process before
capture drains its input. File-backed input/output, short socket roots and an
isolated hook store retain the original target, transcript, status, notification
and duplicate-suppression assertions. Current id-less telemetry receives no reply;
the repeated-prompt case verifies that telemetry actually arrived. The shell
process owner is shared with the Claude/shell contract fixtures, not duplicated
in the final integration. Its constructor injects the failure deadline and
termination grace, retaining the existing five-second and 200-millisecond defaults.
Focused spawn-failure, deadline escalation and cancellation controls pass with
short injected durations; each verifies the owned child has exited before cleanup.

Exact native build 786 execution passes both cases with a warning-free Swift 6
compile. This corrects a measured fixture protocol mismatch; it does not explain
the separate Antigravity detached-worker timeouts or clear the existing process
scheduling caveat. Full app-host verification remains open. No production code,
CLI deadline, runner policy or shipped localization changed.

### Antigravity hook fixture completion boundary

Combined run 38509817630 shard 3 failed the Antigravity stop/notification
lifecycle case. Its detached mock launched 128 blocking accept workers before
running any hook. A controlled native probe using the unchanged legacy process
helper returned `/usr/bin/true` with status zero but `timedOut=true` after 7.019
seconds under those workers; without them it returned normally in 0.065 seconds.
This proves a false timeout at that fixture boundary, not the cause of every
subprocess failure in the combined run.

The migrated case uses the existing asynchronous socket fixture and joined shell
process owner, with the same five-second deadline. All original background-work,
missing-fullyIdle, shared-status, completion, session-end routing, duplicate,
permission and error assertions remain. Each invocation captures completed RPC
and id-less telemetry producers without preallocating blocking accept workers.
The owned responder supports current routing/resume requests and rejects unknown
commands; id-less telemetry receives no response.

Unchanged build 786 passes the full lifecycle case in 0.917 seconds with a
warning-free Swift 6 compile. Removing captured notifications in a temporary
control fails five original notification assertions. Local proof does not replace
fixed app-host and full-suite verification; the canonical/local caveat remains
open. No production, subprocess timeout, runner or shipped string changed.

### Workspace runtime close fixture ownership

Combined run 38509817630 shard 3 crashed while closing a workspace whose test
installed the invalid native pointer `0x5282`. Intercepting only native free did
not protect the earlier focus/occlusion calls. The migrated test attaches a real
terminal to an owned retained window, subscribes before attachment, and awaits
its actual runtime-ready event under the original three-second failure bound.
It retains confirmation, workspace removal, remaining-workspace count and runtime
detachment assertions, and verifies closed lifecycle plus idempotent teardown.

The old global free override selected a DEBUG-only utility-coordinator branch.
Ordinary explicit teardown schedules native free on the next MainActor turn;
deinitialization has a separate utility policy. Off-main and exact-pointer checks
therefore belong to the existing package coordinator's injected-free tests. No
invalid pointer enters live Ghostty, and no new global override is installed.
The real-runtime test does not claim to observe native free count or its thread.

Native build 786 executes the real workspace close successfully without activation;
the coordinator checks execute against the same compiled package owner. Focused
Swift 6 compilation is warning-free. Full app-host verification remains pending,
and the canonical/local caveat stays open. Production lifecycle/threading and
shipped strings are unchanged.


## Markdown rendering window ownership verification

The final C shard-2 job 115676261618 identifies four Markdown rendering cases in
XCTest object cleanup. `MarkdownWindowRenderingTests` migrates those cases while
retaining their windows from construction through close. All 118 expectations
remain: heading position (3), local image boundaries (12), data images (5), and
remote image consent/security (98). The other 24 legacy test bodies are unchanged.

The fixture owns navigation completion and DOM observations instead of XCTest
expectations or polling. The existing five-second navigation and three-second
image deadlines are retained; copied/reverted button states share one eight-second
budget. DOM load/error events and MutationObserver check the actual predicate,
including an initial-ready check. Completion removes listeners and observers;
native cancellation queues cleanup on the same page, and pagehide/phase expiry
also disconnect. Closing removes the script handler, stops loading, detaches the
delegate/view, cancels owned scheme work and releases the retained window.

Exact new sources compile without warnings in both the actual Swift 5 target mode
and Swift 6 against build 786. A temporary offscreen minimal-HTML WebKit probe
passes seven cases covering initial readiness, mutation, real image load/error,
deadline, cancellation and navigation replacement. Actual observer counts return
to zero and the script handler is absent after close; omitting disconnection in a
temporary negative control fails six cleanup assertions. Full rendering,
navigation, security and scroll execution remains app-host CI verification; a primitive window-lifetime control
or a minimal offscreen WebKit observer probe does not establish those outcomes.
No production renderer, timeout policy, CI selector or app runtime was changed.

### Titlebar sizing and command-palette metadata fixture contracts

Final-C run `38509817630` shard 2 failed
`TitlebarControlsSizingPolicyTests.testTitlebarControlsUseDeterministicContentSize`
and `CommandPaletteSwitcherSearchIndexerTests.testKeywordsIncludeDirectoryBranchAndPortMetadata`.
The former expected the old 152/139-point widths; the current classic/compact
controls reserve 238/233 points for seven 28-point targets and shortcut hints.
The latter expected a compound branch fragment as an independent token; the
package retains the full branch and splits surface components at path, punctuation,
and whitespace delimiters, so the compound query still matches the full branch.

Only those two methods migrate to Swift Testing. The titlebar case preserves its
0.001 tolerance and height assertion, renders the actual ordinary and split
controls, and verifies seven contained hit lanes, action dispatch, and noninteractive
gaps. Its synchronous main-actor fixture snapshots and restores exact persistent
values and argument/registration fallbacks separately for the six shortcut keys,
font magnification, and constructor-owned backup/import/legacy metadata. It also
restores shortcut file-store identity. A constructor-owned empty settings file
disables fallback paths and watching; SwiftUI debug settings use an isolated
defaults suite. No global fixture value crosses an await.
The search case retains directory, basename, full-branch and port assertions and
requires component tokens plus successful compound-query matching.

Native 786 verification on local macOS 26 passed both functions (three parameter
cases), with temporary seeded-settings restoration controls. Success and throwing-body
controls preserve originally absent persistent keys despite argument/registration
fallback values, restore store identity, and remove the owned directory. The
original expectations produced exactly three failures in a controlled temporary
copy. Independent rendering and hit tests show that the old widths clip the
forward-history target. Package controls covered all delimiters, full-value
retention, workspace/surface ranking, and rejected unrelated or branch-removed
queries. No production code, deadline, or assertion tolerance changed.

The current Swift 5 target compile is warning-free. A Swift 6 probe rejects the
existing nonisolated mutable `KeyboardShortcutSettings.settingsFileStore` seam,
including the maintained test isolation pattern; no suppression or unsafe
annotation was introduced. Complete accessory/hint-window composition, macOS 15,
and fixed-head app-host CI remain unverified. The prior full-suite exit-124
incomplete result remains open under
`titlebar_search_metadata_fixture_verification`.
### Initial terminal runtime readiness fixtures

The two initial-input/initial-command cases previously asserted a positive runtime
creation count synchronously, before the asynchronous command-shim prerequisite
finished. Native build 786 reproduces zero immediate attempts with the hidden
startup window already present, followed by a ready runtime and positive count
at the real `terminalSurfaceDidBecomeReady` event.

The migrated parameterized case subscribes before constructing either panel and
retains both original hidden-window and positive-attempt assertions. It also
checks the ready native runtime and absence of a user window. It never attaches
a visible window to force creation. The original tests had no asynchronous
failure deadline; a new injected three-second readiness bound matches the adjacent
real-runtime close fixture, with no sleep used for settling. Both cases pass
against build 786 with warning-free Swift 6 compilation. Full app-host verification
remains pending; production startup and shipped strings are unchanged.

## Notification-record restore fixture verification

Four legacy unread restore cases expected synthetic indicators even when their
snapshots contained actual unread notification records. `Workspace` restores
those records and deliberately suppresses duplicate synthetic indicators;
`TerminalNotificationStore.unreadCount` counts the records plus one independent
manual/panel-derived indicator. The original four cases failed seven assertions
against unchanged native build 786; the corrected record-backed expectations
passed all four on the same artifact.

`WorkspaceNotificationRestoreTests` migrates only those four methods to Swift
Testing, retaining badge visibility, mark-read and independent manual-unread
transitions. A fifth no-record control retains the legacy visual-only indicator
contract. `NotificationRestoreFixture` swaps the existing app notification store
synchronously on MainActor and scopes all mutation/cleanup to its own workspace
IDs; it tears down every owned panel and restores the previous store on throw.
No shared-store reset, production change, new selector or deadline is introduced.

Exact-source Swift 6 native execution uses the existing build 786 module with
isolated HOME/config, test mode before module initialization, an owned bundle
identity and prohibited activation. All five cases pass; a temporary control
that removes restored records fails the four record-backed cases while the
legacy control still passes. Owned normal/throw cleanup preserves an unrelated
record and its manual-unread flag. These are focused native results, not a full
app-host result; fixed-head macOS app-host verification remains pending under
`notification_record_restore_fixture_verification`. The localization audit
covers only test diagnostics and contributor documentation: no shipped copy or
localization catalogs changed.
### Grok payload lifecycle fixture completion

The actual shard-4 failure
`testGrokNotificationHookUsesPayloadMessageAndStopDoesNotSendGenericNotification`
used the same detached blocking-accept helper with 80 worker slots. Its migrated
scenario now reuses the joined Grok fixture. All 24 static hook calls and payloads
are preserved, including the neutral-message loop. The 46 semantic assertions
retain transcript/cwd/session isolation, persisted notification state, oversized
and partial-multibyte history handling, generic/fallback/internal notification
behavior, statuses and target checks. Process deadline, exit and output checks
remain in the shared invocation owner, with no deadline increase.

A separate `/usr/bin/true` probe with 80 workers did not reproduce a timeout;
the 128-worker Antigravity control is not proof that 80 workers caused this
particular CI failure. This removes the demonstrated shared helper's detached
blocking-worker lifecycle risk, while actual CI attribution remains open.
Native 786 runs this full scenario plus both prior Grok cases successfully in
1.697 seconds with warning-free Swift 6 compilation. A temporary wrong-target
capture control fails 12 original notification target assertions. The canonical
Grok verification caveat remains open for full app-host execution. No production
hook, transcript parsing, socket policy or shipped string changed.
### Tagged CLI socket-home fixture paths

Final-C run `38509817630` shard 2 rejected the stable socket paths in
`testBundledCLIInTaggedDebugAppPrefersItsOwnSocketWithoutEnvironmentOverride`,
`testBundledCLIInTaggedDebugAppTreatsCaseVariantStableEnvSocketAsImplicitDefault`,
and `testBundledCLISkipsIdentifierlessNestedAppWhenResolvingTaggedSocket` before
launching the CLI: the platform temporary-directory prefix plus fixture UUID and
canonical `.local/state/bmux/bmux.sock` suffix exceeded Darwin's Unix socket path
capacity (`NSPOSIXErrorDomain` 63).

The shared helper now creates its unique owned home under `/tmp`; canonical
`BmuxStateDirectory` layout, responder capacity guard, bundle-resolution inputs,
response assertions, and deadlines remain unchanged. Native 786 reproduces all
three original long-path rejections. With the short root, the case-variant test
passes; the other two get through socket setup and send `ping`, then fail with
receive-timeout `EINVAL` (22). An owned CLI control receives `TAGGED` and fails
with both default and explicit five-second timeouts, while `PONG` succeeds with
both. The retained multiline response path configures a 0.12-second idle timeout
for `TAGGED`; `PONG` completes without that transition. This separate runtime
failure remains unresolved; no response or assertion was weakened to hide it.

Full three-case acceptance and fixed-head app-host CI remain open under
`cli_socket_home_fixture_verification`; the prior full-suite exit-124 incomplete
result is unchanged. Existing responder stop does not join its accept worker,
and the legacy fake-bundle helper lacks directory cleanup; this root-only change
does not claim to repair those retained lifecycle limitations.

### Mixed signatures in pre-sign universal CLI artifacts

Final-C Release job `115681649397` in run `38509817630` failed the unsigned
Release CLI artifact gate with a universal-binary signature error. A real owned
reproduction with an ad-hoc signed arm64 slice and an unsigned x86_64 slice
produces the same error. `codesign -d` inspects the native architecture by default,
but `codesign --verify --strict` checks every architecture. The prior verifier
therefore detected the native signature and incorrectly rejects the permitted
unsigned sibling slice.

The test-only regression commit extends `tests/test_bundled_cli_artifact.py`,
already run by the existing shard-3 artifact gate. Real arm64/x86_64 fixtures
exercise mixed signed/unsigned CLI and framework targets independently. Their
acceptance cases require relocated execution and archive preservation of complete
Mach-O bytes and framework symlink destinations. Corruption controls first verify
both signatures, corrupt only the nonhost slice, confirm the native signature
still validates, and require verifier rejection before execution. The framework
control uses a thin CLI so the invalid extra framework architecture cannot hide
behind checking only the executable's architecture list.

Local macOS 26 execution currently runs 14 cases: the two mixed-signature
acceptance cases fail at the existing signature gate as intended; the other 12
pass, including both nonhost corruption controls. The mixed cases' archive and
relocation assertions remain pending behind that expected failure. No verifier,
workflow, shipped artifact, or signing policy changed in this test-only commit.
Only disposable test fixtures are signed, stripped, or corrupted.

Under `bundled_cli_mixed_signature_regression_verification`, the existing CI gate
must record the regression failure before the implementation commit. The fix
must inspect every architecture present in each signature target, preserve
framework-bundle signature ownership and deduplication, permit unsigned slices,
and strictly verify every signed slice without modifying artifact bytes. Full
Release/fresh-runner and app-host verification, including the prior exit-124
incomplete native suite, remain open.
### Sidebar terminal hit boundary fixture

The failed C `testHostViewStopsSidebarPassThroughJustInsideTerminalContent` used a full-width terminal over an unrelated internal split and a stale two-point overlap. The maintained `SidebarResizeInteraction` reserves four content-side points; `WindowTerminalHostView` detects the sidebar from the leading hosted-content edge and intentionally rejects sidebar routing for full-width content. `SidebarTerminalHitBoundaryTests` replaces only that case with an owned retained offscreen window and a terminal starting at x=120, with no internal split. A synthetic pointer tests pass-through at x=124 and a concrete hosted-terminal hit at x=125. Both original pass-through/content outcomes remain required. No rendering, hit-testing policy, or typing-sensitive production path changes.

The new suite participates in the existing broad test sharding; workflow selectors are unchanged. Actual C failure and the root's native original-boundary negative are retained. Exact-source strict Swift6 compilation is warning-free; unchanged build786 passes the migrated case in0.058s. A temporary copy restoring the two/three-point boundary fails exactly the original hosted-hit requirement. Full macOS15 app-host verification remains pending. Only test diagnostics and contributor documentation changed; no shipped localized strings were added.

## Closed-peer CLI receive regression gate

The short socket-home correction exposes a separate receive failure: after an
unrecognized newline-terminated reply, `SocketClient.send` changes to its
multiline idle timeout. Darwin returns EINVAL when that socket's peer has already
closed. Native socketpair controls establish that peer state, not `timeval`
size/stride, causes the option-setting error.

`tests/test_cli_closed_peer_receive.py` drives the actual built CLI through a
short owned Unix socket. After receiving its complete ping request, the fixture
stops only its owned child, observes native stop acknowledgment, writes the
response and closes the peer before resuming. This establishes ordering without
polling or sleeps. A scoped three-second harness deadline retains the existing
CLI test bound; the production response/idle timeouts are unchanged. Cleanup
resumes a stopped child before killing/joining it, removes owned files and socket,
and restores the process alarm handler/timer. HOME/config and telemetry test
settings are isolated; no app or user socket is opened.

Against unchanged native build 786, three functions exercise six scenarios:
PONG, empty EOF and truncated EOF pass, while complete TAGGED, Unicode multiline
and final-unterminated-line responses fail with the same receive-timeout EINVAL.
Temporary deadline controls before accept and while writing to the stopped
child confirm joined child cleanup, removed socket/home and restored signal
state. This is test-only red evidence, not a production fix or full CLI pass.

The shard-3 bundled CLI artifact step first builds and executes native linkage,
then invokes both independent Python regressions against that exact artifact.
It retains both exit codes and fails when either is nonzero; dependency-closure
verification and archive creation follow only after success. No failure is waived.
G run `38593929044`, job `115958161129`, executed all three socket test functions
at 2026-10-14 16:25:54 UTC. Exactly the complete TAGGED, Unicode multiline and
final-unterminated-line scenarios failed with receive-timeout EINVAL; PONG and
both EOF error controls passed. The step exited 1. This is the required actual
CI red, distinct from D2's missing-artifact setup failure.

### Closed-peer receive correction

`CLISocketReceiver` owns the receive-timeout syscall/cache and byte-read mechanics;
its descriptor is borrowed from `SocketClient`, which retains socket lifetime,
request/framing policy, timeout sanitization and operation telemetry. If Darwin
rejects a timeout change with EINVAL, one nonblocking receive must actually return
bytes or EOF before the unchanged parser proceeds. Would-block or any other read
failure preserves the original configuration error. Other configuration errors
remain strict, as do connect/authentication/event-stream configuration calls.
Only successful configuration updates the cache; closing the client resets it.
No deadline, retry, polling, JSON/PONG classification, output whitespace or error
message changes. Existing operation phase and byte counts continue to describe
received data; no payload logging is added.

The complete extracted `SocketClient` source compiles warning-free in target
Swift 5 mode and passes the unchanged three-function/six-scenario Python suite.
Strict Swift 6 receiver controls cover an 18 KB Unicode reply across three reads,
final EOF, ordinary live-peer timeout and invalid descriptor. Invalid-timeval
control returns EDOM on this host and remains an error. A temporary syscall-result
injection (not shipped) supplies EINVAL while real native receives return EAGAIN
or EBADF; both retain the original EINVAL message and leave the cache unchanged.
Fresh isolated build 788 (`maintenance-closed-peer`) succeeded on integrated
`fc303bcc862415cb2e74ef255aeeb9616d75891e` in 175 seconds and was not launched.
Its bundled CLI passes the unchanged three-function/six-scenario closed-peer
regression, existing socket-operation deadline suite and broken-stdout SIGPIPE
checks with owned temporary homes and sockets. Additional built-artifact controls
preserve exact JSON output, an 18,024-byte Unicode multiline reply, and an
18,015-byte reply with an unterminated final line. The receiver and CLI compile
without warnings; the app build retains 127 distinct warning lines in existing
app code/assets. Fixed-head run `38600136921` subsequently passed all three
closed-peer tests (six scenarios) and all 14 artifact tests in shard 3 at 17:31 UTC
on October 14. This resolves the specific receive-regression verification caveat;
the final combined candidate still requires every configured merge gate.
Existing shipped error text is byte-identical;
no new user-facing copy needs translation.

## Browser portal presentation fixture migration

The three `BrowserWindowPortalLifecycleTests` failures in final-C native shard 2
(run `38509817630`) are migrated to
`BrowserPortalPresentationContractTests`. The external split-resize test now
observes the real `WKWebView.displayIfNeeded` boundary through a per-instance
`AsyncStream`, accepting only a redraw at the resized anchor width. The old
250ms run-loop wait becomes a cancellable 250ms failure deadline. It preserves
the visible-slot, narrower-frame, repaint, and unchanged-reattach assertions.

Ordinary portal hide/show repaints without WebKit lifecycle reattachment; the
positive control explicitly marks hidden-host adoption and requires reattachment
and flag clearing. Transient anchor removal preserves the visible attached slot
and its frame until rebind; rebind must reuse that slot and repaint. These
contracts are in the existing portal and rendering-state owners, both unchanged
from the main baseline. No production behavior changes in this migration.

All three cases passed locally against unlaunched Debug artifact 786 in both
Swift 5 and Swift 6 compilation modes, without warnings or window activation.
Temporary old-expectation controls failed all three cases. Separate native
controls covered buffered display delivery, missing-signal deadline, cancellation,
and finished-stream behavior. Each test tears down its portal and owned window;
web views use nonpersistent storage. The remaining legacy test bytes are unchanged.

This is focused native-module evidence, not a complete app-host test-target or
macOS 15 result. Integrated fixed-head CI, full-suite execution, and visual
WebKit rendering remain open under
`browser_portal_presentation_fixture_verification`. Contributor verification
notes and test diagnostics add no product UI or localization keys.

### Native Xcode project syntax verification

D activation job115706442232 failed before build or benchmark: Xcode could not parse three newly added Markdown test extension paths containing `+`. Source wiring and normalization had passed because those checks do not parse OpenStep syntax. Quoting only those three `PBXFileReference.path` values fixes the native parser failure; file identities and target membership are unchanged. Native Xcode project loading also exposed one duplicate `ShellContractProcess.swift` navigator membership; removing that duplicate leaves its single file reference and Sources entry intact. `scripts/check-pbxproj.sh` now also runs Apple's `plutil -lint` on macOS, alongside the unchanged object-version and normalization checks. Linux retains its existing checks without a new dependency or custom parser.

An owned temporary copy of the exact D project fails the native guard; the corrected project passes. No metadata-string assertion test was added: the native parser exercises the actual failing boundary. An isolated `xcodebuild -list` now passes project parsing but stops at this sibling worktree’s missing `GhosttyKit.xcframework`; full dependency-resolved project loading remains pending in the initialized integration tree. The failed activation run does not constitute Release-signature or closed-peer regression evidence; both named test-only reds still require actual execution. No app build, launch, active-app replacement, or runtime behavior change is part of this correction. Corrected-head CI remains pending.

### Typed input and Korean Return runtime readiness

Run 38509817630 shard 3 (job 115676261545) reported missing native input in
`testDirectInsertTextUsesTypedInputSemantics` and retained marked text plus a
missing Return in `testReturnAfterKoreanCommitAlsoSendsReturnToSurface`.
The direct-input case passed on retry; Korean Return failed again. Neither
failure recorded whether the terminal runtime was ready.

Both cases now use the existing `TerminalNativeInputDeliveryTests` ready-surface
fixture, which subscribes before attachment and requires the runtime before
installing synchronous input probes. The original exact text/keycode assertions
and real Korean `keyDown` path remain; the Korean case also requires exactly one
interpretation and one forwarded Return. Prior observer, layout and interpreter
hooks are restored before any suspension. The old synchronous cases used 50ms
settling without an explicit failure deadline; the migrated cases adopt the
existing suite's one-minute outer test limit. The helper and runtime timeout
policy, input owners, workflow selectors and production behavior are unchanged.

An owned, offscreen native probe on unchanged build 786 reproduced both missing
input signatures before readiness and delivered the expected inputs after the
actual ready notification. The two migrated cases pass against that same module. A temporary copy bypassing
only readiness fails both cases with five issues, including all four original
behavior oracles. This establishes the fixture precondition, not the exact macOS 15 CI cause.
The complete affected files compile without warnings in the test target's Swift
5 mode. Strict Swift 6 still encounters the existing nonisolated
`KeyboardLayout.debugInputSourceIdOverride` and legacy CJK support boundary; no
suppression or production hook was added. Fixed-head macOS app-host verification
remains pending.

### Remote agent fork fixture path ownership

`WorkspacePanelGitBranchTests.testForkAgentWorkspaceLaunchInRemoteWorkspacePreservesRemoteContext` supplied an agent socket path that did not exist. The maintained `WorkspaceRemoteConfiguration.resolvedAgentSocketPath` deliberately accepts only existing paths and falls back to the caller's agent environment. Native artifact 786 reproduced all four agent-environment mismatches with an absent owned path; creating that path made all original checks pass.

The case now lives in `WorkspaceRemoteForkLaunchTests` using Swift Testing. It owns a unique temporary directory and an existence-only placeholder, matching the resolution boundary already used by `SSHAgentEnvironmentTests`. No SSH connection or agent traffic is started. All 15 original behavior assertions remain, including remote options, launch command/input, four agent path projections and discarded relay/socket ownership. Workspace panels and temporary files are released on every exit. Untouched legacy test methods are byte-identical.

The migrated case passes against native artifact 786 in Swift 5 and Swift 6 without compiler warnings; removing only placeholder creation fails the same four assertions. This is focused native-module evidence, not a full app-host pass. Integrated CI remains pending. No product behavior, workflow selectors, deadlines or user-facing strings changed; localization catalogs need no updates.

### Default cloud proxy retry state

The actual combined C case `testDefaultCloudProxyOnlyErrorsDoNotPolluteConnectedSidebar` fails when a default cloud workspace clears an old proxy-only sidebar artifact during reconnect: the model becomes reconnecting instead of retaining connected state. Native artifact 786 reproduces exactly that assertion, while the other original assertions pass. The shared state-update owner already preserves the default cloud connection on the initial proxy-only error; its retry predicate currently only includes ordinary SSH workspaces.

The existing case is migrated to `CloudProxyRetryStateTests` with all ten original assertions retained and explicit teardown for both owned workspaces. Its source compiles warning-free in Swift 6 against artifact 786 and reproduces the same single failure. No additional workflow selector or deadline is introduced. Non-proxy disconnection, persistent SSH daemon failure, WebSocket transport failure and ordinary SSH proxy behavior remain required controls for the scoped production correction. Fixed-artifact and full app-host checks remain pending under `default_cloud_proxy_retry_state_verification`.

The local correction reuses the existing default-cloud policy in the retry predicate, only when the prior sidebar artifact is classified as proxy-only. Existing details, status cleanup, notifications, logging and error classifications remain owned by the same path. No new diagnostics, secrets, product copy or localization keys are introduced; existing status projections remain the observable verification boundary.

Five temporary controls passed against unchanged artifact 786: default-cloud non-proxy error/disconnection and retry without a proxy artifact, ordinary SSH proxy retry, WebSocket transport failure, and persistent-PTY daemon failure. They establish the retained baseline before the required fixed-artifact rerun; they do not verify the new predicate. The correction changes one shared predicate line with zero file growth. Isolated build 787 now passes the original regression and all five preserved controls, compiled without Swift 6 warnings. Integrated app-host CI remains required.
## Deleted agent-hook working directory regression

Final-C shard 3 (run `38509817630`, job `115676261545`) failed the existing
`SessionPersistenceTests.testRestoreDoesNotPassDeletedAgentHookCwdToTerminalRuntime`
assertion because restore passes a deleted directory to the terminal runtime.
The same case also rejected a valid brace group in the outer zsh launcher's
post-agent footer. `SessionRestoreDeletedDirectoryTests` migrates exactly that
case to Swift Testing and scopes the fish-safe brace assertion to the actual
inline startup command. It preserves the nil runtime-cwd, resume arguments,
saved-path, and guarded fallback assertions, with isolated defaults and explicit
workspace/launcher cleanup.

Against unchanged unlaunched native artifact 786, the migrated test compiles in
Swift 6 without warnings and fails only the original nil-cwd assertion. The
shell assertions pass. The restore policy now keeps a guarded local cwd only if it is an existing
directory, through a constructor-injected filesystem predicate. Remote gating
and directory metadata remain separate. The focused Swift 6 policy harness
passes all eight existing policy methods and six temporary directory-control
variants. Isolated build 787 also passes the migrated regression plus nine
workspace controls: existing, missing, file and unmounted directories; remote
and local launch ownership; process-detected binding cwd; and scrambled
unmounted-volume reports. Compilation is warning-free under Swift 6. The complete
package graph and integrated app-host suite remain pending. Existing local
agent-hook directories, process-detected binding cwd, remote nil-cwd behavior,
and unmounted-volume metadata must retain their contracts. Full integrated
app-host/macOS 15 verification remains open under
`deleted_agent_hook_cwd_regression`. No product-facing strings change.

### Closed-peer gate build prerequisite

D2 run38521190849 shard3 job115712647469 executed all14 bundled-artifact tests and failed exactly the two mixed signed/unsigned slice regressions. The closed-peer suite executed zero tests because its expected CLI did not yet exist: the earlier split-theme check builds only its package, not the app. That setup error is not socket regression proof.

The existing `BundledCLILinkageTests` xcodebuild invocation now runs before both Python regression commands in the same step, supplying the exact bundled CLI prerequisite. Both Python exit statuses are still collected and enforced; dependency-closure verification and archive creation remain afterward. No job, selector, test deadline, or failure policy is removed. Corrected-order actual closed-peer execution remains pending under the existing open verification caveat. No runtime or product copy changes are included.
The test-only source ran all14 cases in D2 CI run38521190849, shard3 job115712647469. Exactly the two mixed-signature cases failed at codesign inspection; the other12 passed, including nonhost corruption controls. The separate closed-peer suite executed zero cases because its app build prerequisite was missing, so that setup error does not provide socket regression proof.

The verifier now enumerates each closure Mach-O's actual architectures and deduplicates signature checks by existing bundle-or-file target plus architecture. Display and strict verification use the same explicit architecture. Unsigned slices retain the existing pre-sign allowance; signed slices, including extra framework architectures absent from a thin CLI, must verify. Staging, archive creation, executable bytes, framework symlinks, and relocated execution are unchanged. No shipped artifact is signed or modified.

All14 real-artifact tests pass locally on macOS26 in8.122s after the fix, including both mixed targets' relocated execution and exact archived bytes/symlinks and both corrupt-nonhost rejection controls. This is local artifact evidence, not final CI green. The open `bundled_cli_mixed_signature_regression_verification` caveat now records captured CI red and local fixed coverage; full Release/fresh-runner and app-host verification, including the prior exit124 incomplete native suite, remain required. Diagnostic signature counts now describe architecture slices. No product-facing copy or localization keys changed.

### Resume cwd and captured fork command contracts

Final C's shard 3 job 115676261545 failed the old SessionEntry Claude cwd string
assertion, and shard 2 job 115676261618 failed the captured Codex re-fork prompt
omission assertion. The shared cwd guard was adopted by `f2123dc2c` (#6580), then
made fish-safe by `5265559d5` (#6328). Codex captured-fork tag replay was deliberate
in `9374b139e` (#6803); resume still strips those tags, as maintained package
coverage requires.

The two legacy methods migrate to Swift Testing. Claude now executes the actual
command using the existing owned `ShellContractProcess` and verifies cwd plus
exact session argv. `AgentForkCommandContractTests` retains all eleven original
fork command/context checks, correcting only deliberate captured-tag retention.
Its executed direct/Teams fork-versus-resume controls verify the exact target,
argument ordering, tag boundary, cwd and `CODEX_HOME`. No production parser,
command policy or workflow selector changes.

The affected suites and shared process helper compile warning-free under Swift 6
against unchanged native build 786. Five functions (nine expanded cases) pass.
Owned native generation followed by shell execution also passes fourteen sh/zsh
scenarios, including the existing missing-cwd policy. These probes do not launch
real agents or activate the app. Fixed-head app-host verification remains pending.
### Sidebar pull request projection fixture

Run 38509817630 shard 2 (job 115676261618) failed the background-PR-empty
assertion in `testSidebarPullRequestsTrackFocusedPanelOnly`. The maintained
`Workspace.sidebarPullRequestsInDisplayOrder` aggregates valid PRs from every
panel; `Workspace.pullRequest` separately projects the focused panel's PR.
The original fixture incorrectly required these two projections to coincide.

The case now lives in `WorkspacePullRequestFocusContractTests`. It retains the
original focused nil and post-focus PR assertions, requires the background PR
in the sidebar aggregate, and verifies that switching back clears only the
focused projection. The synchronous fixture owns and tears down its workspace
panels; it introduces no observation, polling, deadlines or shared hooks.
All other legacy methods remain byte-identical. An isolated native build 786
probe reproduced the original empty-list failure and passed the corrected
projection contract. Fixed-head app-host verification remains pending. There
are no product strings, production changes or workflow selector changes.

### Combined repair build 787 and D2 outcome

The initialized integration tree loads through Xcode's native project parser,
and D2 run `38521190849` passed Swift packages, build/lag checks, and web/Linux
checks. The separate D2 activation benchmark passed. All four native shards
failed; shards 2 and 4 timed out before completing broad coverage. Release
failed at the mixed-signature audit captured above. These are unresolved gates,
not successful validation of the complete change.

Isolated `maintenance-runtime-repairs` build 787 compiled source `1d72f1417`
without launching or replacing the running previews. Native cloud and directory
controls above exercise this exact artifact. The integrated tree passes native
project parsing, normalization, wiring for 553 test files, strict determinism,
and the main-base Swift file budget. The warning budget reports 126 retained
warnings against 221 allowed, matching build 786; no warning allowance changed.
The tagged reload compiles the app, not the complete test target. The next CI
run must execute that target and all configured gates on the published commit.

### Notification focus event fixture

Run 38509817630 shard 2 failed all five dismissal/flash results in
`testFocusPanelDismissesUnreadNotificationWithDismissFlash`. The maintained
`FocusSurfaceBroadcaster` explicitly defers delivery; the original test asserted
before the real focus notification reached `TabManager` and its shared dismissal model.
The existing synchronous `flush()` boundary preserves that event path without a
sleep, fabricated notification, or production behavior change.

`NotificationFocusEventTests` retains every original focus, unread, indicator,
and flash assertion and verifies unread state before delivery. It seeds only its
owned workspace's records, clears only those records, and restores app composition,
focus override and exact persisted defaults before returning on the MainActor.
Teardown focus delivery is flushed before restoring the original optional app
delegate; native nil/existing-delegate controls verify identity restoration.
No delivery-handler override or shared notification reset is installed. All other
legacy methods remain byte-identical. Native artifact 786 passes the migrated
case; removing only the final flush reproduces the five original failures.
Actual-target Swift 5 compilation is warning-free. Forced Swift 6 still rejects
the existing imported mutable `AppFocusState.overrideIsFocused` seam; this repair
does not suppress or alter that legacy owner. Fixed-head app-host verification
remains pending. No shipped strings or workflow selectors changed.
### IME, modifier and terminal focus fixture readiness

Seven additional failures from C run 38509817630 and D2 are now covered in
`TerminalNativeInputDeliveryTests` and `TerminalSurfaceRecoveryTests`: Option-N
dead-key composition, shifted backquote, Option-Delete, Zhuyin marked text,
responder loss during recovery, inactive visibility restoration, and direct
focus refresh. Only those seven legacy methods move; their exact input modifiers,
text/key arrays, marked-text, focus and redraw assertions remain. Backquote uses
the existing per-view interpreter hook to commit no text, explicitly exercising
the real fallback instead of depending on the machine's input-source behavior.

`TerminalRuntimeReadinessFixture` owns the notification subscription before
attachment or recovery, plus an injected cancellable failure deadline. Initial
readiness is bounded at three seconds; recovery retains the original explicit
five-second bound. The migrated tests also inherit their suites' one-minute outer
limit, replacing unbounded synchronous cases with 50ms settling. Process-wide
input hooks exist only in synchronous bodies after readiness and are restored
before suspension. Owned windows are retained at construction and closed after
terminal teardown. No production input policy, workflow selector or clipboard
behavior changes; paste-routing, Kitty output and notification-flash cases remain
outside this correction.

Unchanged native build 786 reproduces missing input/focus preconditions without
readiness, then passes the preserved assertions with actual runtime events.
These controlled results establish fixture prerequisites, not the exact macOS 15
CI scheduling cause. The complete affected suites compile without warnings in
the test target's Swift 5 mode and pass 14 functions (15 cases) in an owned,
offscreen native process. A temporary exact-source copy omitting initial readiness
fails all seven migrated cases with nine behavior issues. Two temporary lifecycle
controls verify missing-event timeout, cancellation/join, and observer closure.
Strict Swift 6 retains the existing imported
`KeyboardLayout.debugInputSourceIdOverride` and legacy CJK hook isolation gap;
no suppression or runtime hook was introduced. The shared readiness owner and
complete recovery suite also compile without warnings in strict Swift 6; the
async fixture body explicitly retains MainActor isolation. Fixed-head macOS app-host
verification remains pending.

### Keydown notification surface-flash fixture

The C app-host failure in
`testTerminalKeyDownDismissesUnreadWhenSurfaceIsAlreadyFirstResponder` cleared
unread state but counted zero renderer flashes. Its ambient overlay preferences
could select a valid workspace-pane flash instead, and it did not establish the
native runtime before keydown. These are proven fixture preconditions; the
actual failing CI preference value is unknown.

`NotificationKeyDownTests` preserves the real F1 action, first-responder and unread
assertions, and the exact one-renderer-flash result. Its owned fixture awaits the
real runtime-ready event, then synchronously installs and restores app composition,
focus and exact persisted preferences with an explicit enabled surface target.
Only its unique workspace notification is seeded and cleared. The renderer queues
one callback; the maintained FIFO event-delivery pattern observes that callback
with the original one-second failure bound after all global overrides are restored.
No polling, shared counter reset, clipboard access, production change or new
workflow selector is introduced.

Unchanged native artifact 786 passes the migrated case with warning-free target
Swift 5 compilation. A temporary ready-runtime control retaining the original
renderer assertion fails exactly once when only the target changes to a workspace
pane; the explicit surface target passes. This proves preference isolation matters,
not that it caused the CI failure. The imported mutable `AppFocusState` seam still
prevents forced Swift 6 checking, as in the adjacent focus fixture. Fixed-head
macOS 15 app-host completion remains pending.
### Fork-command fixture compiler inference

E run 38585955198 shards 2 and 4 (jobs 115929521031 and 115929521191)
failed before tests: Xcode 26.3 could not type-check an expression in
`AgentForkCommandContractTests`. The retained console output names the file but
omits the expression location. The same source compiles with local Swift 6.3.3
in the target's Swift 5 language mode, so the older compiler failure has not
been reproduced locally.

The measured local inference hotspot is the final macro assertion combining
`Array(fields.dropFirst())` with a concatenated expected argument array. Both
arrays now have explicit `[String]` local bindings before their unchanged
comparison. The expected fields, order, all eleven fork-command variants, and
executed argument/cwd/environment assertions remain identical. No command,
process fixture, timeout, test selection or compiler setting changes.

The complete affected fork and Claude resume fixtures compile without warnings
and pass five functions (nine cases) against unchanged native build 786.
This focused check does not replace full test-target compilation: the next
integrated batch must compile the entire `bmuxTests` target with CI's Xcode 26.3
and run the app-host tests. That gate remains open.

### Combined native test-target compilation after E

The combined revision `3a3f5f7ee` passed a complete `bmux-unit`
`build-for-testing` with Xcode 26.6 (Swift 6.3.3), using the target's Swift 5
language mode. The compiler input contained all 557 wired test files plus 14
shared source files. This used a new isolated derived-data path and bundle IDs;
no tests or app were launched and existing preview artifacts were untouched.
The local SDK's existing `BMUX_SKIP_ZIG_BUILD=1` workaround was retained.

The repaired fork assertion and all newly added or rewritten fixture owners
compiled without warnings. The full target still emitted 404 distinct warning
lines, predominantly legacy XCTest import diagnostics repeated across compiler
batches, alongside existing app/test warnings. Modified legacy files retain
unchanged import and unused-result warnings; no warnings were suppressed and no
warning budget was relaxed. This is compilation evidence, not a passing test
suite. CI's Xcode 26.3 compilation and complete app-host execution remain open.
Run 38585955198 shard 2 (job 115929521031) and shard 4 (job 115929521191)
failed before tests because Xcode 26.3 could not type-check an expression in
`AgentForkCommandContractTests`. The subsequently available shard 3 diagnostic
identifies line 345: `prefix + (resume ? ... : ...)`, not the final macro
comparison. The initial typed-comparison correction alone left that expression
unchanged. The correction now also uses an explicitly typed `[String]` branch
value followed by a separate prefix concatenation. Both branches retain exact
argument values and order; the final comparison keeps its explicit array types.

The local Swift 6.3.3 compiler accepts the original expression, so the older CI
compiler failure has not been reproduced locally. No compiler limits or flags
were relaxed. The complete affected fork and Claude resume fixtures compile
without warnings in Swift 5 target mode and Swift 6, and five test functions
(nine parameter cases) pass against unchanged build 786. All eleven original
fork-command assertions and actual argv/cwd/environment checks remain intact.
The next integrated batch must compile the entire `bmuxTests` target with CI's
Xcode 26.3 toolchain before these local results count as a repaired compiler gate.
### Paste shortcut binding fixture contracts

The three terminal paste cases from run 38509817630 shard 4 asserted a forced
AppKit paste action after a menu miss. Commit `a90bc5480` deliberately delegates
that path to Ghostty bindings so user overrides win. `GhosttyPasteShortcutBindingTests`
now exercises the real `NSWindow.performKeyEquivalent` entrypoint for Command-V,
Command-Shift-V, and Command-V after runtime release. It preserves consumption,
terminal association, exact modifiers/key, and immediate runtime recreation,
while expecting one native binding event instead of the obsolete direct action.

`GhosttyPasteShortcutFixture` owns a manual-I/O terminal, retained offscreen
window, and per-surface config. Actual Ghostty `text:` bindings emit distinct
bytes; neither the general pasteboard nor the global Ghostty config is changed.
A synchronous runtime-ready observer reinstalls only the owned config during
recreation. Menu/input probes and that observer are restored before the output
wait. Existing `TerminalRuntimeReadinessFixture` subscribes before mounting.
Initial readiness and output each have an injected three-second failure bound,
with cancellation and joined tasks. The old cases used a 50ms settling delay
and had no output deadline; these bounded waits are new fixture behavior.

Exact repository sources compile without warnings in Swift 5 target mode and
Swift 6 against unchanged native build 786. All three parameter cases pass in
an isolated test-mode process; wrong binding output and duplicate real dispatch
controls fail their exact output and single-forward assertions respectively.
These controls prove custom binding precedence, action execution, output and
runtime recovery. Actual default clipboard payload delivery remains untested.
Fixed-head macOS app-host verification is pending; local macOS results do not
resolve the macOS 15 CI boundary. No production policy, workflow selector or
terminal rendering changes are included.

### Exact conditional inference correction: combined compilation

After E shard 3 identified the failing conditional expression at line 345,
revision `8e79b921f` passed complete incremental `bmux-unit build-for-testing`
with Xcode 26.6 in Swift 5 mode. All 559 test files plus 14 shared sources were
compiler inputs. The exact conditional correction and both paste-binding
fixture files compiled without warnings. The retained CJK fixture emitted only
its existing XCTest import warning. The incremental log contains 158 distinct
warning lines; that count is not comparable to the preceding fresh build.
No app or tests were launched. Xcode 26.3 compilation and execution still gate
merge; the earlier local build did not prove the conditional compiled in CI.

### Browser omnibar arrow context fixtures

Run 38509817630 shard 2 (job 115676261618) reported empty field-editor key arrays
in the two omnibar restoration cases. Their random panel IDs and unregistered
windows did not satisfy `focusedBrowserAddressBarPanelIdForShortcutEvent`'s real
window-context, selected-workspace and browser-panel guards. The marked and
unmarked controls on unchanged build 786 reproduce that boundary: an unknown
window reports handled but delivers no editor key; a valid context delivers 123.

`BrowserOmnibarArrowRoutingTests` preserves both original native window dispatch
and exact `[123]` destination assertions, first-responder transitions, marked-text
state, event modifiers and field-editor identity. It adds explicit field-resolution
and restored-editor identity checks. `BrowserOmnibarArrowFixture` composes the real
`MainWindowContext` directly, following the maintained popover-focus fixture, and
uses the real panel's web view and `focusBrowserAddressBar(in:)` action. It avoids
`registerMainWindow`'s listener and persistence side effects. All setup, dispatch
and shared delegate/active-manager restoration are synchronous on MainActor;
owned panels and retained windows are closed. No clock bound, polling, production
seam, workflow selector or unrelated legacy case changes.

The new sources compile without warnings in Swift 5 and Swift 6. Both cases pass
in an isolated, nonactivating native 786 process. Removing only context composition
fails both original destination checks plus the four added resolution/restoration
checks. Temporary controls verify cleanup with both absent and existing delegates
and active managers; the owned socket path stays absent and no listener starts.
Native logs include existing disabled-Sentry breadcrumb diagnostics; these are
runtime diagnostics, not compiler warnings. Fixed-head macOS app-host verification
remains pending; the native check does not replace that gate.

### Kitty clear-history PTY fixture

C run 38509817630 shard 4 failed the Kitty clear-history test before either raw
input assertion: neither terminal-visible marker was found. The legacy reader
used `GHOSTTY_POINT_SURFACE`, which this Ghostty runtime maps to history only.
The maintained complete-text reader uses `GHOSTTY_POINT_SCREEN`. An owned native
787 child emitted both markers and exited normally while the old reader returned
empty; reading the complete screen saw both. A nearby uncorrelated CI PTY-close
line does not establish that this test's child exited.

The migrated single test keeps a real PTY, the actual zsh keyboard-reset bytes,
clear-screen action, synthetic key press/release, exact ASCII capture and absence
of printable CSI fragments. Owned per-surface title notifications acknowledge
that Ghostty parsed each preceding visible marker. Raw mode precedes readiness;
a separate owned PTY control proved that the former ordering could discard input.
The original five-second output bounds and child input bounds remain unchanged.
There is no foreground activation, clipboard access, production hook or polling.

Actual build787 passes the migrated test with warning-free Swift6 compilation.
The original read-domain negative reproduces the marker failure; omitting the
reset produces the Kitty release sequence instead of one ASCII byte. Temporary
cleanup controls cover cancellation, output timeout, a spawned child held before
PID publication, and closing before runtime creation. The existing synchronous
native-free test seam returns before owned files are removed; the held children
are alive before close and absent afterward. No new process-kill policy is added.
These local controls do not establish complete macOS15 app-host or final integrated
suite success; that gate remains open.
### Text-box clipboard timeout completion fixture

The actual C app-host failure in
`testTextBoxSubmitClipboardReadTimeoutRestoresPasteboard` used a synchronous
RunLoop wait while the real timeout posts its completion onto MainActor.
`TextBoxClipboardTimeoutTests` now awaits the existing dispatch completion
through a buffered AsyncStream. It retains all three dispatch events, the
`paste_from_clipboard` key assertion, the original one-second completion bound,
the temporary PNG, and exact restoration of the seeded string. The debug zero
timeout override is restored synchronously after dispatch captures it.

The existing `FakeTextBoxSubmitSurface` moves unchanged into a shared test file;
legacy callers retain their behavior. Cleanup uses the existing synchronous
`debugResetForTesting` boundary before restoring every original pasteboard item
and representation, including on timeout or cancellation. This prevents a late
runner from restoring its temporary snapshot over the outer snapshot. The
two current Swift Testing general-pasteboard writers and TextBox dispatch callers
share this serialized suite; remaining users are XCTest cases. This isolation
must be reassessed if another asynchronous writer is introduced.

Focused source compiles warning-free in Swift 5 and Swift 6. The entire retained
shortcut-routing container and its maintained support compile in Swift 5, with
three existing unused-local warnings and no new warnings. An owned native build
786 probe uses the exact shared fake and only baseline/wait events: the old
synchronous one-second wait does not complete, then awaiting the actual signal
completes successfully. This probe never reads or writes the general pasteboard
and does not prove clipboard restoration. The real general-pasteboard case was
compiled but deliberately not executed locally; isolated macOS app-host CI must
verify its full restoration contract. No production policy, timeout extension,
workflow selector or shipped text changes are included.

### Combined native fixture compilation

Revision `41d77c34d` passed complete incremental `bmux-unit build-for-testing`
with local Xcode 26.6 in Swift 5 mode. All 565 wired test files and 14 shared
sources were compiler inputs. The omnibar arrow, Kitty clear-history and
clipboard timeout fixtures and extracted clipboard fake compiled without
warnings. The incremental build retained 163 distinct warning lines; this is
not comparable to the earlier fresh build's warning count. No warning budget
was relaxed. No app or tests were launched, and the existing preview artifacts
were not replaced. Actual clipboard restoration, real inspector windows and
the complete macOS 15 app-host run remain CI verification boundaries.

### Native symbol point size and configured dimensions

D2 shard 2 (`115712647490`) failed the existing clamped-symbol test: AppKit
returned a 2-by-2 image for a one-point medium question-mark symbol, while the
test expected a 1-by-1 image. The maintained raster-sizing correction
`e3c4357a2` deliberately preserves valid configured symbol dimensions rather
than forcing square point-size dimensions. Point size and image extent are
different native API values.

The fixture now compares the returned image with AppKit's actual configuration
at the explicit one-point minimum and medium weight, matching the neighboring
non-square symbol test. It retains the template-image assertion and all other
sizing, cache, invalid-input and unknown-symbol tests. No production rendering
or cache policy changes. Against unchanged build 786, the original complete
seven-test suite reproduces exactly the 2-by-2 versus 1-by-1 failure; the
corrected suite passes all seven cases. Local compilation is warning-free.
Fixed-head app-host CI remains required; no test selector or gate is relaxed.
### Detached inspector manual-close observation

D2 shard 2 failed
`BrowserDeveloperToolsVisibilityPersistenceTests.testDetachedInspectorWindowWillCloseWaitsForManualCloseState`
at its 2.85-second synchronous wait and final preferred-visibility assertion.
The same case passed twice in C shard 3; this is not a claim of a C failure.
An owned native diagnostic retained preferred visibility after the synchronous
wait, then cleared it when the existing lifecycle stream allowed owner work to
complete. RunLoop-in-async warnings belong only to that temporary negative proof.

The single migrated method now lives beside the existing inspector transition
tests. It subscribes before show/close and uses the unchanged fixture's 2.85-second
bounded lifecycle wait, including closeCount == 1 and both hidden-state predicates.
All ten original assertions and real NSWindow visibility/close actions remain.
A raw willClose must leave the inspector open until its explicit manual-close
state is observed. The observer, retained window and panel use existing cleanup;
no shared fixture, production hook, chorded-close case or PBX membership changes.

The affected real-window source compiles warning-free in the target's Swift 5
language mode. Local execution uses only a temporary offscreen visibility
stand-in: that diagnostic plus seven unchanged lifecycle-observation controls
pass against frozen build 787. Omitting only the async wait fails the original
preferred-visibility assertion. These are diagnostic/control results, not a
passing execution of the real-window test. The committed real NSWindow case,
complete Xcode 26.3 target and macOS 15 app-host suite remain required CI gates.
### File preview inset fixture uses its real text stack

D2 shard 4 (`115712647520`) failed both line-fragment-padding assertions in
`testTextEditorInsetsReapplyWhenMovedBetweenWindows`: the convenience
`SavingTextView()` has no text container. The actual editor is constructed by
`makeFilePreviewTextView()`, which owns an explicit TextKit 1 stack. The fixture
now uses that maintained factory and moves into the existing Swift Testing
TextKit suite; exactly one legacy method is removed.

Both window transitions still reset and verify horizontal/vertical insets and
line-fragment padding. Added identity checks verify the editor moved to each
window and retained its original text container. The two retained offscreen
windows detach content and close synchronously; no application activation,
settings mutation, production change or timing wait is introduced.

An owned native build 786 control reproduces exactly the two nil-padding
failures with the old constructor, while the real factory passes both moves.
The complete corrected TextKit suite passes all eight tests locally in Swift
5 target mode without warnings. Fixed-head macOS app-host execution remains
required.

Strict Swift 6 compilation of the complete existing TextKit suite still rejects
its unchanged legacy `KeyboardShortcutSettings.settingsFileStore` references.
The migrated inset case itself adds no settings access or shared mutable state;
no suppression or production concurrency change is included.
### Browser Find routing context fixtures

Final C shard 2 failed the menu assertion in
`testCmdFDoesNotPreflightIntoPageWhenWebInspectorResponderIsFocused`.
The app-before-menu policy introduced in `e133650645` intentionally sends Find
to the selected browser when the event window owns a main-window context.
`BrowserFindShortcutRoutingTests` now covers that real graph and the absent-context
menu fallback through the same `BmuxWebView.performKeyEquivalent` entrypoint.
Both cases retain Cmd+F/key code 3, inspector first responder, consumed=true,
and zero WKWebView preflight events. The owned context opens browser search
without invoking the menu; the absent context invokes the menu once and leaves
browser search closed. Only the obsolete unconditional-menu expectation changes.

The synchronous fixture composes a direct `MainWindowContext`, retains its
closed window, and restores its menu, existing WK hook, shared delegate, active
manager and prior route-retirer. It neither registers a listener nor activates
a window. No production code, clipboard, timeout or CI selector changes.
All other bytes of `BrowserConfigTests.swift` remain unchanged.
The scoped settings fixture uses an owned JSON file, private notification center
and no watchers to bind Find to Cmd+F and leave Find in Directory unbound.
It restores the original store and exact persisted/argument/registration values
of the three settings bookkeeping keys before the existing store setter notifies.
A temporary prior Cmd+G control exposed two false failures without isolation;
with isolation it passes and preserves the remap, store and defaults provenance.

Against unchanged native build 786, both cases pass. Restoring the old menu
expectation fails exactly the registered case. Temporary absent/existing
collaborator controls verify menu/hook restoration, detached views, closed panels
and no owned socket listener. The complete affected BrowserConfig container and
actual support sources compile without warnings in target Swift 5 mode. The new
window-graph fixture owner also passes strict Swift 6. Combined strict checking
is blocked by the four retained mutable globals in BrowserConfig's existing
WK/inspector hook support and the imported nonisolated
`KeyboardShortcutSettings.settingsFileStore` static used by scoped settings
fixtures. No suppression, replacement hook or production isolation change was added.
Native logs retain the existing disabled-Sentry breadcrumb diagnostics.
These offscreen probes do not replace integrated app-host execution, which
remains pending. No product strings or localization catalogs changed.

### Final browser and native-fixture compile checkpoint

Revision `05cc59084` passed complete incremental `bmux-unit build-for-testing`
with local Xcode 26.6: 568 test files plus 14 shared sources were compiler
inputs. The latest Find, symbol, inset, inspector and preceding fixture owners
emitted no warnings. The full incremental build retained 158 distinct warning
lines; historical warning counts are not directly comparable. This build ran
no tests and did not launch or replace a preview app. The older CI compiler
and complete fixed-head native execution remain required.

On published G, job `115958161129` actually ran the closed-peer CLI regression
at 16:25 UTC on October 14. All three expected TAGGED/Unicode/final-line cases
failed with receive-timeout EINVAL; PONG and both EOF error controls passed.
The preceding native CLI linkage test succeeded. This supplies the required
test-only CI red; it does not yet verify a production receive correction.

### Shortcut parser lookup attribution fixture

D2 shard 2 recorded 672 shortcut lookups in
`testLegacySettingsShortcutBindingsParseWithoutRuntimeConflictLookup`, while
its parsed Cmd+1 binding and default/private notification counts remained valid.
The settings-file parser uses `normalizedSettingsFileShortcut`; initialization
also writes managed-default bookkeeping. A `UserDefaults.didChangeNotification`
subscriber can legitimately validate a live global-search shortcut during those
writes. A controlled subscriber reproduces the same three 224-lookup sequences;
this is causal local evidence, not a captured CI subscriber stack.

`ShortcutSettingsParsingContractTests` scopes the zero-lookup assertion to the
actual pure normalization call, restores the previous lookup observer, and then
constructs the complete fallback-file store. Both subscriber-off and
subscriber-on cases retain the live Cmd+2 browser conflict, normalized Cmd+1
output, zero default shortcut notifications and one private notification. The
enabled subscriber must execute; its callback count is not fixed. Its validation
calls do not register a system hotkey. Synchronous MainActor ownership restores
the original store and persisted/volatile provenance of the three bookkeeping
keys. No production policy, observer suppression, timing limit or CI selector
changes accompany this one-method migration.

Against unchanged build 786, both cases pass. A temporary control substituting
runtime recorder normalization fails the zero-lookup and normalized-output
assertions in both cases (four issues). Target-mode Swift 5 compilation is
warning-free. Strict Swift 6 checking still rejects the existing imported mutable
`settingsFileStore` and `shortcutLookupObserver` statics; no suppression was added.
Integrated app-host and full test-target verification remain pending. No app was
launched and no general clipboard or user settings file was changed.

### Local Git status root-alias regression

The unchanged build 788 provider returns no status for local explorer roots whose
lexical alias differs from Git's physical repository root. An owned native run of
all six existing `FileExplorerGitStatusProviderTests` methods fails the quoted
filename and sibling-prefix positive assertions; index preservation, type-change
mapping, and both SSH controls pass. Raw Git output contains the modified files;
the local parser filters them out before returning the dictionary.

A test-only parameterized regression adds an explicit owned symlink to a real Git
repository. Its physical-root control uses `git rev-parse --show-toplevel`; the
alias case requires file and parent-directory keys in the requested namespace,
with exact key membership and sibling-prefix exclusion. Both cases modify a
quoted/escaped filename and a sibling path. Repository preparation uses the
existing joined shell-process owner, isolated HOME/config, explicit author and
committer identities, disabled commit signing and empty owned hooks/templates.
Cleanup removes the owned repository, symlink, home and process captures.

Against unchanged build 788, the complete seven-method suite compiles without
warnings in Swift 6. The new physical case passes; its symlink case fails three
assertions (file, parent and exact keys). The two original nil-status failures
remain, giving five issues across eight cases. All original test methods and
helpers remain unchanged. This is deliberate test-only red evidence: the new
regression still needs its separate CI-red commit before publishing a production
correction. No app, Git provider, SSH parser, user configuration or global setting
is changed by this slice. Full fixed-head Xcode 26.3/macOS 15 app-host verification
remains pending.

### Queued text submission completion fixture

G shard 2 job 115958161026 fails the two final assertions in
`testTextBoxSubmitKeepsQueuedRunForStillActiveSurfaceWhenAnotherSurfaceFinishes`:
the active surface has sent neither queued text and only the unrelated surface
has completed. The existing clipboard-read observer posts a MainActor task; the
legacy synchronous RunLoop wait prevents that task from resuming. A native
build 788 event-only control preserves both surfaces, the active queue and real
clipboard-read notification. After the original one-second synchronous wait it
has the same incomplete state; awaiting actual completion then produces both
texts and all three completions in order. This probe omits only the file-paste
event and never accesses the general clipboard, so it does not establish the
pasteboard transaction or its restoration.

The exact case migrates into `TextBoxClipboardTimeoutTests`. Both tests share
a scoped snapshot/attachment/cleanup helper and serialize only their shared
general-pasteboard transactions. The migrated case retains the actual PNG paste,
all five original output/key/order assertions, the ten-second runner timeout
and both one-second completion bounds. The timeout override is captured during
dispatch and restored synchronously before suspension. Buffered completion
streams preserve already-completed events and their deadlines are cancelled
and joined. Cleanup resets owned runners and restores every prior pasteboard
representation before removing the attachment directory. No production policy,
CI selector or user-facing string changes.

The safe event-only native control passes on unchanged build 788; actual
general-pasteboard execution is reserved for isolated app-host CI. The complete
two-case suite and unchanged fake compile locally; full integrated target and
actual fixed-head CI remain pending. Every untouched legacy byte is retained.
### Tmux launch identity endpoint fixture

G shard 2 job 115958161026 failed
`testTmuxCompatEnvStampsLaunchSurfaceNotFocusedPane` before protocol handling:
its platform temporary-directory path was 108 bytes, exceeding Darwin's
104-byte `sockaddr_un.sun_path` capacity. The legacy bind helper asserts the
length nonfatally and then still copies the path; its possible out-of-bounds
write remains separately scoped legacy-helper debt. The diagnostic did not
repeat that unsafe copy or weaken the length check.

`CLITmuxLaunchIdentityTests` migrates only that case to the maintained
`CLISocketFixture` and `CommandRunner`, with a short owned `/tmp` directory,
explicit child environment and owned stdout/stderr files. The socket fixture's
throwing length guard and joined asynchronous serving remain unchanged. The test
retains the real `__debug-tmux-compat-env` entrypoint, distinct launch/focused
identities, all five workspace/surface/panel/tab assertions and the 30-second
process deadline. It additionally requires native success and one actual
`system.identify` request: a missing focused context otherwise preserves the
inherited IDs and can satisfy every original output assertion. Canonical pane
lookup still receives the original unsupported response. No production code,
shared helper, CLI timeout policy or CI selector changed.

Against unchanged build 788, a safely rejected 108-byte endpoint yields no
requests yet satisfies the five old identity checks. A short endpoint serves
`system.identify` and the canonical pane lookups, preserving those checks.
The migrated native test passes; a temporary missing-endpoint control fails
exactly the new request assertion. Its full sources and actual bundled-CLI
locator typecheck without warnings in Swift 5 and Swift 6. Native execution
uses a temporary locator for the exact existing CLI; bundle discovery itself
remains an integrated app-host concern. Owned processes, connections and files
are cleaned without accessing the user's app or socket. Full app-host/test-target
verification remains pending. No product strings or localization catalogs changed.
### Orphan workspace shortcut routing fixture

G shard 2 failed the pruning assertion in
`testCustomCmdTNewWorkspacePrunesOrphanedContextWithoutLiveWindow`.
`synchronizeShortcutRoutingContext` prefers an addressable/focused live context
before the cached active manager; an ambient captured live window can therefore
replace the intended orphan before workspace creation evaluates it. The fixture
now owns both a live and a windowless direct `MainWindowContext`, explicitly
selects the orphan manager and clears/restores the existing captured-window seam.
It does not register a window, start listeners or activate an app.

`OrphanWorkspaceShortcutTests` retains Cmd+T/key 17/window number zero, the
windowless precondition, handled=true, unchanged orphan workspace count and the
pruned-context assertion. It also verifies the existing owned live context
receives routing without a new context or visible window. The synchronous
fixture tears down all panels, retains its window through close and restores the
prior delegate, active manager and focused-window override. It reattaches the
prior delegate as route-retirer when present; it does not reset the registry
when the prior delegate is nil. Owned JSON binds New Workspace to Cmd+T; its constructor-owned store has no
watchers or external fallback paths. Exact persisted/volatile provenance of
three bookkeeping keys and the prior settings store are restored. No production
policy, new hook, selector or deadline changes are included. The old 50 ms
run-loop settling calls are removed because the real routing/pruning operation
is synchronous.

Against unchanged build 788, the migrated case passes. A temporary focused-live
control fails the original pruning assertion and the added context-key assertion,
while handled/count assertions remain valid. Nil/existing prior-delegate controls
also pass, preserving active/focused owners, a previous Cmd+G remap, settings
provenance and panel/window cleanup. Swift 5 compilation is warning-free; the
new graph owner separately passes strict Swift 6. Combined strict checking still
rejects the existing imported mutable `settingsFileStore` static, without a
suppression or production isolation change. Native logs retain existing disabled
Sentry breadcrumb diagnostics. Full integrated app-host/test-target verification
remains pending. No product copy or localization catalog changed.

### Broad shard 2 process diagnostic coverage

G job 115958161026 recorded a main-thread AppHang, repeated host crashes and
CLI timeouts before the broad invocation reached its 900-second watchdog. The
existing opt-in diagnostic environment was set only for the focused shard 1
invocation. Its uploaded stack files contained no usable call graph and cannot
establish the cause of the separate broad shard 2 failures.

The same opt-in sampler now also wraps the broad shard 2 invocation. Its native
Swift Testing start marker, 30-second observation window, eight-sample maximum,
two-worker concurrency limit, one-second samples and five-second worker
completion allowance are unchanged. Selection still requires the exact owned
DerivedData host and CLI descendants; artifacts omit arguments, environment,
payloads and raw sample headers. The existing upload moves after the broad
invocation and runs on either selected shard even after failure. All command
exit statuses, native test deadlines, selectors and retries remain unchanged.

This adds at most eight bounded samples to the implicated broad invocation when
the existing manual input is enabled. Sampling overhead is diagnostic overhead,
not a test repair or proof of timeout causality. Automatic runs remain disabled.
The host sample occurs once near two seconds, and the observation window ends
30 seconds after the Swift Testing marker. G shard 2 reported its later host
hang near 49 seconds, so this coverage may miss that hang; it first supplies
startup and child-process scheduling evidence. Usable actual macOS 15 call
graphs remain pending.
### Agent launch producer cleanup ordering

G's broad shard 2 (run `38593929044`, job `115958161026`) recorded both
agent-launch fixture cases timing out. Its main-thread hang, crashes, and final
900-second watchdog failure remain unresolved; the roughly 61-second suite
completion does not establish when each five-second CLI timer fired.

A separate controlled native probe of unchanged build 788 established a cleanup
contract mismatch: `CommandRunner` returned a timeout while its owned child was
still alive, and socket unlink plus fixture-directory removal preceded child
exit. This occurred both when the child honored SIGTERM and when it ignored it;
the latter exit observation followed about 208 ms later, consistent with the
existing 200 ms escalation grace. Both owned children were subsequently observed
exited and absent. This proves cleanup ordering, not the cause of G's longer stall.

Only `AgentLaunchEnvironmentFixture` now uses the maintained
`ShellContractProcess`, with the same five-second deadline and 200 ms termination
grace. It invokes the actual bundled CLI directly with the same arguments and
environment; the process owner supplies null stdin and solely owns stdout/stderr
files. A captured result carries success or the original failure through the
socket's final drain, after producer exit. Failure context includes only owned
requests and output, then the original error propagates. Owned directory removal failures also record
a test issue instead of disappearing in teardown. Environment allowlist,
executable, arguments, working directory, source and persisted identity assertions
are unchanged. No production process owner, socket policy or test deadline changes.

Against unchanged build 788, both existing parameterized cases pass in 0.205 s
with warning-free Swift 6 compilation. An injected directory-removal failure
records the expected issue; this final three-case run completes in 0.206 s. Temporary exact-fixture controls exercise
TERM-ignoring timeout and cancellation: the child is absent before producer return
and before socket cleanup, original errors and request context remain visible,
and owned exit observation plus directory cleanup complete. Both controls pass
in 5.503 s with exactly the two deliberately expected failure issues. The
controls use only owned children and add observational timestamps to a temporary
socket-helper copy; no diagnostic hook or extra test is committed.

Guidance and complete owners reassessed: root AGENTS, continuous-code-quality,
bmux-testing, architecture/concurrency, debugging, shared behavior, observability,
`CommandRunner`, `ShellContractProcess`, shared socket lifecycle, launch target
validation and the existing assertions. Canonical and local caveat
`agent_launch_joined_producer_verification` retains actual app-host verification
as pending. No UI or shipped text changes; localization scope is contributor
verification notes only.
### Titlebar hit-test event context

G2 recorded 28 nil-hit assertions in the two style cases of
`TitlebarControlsContentContractTests`. On unchanged build 788, an owned native
application supplying a mouse-down event passes both cases; supplying a key-down
event reproduces all 28 failures. That establishes the fixture's ambient-event
dependency, but the actual event during the CI failure was not recorded.

`MinimalModeSidebarControlActionView.hitTest` now reads `NSApp.currentEvent` once
and forwards it to internal `performHitTest(at:currentEvent:)`, following the
maintained `WindowTerminalHostView` boundary. The pointer gate, nil-event behavior,
context-menu eligibility, enabled/revealed checks, geometry and existing telemetry
are unchanged. No global override, swizzle, new product API or new logging is added.

The existing two style cases pass explicit left/right mouse-down, key-down and nil
contexts. They retain content sizes, seven 28pt control frames, hit edges, gaps,
accessibility identifiers and exact action order, and cover disabled/unrevealed
rejection and outside bounds. Settings remain synchronously scoped and restored;
no test deadline, CI selector or production action changes. Product text and
localization catalogs are unchanged; the added prose is contributor verification
material, not localized product content.

Root-owned isolated build 789 contains the unchanged reviewed production seam.
The exact corrected suite compiles without warnings in the target's Swift 5 mode
and passes both style cases against that artifact. A temporary owned application
supplying an ambient key-down event also passes both cases, while the original
ambient-dependent suite failed 28 assertions in the earlier controlled probe.
One redundant test unwrap exposed by compilation was removed without changing
its comparison. The native harness uses an isolated home and test-mode environment
before module loading and prohibits activation; no user window or clipboard is
accessed. Integrated fixed-head app-host verification remains pending.

### Legacy CLI socket setup failure boundary

G shard 2 reported a 108-byte Unix endpoint against the 104-byte `sun_path`
capacity. The legacy notification support helper used nonfatal XCTest checks,
then continued into the unchecked copy or returned a failed listener. The
current tmux fixture migration removes that observed long-path caller, but
remaining legacy callers still share this setup owner.

`bindUnixSocket` now rejects oversized UTF-8 paths before unlinking or creating
a descriptor. Socket creation, bind and listen failures throw a captured POSIX
error; failures after creation close only the owned descriptor. A listen failure
also unlinks the endpoint this helper successfully bound before caller ownership
was transferred. Bind failure does not unlink a possibly unrelated path. Successful
address encoding, backlog and caller-owned close/unlink semantics are unchanged.
The shared legacy process runner and other server helpers are outside this
bounded correction; their existing blocking/task cleanup risks remain open.

A temporary native harness compiled the complete actual support file in Swift 5
mode without warnings. Five controls passed: 108-byte rejection preserved an
existing sentinel and descriptor count, missing-parent and directory bind errors
preserved errno without leaking descriptors, and normal plus maximum 103-byte
paths connected/accepted and transferred an exact byte. A safe original-helper missing-parent control failed because it returned a
listener instead of throwing; its returned descriptor was closed by the harness.
No unsafe original buffer copy was executed. The harness's minimal XCTest host is temporary, not a shipped
Swift Testing adapter or new fixture API. Full integrated test-target and macOS 15
app-host execution remain pending.

### SSH agent forwarding joined producer

Current candidate 995 job 115978363652 completed 115 tests in 27 suites with
three issues. One SSH agent case (explicit tilde path, missing candidate) timed
out, while its other two cases passed; both agent-launch cases also timed out.
The SSH fixture still returned a `CommandRunner` timeout result before its owned
child had joined, violating the shared socket fixture's producer-completion
contract. Independent owned-child controls established this cleanup ordering
gap; they do not establish the cause of the CI deadline.

The three SSH agent variants now use the existing `ShellContractProcess` with
the same five-second deadline and 200 ms termination grace. Direct argv,
environment, cwd and null stdin are unchanged. The process owner alone writes
stdout/stderr. Success or captured failure joins before socket final drain;
after capture, failure records only owned requests/output and rethrows the
original error. Owned root removal failures are visible. Status, empty stderr,
exact two RPC methods, both agent paths, workspace and option assertions remain
unchanged. No shared helper, runtime API, serialization or deadline changed.

Actual bundled CLI build 788 passes all three original parameter cases in
0.478 seconds; complete source compilation in Swift 6 emits no warnings.
Temporary exact-method timeout and cancellation controls also pass (two cases,
5.404 seconds, two expected recorded issues). Their TERM-ignoring children are
already absent at producer return and socket-source join, before owned root
removal; original error types and request/output context remain visible. Native
exit observations join, and all roots disappear. The fixed-head macOS 15 app-host
execution remains pending. Neither this resource correction nor local success resolves the wider process scheduling
risk or proves the six-second CI stall repaired.
### File-preview and notification test-window ownership

G shard 4, job `115958161892`, repeatedly crashed during XCTest cleanup after
`FilePreviewPanelTextSavingTests.testPendingTextFocusAppliesWhenTextViewAttaches`
and the notification open, latest-unread/no-op, and fallback-unread cases in
`TerminalNotificationSocketActionTests`. Its XCTest invalid-object cleanup frame
matches the previously measured raw-window close lifetime failure. This is
supporting evidence for the constructor ownership repair, not proof that every
shard crash or idle timeout has the same cause.

The two existing window constructors now set `isReleasedWhenClosed = false`
before returning or presenting the owned window. All test bodies, assertions,
actual Unix-socket requests, navigation/read/no-op/fallback behavior and failure
bounds are byte-for-byte unchanged. Only the pending-focus case calls the
file-preview helper; the three notification cases request its window-bearing
fixture. No new API, workflow selector, production code or product string changes.

An offscreen Swift 6 AppKit control exercises both exact window sizes/style,
close, autorelease-pool drain and final ARC release successfully. The earlier
unsafe-close negative control is retained, not replayed. No notification case
was executed locally because its real route raises a window and may activate the
application. Complete target compilation and the four fixed-head app-host cases
remain pending; the primitive control is not a full-case pass.

This helper-only correction leaves existing notification-fixture debt explicit:
shared delegate/store/listener mutation across suspension, whole-store replacement
that discards queued/unread metadata, socket-readiness polling and window
foregrounding. Those responsibilities are unchanged and are not claimed isolated
or repaired by the retained-window setting. No XCTest case body is being migrated
or rewritten as part of this constructor-only lifetime correction.

### Combined producer and window-ownership compile checkpoint

Revision `7983d988b91dfa4a09469de5770396db69099a0e` passes the complete
`bmux-unit build-for-testing` with local Xcode 26.6: all 573 wired test files
and 14 shared sources are compiler inputs. This includes the joined agent-launch
and SSH-agent producers, throwing legacy socket setup, retained test windows,
explicit titlebar event context, and preceding shortcut/clipboard/tmux fixtures.
Authenticated Project Truth, native project parsing and normalization, test
wiring, strict determinism and the existing Swift file-length budget also pass.

The build retains 405 distinct warning lines. The changed titlebar owner and
new Swift Testing fixtures emit none. Touched legacy support files retain three
XCTest import-consistency diagnostics and one redundant Void-result diagnostic;
all four are present in the prior compile, with the last shifted by the window
constructor line. No warning suppression or budget change was made. Other
retained warnings include legacy concurrency, deprecations and unused results.
Compilation does not establish app-host runtime success. The four affected
window cases and broader timing/host-crash behavior still require CI.

Build 789 remains the isolated verified production artifact; the source changes
after its build are test/documentation-only. No running preview was rebuilt,
launched or replaced. All 19 original fixture source heads and current PRs
169/170 remain ancestors. The older G workflow was canceled after comparing its
Release production inputs with the successful E Release build; this is recorded
as cancellation, not a passing gate. Diagnostic run `38605111245` retains the
separate test-only Git-root alias regression and bounded process sampling.

### Partial Claude hook context construction cleanup

The shared Claude hook context factory also removes its owned temporary directory
when CLI lookup or listener construction throws before ownership reaches callers.
Cleanup errors remain visible through the existing test failure channel while the
original setup error is rethrown. The listener helper still owns descriptor and
bound-path cleanup; successful context cleanup is unchanged. Other callers that
create directories before binding already install a defer or XCTest teardown.

A temporary native harness used the actual factory and bind-helper bodies with
controlled lookup/path inputs. Lookup failure, bind failure, successful ownership
transfer and cleanup-error reporting all passed, with original errors preserved,
no remaining owned roots and unchanged descriptor counts. Original-factory lookup
and bind controls each failed specifically on the leaked root. Swift 5 compilation
was warning-free. No permanent test adapter, production API, case-body change or
app operation was introduced; integrated target compilation remains required.

### Terminal file launch directory identity

H shard 3 reports two working-directory string mismatches in
`TerminalDefaultFileOpenRequestTests`: Foundation's decoded parent-directory
path retains a trailing slash, while the expected `.path` string omits it.
The complete request initializer and both AppDelegate launch paths use the
result as a directory, not an exact serialized identifier. Both spellings
identify the same directory. No application change is needed for this mismatch.

Only the two launch cases migrate to `TerminalDefaultFileLaunchContractTests`.
They compare directory URLs without resolving symlinks and retain the exact
quoted executable input, including the apostrophe/space case. The executable
case still creates a real owned executable and cleanup errors remain visible.
The plain-text and script-named-directory rejection tests remain unchanged.
The new file is wired into the native test target; no selector or deadline changes.

Against unchanged build 789, both original string assertions fail exactly as in
macOS 15 CI. Both corrected cases pass with warning-free Swift 5 and Swift 6
compilation. Temporary wrong-sibling and unquoted-input controls fail their
respective assertions, showing the new oracle still rejects incorrect behavior.
These native checks use an isolated test-mode process and do not launch or
activate a window, execute the fixture script, or change user settings. Complete
integrated target compilation and fixed-head app-host execution remain pending.
No product strings or localization catalogs changed; added prose is contributor
verification material.


### Hook prompt stable workspace identity

H shard 3 reports one outdated workspace identity assertion in the hook prompt
session test. The accepted `ecf7190a7` implementation records the persistent
workspace ID for both hook and transcript evidence; the runtime resolves a live
workspace before passing `workspace.stableId`. This matches the merged workspace
association capability and its production lifecycle coverage. The old assertion
still expected the transient `runtime-workspace` fixture value.

Only that existing hook/backfill case migrates to Swift Testing. Its session
workspace assertion now expects the supplied stable ID; every other prompt,
turn, display, backfill and synthetic-identity assertion is preserved. The
existing capturing client is shared within the test target; production identity
policy and other legacy cases are unchanged. The new test file is wired into
Xcode without changing CI selection.

An isolated native test process linked to unchanged build 789 reproduces the
original single mismatch and passes the corrected complete case. Swift 5 and
strict Swift 6 compilation are warning-free. Native project parsing, 575-file
wiring, strict determinism, the existing file-length budget and Project Truth
validate/generate/check pass. Integrated test-target compilation and exact-head
macOS app-host execution remain pending. No application window, external service,
user settings or product strings are changed; the prose is contributor evidence.

### Closed retained main-window routing

H run `38600136921`, shard 3 job `115978363675`, failed all three
closed-window presentation assertions in
`ClosedMainWindowRoutingTests.testClosedMainWindowIsNotListedOrFocusableWhileItsObjectsLinger`.
The unregistered, ordered-out window remained listed, accepted focus, and became
visible. The original test also requires its retained manager to remain
resolvable. Its recovered-visible companion passed. The affected routing owners
are unchanged between H995 and J `7d6838c7e`.

Two temporary native controls on unchanged build 788 distinguished the test's
unregister/orderOut path from real `NSWindow.close` through `WindowCloseObserver`.
Both removed the registered context but retained list membership, window identity,
manager identity, and focus acceptance. The two controls passed in 0.231 seconds;
Swift 6 compilation emitted no warnings. They used owned HOME/test-mode state,
disabled sockets, never-presented windows, guarded startup/persistence, and the
existing nonfocus socket policy for the focus call. Thus they establish routing
acceptance, not visible-window behavior. Disabled-Sentry breadcrumb diagnostics
were present in the unlaunched native harness.

The correction keeps one computed presentation rule in the existing window
identity owner: registered windows remain eligible even when hidden; orphaned
windows must be visible or miniaturized. Window identity, list/search/scripting
projections, and stale-search-hit actions use that rule. The weak recovery ledger,
manager lookup, surface lookup, history, inspector cleanup, memory accounting,
and quit checks retain their existing resource scope. The existing complete
ordered window-state projection is named `retainedMainWindowStates` for terminal
diagnostics and provenance workspace resolution; those two callers retain their
previous population, ordering, and identity semantics. This does not change PE
contracts, storage, session identity, or the separate SessionProvenance failure.

The exact original regression and recovered-visible test remain unchanged.
The original H failure is the red evidence; no additional permanent regression
or deadline change is included. Fixed-runtime controls, a fresh isolated tagged
app build, full test-target compilation, and real-window macOS 15 app-host
verification remain pending under `closed_main_window_routing_verification`.
Local offscreen evidence does not close those gates. Source review and the
existing CI window-list/focus assertions remain the operational acceptance path;
no new telemetry or user-facing strings are introduced.

Local static verification passed: all five affected Swift sources parse without
diagnostics; the actual-main `ce17e9888a6dce4d2e5755795946b68cf52f0329`
file budget passes; all 574 test files remain wired; Project Truth validation,
generation and freshness pass. The retained ordered enumeration was checked
against the prior body, and the two resource callers have only the intended
method-name substitutions. These checks do not establish fixed-runtime behavior.

### Focused Git metadata publication boundary

H shard 3's focused-branch duplicate test still expects `Workspace.objectWillChange`
to fire for the first Git update. The accepted sidebar extraction `f5f58c4b3b`
moved that state into `WorkspaceSidebarMetadataModel`; Workspace forwards its
values, and the sidebar's composed publisher observes the model's subjects.
The adjacent sidebar-publication test already uses that maintained boundary.

The failing case moves into the existing Swift Testing observation suite. It
checks both stored branch values, a positive first sidebar notification, no
notification for an identical refresh, and no whole-workspace publication for
either update. Subscriptions are canceled and owned panels torn down. Other
legacy tests and production owners remain unchanged; no new file or CI selector
is needed.

Unchanged build 789 reproduces the old single failed expectation. The corrected
native case passes; temporary forced workspace publication and a nonidentical
branch update trigger the three expected failures. Swift 5 and strict Swift 6
compilation are warning-free. These are owned test-mode processes without window
presentation. Strict determinism, existing file budgets, wiring, and Project
Truth validation/generation/freshness pass. Full integrated target compilation
and exact-head app-host execution remain pending. No product strings changed;
this section records contributor verification only.

### Notification focus completion boundary

H shard 3 failed only the notification-focus test's artificial 100 ms delayed
expectation; its subsequent focus, unread-indicator and dismissal-flash assertions
passed. The existing `FocusSurfaceBroadcaster.flush()` is the causal delivery
boundary already used by `NotificationFocusEventTests`. The timer does not prove
that delivery occurred and can fail independently of the intended behavior.

The legacy case now shares that existing Swift Testing fixture as a second
parameter: direct panel focus and notification-triggered manager focus. Both
check unread state before the action, the actual selected panel afterward,
unread/indicator removal, and exactly one dismissal flash with the expected panel
and reason. Notification state is seeded through the existing scoped restoration
method, which preserves the supplied record without adding a restored-state flag.
This avoids external delivery and global delivery-hook replacement. The fixture
flushes prior work before installing its synchronous composition, restores
preferences and shared references, and tears down only its owned workspaces.

Both native cases pass against unchanged build 789. Omitting the notification
focus action in a temporary negative control produces six expected failures.
Swift 5 compilation is warning-free. Strict Swift 6 rejects both the original
fixture and this revision at the same three accesses to the existing nonisolated
`AppFocusState.overrideIsFocused` test override; no new access or suppression is
introduced. The synchronous MainActor scope is retained. Full target compilation
in the repository's configured language mode and exact-head app-host execution
remain required. The unlaunched harness reports disabled-Sentry breadcrumb
messages; it does not start telemetry or display windows. No product text changes.
