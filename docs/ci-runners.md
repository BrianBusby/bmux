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
cleanup controls pass. Actual test-only CI red remains pending.

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
