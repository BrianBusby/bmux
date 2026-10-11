# Stage 3 verification

The comparison page places the target app crop and native sidebar captures at
1092 × 593 points. Prototype controls/inspector are excluded. Texture is off.
The main panel and terminal chrome are intentionally awaiting stage 4.

Fixture data belongs only to the isolated `matte-skin-stage3` automation app.
It uses a local temporary repository named Company-Cam-API, two workspace titles
from the supplied reference, and reference PR metadata through the existing
`report_pr` API. No original workspace/session database was copied or changed.

Reproduce with the tagged reload and `scripts/launch-tagged-automation.sh`, using
`BMUX_UI_TEST_TERMINAL_VIEWPORT_SETUP=1`, a temporary viewport output path, and
`BMUX_UI_TEST_TERMINAL_VIEWPORT_WINDOW_SIZE=1092x593`. Use the tag-bound helper for
workspace setup and `rpc debug.window.screenshot` for nominal-resolution PNGs.
Set `appearanceMode` only in the tagged bundle's defaults domain, never globally.

See the parent implementation record for actual checks, native adaptations,
stage ownership, and outstanding verification. The package tests render actual
SwiftUI control/surface pixels, but do not substitute for live keyboard tests.

## Observed differences and ownership

- The main panel, heading, primary tabs, terminal tab strip/toolbar, and terminal
  inset are still the existing presentation; these belong to stage 4.
- The app header remains above its target vertical position. Final header spacing
  and typography are stage 4 work. The sidebar's first card starts at approximately
  the target position; its exact height follows native font metrics.
- The fixture contains two workspaces, compared with the reference count of six.
  Both reference card titles and the PR metadata are present. The original prompt
  preview is unavailable in this fixture, so no preview content was fabricated.
- The author is a link when the existing model provides an owner URL. Existing PR
  text remains limited to two lines and may truncate differently with native font
  metrics. These links keep their existing actions.
- The live shell, terminal font, terminal colors, build badge, and native titlebar
  controls reflect the actual app. Terminal rendering has not been restyled.
- Texture is off; stage 5 adds the optional static pattern after material review.
- Native hover underlines are 1pt, explicitly approved by Brian. The 4pt selected
  square was also approved. Native edge/shadow rasterization and spread mapping
  use the already reviewed stage 2 approximation.

Build 748 passed final live checks: rapid search → Tab → Space opens the filter
with Terminal/Find visible; Return toggles once; Escape dismisses the popover
without closing Find. Clicking 3pt beyond the filter's right face activates it.
The two main PNGs are build 748 at 1092 × 593; the narrow PNG is build 743 at
802 × 593. Final source has no temporary focus probes.

The existing main panel remains dark even in the light capture. Titlebar icons,
window title and build badge retain the existing terminal-derived foreground and
are low contrast on the new light base; appearance integration for that header
belongs to stage 4. This is an outstanding whole-app accessibility gate, not an
accepted final contrast exception.

Native sidebar geometry: approximately 288pt width versus 290pt in the target;
first card begins at 182pt versus 183pt. The selected card is approximately 68pt
high versus 74pt, from the specified native type/spacing mapping. The second card
is shorter because the fixture lacks the original preview line. Target icon glyphs
and native SF Symbols have different optical shapes. The existing PR link's two-line
limit truncates earlier; no content/navigation behavior was redesigned to force
browser-identical line breaks.

Package/native-harness tests cover 42 and 14 tests respectively. Full app-host
compilation/execution remains CI coverage. Direct live hover, Reduce Motion system
toggling, VoiceOver and older-macOS verification are not claimed. See the parent
record for scope, warnings and the English/Japanese localization audit.

The post-handoff CI file-budget repair extracts the existing shell layout and
native focus lookup helpers without changing appearance or behavior. Its separate
compile-only tag `matte-skin-stage3-ci` (build 750) passed; the user's build 749 was
left running. The native harness now passes 18 tests (four additional field-editor
ownership cases), with the same 42 package tests. Existing captures remain valid
as stage 3 visual evidence; they were not retaken for this structural repair.
The file-budget gate passes. App-host CI is still required, and the separate
Xcode 26.3 typography type-inference failure remains unresolved in this repair.

The compiler compatibility follow-up makes the typography line-spacing local
explicitly nonoptional with unchanged arithmetic. Local Swift 6.3.3 passes the
42 package tests and Release compilation; actual Xcode 26.3 CI and app-host tests
remain the acceptance gate, so the compiler caveat is still open. Isolated
compile-only build 751 also passes; the user's running build 749 was untouched.
