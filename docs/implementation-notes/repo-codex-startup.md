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
The native repo menu and real Codex provider acceptance still require a fresh
user-approved isolated build; tests use the existing connected-host fixture. A fresh tagged
app build requires user agreement under AGENTS.md's active-dogfood rule.
No new user-facing text was added; existing localized loading/error UI stays
in use. No Session roadmap gate, provider capability or persistence policy is
advanced by this regression correction.
