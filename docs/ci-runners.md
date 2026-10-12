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
