# Stage 4 verification

Main panel, native primary tabs, terminal tab strip/toolbar, terminal inset,
window title and header now consume the shared matte theme. Texture is off.
The [comparison](comparison.html) places each target app crop beside the native
1092 × 593 captures from build 756, including the corrected selected-card header.
The [selected-card comparison](selected-card-comparison.html) isolates that detail. Prototype controls and inspection tooling are excluded.

## Observed deviations and reasons

- Main panel begins at approximately (314,90), versus (313,90) in the target;
  inset begins at (339,247), versus (336,246). Exact native 24pt padding, layout
  rounding and font metrics account for the remaining small offsets.
- Native SF rasterization differs from the browser screenshot. Intermediate
  650/750 weights quantize on this macOS; browser equivalence is unverified.
  The card’s specified 600 weight resolves to native semibold.
- Terminal font, cursor, shell output, ANSI colors and wrapping remain native. The
  reference uses an HTML text fixture. Existing horizontal terminal scrolling is
  disabled; adding it would change behavior and is outside this approved skin.
- Bonsplit retains its existing tab sizing and toolbar spacing around the new
  minimum 28pt targets. Its native symbols and close glyph differ optically from
  the prototype; actions, drag behavior and keyboard shortcuts remain intact.
- macOS owns the window corners, recording/privacy indicator replacing traffic
  lights during automation, and window-frame treatment. These are not drawn by
  the skin. The build number reflects the actual preview.
- Two fixture workspaces are shown rather than the reference count of six. The
  second card lacks the original prompt preview, so it is shorter. Native PR
  text retains its existing two-line limit; the author remains its existing link.
  The selected card now measures about 74pt, matching the reference after its
  compressed header was corrected to 20pt. The sidebar is about 288pt versus 290pt.
- Native negative-spread shadow/inner-edge rasterization uses the reviewed stage
  2 approximation. Native hovered-link underline is 1pt and selection mark 4pt,
  both explicitly approved.
- Texture is intentionally absent until stage 5.

## Pointer-selection follow-up

Build 759 reproduces and fixes the two-card discrepancy: a pointer-selected Chat
workspace keeps the same thin selection ring as a Terminal workspace, even when
native focus remains on the card. The extra outline appears for keyboard input.
Tab/Shift-Tab, Return and clicking the already-focused card were checked live.
[Graphite selected second card](graphite-selected-card-focus.png) and
[porcelain selected second card](porcelain-selected-card-focus.png) use the same
1092 × 593 window. This corrects state presentation without changing geometry,
focus ownership, navigation or actions. Existing deviations listed above remain.

Links no longer use the flat-icon hover wash. Brian approved retaining their
existing background while pressed; unpressed captures are unchanged by that
restoration. Tests verify link hover/pressed pixels and outline-only changes in
both appearances. Shared UI now passes 47 tests; native focus harness passes 19,
including the actual environment value inside the hosting boundary and preserved
local state. CI now explicitly runs the shared UI package. No strings changed.

## Runtime evidence

Build 756 passed the corrected card’s dark/light visual check at 1092 × 593,
search → filter → selected-card keyboard traversal, and the separate close
control. Closing the disposable selected workspace removed only that workspace;
the remaining workspace stayed usable. The comparison fixture was then restored.
Keyboard focus adds its specified outline without shifting or resizing the card.
The 28pt close target is retained in source; pointer-edge hit coverage is not claimed.
No user-facing strings changed in this geometry follow-up.

Build 753 passed native keyboard traversal from search/filter through card
controls to Chat/Terminal/Session, selected-button focus retention, Session
activation, terminal Find layering, real shell input/output, split-right and
Cmd-W close, new-terminal creation and separate pointer-close with its existing
confirmation, live light→dark appearance change, 802 × 593 long-title layout, and
fullscreen entry/exit. The narrow capture records this build. The automation accessibility close action was unavailable, but clicking the
visible close control opened its existing confirmation and closed only the
disposable tab; the selected workspace and other terminal remained intact.

The first porcelain Chat preview exposed pale text on the light panel. The fix
uses only the existing web-renderer theme seam, scoped to the shell caller, with
no HTML, content, action or lifecycle changes. Final fresh-build verification is
recorded in the implementation plan.

Focused checks: 45 shared-UI tests, 175 Bonsplit tests, and 18 native focus-harness
tests. Shared tests include rendered appearance/state pixels and magnified text.
Actual app-host compilation/execution remains a separate CI gate. Direct live
VoiceOver, pointer-hover and system Reduce Motion toggling, and older-macOS
runtime checks are not claimed. Earlier stage 3 scrolling-sidebar coverage
remains applicable; state/motion behavior also has source and render coverage.

Localization audit covers moved/reused titlebar and tab keys in English/Japanese.
The affected build-badge Japanese translation was corrected to “ビルド %@” with
placeholder parity. Existing untranslated vendor accessibility glyph names were
not introduced by this patch; a whole-vendor translation audit is not claimed.

Reproduce using the tagged reload and `scripts/launch-tagged-automation.sh`,
`BMUX_UI_TEST_TERMINAL_VIEWPORT_SETUP=1`, a temporary viewport output path, and
`BMUX_UI_TEST_TERMINAL_VIEWPORT_WINDOW_SIZE=1092x593`. Use the tag-bound CLI for
fixture setup and `rpc debug.window.screenshot` for nominal-resolution PNGs.
Only the isolated tag's settings and disposable workspaces were changed.
