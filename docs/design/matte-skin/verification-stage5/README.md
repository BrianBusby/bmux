# Stage 5: static texture verification

Optional texture is off by default. The existing material system remains usable
without it. The preview flag is scoped to the tagged app:

```sh
defaults write com.bmuxterm.app.debug.matte.skin.stage5 matteTextureEnabled -bool true
# false disables it. The running preview observes the change live.
```

No product controls, strings, navigation, or terminal rendering were added.
`WorkspaceReferenceAppShell` owns the flag, the shared texture scope retains the
loaded image, and surfaces consume the immutable environment value. Texture is
clipped between fill and edge/content, never painted on controls or terminal.

## Reproduce the assets

The checked-in SVG is offline source only. It copies the authoritative noise
filter: fractalNoise, frequency .9, two octaves, seed 7, stitchTiles, alpha 4R−1.6.
Its mean alpha is approximately .43 (the spec describes approximately .4).

```sh
rsvg-convert -w 128 -h 128 docs/design/matte-skin/micrograin.svg -o Packages/macOS/BmuxAppKitSupportUI/Sources/BmuxAppKitSupportUI/Resources/Matte/MatteNoise.png
rsvg-convert -w 256 -h 256 docs/design/matte-skin/micrograin.svg -o Packages/macOS/BmuxAppKitSupportUI/Sources/BmuxAppKitSupportUI/Resources/Matte/MatteNoise@2x.png
```

Both PNGs have eight-bit RGBA channels. The monochrome alpha image is tinted white
in graphite, black in porcelain. Opacity: base .07/.06, panel .035/.035, card and
overlay .03/.028. The logical tile is 128pt at both backing scales. Native rendered
pixel tests verify repeat, stationary output, clipping, theme tint direction,
reduced intensity on raised surfaces, and unchanged inset/opaque content pixels.

## Native captures and checks

Build 761: [comparison](comparison.html), [graphite on](graphite-on.png),
[graphite off](graphite-off.png), [porcelain on](porcelain-on.png),
[porcelain off](porcelain-off.png). All captures are 1092 × 593.
The flag was switched live off/on; native lifecycle loading and inherited
image propagation were observed on base, cards and panel. No restart is needed.
The empty terminal region (680 × 260 at350,285) is pixel-identical between on/off
captures in both appearances. No visible tile seams or content shift were found.

All 51 shared UI tests pass, including four texture tests with appearance/scale
cases. The tagged app build, source-length gate and Project Truth checks pass.
Independent review covers resource ownership, list boundaries, lifetime, rendering
scope and tests. No strings were added: the added Swift lines were audited for
UI text and the existing localization catalog parses. Existing native focus and
Bonsplit test results remain documented in stage4; full app-host CI is separate.

System Reduce Motion was enabled for live card selection and keyboard traversal;
the close control retained a visible focus outline. Zero-duration/lift policy is
also covered by the existing motion tests. VoiceOver was enabled for the same
pointer/Tab sequence; selected accessibility state and independent close/link
controls remain exposed. Spoken output and VoiceOver-cursor traversal could not
be established through the automation bridge, so a complete VoiceOver audit is
not claimed. Both system preferences were verified restored to their original
off state. Precise live hover/lift timing and older macOS remain unverified.

## Observed deviations and reasons

- Native noise uses the exact filter parameters rendered offline by librsvg;
  native raster sampling can differ from browser SVG filtering. Assets remain
  stationary, seamless, and use the specified tint and opacities.
- Main panel starts near314,90 instead of313,90; inset339,247 instead of336,246.
  Native layout rounding, 24pt padding, and font metrics account for the offsets.
- Native SF font rasterization/650–750 weight quantization and the stage2
  shadow/inner-edge approximation differ from CSS. No replacement values added.
- Native terminal font, cursor, prompt/output and wrapping remain unchanged;
  the reference uses static HTML. Horizontal terminal scrolling remains disabled
  by existing behavior, as recorded in the approved implementation plan.
- Native Bonsplit tab sizing/symbols/toolbar spacing preserve existing controls
  and minimum28pt hit targets; their glyph metrics differ from the prototype.
- macOS owns window corners, titlebar separator and capture/privacy badge in
  place of traffic lights. The build badge is the actual preview number.
- Two fixture workspaces replace the reference count6. The second has no prompt
  preview and is shorter. Existing two-line PR truncation and author link remain.
  Sidebar width is about288pt versus290pt; selected card is about74pt as approved.
- The approved selection square is4pt and native hovered-link underline1pt.
- Texture-off captures intentionally omit grain; layout, state and depth remain.

## Separate runtime caveat

An automated Cmd-W immediately after Settings theme switching routed into the
existing workspace-close path and closed the disposable preview. Logs show an
unresolved Settings event-window context; the routing and fallback predate the
matte branch unchanged. It has not been reproduced on a base build, so its cause
is not definitively attributed. The disposable fixture was restored. Texture
adds no shortcut/focus routing. Prefer the Settings close control during review;
this unrelated behavior was not patched in the visual-only stage.
