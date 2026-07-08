# BMUX Reorganization Inventory

This inventory records the first conservative repo-organization pass. The goal
is to reduce root noise while keeping the bmux app buildable and preserving
uncertain material.

## Top-Level Classification

| Path | Classification | First-pass action |
| --- | --- | --- |
| `Sources/` | Core macOS app source | Kept in place; Xcode references make this a later package/file split. |
| `Resources/` | Core app resources and bundled assets | Kept in place. |
| `CLI/` | Core CLI source | Kept in place; needs later decomposition before any directory move. |
| `Packages/` | Shared/macOS/iOS Swift packages | Kept in place. |
| `bmux.xcodeproj`, `bmux.xcworkspace` | Xcode build metadata | Kept in place. |
| `bmuxTests/`, `bmuxUITests/`, `tests/`, `tests_v2/` | Tests | Kept in place. |
| `webviews/` | Embedded webview bundles | Kept in place. |
| `daemon/remote/` | Remote daemon service | Kept in place. |
| `web/` | Web/backend product infrastructure | Kept in place; active package with scripts and dependencies. |
| `ios/` | iOS app/workspace | Kept in place; active code references presence and pairing work. |
| `workers/presence/` | Active Cloudflare presence service | Kept in place; referenced by iOS, docs, and packages. |
| `Examples/` | Active sidebar extension/custom sidebar examples | Kept in place; referenced by docs, scripts, tests, and Xcode metadata. |
| `design/` | Design assets | Kept in place; referenced by scripts. |
| `plans/` | Active design history | Kept in place; referenced by worker comments and iOS plans. |
| `experiments/` | Spike code tied to plans/docs | Kept in place; referenced by iOS/Iroh docs. |
| `Prototypes/` | Standalone prototype projects | Moved to `archive/Prototypes/`. |
| `dogfood/` | Manual dogfood fixtures | Moved to `archive/dogfood-fixtures/`. |
| `README.*.md` translations | Documentation translations | Moved to `docs/translations/`. |
| `ghostty/`, `GhosttyKit.xcframework`, `vendor/` | Submodule/vendor artifacts | Kept in place. |
| `.github/`, scripts, release/homebrew metadata | Automation/release infrastructure | Kept in place. |

## Largest Hand-Maintained Files

Measured with `wc -l` over source/test/config/doc files:

| File | Lines | Notes |
| --- | ---: | --- |
| `CLI/bmux.swift` | 34,427 | Highest-priority CLI decomposition target. |
| `Sources/AppDelegate.swift` | 18,487 | App lifecycle/window/menu/socket responsibilities are mixed. |
| `Sources/ContentView.swift` | 16,630 | Workspace/sidebar/titlebar/view composition responsibilities are mixed. |
| `Sources/TerminalController.swift` | 14,224 | Socket/control/mobile routing responsibilities are mixed. |
| `Sources/Workspace.swift` | 12,965 | Workspace model, panel lifecycle, and UI-adjacent behavior are mixed. |
| `Sources/GhosttyTerminalView.swift` | 12,214 | Terminal rendering/input/search boundaries need careful extraction. |
| `Sources/Panels/BrowserPanel.swift` | 11,671 | Browser runtime and panel orchestration are mixed. |
| `Sources/Panels/BrowserPanelView.swift` | 8,032 | Browser UI surface is large enough to split by controls/overlays. |
| `Sources/BmuxConfig.swift` | 3,443 | Config schema, decoding, resolution, and issue reporting should split. |
| `Sources/Update/UpdateTitlebarAccessory.swift` | 3,124 | Titlebar UI, layout metrics, AppKit accessory controller should split. |

## Generated, Vendored, Or Heavy Material

- `ghostty/` is a submodule and intentionally large.
- `GhosttyKit.xcframework/` is a prebuilt framework.
- `vendor/` contains vendored third-party material.
- `bun.lock` and package-local lockfiles are retained because active package
  managers depend on them.
- `bmux.xcodeproj/project.pbxproj` is large but expected for an Xcode project.

## Deferred Moves

The aspirational BMUX shape is still:

```text
apps/
  macos/
  cli/
  webviews/
services/
  remote-daemon/
  web/
packages/
docs/
design/
scripts/
tests/
archive/
```

This pass intentionally does not move compile-critical app source into that
shape. The next safe step is to split large files behind existing Xcode paths or
extract leaf Swift packages first, then move directory roots once build metadata
can be updated with low conflict risk.
