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
