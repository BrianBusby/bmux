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
2. Reusable base, card, panel, inset, and overlay styles — implemented; awaiting Brian’s review.
3. Workspace cards and existing sidebar controls.
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
