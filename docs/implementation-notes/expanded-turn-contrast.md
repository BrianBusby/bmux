# Expanded turn contrast follow-up

Base: PR133 HEAD 46795a6bf, preserving build 720 runtime 00ce0570d and subsequent
reviewed PATH/exit corrections. User supplied screenshot and live read-only CUA
inspection reproduce the same white panel with nearly white text. No current
app was changed, navigated, rebuilt or replaced.

Governing sources: AGENTS.md/CLAUDE.md; continuous-code-quality; bmux architecture
and file/API discipline, debugging/list boundaries, testing, localization and
dev-workflow. Pattern: Sources/Sidebar/Color+WorkspaceReference.swift. The native
Session shell is a fixed dark surface independent of the system appearance;
ExpandedTurnDetailView mixes inherited light text with controlBackgroundColor
and system Color.primary. Prior screenshot coverage asserted only geometry and
rendered the detail without the shell's inherited foreground.

Plan: add actual bitmap contrast regression under Aqua and Dark Aqua with the
shell foreground; use the existing workspace surface/text tokens and scope the
native dark color scheme to expanded evidence controls. Preserve evidence,
state identities, collapsed headers, current turns, and other tabs. Resolve the
inherited 851-line view budget by cohesive owner/type extraction with no behavior
changes. No new text/localization keys expected. Native patched-app verification
requires a separately approved isolated build; running build 720 stays untouched.

Verification so far:
- Test-only commit f3794d8ee reproduced Aqua white-background luminance near 1.0
  and a 1:1 evidence contrast ratio; the regression failed twice as expected.
- The fix uses workspaceReferenceSurface/workspaceReferenceTextPrimary and a
  scoped dark SwiftUI color scheme matching the surrounding fixed-dark shell.
- All 11 ExpandedTurnPresentationTests pass (including 29 command category
  cases) in the existing temporary SwiftPM harness. Both actual NSHostingView
  rendering tests ran. The harness compiles unchanged detail/presentation source
  copies and the real clipboard copy method; unrelated workspace-link methods
  and the history container are excluded. It does not prove app target wiring.
- Inspected rendered Aqua empty-evidence and 320-point populated fixtures:
  readable labels/evidence, wrapped long text, filter chips and failed result.
  The layout test also renders 800 points and Dark Aqua. These are fixtures, not
  the live user turn. Keyboard/VoiceOver and patched-app behavior remain open.
- No new user-facing strings or locale keys; existing English/Japanese copy
  and accessibility labels are preserved. Fixture assertion text is test-only.

The inherited oversized Session file was split into its existing ModeHost,
workspace value records, evidence row projection, and current-turn value view.
The Session view is now 486 lines. The refresh owner/tasks, view-mode state,
canonical history IDs, tab closures and current-turn content are unchanged;
current-turn text colors map to identical shared RGB tokens and its link tint
is preserved exactly. The static evidence helper is now a struct, retaining
its API and projection semantics. Xcode source entries are wired and quoted.

Static checks passed: file-length budget versus base 46795a6bf, pbxproj parsing
and normalization, all 428 test-file wiring entries, and git diff --check.
Project manifest validation, generation and freshness check passed. Audited
all 35 localized keys in changed/moved UI: no additions/removals and every key
has English and Japanese catalog entries. Existing unrelated file-budget
reductions suggested by the checker are not part of this patch.

Independent read-only review found no introduced blocker in the palette fix,
its scope, or the bitmap regression. The sampled contrast assertion covers
empty-evidence text and the card surface; it is not a claim of comprehensive
contrast, keyboard, or VoiceOver acceptance. Existing populated fixture images
were also inspected. The review and mechanical extraction checks do not replace
the full Xcode regression run or native dogfood.

Full Xcode validation passed: 22 Swift Testing tests across
ExpandedTurnPresentationTests and AgentSessionFactualProjectionStoreTests,
including both native bitmap tests. The complete app and unit-test targets
compiled using bmux-unit, isolated derived data/bundle identity, cached exact
SwiftPM dependencies, BMUX_SKIP_ZIG_BUILD=1 and the documented GlobalISel
workaround. Log: /tmp/bmux-expanded-contrast-xcode-tests.log. No tagged reload,
new dogfood app launch, or changes to running builds 719/720 occurred.

Compiler warnings were reviewed. No warnings originate in changed/moved
Session files. Retained warnings include existing BrowserPanel actor/sendability
issues, deprecated AppKit APIs, unused TabManager closePanel results, and test
XCTest implementation-only import warnings; these files are unchanged here.
No broad concurrency or lifecycle correctness claim follows from this run.

Remaining: user-authorized fresh isolated tagged reload/native acceptance,
then push/open the scoped stacked PR and background review under the normal
workflow. The active dogfood restriction is AGENTS.md lines 197–207; this patch
must not rebuild or replace codex-update-fix or readable-turns-build715.
