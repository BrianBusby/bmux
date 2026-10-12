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
