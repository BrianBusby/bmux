# SSH manual reconnect handoff

## Scope and ownership

This repair is isolated from SSH lifecycle fixture and error-sanitizer maintenance. `Workspace.reconnectRemoteConnection` owns terminal replacement for shell prompts, native context menus and disconnected placeholders. Shell handoff never starts another SSH process. Explicit targets fail without changing session tracking when replacement is unavailable; nil/workspace reconnect retains its prior acceptance and pre-respawn cleanup semantics.

The old session reports its end and removes one-shot askpass files before the manual prompt requests a replacement. `r`, `R`, `retry` and `reconnect` request one explicit workspace/surface RPC. Accepted handoff exits the old shell. Failed requests print a localized error and allow another explicit choice. Enter and EOF preserve the original SSH status, including reusable wrappers. Automatic retry eligibility, limits and delay are unchanged.

`ControlWorkspaceRemoteResolution.reconnectFailed` carries the explicit target and an app-localized message. The socket coordinator emits `invalid_state` rather than falsely acknowledging success. Other remote mutation outcomes and workspace-level calls retain their previous behavior.

The native disconnected-placeholder script and package remote-mutation routing now have cohesive extension files. This keeps changes within source budgets without moving private workspace state or exposing new public mutation APIs. The context menu invokes the existing owner directly.

## Evidence and history

Commit `bd0b24b74161f9f546773a9e288105999c5bdc1f` moved cloud reconnect to native surface replacement while extracting the shell startup builder. Its extracted builder dropped the manual retry handler but retained the localized helper and native menu input injection. Reinstating the older inline SSH loop would create two replacement owners.

The pushed test-only commit `36114abc088693f49a5162089461e8eb76560a00` corrects the fixture's current `vm.ssh_info` and created-surface protocol, then asserts one targeted handoff after session-end and one SSH attempt. The unchanged 773 CLI runs that test and fails exit-status, RPC-count and exact-payload expectations. The initial focused job selected a malformed Swift Testing method name and ran zero tests. Test-only follow-up `af8b9e055` selects the full suite. Actual run `38431148481`, job `115414778320`, then executed four functions and failed five assertions with exit 65: the shell sent no reconnect RPC, and rejected unbound targets changed session tracking. This supplies the required CI red before the production repair.

Separate unchanged-773 executable probes confirm:

- Failed unbound respawn incorrectly tracks the target and removes its pending-exit marker; missing explicit targets receive socket success.
- Both valid replacement cases with a live sibling preserve connected/reconnecting workspace state, stable pane/tab identity and the sibling.
- The context menu injects input without replacing the ended panel.
- A disconnected placeholder runs the configured startup command again after RPC acceptance.
- One-shot bootstrap Enter/EOF preserves status 7; reusable wrappers mask it as 0 by unsetting their saved status before exiting.

The three old manual guard methods are replaced with meaningful owner tests: unbound targets preserve state on failure, and real ended panes bound to a layout are replaced successfully while preserving the sibling and workspace state. Native routing probes are saved/restored synchronously on the main actor. No global probes survive an await. Placeholder subprocess capture uses owned files through positional shell redirection and the maintained `CommandRunner`; no production process infrastructure changes.

## Verification

- Current-source startup builder executable: 27 initial/reusable/shell-snippet cases pass, covering all reconnect choices, dismissals, failure, missing surface, one SSH attempt, cleanup-before-handoff and removal/non-reuse of one-shot credentials.
- BmuxControlSocket: 206 tests in 34 suites pass. Existing unused-public-import warnings in unchanged BmuxFoundation sources remain outside this slice.
- All three native suites compile without warnings against builds 773 and 779. The parent-owned fixed build 779 passes all 25 cases across eight methods (13 startup, 11 native-owner and one placeholder); unchanged 773 fails 37 behavior assertions with no timeout failures. The new async harness therefore retains production-regression sensitivity. Logs: `/tmp/ssh-manual-async-779-green.log` and `/tmp/ssh-manual-async-773-red.log`.
- Test wiring, strict determinism, base-aware source budgets and project documentation gates are recorded as checks run during the slice. The focused CI gate selects all three affected suites on existing shard 3 before unchanged full coverage.
- The separate PR150 lifecycle fixture correction preserves nine legacy methods and migrates the stale-control case to a real managed-attach fixture. All ten pass against both 773 and 779 (`/tmp/ssh-lifecycle-repaired-773.log`, `/tmp/ssh-lifecycle-repaired-779.log`). The original stale-control fixture had falsely passed on 773 because the reusable wrapper masked missing attach failure; it is not valid successful-attach evidence.
- Localization audit: the manual failure prompt and native RPC failure message have English and Japanese entries. Existing localized automatic/manual prompt keys are reused. The touched catalog parses, changed keys have both required locales, and package code does not resolve app-bundle strings.

The parent owns the isolated build 779. This fixture follow-up used that existing artifact and unchanged 773 without building, launching, quitting or replacing an app. No runtime dogfood acceptance or full app-host green is claimed. Actual test-only CI red and independent source review are complete. Fixed-head app-host CI and runtime acceptance remain pending; the native harness is not full app-host or dogfood evidence.

## Async fixture correction

The first new manual suite copied a blocking semaphore/process/socket harness.
That was introduced test infrastructure, not grandfathered legacy code. One
incidental 779 run recorded two timeout assertions in the same failed-RPC
`r/r/Enter` case despite the generation and shell children reporting their
expected native statuses (0 and 1). Concurrent compilation was observed but its
causal role was not established; the older executable still linked the correct
779 artifact. `/tmp/ssh-779-incidental-stale-harness-run.log` retains that evidence.

`SSHStartupManualReconnectFixture` now owns the isolated root, explicit child
environment, generated-command protocol and process capture. It reuses the
reviewed `CLISocketFixture` from PR150, including inherited SIGPIPE protection,
nonblocking readiness, partial writes, single-task command ownership and awaited
source cancellation/descriptor closure. No custom blocking accept loop, shared
lock state or semaphore remains in the manual suite. Both child phases receive
only owned HOME/CFFIXED/XDG/TMPDIR/PATH values and explicit fixture settings;
ambient BMUX/CMUX credentials, targeting and user shell configuration are omitted.

The maintained `CommandRunner` invokes positional shell redirection for owned
stdin/stdout/stderr files. Reads happen after confirmed native completion and
propagate read errors. These tests verify shell routing and payloads, not pipe
draining. The existing runner's broader cooperative-executor pipe-reader risk
remains outside this test-only correction. Five-second deadlines and all 13
startup behavior assertions/cases remain intact. Each case is isolated and runs
in parallel instead of serializing around the old blocking transport.

Native build-779 execution passes all 25 cases in 4.221 seconds with this harness.
The unchanged-773 control fails the expected reconnect/status/state assertions,
not fixture timeout checks. This focused execution does not prove absence of
all scheduling failures in full app-host CI; actual CI remains a separate gate.
No production source or timeout policy changed during this follow-up. Independent
review compared the complete replacement against the prior expanded 13-case
fixture and found no blocker. Project normalization/wiring (434 files), strict
determinism (zero findings), base-aware source budgets, shard coverage (2,007
selectors), shard tests and Project Truth validation/generation/freshness pass.

## Governing references

Root `AGENTS.md`; personal `continuous-code-quality`; repository testing (regression quality, migration, CI), architecture (file/API and concurrency), shared-behavior, socket-policy, debugging and localization skills. Maintained references include `ControlSurfaceRespawnStrings`, `TerminalControllerSurfaceActionSocketTests`, `AppDelegateMainWindowTestingSupport`, `TabManagerUnitTests`, and the SSH lifecycle fixtures. App localization remains at the adapter; native workspace lifecycle remains authoritative.

## Final publication checkpoint

The shared socket fixture is now identical to reviewed PR 169's transport,
including per-client canceled-write handling. The three focused suite selectors
remain intact. No production source changed since isolated build 779; the final
fixture execution passes all 25 cases across eight functions and three suites in
3.989 seconds against that exact artifact (`/tmp/ssh-manual-final-779-green.log`).
Native owner, shell handoff and placeholder state assertions remain unchanged.
