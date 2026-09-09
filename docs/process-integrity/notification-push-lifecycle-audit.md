# Notification and Push-Registration Lifecycle Audit

## Scope

Project Truth slice: `app_runtime_notification_push_lifecycle_migration`.

This audit covers app-scoped notification and phone-push lifecycle behavior in
the macOS app and the iOS APNs bridge that mirrors those notifications.
It is bounded to notification-center configuration, notification authorization
transitions, AppDelegate callbacks, macOS phone-push forwarding, iOS APNs token
publication, foreground/background transitions, sign-in/sign-out hooks, and
teardown.

This slice does not migrate menu-bar visibility or presentation preference
observation.

Evidence inspected includes `Sources/AppDelegate.swift`,
`Sources/App/BmuxAppRuntime*.swift`, `Sources/TerminalNotificationStore.swift`,
`Sources/Cloud/PhonePushClient.swift`, `Sources/Feed/FeedCoordinator.swift`,
`Packages/macOS/BmuxNotifications`, `ios/bmux/BmuxAppDelegate.swift`,
`ios/bmux/bmuxApp.swift`, `ios/bmux/AppCompositionRoot.swift`,
and `Packages/iOS/BmuxMobileShellUI/.../MobilePushCoordinator.swift`.

## Current Lifecycle Before This Slice

The macOS path is split across several owners:

- `bmuxApp.init()` constructs app-runtime services and then calls
  `AppDelegate.configure(...)`.
- `AppDelegate.configure(...)` directly calls
  `PhonePushClient.shared.configure(auth:)`.
- `AppDelegate.applicationDidFinishLaunching` directly installs notification
  categories and the user-notification delegate.
- `AppDelegate` forwards notification-center response and foreground
  presentation callbacks directly to its lazy `NotificationDeliveryCoordinator`.
- `TerminalNotificationStore.shared` owns authorization state, automatic prompt
  deferral, settings prompts, native scheduling, unread projections,
  mobile-host notification events, and direct phone-push forwarding.
- `PhonePushClient.shared` owns banner and silent-dismiss sends, presence
  gating, burst throttling, dismiss coalescing, and auth retained from startup.

The iOS path is already root-injected but has no explicit lifecycle state:

- `ios/bmux/bmuxApp.init()` directly calls
  `MobilePushCoordinator.configure(delegate:)` and injects the same coordinator
  into `BmuxAppDelegate` and SwiftUI.
- `BmuxAppDelegate` forwards APNs token success, foreground decisions, taps,
  dismisses, and silent dismiss pushes to `MobilePushCoordinator`; registration
  failure analytics still live in the delegate.
- `MobilePushCoordinator` owns opt-in registration, foreground suppression, tap
  parking, dismiss forwarding, and background delivered-banner clearing, but it
  calls `UNUserNotificationCenter.current()` and `UIApplication.shared`
  directly.
- `MobileAuthComposition` constructs `PushRegistrationService` and wires
  post-sign-in token sync through a deferred hook.
- `BMUXMobileRootView` binds the active shell store and unregisters push tokens
  during sign-out with captured credentials.

## Owner and Trigger Inventory

| Responsibility | Current owner | Trigger | Teardown | Risk |
| --- | --- | --- | --- | --- |
| macOS notification categories and delegate | `AppDelegate` and `NotificationDeliveryCoordinator` | `applicationDidFinishLaunching` outside XCTest | none explicit | bypasses app-runtime configuration |
| macOS notification callbacks | `AppDelegate` | OS callback | callback completion | can route without runtime readiness |
| terminal authorization state | `TerminalNotificationStore` | singleton init, delivery, app-active | store deinit removes defaults observer | not composition-gated |
| settings notification prompt/test | `HostSettingsActions` to `TerminalNotificationStore` | user button | prompt retry limit | correct but hard-wired to shared store |
| native terminal scheduling | `TerminalNotificationStore` and hooks | delivery side effects | request removal by id | scheduler is injectable, center is defaulted |
| Feed permission/plan/question notifications | `FeedCoordinator` | feed events awaiting decision | `cancelNotification(requestId:)` | direct center access remains |
| Mac banner push | `PhonePushClient.shared` | unsuppressed desktop delivery | no tracked send cancellation | store can reach singleton when runtime is disabled |
| Mac silent dismiss push | `PhonePushClient.shared` | user read, clear, or remove | drain task clears itself | no app-runtime stop |
| phone badge live event | `TerminalNotificationStore` via `MobileHostService.emitEvent` | unread count changes | none | belongs to mobile-host event domain |
| iOS notification category/delegate | `MobilePushCoordinator` | `bmuxApp.init()` | none explicit | no lifecycle state |
| iOS APNs registration | `MobilePushCoordinator` | settings toggle | disable unregisters | direct system calls |
| iOS token upload | `PushRegistrationService` | token and post-sign-in hook | disable or sign-out unregisters | success and failure callbacks are asymmetric |
| iOS tap/dismiss routing | `MobilePushCoordinator` | notification callbacks | pending tap expires; dismiss queue persists | root-injected but not lifecycle-gated |

## Invalid or Partial States

- Default XCTest composition can construct `TerminalNotificationStore` and
  `AppDelegate` while the runtime has no notification/push disabled state.
- `PhonePushClient.shared` can receive forwarding calls from the store before a
  composition-owned start configures auth. Existing behavior silently skips
  sends, but the missing owner is invisible.
- `PhonePushClient.shared` starts untracked banner send tasks and one dismiss
  drain task with no app-runtime stop.
- AppDelegate notification callbacks can route directly into delivery even when
  no runtime service started.
- iOS push configuration is repeatable but has no lifecycle state, and failure
  callbacks are handled outside the push owner.
- Feed notifications still call `UNUserNotificationCenter.current()` directly;
  this audit records that as residual center access, not as app-scoped startup
  ownership.

## Ordering Constraints

- macOS notification categories must be installed before terminal or Feed
  notifications need actions.
- Notification response routing needs AppDelegate seams that read late-bound
  window, notification-store, and Feed state.
- Phone forwarding needs `AuthCoordinator`, but notification delivery must stay
  best effort when auth is absent or offline.
- Phone forwarding depends on mobile-host identity and presence decisions, but
  it does not own the mobile-host listener, route publication, or presence
  heartbeat lifecycle.
- iOS token sync still depends on auth sign-in hooks and sign-out captured
  credentials. Those flows remain owned by the mobile app composition/auth
  surfaces and call into the push coordinator only for push-specific work.

## Target Owner and Boundary

The macOS target owner is `NotificationPushRuntimeService`, constructed only by
`BmuxAppRuntimeComposition` and reached only through `BmuxAppRuntimeServices`.
It owns app-scoped startup, callback routing, and stop for:

- `NotificationDeliveryCoordinator` construction and notification-center
  category/delegate configuration;
- `PhonePushClient.shared.configure(auth:)`;
- the `TerminalNotificationStore` phone-forwarding seam;
- AppDelegate notification response and foreground presentation callbacks;
- application-active authorization refresh routing.

`AppDelegate` remains the required `NSApplicationDelegate` and
`UNUserNotificationCenterDelegate` callback adapter. It supplies weak-owner
navigation, Feed, activation, localized action-title, auth, and store
dependencies to the runtime. It no longer owns the delivery coordinator or
phone-push lifecycle.

`TerminalNotificationStore` remains the owner of terminal notification records,
authorization state, settings prompts, unread projections, local scheduling,
and mobile-host live badge/dismiss events. Its phone-push cold lane now calls an
injected `TerminalPhonePushForwarding` protocol instead of reaching directly
for `PhonePushClient.shared`; the default is a noop so tests and partial
runtimes do not accidentally publish.

`PhonePushClient` remains the transport implementation for macOS banner and
silent-dismiss APNs pushes. The runtime owns its configure/stop lifecycle, and
the client now tracks and cancels pending banner-send tasks, the dismiss-drain
task, auth, throttle state, and presence cache during stop.

The iOS target owner remains `MobilePushCoordinator`, now with explicit
`MobilePushLifecycleState`, `start(delegate:)`, and `stop()` entrypoints plus a
`MobilePushSystemClient` seam for notification-center and APNs registration
calls. `BmuxAppDelegate` stays an OS adapter for APNs token success/failure,
foreground presentation, taps, dismisses, and silent push wakeups.

## Implemented Lifecycle

macOS startup:

- production `BmuxAppRuntimeConfiguration` enables
  `.notificationPushLifecycle`; default XCTest and partial process
  configurations disable it unless tests opt in;
- `bmuxApp.init()` builds `BmuxAppRuntimeServices` once;
- `AppDelegate.configure(...)` calls `startNotificationPushRuntime(...)` after
  auth bootstrap exists;
- `BmuxAppRuntimeServices.startNotificationPushLifecycle(...)` gates the call by
  capability and records one start attempt;
- `NotificationPushRuntimeService.start(...)` validates required runtime
  availability, builds/configures `NotificationDeliveryCoordinator`, configures
  `PhonePushClient`, injects the store forwarder, and moves to `ready` or
  `degraded`.

macOS stop:

- `BmuxAppRuntimeServices.stop()` stops notification/push before browser,
  mobile-host/presence, sidebar Git/PR, and work-provenance services;
- `NotificationPushRuntimeService.stop()` is idempotent, resets the store
  forwarder to noop, stops `PhonePushClient`, drops the delivery coordinator,
  and transitions to `stopped`;
- failed or disabled startup attempts are also stopped deterministically and can
  only be retried after stop resets the lifecycle.

Callback routing:

- AppDelegate notification response and foreground-presentation callbacks call
  `BmuxAppRuntimeServices`, which routes them only when the capability is
  enabled and the runtime state permits callbacks;
- application-active refresh likewise routes through the runtime and is ignored
  while disabled, not started, failed, stopping, or stopped.

iOS startup and transitions:

- `bmuxApp.init()` calls `MobilePushCoordinator.start(delegate:)`;
- repeated start installs the delegate/category and APNs registration path once;
- if the user already opted in, start reasserts APNs registration;
- `enable()` reads authorization through the system seam, requests
  alert/sound/badge permission, persists server opt-in only after grant, and
  then registers for APNs;
- denied authorization records the same analytics decision and does not persist
  opt-in or register;
- `disable()` clears server opt-in and unregisters APNs through the system seam;
- APNs token success and failure callbacks route into the coordinator.

## Behavior Preserved

- macOS terminal notifications still use the same local category/action
  identifiers and localized action titles.
- Foreground notification presentation decisions, response routing, Feed reply
  actions, click actions, native scheduling, automatic authorization refresh,
  settings prompts, unread projections, Dock badge behavior, and mobile-host
  live badge/dismiss events remain in their existing domains.
- Phone forwarding remains opt-in and best effort. It still respects hide
  content, presence mode, burst throttling, silent dismiss coalescing, and the
  absolute badge-count contract.
- iOS push opt-in, opt-out, foreground suppression, tap parking, dismiss-sync,
  silent dismiss handling, and sign-in token sync keep their existing external
  behavior.

## Removed Legacy Ownership

- `AppDelegate` no longer directly constructs or retains
  `NotificationDeliveryCoordinator`.
- `AppDelegate.applicationDidFinishLaunching` no longer directly configures
  notification categories/delegate.
- `AppDelegate.configure(...)` no longer directly calls
  `PhonePushClient.shared.configure(auth:)`.
- `TerminalNotificationStore` no longer directly calls `PhonePushClient.shared`
  for forwarding or replacement decisions.
- `BmuxAppDelegate` on iOS no longer owns APNs registration-failure analytics;
  it forwards the failure to `MobilePushCoordinator`.
- iOS APNs register/unregister and notification-center configuration calls are
  isolated behind `MobilePushSystemClient`.

## Remaining Outside the Runtime

- `TerminalNotificationStore` still owns authorization state and the settings
  prompt because those are notification-store state, not runtime ownership.
- Feed notification scheduling still has direct notification-center access in
  `Packages/macOS/BmuxNotifications`; this is a delivery feature path, not the
  app startup lifecycle owner moved here.
- Mobile-host live badge/dismiss events remain in `MobileHostService` because
  they are live phone-attachment events, separate from APNs push forwarding.
- iOS sign-out unregisters push tokens from the root view with captured
  credentials. That flow remains an auth/account teardown responsibility.

## Risks and Rollback

- If macOS delivery callbacks stop routing, rollback is localized to
  `AppDelegate+NotificationPushRuntime.swift`,
  `NotificationPushRuntimeService`, and `BmuxAppRuntimeServices`; the
  notification delivery coordinator and store APIs remain intact.
- If phone forwarding regresses, the store can be reset to the noop forwarder
  and `PhonePushClient.stop()` clears auth/tasks without changing local
  notification delivery.
- If iOS APNs behavior differs on device, the `MobilePushSystemClient` seam is
  the rollback boundary for direct UIKit/UserNotifications calls.
- The root workspace cannot run the full iOS package graph because existing
  macOS package target-name collisions remain outside this slice; iOS
  validation uses `ios/bmux.xcworkspace`.

## Validation Evidence

- `bmuxTests/NotificationPushRuntimeCompositionTests` covers production/test
  capability selection, disabled construction, start once, repeated start,
  failed-start idempotency, stop once, repeated stop, degraded/failed states,
  app-active callback routing, injected store forwarding, and stop-time noop
  isolation.
- `ios/bmuxPackage/Tests/bmuxFeatureTests/MobilePushCoordinatorLifecycleTests`
  covers iOS start/stop idempotency, disabled construction, authorization grant
  and denial, token registration, registration failure routing, and APNs
  unregister behavior.
- `scripts/check-app-runtime-composition-boundary.sh` now names the permitted
  construction and adapter locations for notification/push ownership, macOS
  `PhonePushClient.shared` lifecycle/forwarding calls, macOS notification
  delivery coordinator construction, and iOS APNs register/unregister calls.

Local validation on 2026-09-09:

- `BMUX_SKIP_ZIG_BUILD=1 xcodebuild -project bmux.xcodeproj -scheme bmux-unit
  ... -only-testing:bmuxTests/NotificationPushRuntimeCompositionTests` passed
  with 6 Swift Testing cases.
- `BMUX_SKIP_ZIG_BUILD=1 xcodebuild -project bmux.xcodeproj -scheme bmux-unit
  ...` across notification, app-runtime, browser/DevTools, sidebar Git/PR,
  mobile-host, and presence suites passed with 44 Swift Testing cases.
- `xcodebuild -workspace ios/bmux.xcworkspace -scheme bmux-ios ... build`
  passed for the iPhone 17 simulator.
- `xcodebuild -workspace ios/bmux.xcworkspace -scheme bmux-ios ...
  -only-testing:bmuxFeatureTests/MobilePushCoordinatorLifecycleTests` passed
  with 6 Swift Testing cases.

## Caveats

- UserNotifications response/presentation objects are OS-created, so local unit
  coverage proves runtime gating and owner routing rather than constructing real
  `UNNotificationResponse` or `UNNotification` values directly.
- Human acceptance is not claimed by this audit. Delivery remains open until
  the implementation PR merges and post-merge Project Truth reconciliation runs.
