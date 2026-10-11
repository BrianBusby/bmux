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
3. Workspace cards and existing sidebar controls — current; authorized by stage 2 approval.
4. Main panel and terminal chrome.
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
