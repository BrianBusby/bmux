# Matte skin implementation record

Visual-only native skin, authorized by Brian on 2026-10-10. Preserve navigation,
workspace data, action routing, terminal rendering, and terminal fonts.

## References and base

The three PNGs here are verbatim conversation attachments. No PDF or original
pre-redesign screenshots were attached. The spec image is 444 × 2048; the two
targets are 1183 × 2048, including prototype tooling outside the simulated app.
That tooling is not product UI. Palette labels are cross-checked against raw
RGBA pixels in solid spec swatches, without display color conversion.

Branch `matte-skin` starts from `origin/main` at `ce17e9888`.

## Stages

1. Theme tokens for both appearances — approved by Brian on 2026-10-10. Definitions and resolution only.
2. Reusable base, card, panel, inset, and overlay styles — approved by Brian on 2026-10-10.
3. Workspace cards and existing sidebar controls — visually approved by Brian; CI compatibility follow-up remains separately tracked.
4. Main panel and terminal chrome — current; authorized by Brian’s “looks good keep going.”
5. Optional static texture behind a flag.

One commit per stage, followed by focused checks, an isolated tagged build and
launch, same-size dark/light captures, comparison, and user review. Do not
advance automatically. Stage 1 captures are the existing UI baseline; palette
verification precedes surface primitives in stage 2 and component adoption in stages 3–4.

## Governing sources and ownership

Read AGENTS.md, continuous-code-quality, and bmux architecture, debugging,
testing, dev-workflow, and localization skills. Apply installed Superpowers
implementation/review/verification workflows with repository rules taking priority.

Tokens belong to the existing BmuxAppKitSupportUI appearance area. MatteTheme
owns all numeric style values. Supporting value types have separate files.
No new package, service, mutable state, or settings owner. Existing
WindowAppearanceResolver/Snapshot and AppearanceSettings remain the integration
boundaries. The active `WorkspaceReferenceRail` consumes card and repository scopes; rows must retain immutable presentation snapshots. The older `TabItemView` equality boundary remains intact.
Bonsplit appearance owns terminal tab chrome. TerminalPanelView and the AppKit
portal retain identity/focus/geometry; GhosttySurfaceScrollView retains search.

## Constraints and pending verification

- Live verification corrected the initial source-search miss: the reference shell
  exists in `ContentView.bmuxReferenceAppShell`; its sidebar is
  `Sources/Sidebar/WorkspaceReferenceRail.swift`, search/filter is
  `WorkspaceTabFilterBar.swift`, and heading/navigation comes through
  `Sources/Panels/AgentSessionFactualProjectionModeHost.swift` and
  `AgentSessionFactualProjectionView.swift`. Existing hard-coded colors live in
  `Sources/Sidebar/Color+WorkspaceReference.swift`. Preserve action ownership.
- The current PR-link closure in ContentView selects the workspace before opening
  the link. Stage 3 must address the explicit requested no-selection interaction
  without creating a second selection or URL-opening path.
- Existing terminal horizontal scrolling is disabled. Adding it would change
  behavior, outside this skin. The spec terminal font is reference-only.
- CSS negative spread requires a documented native approximation. Native menus,
  window shadows, and font rasterization are not browser-pixel-identical.
- Homebrew submodule setup URL is unavailable; app-required Ghostty and Bonsplit
  initialize separately. Pinned GhosttyKit uses the existing legacy cache path.
- Existing shell hard-codes dark colors even in light appearance. The stage 1
  light baseline documents this; token integration must remove it in stages 3–4.
- No native visual parity claim until the surfaces and components consume tokens.
- Stage 1 adds no product strings. Later UI stages audit English/Japanese labels.

## Stage 1 verification

- `swift test --package-path Packages/macOS/BmuxAppKitSupportUI`: 25 tests in
  eight suites passed, including six new parameterized test functions.
- Independent spec review: all 48 opaque palette values match raw reference
  swatches; translucent colors, dimensions, typography, shadows, motion, and
  texture match the enlarged spec. Native token swatches were rendered from the
  production Swift files. No color or token deviations found.
- Independent code review: one README test-seam omission corrected. Complete
  types, tests, existing appearance owners, and concurrency boundaries reviewed.
- `BMUX_RELOAD_NO_GLOBAL_CLI_LINKS=1 ./scripts/reload.sh --tag matte-skin-stage1`:
  passed; isolated app launched and tag-bound socket commands succeeded.
- Baselines use the existing debug viewport recorder at 1092 × 593 points and
  `debug.window.screenshot` at nominal resolution. Only the tagged bundle's
  `appearanceMode` was changed. No main-app preferences or global CLI links changed.
- `./scripts/project-docs validate`, `generate`, and `check`: passed.
  `repo-status.yaml` records the token capability; no unrelated roadmap slice
  was reassigned. Explicit user authorization governs this separate visual task.
- Localization audit: no product labels, accessibility strings, menus, settings,
  or localization catalogs changed. Added prose is internal engineering/design
  documentation and diagnostic comparison labels, not shipped app UI.
- Existing full-app warnings include AppIcon unassigned children, AppDelegate
  deprecated AppKit calls, BrowserPanel actor-isolation/preconcurrency warnings,
  ContentView existential syntax, and a WebKit conformance warning. No changed
  token file emitted a warning. The app test target and entire repo test suite
  were not run locally; package tests are the focused stage 1 coverage.

See [comparison.html](verification-stage1/comparison.html) for reference/baseline
pairs and native token swatches. These are stage 1 evidence, not acceptance of
completed skin parity.

## Baseline deviations and stage ownership

| Area | Observed deviation in both baselines unless stated | Reason / owning stage |
| --- | --- | --- |
| Palette | Cool dark shell and saturated selected fill; light mode remains dark | Existing fixed reference colors; stages 2–4 consume dynamic tokens |
| Base / separation | Inset outer framed shell, darker sidebar, strong vertical divider, no 14pt floating gutter | Existing shell layout; stage 2 and integration in 3–4 |
| Elevation | Flat card/panel; no contact/ambient pair, directional inner edges, or floating main panel | Surface styles deferred to stage 2 |
| Header | Wordmark shape, brand spacing, top margin, icon size/spacing, count casing differ | Existing native header/control styles; stages 3–4 |
| Sidebar | 340pt fixed rail, larger search/filter, different gaps and card padding/radius/type | Existing rail metrics; stage 3 |
| Card states | Existing selected blue border; no square marker or specified hover/focus/press styles | Stage 3; state behavior not integrated yet |
| Main heading / tabs | Main title and metadata positioned differently; tab indicator/color and margins differ | Existing projection chrome; stage 4 |
| Terminal | No recessed container; different tab silhouette/indicator; fonts, prompt and engine theme differ | Container/tab styling stage 4; terminal fonts/renderer preserved |
| Texture | No grain | Optional stage 5; off is required to remain usable |
| Content | One fresh workspace; no second PR/author card; current home-directory label and shell prompt | Isolated baseline has no original workspace session/data; do not fabricate product data |
| Native titlebar | Current build 736, native folder icon, macOS capture/share badge in traffic-light area | Runtime/OS chrome and version; not prototype controls, no removal of existing features |
| Prototype tooling | Top controls and bottom inspector absent from native app | Intentional: reference tooling is not product UI |

Material mismatches above are explicitly pending integration stages, not changes
introduced by stage 1. Brian approved stage 1 on 2026-10-10; stage 2 is now authorized.

## Stage 2 ownership and verification plan

Implement reusable, noninteractive SwiftUI surface drawing in the existing
`BmuxAppKitSupportUI/Matte` concern. `MatteTheme` continues to own every design
literal. Immutable role/state inputs resolve fills, radii, edges, contact and
ambient shadows; the renderer owns native drawing only. Components keep all
selection, actions, focus, gesture state, lifecycle, and terminal ownership.
Stage 2 does not apply new styling to app views: sidebar adoption is stage 3,
main panel/terminal-container adoption is stage 4. The preview is diagnostic,
not another product screen or feature.

Native shadow mapping uses the reference blur converted to the native radius,
and contracted shadow-caster geometry for negative spread. Inner edges use
`strokeBorder` gradients; no material, live blur view, or animated texture.
Verify actual SwiftUI rendering in both schemes, including resting, hover,
selected, selected+hover, pressed, focused, disabled, and inactive appearances.
Package tests should exercise resolved state priority and rendered pixels/layout,
not duplicate literal tables. Compare the native preview against reference
inspection surfaces, and capture the unchanged app baseline at 1092 × 593 using
an isolated stage 2 tag. Preserve the user's stage 1 tagged app if still in use.

## Stage 2 verification

- Added passive `View.matteSurface` drawing for all five roles, immutable
  `MatteSurfaceState`, semantic appearance resolution and separate edge rendering.
  No app view, navigation, store, terminal engine, font, or action routing changed.
- `swift test --package-path Packages/macOS/BmuxAppKitSupportUI`: 32 tests in
  nine suites passed. Seven new test functions cover state resolution and actual
  SwiftUI pixels/layout in both schemes. Rendered checks caught and corrected a
  uniform inset band and disabled caster bleed-through before final verification.
- Actual native galleries rendered at 1092 × 593 points, 2× scale, using production
  files. Both galleries were inspected against reference surfaces with texture off.
- Independent spec and subsequent code-quality reviews found no remaining issue.
  Reviewed full primitives, token ownership, tests, package patterns and README.
- Tagged `matte-skin-stage2` reload passed; build 738 launched and tag-bound CLI
  rename/screenshot commands succeeded. App captures are both 1092 × 593 points.
  Only the stage 2 bundle's appearance preference changed. Stage 1 was untouched.
- Existing app warnings were reviewed: deprecated APIs, Swift concurrency warnings,
  unused values/results, icon assignments, absent AppIntents metadata and optional
  command-palette FFI skipped because Cargo is unavailable. No Matte file emitted
  a warning. Release download 404s fell back to the existing local artifact path;
  the tagged build succeeded. Full app tests remain CI coverage, not a local claim.
- Localization audit: production additions contain no user-visible strings or
  accessibility labels. Diagnostic gallery text and engineering docs do not ship
  in the app. No localization catalogs changed.
- Live pointer routing, VoiceOver, keyboard behavior, list performance and older
  macOS rendering remain integration checks. The surface modifier is noninteractive
  and hidden from accessibility; that source contract is not a live app AX test.
- Project Truth records surface primitives only. Component adoption remains pending.

See [stage 2 comparison](verification-stage2/comparison.html) and its reproducible
native gallery harness. Pause for Brian’s review before stage 3.

### Stage 2 comparison deviations

| Area | Deviation and reason |
| --- | --- |
| Shadow rasterization | Native blur radius is CSS blur / 2 and negative spread contracts the caster. SwiftUI and browser kernels differ; the spec's contact/ambient ingredients and geometry are retained. |
| Inner edges | Raised diagonal gradient strokes and concentric fading inset strokes approximate CSS inner shadows without live blur. Exact browser shadow-pixel equality is not claimed. |
| Gallery composition | Diagnostic text and specimen sizes differ from the HTML inspector; this verifies materials, not app layout/type. No prototype controls were added. |
| Card semantics | Gallery shows state decoration only. Leading selection square, accessibility selected trait, close/link targets, hover lift and reduced-motion behavior belong to the existing components in stage 3. |
| Texture | Off; static optional texture remains stage 5. Material hierarchy is visible without it. |
| App integration | All baseline deviations listed above remain: legacy palette/divider/card geometry, header/sidebar/main spacing, terminal chrome. Stage 2 adds reusable drawing only; stages 3–4 adopt it. |
| Capture content | Build badge is 738; fresh isolated session shows one workspace, current home directory/prompt and startup help in the dark capture. No original PR/session data was supplied. The OS capture badge occupies the traffic-light area. |

No unexplained material mismatch remains within the stage 2 primitive scope.
App parity and runtime performance are not yet accepted.


## Stage 3 — sidebar ownership and verification

Stage 2 was approved by Brian; its full CI on `27e5101e7` passed, including all
four app-host test shards and release build. Stage 3 is implemented and awaits
user review. Do not advance to stage 4 before that review.

### Ownership and native mapping

- `MatteTheme` owns colors, metrics, typography, motion and surface/control values.
  New shared `MatteButton` presentation uses native SwiftUI Button actions and
  local hover/focus/press state. Decorative layers are noninteractive.
- `WorkspaceReferenceRail` retains projection/observation above the list boundary.
  `WorkspaceReferenceCardView` receives immutable snapshots and action closures.
  Selection/close remain existing TabManager actions; busy state and final-card
  close eligibility are preserved. PR/author links retain BrowserExternalLinkOpener
  and no longer incidentally select the card, as explicitly requested.
- Cards, search, filter, filter popover and count consume semantic tokens. The
  continuous base and 14pt gutter are integrated; main panel, title/navigation,
  terminal chrome and final brand-header metrics remain stage 4. Chat/Session
  content, terminal engine, fonts, models and rendering are unchanged.
- Brian approved the 4pt selection square and native 1pt hovered-link underline.
  The spec's 2pt underline remains documented as the native adaptation.
- The native control target expands by the existing 4pt token with outer layout
  compensation. The rail's explicit native host includes the existing 14pt gutter,
  also compensated, to retain out-of-face clicks and room for card shadows.

### Keyboard integration and evidence

Live testing found the existing terminal focus-repair policy reclaimed Space,
Return and Escape from newly keyboard-focusable sidebar buttons. A render-driven
per-button focus callback lagged rapid Tab input; a native timing harness proved
that retaining a SwiftUI FocusState binding had the same delay. Those approaches
were removed. No private SwiftUI class exemption, per-key tree scan, layout flush,
deprecated focus callback or delayed race workaround is present.

`WorkspaceSidebarFocusScope` and `WorkspaceSidebarHostingView` give the rail and
filter popover explicit native identity/lifecycle boundaries. They forward the
entire inherited environment (including appearance, accessibility and locale),
preserve stable SwiftUI local state, and use flexible rail/intrinsic popover size.
`MainWindowFocusController` owns `WorkspaceSidebarFocusOwner`; it resolves native
membership synchronously through the existing first-responder-change hook and
keeps weak identities. Per-key ownership checks are constant-time comparisons.
Detach/reparent/unregister revoke grants; reattachment requires fresh focus.
An AppKit `NSKeyValueObservation` token revokes child-window ownership synchronously
before parenting changes, under the documented native-boundary carve-out.

The shared foreign-responder policy and existing terminal restoration paths honor
only these explicitly owned controls. The terminal-Find Escape helper leaves an
active sidebar popover to native dispatch. Explicit terminal/Find focus requests
retain their existing precedence. These are narrow focus-integration changes,
including in GhosttyTerminalView; they are not terminal rendering changes.

### Checks completed before the final candidate

- Package suite: 42 tests, including rendered native control/surface pixels,
  state priority, keyboard action and environment-sensitive drawing.
- Production-source native harness: 14 focus/hosting tests, including rapid Tab
  before layout, exact main/child ownership, detach/reparent/weak lifetimes,
  environment/state continuity and the 3pt outside-face native hit area. This
  temporary harness uses the actual production sources; it does not establish
  that the full Xcode app-host test target compiles. That remains a CI gate.
- Build 747 live: rapid search → Tab → Space opens filter with Terminal visible,
  both with Find closed and open; Return toggles once and exposes selected AX
  state; Escape dismisses filter while preserving Find; explicit Find close
  returns to terminal. Tab reaches cards, close buttons and metadata links and
  continues outside the sidebar host. Unselected close appears on keyboard focus.
- Prior live candidate: Shift-Tab returns to search; Return selects a card through
  the existing action. Closing a focused disposable workspace uses the existing
  confirmation and returns to the remaining terminal. Last-workspace close is
  AX-disabled and clicking is a no-op. PR activation does not select its workspace.
  Explicit Command-F from sidebar focus and terminal shell input both work.
- Narrow fixture at 802 × 593: eight workspaces, a six-line title and scrolling
  preserve search/filter/close usability (`graphite-narrow.png`, build 743).
- Build 748 passed the final native out-of-face test: clicking 3pt beyond the
  filter face opens the popover. Rapid Tab/Space with Find open, Return toggle,
  Escape preserving Find and explicit Command-F were repeated successfully.
  Temporary DEBUG focus probes are removed.
- English/Japanese audit covers 30 sidebar labels, including three new localized
  accessibility labels. No user-facing bare English was added; engineering notes
  and comparison labels are not shipped UI.
- Independent spec and quality reviews cover full affected modules, prior surface
  primitives, focus callers and lifecycle tests. Final corrections are re-reviewed.

Desktop sleep interrupted native automation twice (`cgWindowNotFound` affected
both this app and the unchanged stage 2 app). Waking restored access; a bounded
display-awake assertion supports the test run without changing persistent settings.

### Final stage evidence

Build 748 succeeded and ran in both appearances. The final PNGs are exactly
1092 × 593 points; `verification-stage3/comparison.html` places them beside the
same-size target crop. The captures include the two reference card titles and PR
metadata, a Codex-named real terminal tab, and no texture. The temporary fixture's
local Git refresh can clear manually reported PR metadata; metadata was restored
through the existing API immediately before each capture. No production data was
copied or changed.

No unexplained material mismatch remains within the sidebar scope. Differences
and ownership are enumerated in `verification-stage3/README.md`. In particular,
the main panel is still dark in light appearance and titlebar controls retain
the existing terminal-derived foreground, making them low contrast on the new
light base. These remain explicit stage 4 header/panel integration gates; this
stage does not establish whole-app visual or accessibility acceptance.

The final build retained existing warnings (deprecated AppKit/SwiftUI APIs,
concurrency diagnostics in unrelated owners, unused values/results, asset and
AppIntents notices). No new Matte, sidebar, native-host or focus-owner source
warning was emitted. Optional helper downloads fell back to existing local
artifacts; no dependency or toolchain change was made.

Final checks: 42 package tests and 14 production-source native tests pass;
Xcode normalization/test wiring and diff checks pass. Localization audit parsed
the catalog, checked all 30 sidebar/control keys in English/Japanese (including
dynamic status labels), and scanned added/moved view strings. Existing product
names remain literal; three new accessibility labels have both translations.
Project Truth validation/generation/freshness checks complete the stage manifest.
Independent spec and quality review covered accumulated primitives, controls,
sidebar snapshot boundaries, focus ownership/callers and lifecycle corrections.

Hover and Reduce Motion have source/render coverage; direct live hover/system
setting verification, VoiceOver and older-macOS behavior are not claimed. The
full Xcode app-host test target remains a CI gate. Stage 3 is one commit; the
new lifecycle regression has local failing-before/passing-after evidence within
that stage, honoring Brian's explicit one-commit-per-stage instruction.

After commit/push: update the draft PR, build the pushed HEAD under the same
isolated verification tag, perform a short smoke check, then pause for stage review.
The checked-in captures document build 748; a build-number-only change in the
post-commit verification does not require replacing them.

### Stage 3 CI file-budget repair

The first stage 3 CI preflight found positive growth in three files already above
900 lines. The repair follows `AGENTS.md`, `continuous-code-quality`, and the
architecture file/API discipline: extract cohesive native presentation and focus
responsibilities, without changing the budget, compressing code, or adding state.

- `WorkspaceReferenceAppShell` owns only the continuous-base/header/gutter layout.
  Its generic builders preserve the existing hierarchy, metrics and inherited
  appearance. ContentView retains workspace projection, Chat/Terminal content,
  navigation state and terminal lifecycle callbacks. Stage 4 header tuning is
  still deferred.
- `WindowKeyboardFocusRouting` binds an injected optional AppDelegate/window to
  the existing foreign-responder policy and native focus owner. It consolidates
  repeated lookup wiring and the native child-window dispatch path. The shared
  policy, nil-delegate NSText fallback, explicit terminal/Find bypass, and
  automatic sidebar ownership checks retain their prior semantics.
- `NSResponder.keyboardFocusOwnerView` owns the existing field-editor responder
  chain fallback. The terminal surface still resolves its mounted Find field
  first. Its four existing focus/search callers use the same wrapper and traversal;
  no renderer, font, hot-path scan, or navigation behavior was added.

Against PR base `ce17e9888`, ContentView is 17,017 versus 17,032 lines,
AppDelegate is 18,183 versus 18,185, and GhosttyTerminalView is 13,451 versus
13,457. The read-only file-budget guard passes with new/uncommitted files included;
no budget file changed. Normalization and test wiring pass (433 test files).
The package suite passes 42 tests. The native production-source harness passes
18 tests, including four new owning-view/no-owner/field-editor fallback cases.
The test uses the maintained bmux_DEV/bmux conditional import for app-host CI.

A separate `matte-skin-stage3-ci` tagged build (750) compiled all extracted sources
successfully without launching or replacing Brian's stage 3 build 749. No new
helper emitted a warning. Existing unrelated warnings remain. The checked-in
screenshots still document builds 748/743; no new visual claim is made from the
compile-only repair. App-host test compilation/execution remains a CI gate.

Localization audit: the shell moves the existing bmux/CompanyCam product names
and decorative mark unchanged; no labels, keys or translations were added.
The English/Japanese catalog parses, and moved/added views were scanned for text.
The prior 30-key sidebar audit remains applicable.

A separate CI blocker remains outside this bounded repair: the activation-session
benchmark on Xcode 26.3 reports optional type inference at
`View+MatteTypography.swift:27`. The local Xcode 26.5 build passes; it does not prove
compatibility with that older CI compiler. Typography is unchanged by this repair.

### Stage 3 typography compiler compatibility follow-up

The Xcode 26.3 activation-session benchmark and app-host CI shards still failed
on `7c5f3450a` because the compiler inferred optional `Double` for the local
line-spacing expression. The bounded follow-up replaces optional `map`/coalescing
with an explicitly nonoptional `Double` and `if let`/`else`. It preserves exactly
`max(0, pointSize * lineHeightMultiple - nativeLineHeight)` when configured and
zero otherwise. Native ascent/descent rounding, font selection, weights, tracking,
all token values, and terminal preferences are unchanged. No new state or caller
responsibility was introduced.

Local Swift 6.3.3 verification: 42 package tests pass, including the rendered
multiline-title baseline check, and Release package compilation passes. The
Release build retains existing unused-public-import, Bonsplit deprecation/actor
isolation and NotificationCenter-isolation warnings; the typography file emits
no warning. The installed toolchain is newer than CI, so this local result does
not establish Xcode 26.3 compatibility or full app-host test success.

The isolated incremental `matte-skin-stage3-ci` reload (build 751) also passes,
without launching or replacing the user's build. Global CLI links were preserved.
The `matte_skin_ci_compiler_compatibility` caveat remains open until actual
Xcode 26.3 CI passes. Localization audit: this expression-only repair adds no
user-facing strings, labels, keys or translations; the prior sidebar audit is
unchanged. The checked-in visual evidence and user's build 749 remain unchanged.

## Stage 4 ownership and verification plan

Brian approved the stage 3 visual build and authorized continuing. The parent
reviewed the pushed stage 3 shell/focus extractions and the explicitly typed
line-spacing fix (`24b555192`); no formula, terminal renderer or ownership
regression was found in those deltas. Exact-head Xcode 26.3 CI remains monitored.
The running stage 3 build 749 must remain untouched. Stage 4 uses a new isolated
tag and pauses after its one stage commit and dual-appearance review.

- `WorkspaceReferenceAppShell` owns the continuous base, brand header and rail/main
  layout. Existing sidebar snapshots/actions remain unchanged. Header/titlebar
  foreground must use the effective matte appearance instead of terminal luminance.
- `AgentSessionFactualProjectionView` retains selected-primary-tab state, identity,
  refresh and existing content routing. Extract passive panel heading/navigation
  presentation as needed; apply shared panel surface and semantic typography.
  Preserve Chat/Session content and explicit terminal identity.
- Bonsplit owns the existing terminal tabs, close/menu/drag behavior and toolbar.
  Its current public API lacks exact state palette, selected-tab geometry and
  28pt control-target hooks. A minimal optional presentation API must preserve
  existing defaults and actions; bmux supplies values from MatteTheme. Initial
  appearance and both Ghostty/resolved-chrome updates must share one mapper.
- Bonsplit is pinned to `fb5307f`; upstream main is 243 commits ahead and is not
  writable from this account. Do not upgrade it wholesale or leave an unreachable
  submodule commit. Prepare the scoped patch against the pinned source for review;
  resolve reachable remote-main delivery before committing the parent pointer.
- Terminal foreground/background colors are permitted presentation inputs in the
  request. Use existing native/configuration seams only if fonts, renderer, ANSI
  colors, lifecycle and global user configuration remain intact. MatteTheme owns
  the values; no duplicate palette in terminal core. Do not edit Ghostty itself.
- Terminal views live in the AppKit portal, so a SwiftUI rounded clip alone is
  insufficient. Keep stable panel identity, native Find/accessory layering and
  pointer-only portal routing. Use the shared SwiftUI inset outside a padded, unchanged native portal footprint;
  no per-frame work or new rendering loop.
- Files over the 900-line hard cap may not grow versus the PR base; existing
  tracked files below that cap retain the guard’s 25-line incidental allowance
  (`scripts/swift_file_length_budget.py`). New files stay below 500 lines. Use
  coherent extraction with explicit inputs, not compressed code or budget changes.

For header/tab gaps absent from the token image, Brian was asked whether to use
screenshot measurements or retain existing spacing. After ample opportunity to
answer this optional preference, the parent stated the assumption that measurements
from the authoritative screenshots will be used and recorded as semantic tokens.
This follows the requested visual match; it is not claimed as an explicit answer
or permission to invent values. Actual native comparison still precedes geometry edits.

Verification includes focused native rendering/state coverage, actual CI compiler
compatibility, app-host compilation, new-tag build/run, 1092 × 593 dark/light
comparison, native keyboard focus and separate tab/close targets, Find, terminal
input, split/resize/narrow-window usability and localization audit. Record every
remaining reference difference. Texture stays off until stage 5.

### Stage 3 CI compiler evidence

On `24b555192`, the Xcode 26.3 activation-session workflow successfully completed
its tagged app build at 2026-10-11 03:28:49 UTC. This resolves the specific older
compiler failure in the typography line-spacing expression. Evidence: [run
38107446173, job 114375911325](https://github.com/BrianBusby/bmux/actions/runs/38107446173/job/114375911325).
The activation benchmark, package tests, build-and-lag job and app-host shard 4
subsequently passed. The other shards and release check remain monitored; this
is not a claim that all CI passed. Stage 4 has separate new changes
that still need its own build, test and runtime verification.

### Stage 4 first-pass checks

The initial app build caught a duplicate Xcode object identifier; the scoped fix
was verified by reproducing the failing project load and then obtaining a successful
`xcodebuild -list`, plus checking all 1,887 build-phase references. A subsequent
compile caught a missing shared-UI import, now fixed. Package and native-harness
passes alone had not exercised these app-target issues.

The independent specification review identified titlebar split controls below
28pt, a duplicated accessory hover wash, and missing passive terminal-tab hover
motion. Those were corrected before visual review. Its initial inactive-tab weight
finding was retracted after direct inspection of the authoritative image: both
active and inactive tabs are 14pt / 500. No conflicting typography change was made.
The updated checks pass 44 shared-UI tests, 175 Bonsplit tests (155 XCTest plus
20 Swift Testing), and 18 native focus harness tests. The latest full app build
and runtime comparison remain pending.

### Stage 4 measured geometry and ownership checkpoint

The 1092 × 593 native preview was measured against the reference app crop. Theme
metrics now record brand inset 8 and vertical offset 24, main-panel top inset 28,
heading native-baseline adjustment -3, navigation gaps 12/4, embedded terminal
gap 18, terminal strip height 32 and terminal interior padding 13 horizontal /
12 vertical. Exact type/color/material tokens remain unchanged. Native text
rasterization is not corrected by shrinking authoritative font sizes.

The first inset experiment exposed stacked inner-edge siblings as horizontal
bands. The final composition removes the native edge attachment/hosting API
entirely: `TerminalInsetContainer` pads the unchanged native portal and places
the existing shared inset outside its footprint. The shared inset has dark/light
pixel coverage for a continuous interior. Find remains owned by the native portal.
`WorkspaceTitlebarPresentation` owns only centered title/folder and badge drawing;
the folder's existing drag/menu actions remain in `DetachedFolderDragIcon`.

The final quality fixes propagate the 28pt toolbar minimum into width reservations
and narrow-pane caps (nil presentation retains 22pt), extract `PanelAppearance`
coherently, and replace the moved styling namespace with an immutable appearance
value. The file-budget guard passes without changing budgets; its explicit
incidental allowance covers +5 focus-controller and +2 workspace-content lines.
Project loading, normalization, 433-test wiring, duplicate-ID audit, Swift parsing
and diff checks pass. Existing package unused-import and vendor deprecation/actor
warnings were inspected; no new warning was identified in focused test logs.

### Stage 4 native preview and dependency delivery

Tagged build 753 passed. At 1092 × 593, the main panel begins at approximately
(314,90), matching the reference (313,90); the terminal inset begins at (339,247)
versus (336,246). The remaining few points follow exact native padding/rounding.
Live checks passed search-to-filter-to-primary-tab keyboard traversal, selected
Terminal focus retention, Session activation, native Find above the terminal,
shell input/output, split-right creation and closing the temporary split with
Cmd-W. At 802 × 593 a long workspace title wraps while the close button, primary
tabs and four terminal tools remain visible. Fullscreen entry/exit retained the
centered title and terminal. Appearance changed light→dark in place through the
tagged app’s Settings. No user build or global appearance was changed.

The light Chat preview exposed white text on the new porcelain backing. The
correction uses the renderer’s existing explicit theme-input seam, scoped to the
shell Chat caller. It changes semantic colors only, with no web layout, content,
action or lifecycle changes. This correction still requires a fresh app build
and light/dark live check. Final token review also centralizes retained native
titlebar/header metrics and fixes the affected Japanese build-badge translation.

Bonsplit’s reviewed optional presentation patch is commit
`306a7424d93259ddc1728634e237947d2c4ede13`, pushed to `main` in the owned dependency
repository https://github.com/BrianBusby/bonsplit. It preserves the pinned
`fb5307f` history and MIT license rather than taking 243 unrelated upstream commits.
Remote-main reachability was verified before the parent pointer update. The
parent submodule URL now points to this reachable copy; local `upstream` retains
https://github.com/manaflow-ai/bonsplit.git. HTTPS publication lacked workflow
scope, so publication used the existing GitHub SSH identity. GitHub’s large-file
warning concerns inherited `.build` history, not this source/test-only patch.

### Stage 4 final source and preview check

Build 754 passes after the Chat contrast correction and token centralization.
The porcelain Chat preview now shows readable ink text, metadata and its existing
button without changing content/layout. Its diagnostic capture is included.
Independent final specification and quality reviews have no remaining findings.
Shared UI now passes 45 tests, including native magnified-title rendering;
Bonsplit remains 175 tests and native focus harness 18. Catalog JSON parses;
the moved badge’s English/Japanese placeholder parity is verified.

The main-presentation capability is implemented, with the requested user review
gate still pending before texture. App-host and full suite results on the stage 4
commit remain CI evidence, not inferred from the successful app build.

The open 754 preview changed during automation, so it is treated as potentially
in use and will not be quit/replaced. Final pushed-commit dogfood uses the
separate `matte-skin-stage4-review` tag. The committed graphite/porcelain pair
records builds 753/754; the final review build uses the same production sources
with no further geometry changes. Full suite and app-host CI stay pending.

## Selected-card visual follow-up

Brian explicitly confirmed using screenshot measurements for unspecified spacing,
and identified the selected sidebar card as still unlike the reference. Stage 4
commit `00d3d13b8` had already been pushed and its isolated build 755 passed; this
follow-up corrects the specific sidebar discrepancy before the next visual gate.

Read-only comparison found a concrete header-line-box error: the close button’s
outer 14pt frame collapsed the header, producing a roughly 68pt card versus 74pt
in the reference. The title sat about 6pt too high and repository label about
3–4pt too high. A measured 20pt, vertically centered header corrects this while
preserving the authoritative 13/16/14 padding, 7pt gap, 15pt/600 title, and 28pt
close target. Rich metadata can still increase row height. The semantic selected
fill, 1pt ring, inner edges and level-2 shadows were already applied. The separate
keyboard-focus outline must remain accessible; it is not the ordinary selection
ring. Texture remains deferred.

The selected card’s 600 weight correctly resolves to native semibold. Native
650/750 requests quantize on this macOS, but that observation alone does not prove
a browser-reference mismatch; no typography substitution or whole-UI scaling is
authorized or introduced in this follow-up. Verification remains actual native
card geometry in both appearances and close/focus targets, plus focused checks.


Follow-up verification: tagged build 756 passed. Both 1092 × 593 captures now
show the corrected approximately 74pt selected card. Live keyboard traversal
reaches its selected accessibility element and adds a separate focus outline
without a geometry change. Its independent close control removed only the
disposable selected workspace; the fixture was restored afterward. Shared UI
45 tests, source parse, length budget and diff checks passed. Independent review
of the complete card/rail/focus path found no new state or ownership change.
No localized strings changed. Full app-host/CI remains a separate pending gate.


## Pointer-selected card consistency follow-up

Brian supplied two porcelain screenshots showing a thin selection ring on the
terminal workspace and an extra outer ring on the Chat workspace. Reproduced
on running build 757 with real pointer clicks: Terminal receives native focus
after selection, while Chat leaves the clicked card focused. Raw FocusState
incorrectly drove keyboard decoration for both input methods. This is a visual
state issue; native focus, navigation and activation must remain unchanged.

The existing application event dispatch now reports input modality through
WindowKeyboardFocusRouting to the per-window WorkspaceChromeFocusOwner. Only
modality transitions update the registered hosts' value-only environment.
No new event monitor, gesture, observable row dependency, responder change,
view-tree scan, or per-frame work is introduced. The hosting root keeps its
content identity; callbacks capture hosts weakly and are cleared at teardown.
Actual focus still controls close visibility and accessibility. Both button
and card decoration gate the whole focus expression, preserving keyboard rings.

The PR-link hover wash was also incorrectly shared with flat icon controls.
Links now retain only their existing token color and native underline on hover;
flat icon controls retain the wash. No new color, metric, or string is added.

Guidance: AGENTS.md snapshot/hot-path/file-budget requirements; continuous-code-
quality; bmux-architecture, debugging and testing skills. Existing patterns:
WorkspaceChromeFocusOwner/Scope/HostingView, WindowKeyboardFocusRouting and
NSApplication.bmux_applicationSendEvent; MatteButtonLabel/ControlDecoration.
Independent complete-path review found no blocking ownership/lifecycle issue.
AppDelegate remains smaller than the feature base; the exact base-aware source
length gate passes.

Regression evidence: the link-hover rendered-pixel test failed in both themes
before the fix (test-only e32a72f94). CI previously omitted BmuxAppKitSupportUI,
so test-only 75528c0b2 adds the confirmed standalone package to its existing job.
The fix passes 47 shared UI tests and 19 native focus-harness tests, including
modality deduplication, unchanged responder ownership, separate-window state,
new-host propagation, and actual outline/interior pixel comparisons. Test-host
compilation/full app suites remain CI gates. No new localization strings.
Live build 759 passes the exact pointer sequence in both appearances. Tab and
Shift-Tab restore the outline, Return retains the selected workspace, and clicking
an already-focused card suppresses only decoration while retaining its actual
accessibility focus. The first live pass exposed inherited EnvironmentValues
overwriting the semantic Boolean; ordering is corrected and the hosting-boundary
test now asserts the actual subtree value and unchanged local-state UUID.
Brian explicitly approved retaining the existing pressed-link background while
removing only its hover background. The rendered test distinguishes both states.
The paired selected-card captures show build 759 (before that pressed-only
restoration, which does not affect these unpressed captures). Final committed
source reload and CI are reported in the PR/handoff. Direct VoiceOver visual
behavior after pointer input is not claimed.

## Texture stage reverted at Brian's request

Brian rejected the optional texture after reviewing build762. Revert only stage5
commit16e9e6a4e: remove the grain assets, loader/scope, preference flag, surface
integration and texture-specific tests/artifacts. Keep approved stages1–4, the
selected-card focus fixes, and the independent metric-test corrections. Runtime
source is identical to approved2f0181b3c after this revert. The running stage5
preview's flag was disabled immediately, without quitting or rebuilding it.
No UI text is added or changed; localization entries remain unchanged.

## Retained CI follow-up (historical texture-build evidence)


Exact-source CI at `16e9e6a4e` passes all 51 shared UI tests, the package suite,
activation checks, and build/typing-lag checks. Full app-host verification remains
blocked: run `38113835880`, shard 3 (`114395249842`) fails, while completed shards
1 and 4 contain assertion failures despite successful job statuses. The existing
workflow accepts any XCTest summary containing `(0 unexpected)`; that text does
not mean assertion failures are approved expected failures. The feature-base run
`38072470965` also contains many failed tests. Some current cases did not execute
in its logs, so a clean baseline or wholly pre-existing failure set is not claimed.

The bounded follow-up corrects two metric tests: retained right-sidebar controls
must use their own shared 20pt owner instead of the new 28pt matte titlebar value;
the group/row alignment test already had stale 10/6 padding expectations on the
feature base and now checks the existing 12/8 padding and 20/28 edge/center offsets.
All alignment, scaling, icon and radius assertions remain. The touched XCTest
method moves to a same-file Swift Testing suite; the oversized file shrinks one
line. No production behavior changes and no preview is rebuilt.

Seven focused compiled metric tests pass with actual production definitions and
shared-package dependencies. Full app-host compilation remains a CI gate. The
standalone harness emits an actor-isolation warning in unchanged header-icon
code; no new warning is introduced in repository source. Test wiring, Swift parse,
base-aware file budget and diff checks pass. No user-facing strings change.
Source rules remain root AGENTS, continuous-code-quality and bmux-testing's
incremental Swift Testing migration; CI ownership stays separate from dogfood.
The app-host masking rule and unrelated baseline failures are reported rather
than broadened into this visual change. `matte_skin_full_app_host_verification`
records the unresolved acceptance gate in Project Truth.

Texture-revert checks: all47 shared UI tests pass; Sources and the shared UI
package match approved2f0181b3c exactly. No new localization strings. The existing
light preview was inspected with texture off, preserving its window/workspaces.
A separate matte-skin-no-texture tagged build validates the reverted source
without replacing the user's active preview. Full app-host CI caveats above
remain unresolved and are not hidden by this revert.


## Truthful CI reporting and matte test follow-up

Brian authorized the reporting fix and base comparison after the texture revert.
The reporting change is isolated in PR142 (`ci-test-result-reporting`, based on
`ce17e9888`); it must preserve nonzero runner/timeout status instead of accepting
XCTest's `(0 unexpected)` text. No merge is authorized. The existing
`matte_skin_full_app_host_verification` caveat remains open.

Comparison of XCTest case-result lines from current run38143802312 and base
run38072470965 found 133 current failed cases, 114 also failed on the base,
14 passed on the base, and 5 were absent from the base log. These counts cover
observed XCTest cases only, not all Swift Testing cases or a clean complete run.
Five of the 14 pass in another sampled matte run: AX insertion, initial git
metadata coalescing, mouse unread dismissal, detach reconciliation and relay
ZDOTDIR history. That establishes intermittency, not an acceptable green gate.
Six terminal-runtime initialization checks and the active-surface queued-submit
check remain unresolved; no environment-only or pre-existing claim is made.

Two deterministic failures were stale presentation expectations. The titlebar
test required pure black rather than the approved secondary-text token. Its
replacement checks the token and >=4.5 contrast against the actual matte base
in both appearances. The drag test's fixed x=240 point is inside a 28pt button;
the replacement checks all actual button centers, inter-button gaps and trailing
whitespace for all five existing titlebar styles. Only these tests migrate to
Swift Testing; both new files are wired into the existing Xcode test target.

Seven parameter cases pass in a native harness using the production foreground,
hit-region registry, range calculations and drag-capture code. Application-only
Bonsplit/minimal-mode fallback and telemetry are absent in that harness, so it
does not replace full app-host compilation and execution. No production code,
user-facing strings, terminal code or active preview changes in this follow-up.
Localization audit: the diff contains test names/assertions only, no UI strings.

The five color failures absent from the base log expect translucent #1122337F.
An isolated native probe of the byte-identical base/current bonsplitChromeHex
function and WindowAppearanceSnapshot produces opaque composited colors in both
appearances, reproducing that expectation mismatch without matte changes.
This is focused source/runtime evidence, not a complete baseline app-host run.

Governing sources: root AGENTS.md; continuous-code-quality; bmux-testing and its
Swift Testing migration rule; bmux-debugging's routing/hot-path boundaries;
bmux-dev-workflow's Xcode test wiring and normalization requirements. Ownership
remains the existing semantic theme and drag registry. Full CI evidence and
the seven unresolved cases above remain required before merge readiness.


### Final verification and native CI isolation follow-up

Final build763 was inspected in both appearances at1092×593, then at802×593
with the long reference heading and an eight-workspace scrolling sidebar.
Fresh images and the side-by-side comparison are in `verification-final/`;
`verification-stage4/README.md` records differences and exact live coverage.
Only the newly launched no-texture tag was manipulated; the user's stage5
preview remained untouched. Original System appearance was restored afterward.
No app source or shipped strings changed; production source still matches2f0181b3c.

Actual20bf68591 app-host logs show all7 titlebar parameter cases starting but no
completions before the45-second post-XCTest cutoff. Shard2 also crashes from a
ContentView fixture missing SidebarUnreadModel. That root omission predates the
skin, but directly obstructs verification. The one affected file-drop test now
uses the maintained root composition (the notification store's own unread
projection), detaches its content at teardown, and migrates to Swift Testing.
Review identified that Task.yield alone does not drain AppKit attachment work;
the final test uses the existing visibility fixture's bounded main-run-loop
drain. Both affected files typecheck against the actual built app module without
warnings. Full runtime execution remains required.

PR142's three reporting commits are cherry-picked as a prerequisite onto this
branch, without merging either PR to main. Project Truth conflict resolution
retains both matte and CI capabilities/caveats and regenerates derived documentation.
A focused shard3 invocation runs all seven affected native suites before legacy
full-suite fixtures. It uses the same console-session/serialized app-host runner
and authoritative exit status; no timeout is extended and no full-suite tests
are removed. This separates feature evidence from later unrelated failures.
The shared package's47 tests passed on20bf68591; all remaining app-host failures
and incomplete runs still block a clean full-suite claim.


### Terminal preference precedence review correction

Review of PR141 found the post-user-config matte override replaced explicit
Ghostty themes, colors and opacity. Matte foreground/background now enter through
the existing managed-default loader, before user files and recursive includes.
Explicit themes retain their existing default-suppression rule; individual colors
override only the matching default. Matte no longer writes background-opacity,
so opacity-only user configuration survives the existing stale-legacy reassertion.
Startup, app reload, surface reload and preview profiles retain the same loader.
Renderer code, fonts, input handling and the existing readable-foreground policy
are unchanged. Production source therefore no longer matches2f0181b3c exactly.

The test-only commit edf7fa0b7 adds a native C-config/full-loader suite and the four
unresolved terminal cases to the existing focused CI invocation. The corrected
identical suite completes all12 parameter cases against both compiled app dylibs:
the previous build fails14 assertions; the fixed isolated build passes all12 cases.
It covers both default palettes, explicit colors, single/paired themes, independent
color overrides and opacity0.88. Expected theme foreground retains the pre-existing
contrast reconciliation rather than changing the renderer. The synchronous
MainActor fixture restores preview state and preserves shared shell/host modes.
Both test compiles are warning-free. Existing config-policy package tests complete
11/11 cases, but SwiftPM exits nonzero with existing binary-name diagnostics; this
is not counted as a clean package command. Independent review found no blocker.

Fresh baseline app/test source ce17e9888 now reproduces three of the seven disputed
failures: queued-submit, direct-first-responder refresh and visibility restore.
IME repeat, printable repeat, detached-surface recovery and closed-surface recovery
pass on base but previously failed on matte at their initial runtime-surface
precondition after a fixed50ms drain. Both suites show readiness instability;
matte resource discovery occurs after one failed readiness assertion. This is a
timing hypothesis, not proof those four failures are unrelated. They remain in
the focused native gate. The five static chrome-color failures use literal colors
and opacity through unchanged compositing functions; they do not read Ghostty
configuration and remain separate stale alpha expectations. Baseline shards1/4
correctly fail with exit124; required comparison logs are retained and remaining
baseline jobs were cancelled after evidence capture. Full-suite green is not claimed.

Governing sources remain root AGENTS, continuous-code-quality, bmux-architecture,
bmux-debugging and bmux-testing. Existing default-config ownership and discovery
patterns are reused; no new config store, parser or test-only app branch is added.
No shipped strings change. The explicit-preference regression is resolved in
Project Truth; full app-host verification remains open. New default/custom visual
checks and exact-head CI are still required before a merge decision.

### Popover routing, terminal inset paint, and readiness follow-up

The completed 616e app-host run (38159675610, shard 3 job114530497925)
passed all 12 native config cases and the seven original native suites. IME and
printable-repeat also passed. Detached recovery and closed recovery failed their
initial runtime-surface precondition; the focused failure skipped the later full
legacy invocation. This is partial passing coverage, not full-suite green.

Two actual popover callers incorrectly inspected the parent window's responder
while handling a child window. WindowKeyboardFocusRouting and the shared terminal
Find Escape route now inspect the child responder while retaining the existing
parent-owned WorkspaceChromeFocusOwner. Its exact registered-host ownership and
revocation rules are unchanged. Native caller tests exercise actual AppDelegate
contexts with distinct parent/child responders, unrelated child focus, and open
terminal Find. Against 616e, two tests complete with three expected assertions.
The fixture restores shared app/active manager and the registry's route-retirer,
and closes its terminal panels. No new production state owner is introduced.

Live custom-theme checking also exposed a separate paint regression: config
precedence was correct, but TerminalInsetContainer painted the fixed matte inset
under the terminal's configured foreground. The container now receives
PanelAppearance.backgroundColor through a per-call matte-surface fill. This
reuses the existing GhosttyBackgroundTheme/WindowAppearanceSnapshot composition
(and thus existing readable-foreground input). Raw config opacity remains intact;
its effect is represented in the already-composited panel color. The inset keeps
its native radius/edge stack; other matte surfaces retain semantic token fills.
No renderer, engine, font, per-keystroke work, or user preference changes are made.
The full TerminalPanelView is rasterized through native NSHostingView: four custom
color/opacity cases fail on616e, while both default matte palette cases pass.
ImageRenderer cannot capture an NSViewRepresentable and was not used as proof.

The two recovery tests are incrementally migrated to Swift Testing, preserving
the release/detach and closed-lifecycle behavior assertions. Their fixed 50ms setup
could release nil while asynchronous Claude shim installation was pending; its
later completion could create the headless bootstrap window after detachment.
They now subscribe to terminalSurfaceDidBecomeReady before mounting, following
ConfiguredCodexLaunchTests, and require a runtime before changing lifecycle. The
closed test additionally checks no queued restart or new create attempt. Existing
failed616e cases provide the failing fixture evidence. No production lifecycle
code or timeout/retry policy is changed. Both migrated cases pass against the actual
616e and fixed production dylibs. The notification sequence filters immutable surface
UUIDs before yielding Bool, avoiding transfer of the non-Sendable surface object.

Governing sources: root AGENTS; continuous-code-quality; bmux-architecture file/API
and concurrency guidance; bmux-debugging runtime pitfalls; bmux-testing behavioral,
Swift Testing migration, wiring, and native-host validation guidance; shared-behavior
routing guidance. Complete callers, owner, config/panel composition and maintained
native render/launch fixtures were inspected. Independent review identified the
fixture route-retirer cleanup and it was corrected; no remaining production blocker
was found in that scoped review. No shipped strings are added (test diagnostics and
contributor docs only). The test-only commits are a96772a22 and 5ddefd5ce. Native red
runs and warning-free test-file compilation are recorded. The fixed 766 production
dylib passes 16 tests across four suites (popover, six inset parameter cases, 12
config cases, and existing native matte surface tests); recovery separately passes
2/2. Parent-owned isolated tagged reload succeeded. Test wiring, source length,
diff and Project Truth gates pass. Actual app-host CI
remains pending; existing full-suite caveats remain open.

Parent live verification on isolated build 766 passed in both appearances: the
explicit Tango Dark terminal background now stays dark with readable white text;
reloading configuration preserves it. With terminal Find open and workspace filter
popover focused, the first Escape dismisses only the popover and keeps Find open;
the second Escape closes Find. System appearance was restored. New 1092×593 captures
are verification-final/custom-theme-graphite.png and custom-theme-porcelain.png.
Their terminal intentionally differs from the default reference because the user
explicitly configured Tango Dark and opacity 0.88; no preferences were edited. The
earlier default captures/walkthrough remain labeled build 763. The configured-inset
visual caveat is resolved; exact-commit tagged build and actual CI remain gates.

The test-only 5ddefd5ce app-host job 114567585239 (run 38172199110)
completed both popover tests with the expected three assertions, and all six inset
cases: four custom-color failures and two passing default palettes. All 12 config
cases and the original seven native suites passed. IME repeat passed; printable
repeat again failed its initial runtime-surface precondition (it passed on 616e),
and the old detached/closed fixtures failed as before. This preserves actual CI
red evidence for both fixes and confirms that the readiness issue varies across
runs. The exact 7ce43151c tagged reload succeeded as build 767; production source
is unchanged by this documentation update. Fixed-head app-host results remain
pending, including the migrated recovery cases and existing printable-repeat case.
