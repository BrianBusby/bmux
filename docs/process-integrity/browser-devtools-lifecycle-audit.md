# Browser And DevTools Lifecycle Audit

## Scope

This audit covers the Process Integrity slice `app_runtime_browser_devtools_lifecycle_migration`. It follows the deterministic app-runtime composition work and the mobile-host/presence lifecycle migration. The boundary is intentionally app-scoped Browser/DevTools lifecycle ownership: system proxy observation, browser address/focus observers, app-level Web Inspector teardown, hidden prewarmed WebView drain, and browser profile save drain. It does not move per-window or per-panel browser objects away from their natural owners.

Evidence inspected for this slice included `Sources/AppDelegate.swift`, `Sources/App/BmuxAppRuntime*.swift`, `Sources/Panels/BrowserSystemProxyWatcher.swift`, `Sources/Panels/*Browser*.swift`, `Sources/KeyboardShortcutContext.swift`, `Packages/macOS/BmuxBrowser`, browser-related app tests in `bmuxTests`, and browser package tests under `Packages/macOS/BmuxBrowser/Tests`.

## Lifecycle Before This Slice

`BmuxAppRuntimeComposition` already constructed composition-owned runtime services for Work Provenance and mobile-host/presence. Browser/DevTools work still escaped that boundary:

- `AppDelegate.applicationDidFinishLaunching` directly started `BrowserSystemProxyWatcher.shared`.
- `AppDelegate` directly owned NotificationCenter observer tokens for address-bar focus, address-bar blur, and browser WebView first-responder notifications.
- `MainWindowController.windowShouldClose` directly called `WebViewInspectorTeardown.closeAllInspectors(in:)` for the closing window.
- Quit confirmation and `applicationWillTerminate` directly called all-window inspector teardown through `NSApp.windows`.
- `applicationWillTerminate` directly flushed `BrowserProfileStore.shared`.
- `BrowserPrewarmedWebViewPool.shared` remained user-action driven, with shutdown reachable only through local pool behavior.

The current model preserved product behavior but did not provide one deterministic answer for which browser services were app-scoped, when they became ready, how tests prevented side effects, or which entrypoint was allowed to stop them.

## Service Inventory

| Component | Previous owner | Scope | Side effects | Readiness and failure | Teardown before this slice |
| --- | --- | --- | --- | --- | --- |
| `BrowserSystemProxyWatcher.shared` | `AppDelegate.applicationDidFinishLaunching` | App-scoped | Opens `SCDynamicStore`, registers proxy keys, dispatches on main queue, posts `.browserSystemProxySettingsDidChange` | Implicit; startup returned no result | `stopObserving()` existed but was not app-runtime owned |
| Browser address/focus NotificationCenter observers | `AppDelegate` stored tokens | App-scoped observation over panel-local state | Observes `.browserDidFocusAddressBar`, `.browserDidBlurAddressBar`, `.browserDidBecomeFirstResponderWebView`; suppresses WebView focus churn and syncs omnibar repeat state | Implicit; duplicate prevention via token nil checks | No composition-owned shutdown path |
| App-level Web Inspector teardown | `AppDelegate` and `MainWindowController` | App/window scoped | Closes detached/attached inspectors for terminating or closing windows | Local best effort | Repeated from termination and window close paths |
| `BrowserProfileStore.shared.flushPendingSaves()` | `AppDelegate.applicationWillTerminate` | App-scoped drain of panel-owned profile state | Flushes pending profile persistence writes | No readiness concept | Direct AppDelegate call |
| `BrowserPrewarmedWebViewPool.shared` | User-action/hover call sites and pool singleton | App-scoped cache with local use sites | Creates hidden nonvisible WebViews on demand, can retain callbacks/tasks | No startup readiness concept | Pool-local `discard`, not app-runtime shutdown owned |
| `BrowserPanel`, `BmuxWebView`, popups, DevTools visibility controller | Workspace/panel/window objects | Panel/window scoped | Creates WebViews, profiles, WebKit configuration, developer tools sessions, popup windows, navigation/focus state | Panel-local behavior | Panel `close`, `deinit`, popup close, and per-panel DevTools lifecycle remain local |
| Keyboard shortcuts and `KeyboardShortcutContext` | AppDelegate/action routing | Functional and focused-window scoped | Resolve the focused browser panel and invoke panel actions such as navigation or DevTools toggles | Local action success/failure | No app-scoped ownership intended |

## Selected Migration Boundary

The app-runtime composition layer now owns the migrated app-scoped service family through `BrowserDevToolsRuntimeService`. `BmuxAppRuntimeComposition` is the only production constructor. `BmuxAppRuntimeConfiguration` selects `browserAndDevTools` in production and leaves it disabled in default XCTest composition. `BmuxAppRuntimeServices` is the only start/stop entrypoint for the migrated service.

The runtime dependencies are injected through `BrowserDevToolsRuntimeServiceDependencies`. Production dependencies wrap the existing singleton-compatible surfaces without making those singletons lifecycle owners: `BrowserSystemProxyWatcher.shared`, NotificationCenter observer registration/removal, `WebViewInspectorTeardown`, `BrowserPrewarmedWebViewPool.shared.discard`, and `BrowserProfileStore.shared.flushPendingSaves`.

`AppDelegate` now requests runtime startup and supplies handlers for the existing UI effects. Main-window close routes inspector teardown through `BmuxAppRuntimeServices.closeBrowserWebInspectors(in:)`. App termination routes app-level inspector close, watcher stop, observer removal, hidden-WebView drain, and profile flush through `BmuxAppRuntimeServices.stopBrowserAndDevToolsForAppTermination()` and the existing aggregate `stop()` path.

## Lifecycle State

The migrated Browser/DevTools runtime exposes deterministic state:

- `disabled(reason:)`: composition or dependency policy disabled the service.
- `notStarted`: production/opt-in service is constructed but not started.
- `starting`: startup is running synchronously on the main actor.
- `ready`: required browser runtime validation, system proxy observation, and focus observers are available.
- `degraded(reason:)`: required browser behavior remains usable but a nonfatal app-scoped companion, currently system proxy observation, failed or degraded.
- `failed(reason:)`: required runtime validation failed before app-scoped resources were acquired.
- `stopping`: teardown is releasing owned resources.
- `stopped`: no runtime-owned watcher, observer, or shutdown resource drain remains active.

Readiness is directly observable through `BmuxAppRuntimeServices.browserDevToolsLifecycleState`; no sleep or elapsed-duration assertion is needed.

## Shutdown Guarantees

Runtime-owned shutdown is idempotent. Repeated start calls do not install duplicate proxy watchers or NotificationCenter observers. Repeated stop calls do not duplicate inspector close, hidden-WebView discard, profile flush, observer removal, or system-proxy stop. Shutdown before readiness and after partial failure is safe and observable. Fatal preflight failure does not mark runtime work active and therefore does not drain resources it never acquired.

Window and panel owners keep their local close behavior. Popup windows still close their own inspectors because they are short-lived window-local owners, not app-runtime startup services. `BrowserPanel.close` and `deinit` still tear down panel WebViews, portal bindings, WebAuthn state, download/auth coordinators, popup references, local observers, and panel DevTools timers/tasks.

## Test Behavior

Default app-host XCTest composition disables `browserAndDevTools`, so incidental `AppDelegate` or runtime service construction does not start the real system proxy watcher, register real browser focus/address observers, start inspectors, open real profiles, or drain user browser state. Focused tests opt in with `BmuxAppRuntimeConfiguration.test(enabledCapabilities: [.browserAndDevTools], ...)` and injected fake dependencies.

`BrowserDevToolsRuntimeCompositionTests` covers default disablement, production enablement, injected opt-in startup, observable ready/failed/degraded states, duplicate-start protection, deterministic shutdown, restart behavior, inspector/focus routing through `BmuxAppRuntimeServices`, and a production-configuration path that still uses fake dependencies.

## Boundary Guard

`scripts/check-app-runtime-composition-boundary.sh` now rejects production source that constructs the Browser/DevTools runtime outside `BmuxAppRuntimeComposition`, starts or stops it outside `BmuxAppRuntimeServices`, starts or stops `BrowserSystemProxyWatcher.shared` outside runtime dependencies, directly performs app-level `NSApp.windows` Web Inspector teardown outside runtime dependencies, or drains profile/prewarmed WebView resources outside runtime dependencies.

The guard intentionally allows panel/window-local Browser and DevTools behavior, including popup-window inspector close and legitimate per-panel WebView/profile construction.

## Retained Compatibility And Removal Conditions

`BrowserSystemProxyWatcher.shared`, `BrowserProfileStore.shared`, and `BrowserPrewarmedWebViewPool.shared` remain as compatibility surfaces, but their app-scoped lifecycle use is non-owning and wrapped by runtime dependencies. They can be removed or narrowed only after panel/profile/prewarm call sites have dedicated contracts that do not require shared access.

`AppDelegate` keeps a private fallback address-bar focus cache for manual AppDelegate tests or helper instances that do not build full runtime composition. When every AppDelegate construction path used by tests installs explicit runtime services, that fallback can be removed.

## Deferred Browser/DevTools Work

This slice deliberately leaves these areas out of scope:

- Per-panel WebView creation, profile selection, history, navigation, and popup behavior.
- Panel-local DevTools visibility, docking, console/show-inspector actions, timers, and inspector frontend ownership.
- Keyboard shortcut feature behavior beyond routing to the canonical runtime-owned focus/teardown state.
- Sidebar Git/PR observation, notification/push registration, menu-bar lifecycle, and residual app-host services captured as later Project Truth slices.
- Broader singleton retirement for browser profiles or WebView pools unless future slices establish a separate replacement contract.
