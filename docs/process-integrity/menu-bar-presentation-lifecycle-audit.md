# Menu-Bar and Presentation Preference Lifecycle Audit

## Scope

Project Truth slice: `app_runtime_menu_bar_presentation_lifecycle_migration`.

This audit covers the app-scoped lifecycle for menu-bar visibility, menu-bar
extra creation/removal, Dock versus menu-bar-only activation policy, and
presentation-related preference observation. It is bounded to startup
reconciliation, UserDefaults/settings-triggered reconciliation, global-search
menu-bar anchoring, Sleepy Mode menu refresh, and teardown.

This slice does not migrate updater startup, global search startup, system-wide
hotkeys, feature flags, renderer realization, hibernation, session snapshots,
window-local titlebar/minimal-mode rendering, or the residual app-host audit.

Evidence inspected includes `Sources/AppDelegate.swift`, runtime composition
files in `Sources/App/`, `Sources/App/MenuBarExtraController.swift`,
`Sources/HostSettingsActions.swift`, command-palette setting toggles, and
workspace presentation-mode observers.

## Lifecycle Before This Slice

The app-scoped path was split across AppDelegate, settings host actions, and
value helpers. `bmuxApp.init()` built composition and services, but no
capability selected this behavior. `AppDelegate.applicationDidFinishLaunching`
normalized `menuBarOnly`, applied activation policy, installed a
`UserDefaults.didChangeNotification` observer, reconciled menu-bar visibility,
and retained the persistent menu-bar extra, transient global-search menu-bar
extra, visibility observer token, and last install decision.

Settings wrote `app.menuBarOnly` through `SettingsHostActions.setMenuBarOnly`,
which directly mutated `MenuBarOnlySettings`. The AppDelegate defaults observer
later reconciled activation policy and menu-bar visibility as a side effect.
`showMenuBarExtra` remained a direct defaults-backed setting, while
menu-bar-only mode forced status-item installation even when that preference was
off. Presentation mode was observed by per-window SwiftUI through `@AppStorage`;
there was no app-runtime snapshot or lifecycle state for that preference.

## Producer and Consumer Inventory

| Responsibility | Previous owner | Trigger | Teardown | Migration decision |
| --- | --- | --- | --- | --- |
| `menuBarOnly` normalization | `AppDelegate` / `MenuBarOnlySettings` | launch and reads | none | runtime dependency normalizes before every reconciliation |
| `menuBarOnly` writes | `HostSettingsActions` | Settings toggle | none | settings forwards to runtime, runtime writes and reconciles |
| `showMenuBarExtra` reads | `AppDelegate` / helpers | launch and defaults observer | observer retained by AppDelegate | runtime snapshots the value |
| status-item install/remove | `AppDelegate` | launch, defaults change, hotkey | partial remove in visibility reconciliation | runtime owns persistent and transient controllers |
| activation policy | `AppDelegate` / helper API | launch and defaults change | none | runtime owns injected `NSApplication` mutation seam |
| Sleepy Mode menu refresh | `AppDelegate` callback | status item creation | not cleared on app-runtime stop | runtime installs and clears callback with persistent controller |
| global-search hotkey anchor | `AppDelegate` | global hotkey | transient status item removed on dismiss | AppDelegate forwards hotkey to runtime |
| notification/font menu updates | `MenuBarExtraController` | controller construction | `removeFromMenuBar()` | controller remains UI adapter owned by runtime |
| workspace presentation mode | per-window SwiftUI | `@AppStorage` updates | view lifetime | runtime snapshots for app-level observation contract; window rendering remains local |

## Observer and Callback Inventory

- AppDelegate previously owned a `UserDefaults.didChangeNotification` observer
  and scheduled main-actor reconciliation work from that callback.
- `MenuBarExtraController` owns its notification-menu snapshot Combine
  subscription and `GlobalFontMagnification.didChangeNotification` observer;
  both still tear down through `removeFromMenuBar()`.
- `SleepyModeController.shared.onStateChange` refreshes menu contents and is
  now installed and cleared by the runtime dependency.
- `WorkspacePresentationModeChangeObserver` remains per-window SwiftUI state,
  outside the app-scoped lifecycle owner.
- There is no timer for this lifecycle. Stale callbacks are bounded to defaults
  observer callbacks and transient status-item dismissal handlers.

## Invalid or Partial States

- XCTest and partial runtimes depended on scattered AppDelegate guards instead
  of explicit capability selection.
- Settings could write `menuBarOnly` when no lifecycle owner was started to
  apply or isolate process mutations.
- Readiness, failed activation-policy application, and degradation were not
  observable.
- AppDelegate did not remove the defaults observer or clear the Sleepy Mode
  callback during app-runtime stop.
- Transient global-search status items could outlive visibility changes unless
  AppDelegate happened to clear them.
- The unused `MenuBarOnlySettings.applyActivationPolicy` helper exposed a
  direct activation-policy mutation path outside the runtime boundary.

## Target Owner and Boundary

The app-runtime owner is `MenuBarPresentationRuntimeService`, constructed only
by `BmuxAppRuntimeComposition` and reached only through
`BmuxAppRuntimeServices`. Production composition enables
`.menuBarPresentationLifecycle`; default XCTest and partial process
composition leave it disabled unless a focused test opts in.

`AppDelegate` remains the required AppKit adapter. It supplies
`MenuBarPresentationRuntimeUIActions`, forwards the global-search hotkey, and
offers menu callbacks for main-window display, notifications, task manager,
preferences, updates, Sleepy Mode, and quit. It no longer retains lifecycle
state, observers, or status-item ownership.

`HostSettingsActions` remains the Settings package adapter. Its
`setMenuBarOnly(_:)` method now forwards into the runtime service injected by
composition. If the capability is disabled or no runtime service is bound, it
returns `false` and does not mutate real process presentation state.

`MenuBarExtraController` remains a UI rendering/controller adapter for a
single status item. It still owns menu construction, notification snapshot
observation, font-change observation, and callback wiring for that status item,
but its lifetime is owned by the runtime service.

## Implemented Lifecycle Contract

`MenuBarPresentationRuntimeLifecycleState` exposes:

- `disabled(reason:)` for XCTest, previews, CLI processes, and partial runtimes;
- `notStarted` before startup when enabled;
- `starting` during first reconciliation;
- `ready` when preferences and process presentation were reconciled;
- `degraded(reason:)` when bounded operations fail but observers/controllers
  can keep reconciling, such as activation-policy failure;
- `failed(reason:)` when startup cannot provide the lifecycle contract;
- `stopping` during teardown;
- `stopped` after teardown.

Start is idempotent. A repeated start while already attempted does not install
a second defaults observer, second status item, or second Sleepy Mode callback.
Stop is idempotent and clears the defaults observer, persistent status item,
transient status item, UI actions, latest preference snapshot, and menu-refresh
callback. A failed startup installs no observers/controllers and can be retried
only after stop resets the lifecycle.

The runtime reconciles from the authoritative preferences on startup and every
settings/defaults change. It does not create a durable source of truth; existing
`UserDefaults` keys remain authoritative. Stale defaults callbacks are ignored
unless the runtime is enabled, started, and in a usable `ready` or `degraded`
state. Transient global-search dismissal handlers remove only the currently
owned transient controller by identity, so stale dismissals cannot remove a
newer status item.

## Behavior Preserved

- Default `showMenuBarExtra` remains on.
- Menu-bar-only mode still implies `.accessory` activation policy and forces a
  status item even when `showMenuBarExtra` is off.
- Regular mode still implies `.regular` activation policy and hides the status
  item when `showMenuBarExtra` is false.
- Existing menu commands, notification menu behavior, global-search anchoring,
  update checks, Preferences opening, Sleepy Mode toggle, Task Manager opening,
  and app quit behavior remain in the same UI adapters.
- Window-local titlebar/minimal-mode presentation rendering remains local to
  windows; the runtime snapshots the preference only for lifecycle observation.
- Default XCTest composition no longer applies `.regular` as a launch side
  effect. That intentional difference is part of the test-isolation contract.

## Test-Isolation Strategy

Tests opt in with
`BmuxAppRuntimeConfiguration.test(enabledCapabilities: [.menuBarPresentationLifecycle], ...)`
and inject `MenuBarPresentationRuntimeServiceDependencies` plus
`MenuBarPresentationRuntimeUIActions`. The injected dependencies cover current
preferences, preference writes, current activation policy, activation-policy
mutation, defaults observer installation/removal, status-item controller
construction, and Sleepy Mode refresh callback installation.

Disabled/default XCTest composition constructs the service in
`disabled(reason:)` and `BmuxAppRuntimeServices.startMenuBarPresentationLifecycle`
does not call the injected dependencies. Focused tests assert that no real
observer, status item, preference write, or activation-policy mutation is
performed while disabled.

## Boundary Guard

`scripts/check-app-runtime-composition-boundary.sh` now rejects migrated
menu-bar/presentation lifecycle bypasses:

- `MenuBarPresentationRuntimeService` construction outside
  `BmuxAppRuntimeComposition`;
- lifecycle/mutation calls on the runtime service outside
  `BmuxAppRuntimeServices`;
- `MenuBarExtraController` construction outside
  `AppDelegate+MenuBarPresentationRuntime.swift`;
- production `NSApp.setActivationPolicy`, `MenuBarOnlySettings.setEnabled`, or
  `SleepyModeController.shared.onStateChange` use outside the runtime
  dependency seam;
- legacy AppDelegate lifecycle symbols such as `menuBarVisibilityObserver`,
  `syncApplicationPresentationPreferences`, `syncMenuBarExtraVisibility`,
  `installMenuBarVisibilityObserver`, `setupMenuBarExtra`, and
  `lastMenuBarExtraShouldInstall`.

Pure preference reads such as `MenuBarOnlySettings.activationPolicy(defaults:)`
remain allowed so tests and rendering code can evaluate state without mutating
the process.

## Deferred Findings

- `WorkspacePresentationModeChangeObserver` still observes the presentation
  preference per window. That is a rendering concern and belongs to a future
  window/presentation slice if Project Truth selects one.
- Other app-host services still observe `UserDefaults.didChangeNotification`
  directly. They are outside this menu-bar/presentation lifecycle boundary and
  remain candidates for the residual app-host audit.
- Global-search startup and hotkey registration remain outside this slice; only
  the menu-bar anchor/status-item lifecycle moved here.
- `HostSettingsActions` still owns unrelated Settings side effects such as app
  icon and config-window handling. Those are not menu-bar/presentation lifecycle
  ownership, but the residual app-host audit should revisit their composition
  boundaries.
- `FocusedNotificationIndicatorTests.testFocusedNotificationIndicatorRemainsVisibleAfterFocusedNotificationIsRead`
  fails on `origin/main` at `af91c7601` and on this branch. The failure is in
  `TerminalNotificationStore` focused-read indicator behavior, not the
  menu-bar/presentation lifecycle boundary, so it remains out of scope for this
  slice.

## Validation Evidence

- `bmuxTests/MenuBarPresentationRuntimeCompositionTests` covers production and
  XCTest capability selection, disabled construction, startup reconciliation,
  duplicate start, settings-change reconciliation, activation-policy
  degradation and recovery, stopped callback isolation, transient global-search
  status-item teardown, failed startup, stop, and restart.
- `scripts/check-app-runtime-composition-boundary.sh` enforces the migrated
  ownership boundary.
- Existing affected menu-bar and notification-menu coverage passed after
  excluding the base-main focused-notification failure documented above.
- Human acceptance is not claimed by this audit. Delivery remains open until the
  implementation PR merges and the canonical post-merge reconciliation records
  delivery on `main`.
