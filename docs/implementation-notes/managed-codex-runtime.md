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

Final-commit tagged build 731 also succeeded. Pending: independent review, stack
integration and CI in PR #139.
The initial focused build exposed incorrect Xcode source paths for the three new
runtime files; the references were corrected before further verification.

Project-docs validation/generation/freshness, Xcode project normalization and
430-file test wiring, Swift file-length budgets and diff whitespace checks pass.
Localization: all four new inline/notification/action messages have English and
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
