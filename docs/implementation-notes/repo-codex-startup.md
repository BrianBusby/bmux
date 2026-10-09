# Repository Codex startup regression

Base: build 721 runtime commit `fa7604487`; branch `fix-repo-codex-startup`.
The installed and running app is `/Applications/bmux DEV expanded-turn-contrast.app`.
Its Info.plist records build 721 and the matching runtime commit. User-owned
repo launcher configuration still specifies plain `codex` commands.

## Governing sources and ownership

Read repository AGENTS.md, continuous-code-quality, and bmux architecture,
debugging, shared-behavior, testing, dev-workflow and localization skills.
The configured-command coordinator owns asynchronous startup and cancellation;
Workspace owns stable-panel respawn; TerminalChatRuntime owns host resources;
Ghostty owns the native PTY. Existing configured new-tab and workspace actions
share `sendConfiguredTerminalInput`. Compound/setup, custom PATH and
existing-terminal commands retain ordinary shell routing.

## Evidence and bounded correction

`TabManager.addWorkspace` eagerly schedules the initial terminal startup.
`ConfiguredCodexLaunchCoordinator` awaits host preparation, then silently closes
the prepared host if that placeholder already has a Ghostty surface. This
confuses expected placeholder startup with loss of ownership, leaving a plain
repo-root shell. Existing ownership tests keep their placeholder unmounted.

The regression exercises the real workspace executor with a suspended host
fixture and attaches the placeholder to a native window before releasing host
preparation. It asserts replacement, a configured startup command, stable tab
identity/selection and retention of the prepared host. No sleeps or source-text
assertions are used. The correction retains cancellation, workspace,
panel-object and pane checks while permitting the owned placeholder to be live.

## Verification and outstanding work

Test-only commit: `63b8a6579`. Focused Xcode tests ran with the isolated
`repo-codex-startup-tests` bundle and DerivedData, pinned GhosttyKit and existing
resolved SwiftPM dependencies. The active build is not rebuilt or replaced.
The first fixture attempt asserted readiness before asynchronous shim installation
completed; it was corrected to await the terminal-ready notification. On the
unmodified production code, all other launch tests pass and the new regression
fails exactly three assertions: the placeholder is not replaced, it has no startup
command, and the prepared host is closed. Log: `/tmp/bmux-repo-codex-startup-red.log`.
After the fix, all 29 Swift Testing tests in ConfiguredCodexLaunchTests and
ConnectedSessionOwnershipTests pass. This includes the live-placeholder regression,
closed-source rollback, duplicate-start prevention, current-terminal routing,
setup-command routing, tab/canvas identity, child-exit retention and connected-host
ownership checks. Log: `/tmp/bmux-repo-codex-startup-green.log`.
Project-docs validate/generate/check, all 428 test-file wiring checks and diff
whitespace validation passed. Self-review inspected the complete coordinator,
configured workspace/new-tab callers, terminal-ready delivery and stable respawn.
The app and test targets compiled; no compiler warning originated in the changed
coordinator or new regression. Existing XCTest import/actor warnings and the test
host WebKit pasteboard diagnostic remain outside this patch.
Localization audit: no new UI text or message keys. The existing loading, new-session
notification and failure strings all have translated English and Japanese entries.
The user approved a separate tagged build and native verification; the results
are recorded below. Focused tests use the existing connected-host fixture.
No new user-facing text was added; existing localized loading/error UI stays
in use. No Session roadmap gate, provider capability or persistence policy is
advanced by this regression correction.


## Installed-provider blocker found in native build 722

The first isolated native build succeeded on `f347d4ebf`, but the real repo menu
still failed before reaching the replacement path. Both the installed Bun CLI
and the launcher's login-interactive zsh resolve `codex-cli 0.162.0`; the inherited
host gate accepts only 0.154.0 and 0.161.0. A second test-only commit, `02e9c18a1`,
adds 0.162.0 to the validated-version cases and moves the unsupported-version
case to 0.163.0. This is a second launch blocker in the same reported workflow.

The existing isolated compatibility probe was rerun against the installed
0.162.0, starting a blank original TUI with no thread/resume request. Authless
WebSocket access returned 401. Account/config/model reads and sole-thread
adoption succeeded. Four turns delivered all five accepted client message IDs
exactly once; stale steering was rejected, current steering succeeded, pending
queue evidence survived reconnect, and all replies appeared in the original
TUI. There were no turn/start or turn/interrupt requests. The original native
Swift WebSocket/RPC probe also passed account, config, model and loaded-thread
reads. Temporary auth/token copies were removed and both probe processes stopped.
Sanitized logs live in `/private/tmp/bmux-codex162-compatibility/`.

Ownership reassessment: keep the existing host service and exact version gate;
add only this empirically verified release, preserving fail-closed handling for
unverified versions. Do not broaden interrupt/approval/settings capabilities,
downgrade the installed CLI, or alter user settings. The refreshed native launcher result is recorded below.

The 0.162.0 test-only case failed with `CodexControlError.unsupported` before the
gate change. After it, all 29 focused launch and ownership tests pass, including
actual provider-version metadata and rejection of 0.163.0. Version test logs:
`/tmp/bmux-repo-codex162-red.log` and `/tmp/bmux-repo-codex162-green.log`.
Project-docs validation, regeneration and freshness checks pass with 0.162.0
recorded under observation. No new UI strings were introduced.

## Native build 723 verification

The user-approved `repo-codex-startup` tagged reload succeeded on pushed runtime
commit `c262d0b7c` and launched build 723 separately. Build 721 was left running.
Using the actual sidebar AI Repo Launcher, selecting **bmux (Codex)** and
**Launch Normally** created a new connected session with an editable Chat composer.
One harmless prompt requested only `Ready.` without tools or file changes.
Terminal visibly ran Codex 0.162.0 in `~/repos/bmux` and displayed the prompt and
completed `Ready.` reply. Returning to Chat displayed the same prompt and reply
and an available composer. No duplicate submission was made.

Immediately after submission, Chat briefly displayed “The shared connection is
unavailable. Continue in Terminal.” The prompt nevertheless completed and the
message was absent on return to Chat. Its cause is not established; record it as
a remaining connection-feedback observation, not proof of failed delivery or a
resolved recovery issue. User dogfood, broader recovery and interruption remain
open. No video was recorded.

Final ownership review retains the configured coordinator, stable Workspace
respawn and exact host-version boundary; neither fix adds another mutation path.
No new UI strings were introduced, and the existing loading/new-session/failure
keys were checked for translated English and Japanese entries.
