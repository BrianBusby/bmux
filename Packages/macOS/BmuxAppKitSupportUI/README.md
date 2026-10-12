# BmuxAppKitSupportUI

AppKit/SwiftUI support pieces for the macOS app, grouped by concern. Each top-level folder is
one concern: `WindowChrome/` (this is what the ContentView extraction added), plus the
`Matte/` design tokens and pre-existing `AboutTitlebarDebug/`, `Mouse/`, `Popover/`, and `Scroll/`. Most types are small
`Sendable` value types or narrow `@MainActor` controllers, so resolution logic can be unit
tested without a live window.

## WindowChrome/

"Window chrome" is everything bmux paints around and behind the terminal: the window
background, the native titlebar backdrop, the sidebar material, the hairline borders, and the
macOS 26 glass effect. There are many small types because the chrome is resolved in stages so
each stage stays testable: read current state into a `*Snapshot`, resolve it into a
`*Plan`/`*Policy`, then a `@MainActor` controller applies the plan to a real `NSWindow` and
returns a `*Result`. The value types are pure and unit-tested; the AppKit mutation lives only
in the controllers.

Files are grouped into subfolders by the chrome concern they serve. One major public type per
file, named after the type.

### Appearance/
Resolves the window's overall appearance for one render pass.
- `WindowTerminalAppearanceSnapshot.swift`: current terminal colors/opacity chrome must match.
- `WindowAppearanceUserSettingsSnapshot.swift`: the user settings that influence appearance.
- `WindowAppearanceResolver.swift`: combines those two snapshots into a `WindowAppearanceSnapshot`.
- `WindowAppearanceSnapshot.swift`: the resolved appearance value (colors, opacity, rendering-mode helpers) for one pass.
- `WindowRootBackdropResolution.swift`: the root-backdrop result returned when a pane supplies its own color.

### Backdrop/
The window background fill and how it is applied to AppKit.
- `WindowBackdropRole.swift`: which chrome surface a backdrop targets (root, titlebar, etc.).
- `WindowBackdropPolicy.swift`: the rendering policy chosen for a surface.
- `WindowBackdropHostingPhase.swift`: which AppKit hosting strategy is used.
- `WindowBackdropGlassPlan.swift`: tint and glass style when the backdrop uses native glass.
- `WindowBackdropPlan.swift`: the full set of `NSWindow` mutations for a resolved backdrop.
- `WindowBackdropControllerDependencies.swift`: protocol of app-provided side effects the controller needs (injected).
- `WindowBackdropController.swift`: `@MainActor` type that applies a plan/snapshot to an `NSWindow`.
- `WindowBackdropApplicationResult.swift`: what changed after the controller ran.
- `WindowBackdropLayer.swift`: SwiftUI view that renders the resolved backdrop for one role.
- `LayerBackedBackdropColor.swift`: internal non-hit-testing AppKit color fill for transparent windows.

### Glass/
The macOS 26 `NSGlassEffectView` window glass, with an `NSVisualEffectView` fallback.
- `WindowGlassEffectStyle.swift`: the native glass style applied when glass is available.
- `WindowGlassSettingsSnapshot.swift`: persisted plus terminal-driven settings for the glass root.
- `WindowGlassEffectManaging.swift`: protocol seam for applying and inspecting the glass hierarchy.
- `WindowGlassEffect.swift`: `@MainActor` implementation of that seam (native glass + fallback).
- `WindowGlassEffect+Views.swift`: internal AppKit view helpers used by `WindowGlassEffect`.
- `GhosttyBackgroundBlur+WindowGlassEffectStyle.swift`: maps a Ghostty blur mode to a glass style.

### Titlebar/
The native AppKit titlebar.
- `NativeTitlebarBackdropCoordinator.swift`: `@MainActor` type that hides/restores the native titlebar backdrop.
- `TitlebarLeadingInsetReader.swift`: SwiftUI reader for the inset needed to clear traffic lights and accessories.

### Border/
The hairline borders between chrome surfaces.
- `WindowChromeBorderOrientation.swift`: orientation of a one-pixel border.
- `WindowChromeBorder.swift`: SwiftUI one-pixel border derived from the chrome background color.

### Color/
Color math shared across chrome.
- `WindowChromeColorResolver.swift`: separator color, compositing, and readable-scheme math.

### Sidebar/
The sidebar backdrop material and its persisted options.
- `SidebarBackdropSettingsSnapshot.swift`: persisted sidebar backdrop settings as a value.
- `SidebarBackdropMaterialPolicy.swift`: the resolved AppKit material settings for the sidebar.
- `SidebarVisualEffectBackground.swift`: internal wrapper view (native glass, falls back to visual effect).
- `WindowChromeSidebarPresetOption.swift`: `sidebarPreset` setting values.
- `WindowChromeSidebarMaterialOption.swift`: `sidebarMaterial` setting values.
- `WindowChromeSidebarBlendModeOption.swift`: `sidebarBlendMode` setting values.
- `WindowChromeSidebarStateOption.swift`: `sidebarState` setting values.
- `WindowChromeSidebarTintDefaults.swift`: legacy default sidebar tint constants.

### TerminalSurface/
How an individual terminal surface paints its own background.
- `GhosttyTerminalBackdropRenderingMode.swift`: who owns the terminal backdrop pixels.
- `TerminalSurfaceBackgroundFillOwner.swift`: which layer paints a surface background.
- `TerminalSurfaceBackgroundFillPlan.swift`: the resolved fill decision for one surface.

### Overlay/
Where window-level overlays are inserted in the AppKit hierarchy.
- `WindowContentOverlayInstallationTarget.swift`: the container/reference pair to install into.
- `WindowContentOverlayTargetResolver.swift`: resolves the insertion point for a window.

## Matte/

`MatteTheme` owns the graphite and porcelain design values. It receives the effective
SwiftUI color scheme or AppKit appearance after the app's existing appearance override
resolves. It does not read preferences, apply surfaces, or configure the terminal.
Supporting immutable types describe semantic colors, typography, layout, motion,
texture, and shadow ingredients; all token literals live in `MatteTheme.swift`.

```swift
let theme = MatteTheme(colorScheme: .dark)
let panelColor = Color(nsColor: theme.color(.panel))
let motion = theme.motion(reduceMotion: true)
let dynamicPanelColor = MatteTheme.dynamicColor(.panel)
```

Tests inject `.dark`/`.light`, explicit `NSAppearance` values, and the Reduce Motion
Boolean without launching the app or touching user defaults. `MatteThemeTests` exercises
dynamic color reuse across appearances, text/focus contrast, opaque surface colors,
card-lift eligibility, and shadow semantics. Run the package suite with:

```sh
swift test --package-path Packages/macOS/BmuxAppKitSupportUI
```

Reference CSS font weights and shadow blur/spread are preserved as data for the native
surface renderer to map. Terminal typography is reference-only; the token API does not
change the renderer or the user's terminal font.

### Native surfaces

Apply the semantic background to content whose layout is already established:

```swift
content
    .padding(theme.layout.cardPadding)
    .opacity(isEnabled ? 1 : theme.layout.disabledOpacity)
    .matteSurface(.card, theme: theme, state: MatteSurfaceState(
        isSelected: isSelected, isHovered: isHovered, isPressed: isPressed,
        isFocused: isFocused, isEnabled: isEnabled
    ))
```

`View.matteSurface(_:theme:state:)` accepts `.base`, `.card`, `.panel`, `.inset`,
and `.overlay`. It only decorates the background; content keeps its identity,
layout, hit testing, accessibility, clipping policy, and focus ownership. The
modifier adds no padding, gestures, selection state, preferences, animations,
hover lift, textures, or materials. All decorations disable hit testing and are
hidden from accessibility. Interaction owners supply immutable values. No
observable stores cross into these views and no per-frame work is scheduled.

The base is a flat continuous fill. Cards and the panel rest at level 1; hovered
cards rise visually to level 2; selected cards retain a ring and tinted fill at
level 2, including on hover. Overlays use level 3. Each raised surface has an
outer hairline (selection ring for selected cards), directional inner edges,
one contact shadow and one ambient shadow. A pressed card keeps its resting
contact shadow and drops the ambient shadow; selected pressed cards retain the
selection ring and tint. This is distinct from pressed *control* inset styling,
which is outside this API. Disabled cards suppress hover, press, and focus,
retain selection semantics, and use resting elevation. Inactive cards use the
resting state; foreground contrast remains the caller's responsibility.

Disabled decoration is composited once before applying the token opacity so
shadow casters do not become visible through the surface. The modifier never
dims content: the example applies disabled content opacity **before** the surface
modifier. Do not apply disabled opacity to the composed result a second time.
An enabled surface remains opaque. A disabled surface is intentionally translucent
according to the reference card opacity. Keyboard focus draws the token's
2-point outline with a 2-point gap outside the surface without altering layout.

The renderer uses native circular `RoundedRectangle` geometry with token radii.
CSS shadow blur maps to SwiftUI shadow radius as `blur / 2`, an approximation of
the reference blur extent. The contact and ambient shadows use independent
native `.shadow` layers. Negative spread contracts only that layer's caster
using `inset(by: -spread)`; the contact shadow retains the full surface edge.
The opaque surface fill covers both caster interiors.

Inner edges use `strokeBorder` gradients from upper left to lower right. Raised
surfaces interpolate the reference highlight and shade over their token-derived
edge width. The terminal inset approximates the reference inner blur with
concentric strokes, each one contour-token wide, fading linearly inward across
`max(abs(offsetX), abs(offsetY), abs(spread)) + blur / 2`. Its lower-right highlight
and inner contour use their own shadow tokens. This is a lightweight native
approximation, not pixel-identical CSS inset-shadow rasterization; it preserves
a soft recess without a broad flat bevel. It casts no outward shadow.

Surfaces introduce no transition, so Reduce Motion does not need a separate
rendering path here. A later interaction owner that adds animation or hover lift
must use `theme.motion(reduceMotion:)` and `theme.cardLift(...)` with the effective
accessibility preference.

`MatteSurfaceTests` renders the real SwiftUI modifier with `ImageRenderer` in
both appearances, checking opaque interiors against plain token fills, retained
size, lighting direction, inset falloff, separated focus outline, and disabled
compositing without dimming content. Pure state-resolution tests exercise
selection/hover/press/disable precedence. Live accessibility navigation and
mouse/keyboard routing remain integration checks when these backgrounds are
adopted by app controls. The surface API adds no user-visible strings; caller
content must use the app's localized strings.

### Native controls

`MatteButtonStyle` retains SwiftUI button activation while applying raised, flat,
or link chrome. It owns only pointer feedback, reads native press/focus/enabled
state, and respects Reduce Motion. Labels supply their own layout with the token
minimum hit size. Control shadows use the same native blur conversion and inner
edge renderer as surfaces. Disabled controls composite once before dimming.
`matteField(theme:isFocused:)` adds recessed field decoration; callers keep text
bindings and focus ownership. `matteTypography(_:theme:)` maps semantic metrics
to system fonts without changing terminal fonts.

```swift
MatteButton(hitExpansion: theme.layout.invisibleHitExpansion, action: filter) {
    Image(systemName: "line.3.horizontal.decrease")
        .frame(width: theme.layout.raisedHitSize, height: theme.layout.raisedHitSize)
}
.buttonStyle(MatteButtonStyle(theme: theme))
```

The workspace-card owner uses a full-card native selection button behind sibling
links and close buttons. No nested controls or parent tap gesture participate in
link routing. Its snapshot and callbacks carry all workspace state across the
list boundary; the package has no workspace or navigation owner.

Disabled cards own their content opacity. Pass `dimsWhenDisabled: false` to nested
button styles when that enclosing owner has already dimmed them; individually
disabled controls in an enabled card retain the default control dimming. Render
coverage checks both cases. Multiline card titles subtract measured native font
line metrics from the requested baseline, rather than adding the entire reference
leading to the native line height.

The reference hover underline token remains 2 points. The approved native
adaptation uses SwiftUI's 1-point underline to retain its native multiline text
layout; it does not claim to render that token's thickness. No custom text renderer
is installed. The selected-card square is the user-approved 4-point layout token.

`MatteButton` owns transient native keyboard focus and forwards Space, Return, and
pointer activation to one supplied action. Its internal focus Boolean reaches the
visual style through a local environment value; it carries no model or service.
An optional focus callback lets the containing card reveal its close control.
The button checks the enabled environment for all activation paths. Selected
raised controls receive immutable `isSelected` feedback and retain their semantic
ring and tint during press. Flat and raised controls expand their input shape by
the 4-point token without changing visible geometry. The card selection target
itself remains confined to the card.


FocusState drives only local decoration and close-button visibility. The package
never claims first responder or defines workspace/terminal focus policy. The app
hosts the rail and its filter popover in dedicated native hosting views and
registers their weak identities with its existing window focus coordinator.
The existing synchronous AppKit responder-change hook resolves membership at the
focus transition, before SwiftUI renders; per-key policy checks compare exact
responder and window identities without walking view trees. Host teardown and
popover parenting changes revoke ownership. Reattaching a popover requires a
fresh native focus transition. The app forwards inherited environment values
across the hosting boundary and updates each stable host's root view in place.
Modified Space/Return events remain available to the app's shortcut routing.

For controls using `MatteButtonStyle`, pass the token `hitExpansion` to `MatteButton`:
the style adds invisible padding to native bounds after painting its chrome, and the
wrapper compensates outside the button to preserve visible geometry and layout.
Standalone styled Buttons default to no expansion. Whole-card selection retains
zero expansion so its target does not extend beyond the card.
