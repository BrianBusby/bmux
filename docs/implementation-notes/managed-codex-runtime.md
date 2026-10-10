# Managed Codex runtime

Brian authorized this repair and merging the accumulated workspace-ticket-gap stack
on October 10, 2026. Base runtime: build 729, commit `389c16bd7`. Work remains in
`workspace-header-ticket` on `fix-managed-codex-runtime`; the mobile review
worktree and running app are unchanged.

## Governing guidance and ownership

Read AGENTS.md, continuous-code-quality, bmux architecture (including package and
file/API boundaries), debugging, shared behavior, testing, dev-workflow and
localization skills. No available Superpowers workflow was found. Toolshed
standards cover CompanyCam applications; this change is in bmux.

The application composition root supplies executable resolution to
ConnectedCodexHostService. ManagedCodexRuntime owns package acquisition and
persistence; ConnectedCodexExecutableResolver retains shell PATH discovery for
subprocess tools; the host service owns its provider process and authenticated
transport. ConfiguredCodexLaunchCoordinator retains startup, rollback and retry.
Both configured repo actions and Chat-first launches use the same host service.
The existing terminal ownership, hook routing and single-thread checks remain.

## Decision

Pin the complete official Codex 0.162.0 package, the version already empirically
verified for shared control. Store it under
`~/Library/Application Support/bmux/runtimes/codex/<version>-<target>/`.
Acquire on first use with a bounded download, verify the release's SHA-256 before
extracting, check the executable version, and publish by atomic directory rename.
Concurrent launches share acquisition; concurrent apps accept the verified winner.
Failed staging is removed. An installed package works offline. Never replace an
active version in place, follow `current` symlinks, or change the global CLI.

The complete package retains code-mode, voice, zsh and other provider resources.
ManagedCodexRelease owns version, target and official archive checksum. Promotion
requires the existing compatibility probe (authentication, sole-thread adoption,
queue, steering and reconnect), updating that pin (also read by the host's capability gate),
and rerunning launcher verification. No automatic promotion or widened version
acceptance is introduced. Existing ordinary terminal commands and explicit custom
PATH launch behavior remain user-owned. Codex startup update prompts are suppressed
for the connected TUI.

Acquisition errors are localized and displayed inline with Retry; the existing
notification carries the same diagnosis. A damaged installed runtime requires
closing connected sessions and removing that version's directory before retry.
Credentials and user configuration remain with Codex and are neither copied into
the package nor logged by the installer.

## Verification record

All 44 tests in ManagedCodexRuntimeTests, ConnectedCodexExecutableResolverTests,
ConnectedSessionOwnershipTests and ConfiguredCodexLaunchTests pass. The real
installer fixtures exercise complete-package extraction, concurrent acquisition,
offline reuse, checksum/version rejection and retry. The configured coordinator
checks failure presentation and stable-panel retry. Existing model-policy tests
now assert reasoning preservation specifically while checking startup-update
suppression. Log: `/tmp/bmux-managed-codex-final-tests.log`.

Tagged builds 731 and 732 succeeded, including the copy correction. Full-stack CI
follow-up and remaining integration verification are recorded below.
The initial focused build exposed incorrect Xcode source paths for the three new
runtime files; the references were corrected before further verification.

Project-docs validation/generation/freshness, Xcode project normalization and
430-file test wiring, Swift file-length budgets and diff whitespace checks pass.
Localization: all five new inline/notification/action messages have English and
Japanese translations; the catalog parses. No new UI strings are bare literals.
The test host emitted the existing WebKit pasteboard connection diagnostic.

The app-host test process exposed an existing automatic Chat startup path through
the production composition root. It began staging a real package during tests.
The composition now consults BmuxAppRuntimeConfiguration.processKind and refuses
real provider acquisition/launch in XCTest hosts; behavior tests continue to inject
their fixture host or installer. A regression covers this boundary. The one empty
staging directory created during discovery was removed.

## Native launcher acceptance

Build 730 succeeded with the isolated `managed-codex` tag, leaving build 729 and
global CLI links unchanged. The actual sidebar AI Repo Launcher → bmux (Codex) →
Launch Normally downloaded the official package into the managed directory,
opened the editable Chat composer, and completed one no-tools prompt with `Ready.`
Terminal showed that same prompt/reply and `OpenAI Codex (v0.162.0)` in
`~/repos/bmux`; returning to Chat retained the reply and composer. The global Bun
CLI still reports 0.162.1. The Codex startup warning was inspected: the unrelated
Amplitude MCP needs OAuth reauthentication. No account settings were changed.

The final tests add incomplete-cache rejection and the XCTest acquisition guard;
all 44 pass. No warning originated in the new runtime files. The existing
`ConnectedSessionOwnershipTests` unmutated `alive` variable warning is unchanged.

Build 731 repeated the actual sidebar launcher path using the cached package and
completed the same no-tools prompt in editable Chat. Terminal retained the same
conversation. The repair is pushed in PR #139 with the accumulated worktree stack.
Native acceptance was on Apple silicon; the Intel artifact pin is recorded but
was not executed locally. No demo video was recorded.

## Independent review

A bounded independent review covered the complete managed installer, release/error
values, resolver, host, configured coordinator, composition root and shared launch/
runtime callers against the governing architecture, testing, localization, shared
behavior and development guidance. It found one recovery-copy mismatch: the
configured failure view offered retry while its generic message promised Terminal
fallback. A dedicated English/Japanese message now describes the available retry.
The ordinary Chat fallback remains unchanged. No further runtime findings remain.
The review did not comprehensively reassess the prior accumulated stack, execute
Intel or older macOS builds. Subsequent full-stack CI evidence is recorded below.
Independent pbxproj normalization, 430-file test wiring, flag lint and catalog
validation pass. No new test was added for a copy-only change.
The existing ConfiguredCodexLaunchTests suite passes after the copy correction;
log: `/tmp/bmux-managed-codex-review-tests.log`. No coordinator warning was introduced.

## Full-stack CI follow-up

CI run 38057575569 on 2c17c45a1 exposed terminal fixtures that still assumed a
Terminal-first window. The product now starts in Chat, so those fixtures left
Bonsplit geometry and terminal portals unmounted. Window composition now accepts
an explicit `AgentSessionFactualProjectionMode` initial value, defaulting to Chat;
four terminal-only fixtures opt into Terminal. The same initial value seeds both
the shell tab and terminal visibility. The browser Cmd+D → Cmd+L → Cmd+F UI test
selects the real Terminal button before exercising its original assertions.

Local reproduction confirmed the zero-geometry/focus failures. After explicit
Terminal construction, split equalization and responder ownership pass. Runtime
logs exposed a second fixture precondition: input reached `keyDown.missingSurface`
before asynchronous native surface creation, and the search overlay appeared after
the fixture's fixed 50 ms check. The responder fixtures now await the existing
surface-ready notification and actual search-field mounting, preserving the input
forwarding and search assertions. The existing window positioning helper moved
unchanged to its window-frame policy extension, and the browser test launch helper
moved unchanged to a companion extension to respect the large-file growth limits.

The CI result must not be summarized as all green. The display UI lane failed at
`BrowserPaneNavigationKeybindUITests.swift:922` (omnibar missing). App-host shards 2
and 3 reported success despite assertion failures: the unchanged workflow at
`.github/workflows/ci.yml:675–680` accepts a summary containing `(0 unexpected)`.
That text does not mean XCTest assertions passed. Both logs ended after a 45-second
post-test timeout, and shard 2 restarted its test host twice. No gate was weakened
or assertion suppressed in this repair.

Bounded source attribution against origin/main found retained browser deferred-URL
lifecycle and composited-color fixture failures, CLI hook/socket fixture failures,
and stale shortcut/titlebar/command expectations. Material existing bugs include
missing-cwd restore reintroducing the deleted directory in `Workspace.createPanel`,
persistent-remote child exit clearing sibling surface tracking, and cloud proxy
retry state changing to reconnecting despite clearing the retry error. The relevant
owner chains are unchanged (or behavior-equivalent after extraction); baseline
runtime reruns were not performed. Other input/portal/unread and process-fixture
assertions remain incompletely classified. These existing risks are disclosed,
not repaired or treated as passing, and this review is not a comprehensive audit of
the accumulated stack.

The changed UI test target builds successfully in the isolated managed-Codex test
bundle (`/tmp/bmux-ci-terminal-ui-compile.log`). Local execution did not reach the
test: XCTest timed out enabling automation mode after 60 seconds
(`/tmp/bmux-ci-terminal-ui-run.log`). This is an unresolved local UI execution gap;
the tagged native keyboard-path smoke and next CI run remain the verification
routes. No user's or tagged app was quit for these test runs.

The four terminal regressions and all 18 connected-session ownership tests pass
with zero assertion failures (`/tmp/bmux-ci-terminal-ready-tests.log`, xcodebuild
exit 0). The ready-notification wait allows the main actor to finish native
surface initialization before tests inject input. An async RunLoop API warning
found in the initial readiness helper was removed; the mounted-field helper now
requests layout and cooperatively yields. The existing inconsistent XCTest-import
warnings are unchanged. Xcode project parsing/normalization, 430-file test wiring,
Swift file budgets against origin/main, and diff whitespace checks pass.

The final warning-cleaned four-test rerun did not execute: Xcode became idle after
app registration, and one fresh `test-without-building` retry likewise never
launched a test host. Only those owned idle xcodebuild processes were stopped.
The final helper source timestamp was 10:40:58, its compiled object 10:41:37, and
bmuxTests executable 10:41:47 on October 10; the compile/link/sign log confirms the
current helper was built without the async RunLoop warning. Logs are
`/tmp/bmux-ci-terminal-final-tests.log` and
`/tmp/bmux-ci-terminal-final-retry-tests.log`. Thus the preceding four-plus-18 raw
pass is measured evidence, while final helper execution remains for CI; it is not
reported as a passing rerun. A new tagged build and native acceptance are required
before pushing these composition changes. At handoff, old-head app-host shards 1
and 4 and Release were still running; their results remain unverified.
