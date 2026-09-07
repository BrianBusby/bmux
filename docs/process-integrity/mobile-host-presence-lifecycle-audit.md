# Mobile Host And Presence Lifecycle Audit

## Scope

This audit covers the second Process Integrity runtime-composition slice. It is
bounded to the macOS mobile-host listener, its settings-driven route publication,
network-path monitoring, mobile event publishers, and route-driven presence and
registry companions. It follows the first runtime-composition slice documented in
`docs/process-integrity/runtime-composition-audit.md`, which migrated Work
Provenance startup and left mobile host/presence as the next candidate.

## Current Lifecycle Before This Slice

`bmuxApp.init()` constructs `BmuxAppRuntimeComposition` and
`BmuxAppRuntimeServices`, then calls `AppDelegate.configure(...)`.
`AppDelegate.configure(...)` still configures mobile/cloud singletons directly:

- `MobileHostService.shared.configure(auth:)`
- `DeviceRegistryClient.shared.configure(auth:)`
- `PresenceHeartbeatClient.shared.configure(auth:)`
- `MacPairedMacBackupPublisher.shared.configure(auth:)`
- `PhonePushClient.shared.configure(auth:)`
- `ensureMobileWorkspaceListObserver(for:)`
- `MobileTerminalRenderObserver.shared.start()`
- `installMobileHostSettingsObserver()`

`bootstrapInitialMainWindowIfNeeded(...)` also calls
`MobileHostService.shared.start()` after creating a main window. Termination calls
`PresenceHeartbeatClient.shared.appWillTerminate()` and
`MobileHostService.shared.stop()` before the composition-owned runtime services
are stopped.

The result is that app construction and `AppDelegate` wiring can activate mobile
host/presence behavior without consulting `BmuxAppRuntimeConfiguration`. Default
app-host XCTest composition can therefore install observers, watch mobile-host
routes, and bind or publish mobile-host routes through incidental singleton
startup even when unrelated capabilities are disabled.

## Service Audit

`MobileHostService`

- Constructed as `MobileHostService.shared`.
- Configured by `AppDelegate.configure(...)`.
- Started by `bootstrapInitialMainWindowIfNeeded(...)`,
  `syncToSettings()`, and `MobilePairingModel.refresh()`.
- Touches listener sockets, preferred or ephemeral ports, active connections,
  attach tickets, route caches, event subscriptions, path monitoring, and mobile
  viewport cleanup.
- Reports running, port, routes, fallback, connection count, and last error
  through `MobileHostServiceStatus`.
- `ensureListeningAndReady()` waits for listener settlement through a
  continuation.
- `stop()` cancels the listener and path monitor, closes connections, clears
  public routes, and resets subscriptions.
- Tests used the shared singleton plus a DEBUG XCTest route shim.

`MobileHostNetworkPathMonitor`

- Constructed inside `MobileHostService`.
- Started when the listener is adopted or started.
- Touches a real path monitor and local network interface enumeration.
- Reports deduped path-signature changes back to the host service.
- Stops only when the host service cancels it.

`PresenceHeartbeatClient`

- Constructed as `PresenceHeartbeatClient.shared`.
- `configure(auth:)` starts route observation, installs a defaults observer, and
  evaluates the heartbeat loop.
- Touches `URLSession.shared`, the presence worker, route-observation tasks,
  defaults observers, heartbeat-loop tasks, and clean-quit goodbye requests.
- Failures are best effort and private; they must not fail a healthy listener.
- Before this slice, termination stopped only the heartbeat loop.

`DeviceRegistryClient` and `MacPairedMacBackupPublisher`

- Constructed as shared singletons.
- `configure(auth:)` starts route-observation tasks.
- They post route sets when `MobileHostService.statusUpdates()` changes.
- They had no explicit stop path, and the backup publisher defaults on in DEBUG.
- They are route-publication companions for this slice because app-host tests
  must not start route observers or cloud traffic by constructing the app.

`PhonePushClient`

- Constructed as a shared singleton.
- `configure(auth:)` stores auth only; sends occur from notification paths.
- It is deferred to a later push/notification lifecycle slice because it does not
  start a listener, route observer, path monitor, or loop at app construction.

`MobileWorkspaceListObserver` and `MobileTerminalRenderObserver`

- Workspace-list observation was owned by `AppDelegate`, one observer per
  `TabManager`, and removed only when no registered window used that manager.
- Terminal-render observation was started from `AppDelegate.configure(...)` and
  had an explicit `stop()` that was not called from app termination.
- Both register process-wide observers and publish mobile events, so they belong
  under the same mobile-host capability as the listener.

`MobilePairingModel` and `HostSettingsActions`

- Pairing enables the mobile-host setting and calls `ensureListeningAndReady()`.
- Settings reads status and applies port changes through `MobileHostService`.
- These paths should remain product-compatible but forward startup/configuration
  through the composition-owned runtime instead of owning it independently.

## Canonical Owner

`BmuxAppRuntimeComposition` remains the source of truth for constructing migrated
runtime services, and `BmuxAppRuntimeConfiguration` remains the source of truth
for production versus test capability selection.

This slice selects one additional capability: `mobileHostAndPresence`.

`BmuxAppRuntimeServices` owns ordered startup, diagnostic start counts, readiness
access, and shutdown. A dedicated mobile-host runtime service owns listener
synchronization, settings observation, workspace/render mobile event observers,
route-driven device registry, paired-Mac backup, and presence evaluation.
`MobileHostService` remains the listener/RPC domain owner, but it must no longer
be a second production startup owner.

## Implemented Boundary

This slice adds `mobileHostAndPresence` to the existing runtime-capability model.
Production composition enables it; default XCTest composition leaves it disabled.
`BmuxAppRuntimeComposition` constructs `MobileHostRuntimeService`, and
`BmuxAppRuntimeServices` is the only migrated app path allowed to start, sync,
attach workspace observers, and stop the service family.

`MobileHostRuntimeService` owns the composition-level lifecycle:

- installs and removes the mobile-host settings observer;
- observes host status updates for deterministic readiness state;
- configures the listener service once auth is available;
- starts the setting-enabled side work exactly once: render observation,
  presence heartbeat evaluation, device-registry route publication, and
  paired-Mac backup route publication;
- stops setting-enabled side work immediately when the mobile-host setting is
  disabled while keeping the settings observer alive for re-enable;
- re-enables the side work through the same sync path when settings/auth permit;
- detaches per-`TabManager` workspace-list observers when windows release them;
- stops owned side work, host listener, path monitoring, active connections, and
  observers on shutdown or app termination.

The runtime does not expose or require a new service locator. Production
singleton access is isolated to `MobileHostRuntimeServiceDependencies.production()`
so tests can inject listener/status/presence behavior without touching real
sockets, route monitors, `URLSession.shared`, device identity state, or user
settings.

## Readiness Semantics

The runtime-level state is separate from `MobileHostServiceStatus` and projects
the selected capability into the states consumers and tests need:

- disabled by composition;
- disabled by settings;
- not started;
- starting;
- ready/listening;
- degraded with a bounded reason;
- failed with a bounded reason;
- stopping;
- stopped.

Preferred-port failure followed by an ephemeral bind is represented as
degraded-but-listening. Presence, device-registry, or paired-Mac backup failure
degrades the publication path without marking the local listener failed. A
listener bind failure marks the mobile-host runtime failed. Auth absence while
the host setting is enabled is degraded as waiting for authentication; a later
auth-bearing start call arms the publication path without duplicating the
listener lifecycle.

## Production And Test Rules

Production composition enables the mobile-host capability. Existing user settings
continue to decide whether the listener actually binds:

- Release default remains off until the user enables iOS pairing.
- DEBUG default remains on for dev iOS discovery unless explicitly overridden.
- Presence still follows the mobile-host setting unless explicitly overridden.

Default XCTest/app-host composition disables the capability. Constructing
`bmuxApp`, `AppDelegate`, or `TabManager` under that composition must not bind a
listener, start path monitoring, install mobile-host settings or route observers,
publish routes, send heartbeats, or start device-registry/dev-backup traffic.

Focused tests may opt into `mobileHostAndPresence` with faked listener/presence
dependencies. Tests should assert lifecycle state and event sequences rather
than sleeping for incidental timing.

## Retained Compatibility

`MobileHostService.shared` is retained for domain consumers that need status,
event emission, authorization, attach-ticket creation, or mobile RPC handling.
Compatibility access may forward pairing/settings activation requests to the
composition-owned runtime service while UI and settings callers are migrated.
`MobilePairingModel` still receives a `MobileHostService` handle for pairing
status, ticket creation, and first-use readiness; that path is retained as
product compatibility and must not be used by app construction.

Retained singleton access must not construct a second listener lifecycle owner.
Removal condition: delete startup-capable singleton access once pairing,
settings, terminal control, notification, and mobile event consumers all receive
a runtime-owned protocol or handle instead of reaching for `.shared`.

`PresenceHeartbeatClient.configure(auth:)`, `DeviceRegistryClient.configure(auth:)`,
and `MacPairedMacBackupPublisher.configure(auth:)` remain as compatibility
wrappers around `start(auth:)`. Removal condition: delete these wrappers after
no app startup or tests call the old configure names and consumers receive their
auth/lifecycle dependency from runtime composition.

The DEBUG XCTest route shim in `MobileHostService.start()` is transitional.
Removal condition: delete it after existing mobile RPC tests opt into
`mobileHostAndPresence` explicitly or receive an isolated route fixture.

## Readiness And Teardown Expectations

The migrated runtime lifecycle should distinguish disabled, not started,
starting, ready/listening, degraded, failed, stopping, and stopped states.
Preferred-port failure followed by ephemeral fallback is degraded-but-listening,
not fatal. Presence, device registry, or dev-backup failure may degrade their own
publication state, but must not mark a healthy local listener as failed.

Shutdown must cancel settings observation, route observation, heartbeat loops,
workspace-list observers, render observers, path monitoring, listener sockets,
active connections, event subscriptions, and presence goodbye work owned by this
capability. Repeated start, sync, and stop calls must be idempotent.

Settings changes now reconcile through the runtime owner. Setting disable calls
the host service's sync path so the listener/path monitor/connections stop, then
stops presence, registry, paired-Mac backup, and render observation. Setting
re-enable starts exactly one clean side-work lifecycle. Port-change rebinds
remain domain behavior inside `MobileHostService.syncToSettings()`; the runtime
continues to own who invokes that reconciliation path.

## Deferred Services

Phone notification forwarding is deferred because `PhonePushClient.configure`
only stores auth and does not start a background listener, route observer, path
monitor, or loop. A later push-registration/notification runtime slice should
own its send lifecycle and any APNs/device-token registration separately.

Browser/DevTools lifecycle, sidebar Git/PR observation, remote session SSH
presence, menu-bar runtime services, Dock identity, and push registration remain
separate Process Integrity candidates. They should not be folded into this PR.

The recommended next Process Integrity slice after this one is whichever
app-host side-effect family remains highest-friction after mobile host/presence,
with browser/DevTools ownership and sidebar Git/PR observation still the leading
candidates from the PR #97 audit.

## Unrelated Findings

During validation, the Session provenance app-host regression
`SessionProvenanceTests.testHookPromptSubmitRecordsFactualSessionAndWorkspaceDisplayLink`
still expected the literal workspace id `runtime-workspace`. Current `main`
records the stable workspace UUID in
`WorkProvenanceCodingAgentEvidenceRecorder+Support.swift`, and the same focused
test fails when run alone against this branch. The mobile-host lifecycle PR does
not change that Session provenance path; reconcile the stale test expectation in
a separate provenance/session follow-up if that test is still intended to be
part of the required suite.
