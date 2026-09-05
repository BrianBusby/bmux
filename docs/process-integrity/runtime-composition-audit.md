# Runtime Composition Audit: Work Provenance Startup

## Scope

This audit covers the first Process Integrity runtime-composition slice. It is
bounded to app startup and app-host test behavior around WorkProvenanceRuntime
and the agent-chat execution telemetry projection that writes PE lifecycle
facts. Browser, sidebar Git/PR observation, remote-session/presence, push,
notification, menu-bar, and mobile-host services were inspected for startup
shape but are deferred unless named below.

## Current Lifecycle Before This Slice

`BmuxMain.main()` dispatches sidebar worker modes and otherwise enters
`bmuxApp.main()`. `bmuxApp.init()` is the production composition root for
settings/auth setup, but before this slice it also called
`WorkProvenanceRuntime.live(...)` directly. That call constructed the PE SQLite
client and resolved the database path immediately. The later PR #95 gate only
wrapped `workProvenanceRuntime.start(tabManager:)`, so app-host XCTest runs could
still construct PE storage before startup was skipped.

`AppDelegate.configure(...)` received the already-created runtime, stored it on
`AppDelegate`, assigned it back to `TabManager`, and wired
`AgentChatTranscriptService` callbacks to record PE session lifecycle and prompt
evidence. `AppDelegate+AgentChat` separately gated execution-telemetry
projection startup with XCTest detection before calling
`workProvenanceRuntime.startExecutionTelemetryProjection(...)`.

`WorkProvenanceRuntime.start(tabManager:)` was idempotent only by individual task
nil checks. It launched pruning, workspace observation, notification observers,
activation refresh, workspace-display subscription, and later prompt/lifecycle
write tasks. The runtime did not expose a lifecycle state, did not have a public
stop path, and production-path tests waited for factual projection readiness with
a fixed sleep loop.

## Service Audit

| Service | Constructor | Starter | Startup cause | Side effects | Readiness | Stop/teardown | Test control before this slice |
| --- | --- | --- | --- | --- | --- | --- | --- |
| WorkProvenanceRuntime / PE SQLite | `bmuxApp.init()` via `WorkProvenanceRuntime.live(...)` | `bmuxApp.init()` via `start(tabManager:)` | App construction | Opens PE SQLite store, file-watcher subscription, notification tasks, PE writes | implicit; tests polled factual reads | task cancellation only in `deinit`; no public stop | `shouldStartInCurrentProcess()` skipped observation under XCTest but did not prevent construction |
| Agent-chat execution telemetry PE projection | `WorkProvenanceRuntime.startExecutionTelemetryProjection(...)` | `AppDelegate+AgentChat` | configured agent-chat action/config load | polls sidecar status and writes PE lifecycle/evidence | internal service start | internal service `stop()`, not app termination owned | separate XCTest guard in AppDelegate extension |
| AgentChatTranscriptService | `AppDelegate` property | `AppDelegate.configure(...)` | AppDelegate startup | Seeds hook stores, transcript prompt evidence, registry callbacks | implicit | tailers stop per session; service has no global stop | always constructed by app-host |
| Browser/DevTools lifecycle | AppDelegate/browser panel services | panel/app flows | app/panel construction and debug tooling | browser profiles, inspectors, web views | domain-specific | scattered | app-host side effects were stabilized in PR #95 but not migrated here |
| Sidebar Git/PR observation | sidebar/workspace row services | sidebar rendering/observation paths | sidebar visibility and row refresh | GitHub CLI/git processes, caches | implicit row state | domain-specific | not migrated here |
| Remote/presence/mobile/push | AppDelegate singletons | `AppDelegate.configure(...)` | app-host construction | listeners, ports, auth clients, presence/push registration | service-specific or implicit | scattered stop calls in termination | app-host still starts some of these today; deferred |
| Notifications/menu bar | AppDelegate/shared stores | app startup and UI events | app construction | UserNotifications, menu state, observers | implicit | app termination cleanup | not migrated here |

## Canonical Owner

`BmuxAppRuntimeComposition` is the app-level source of truth for constructing
migrated runtime services. `BmuxAppRuntimeConfiguration` selects capabilities for
production or tests. `BmuxAppRuntimeServices` owns starting, readiness access,
and stopping migrated services.

The first migrated capabilities are:

- `workProvenanceObservation`
- `agentChatExecutionTelemetryProjection`

Production enables both by default. XCTest hosts disable both by default. Tests
that need PE must opt in and provide an isolated home directory or set the
compatibility environment described below.

## Compatibility Behavior

`BMUX_ENABLE_PROVENANCE_RUNTIME_IN_XCTEST=1` still opts an XCTest host into Work
Provenance runtime capabilities, and `BMUX_PROVENANCE_HOME` still overrides the
home directory used to derive PE storage. The compatibility behavior now lives in
`BmuxAppRuntimeConfiguration.currentProcess(...)`; the old
`WorkProvenanceRuntime.shouldStartInCurrentProcess(...)` shim was removed.

Removal condition: delete the environment opt-in only after all app-host PE tests
use explicit `BmuxAppRuntimeConfiguration.test(...)` or a test harness that
passes capabilities directly, and no CI/local scripts depend on the env opt-in.

## Runtime State and Teardown

`WorkProvenanceRuntime` now exposes deterministic lifecycle state:

- `notStarted`
- `starting`
- `ready`
- `degraded(reason:)`
- `stopping`
- `stopped`
- `failed(reason:)`

A composition-disabled runtime starts at `stopped` without constructing the PE
SQLite client. A construction failure starts as `notStarted` with the retained
startup error and transitions to `failed(reason:)` when the composition owner
attempts startup. `stop()` cancels notification observers, workspace-display
subscription, execution telemetry projection, display refresh tasks, and tracked
background PE work, then clears the retained `TabManager` reference.

`waitForBackgroundTasks()` lets production-path tests await real PE recording and
workspace observation tasks. It replaces fixed sleeps in the Session-tab
production lifecycle regression.

Tagged-app dogfood exposed one additional readiness hazard in the production PE
prompt path: transcript prompt evidence appends were spending all sampled CPU in
turn-outcome evidence acquisition because the projection decoded the entire
local event ledger. That was not a composition-construction bypass, but it meant
the migrated production path could start deliberately and still fail to reach a
useful ready state on a long-lived local store. The fix keeps the existing
evidence contract and scopes turn-outcome evidence reads to the affected
`session_id`, using the existing `provenance_events_session_index`; unrelated
ledger history is no longer decoded for one active session append.

Dogfood also exposed that `AgentChatTranscriptService.start()` seeded Codex
prompt evidence from every hook-store record, including ended historical
sessions. That startup behavior is now bounded to non-ended Codex records. The
retained compatibility behavior is live startup backfill for an actually-live
hook-store session plus per-hook live Codex prompt evidence even when no mobile
chat subscriber is attached. Ended hook-store records remain available for
history/listability, but they do not parse transcript history or append durable
PE prompt evidence during production startup. Historical transcript ingestion
remains explicit through `bmux provenance import codex-transcripts` or a future
separately composed maintenance capability.

## Guardrail

`scripts/check-app-runtime-composition-boundary.sh` fails if production app source
constructs or starts migrated WorkProvenance services outside the expected
composition path:

- `WorkProvenanceRuntime.live(...)` must stay in
  `Sources/App/BmuxAppRuntimeComposition.swift`.
- `workProvenanceRuntime.start(tabManager:)` must stay in
  `Sources/App/BmuxAppRuntimeServices.swift`.
- `workProvenanceRuntime.startExecutionTelemetryProjection(...)` must stay in
  `Sources/App/BmuxAppRuntimeServices.swift`.

The guard is intentionally narrow. Tests may still construct fakes or focused
runtime instances, and service-internal implementation remains allowed.

## Deferred Services

The first follow-up candidate is a second Process Integrity slice that migrates
one of the app-host side-effect families still started implicitly by
`AppDelegate.configure(...)`. The best next candidate is remote/mobile-host and
presence startup, because the app-runtime composition tests still show app-host
logs from listener/mobile-host startup even when PE is disabled. Browser/DevTools
ownership and sidebar Git/PR observation are also candidates, but they should be
migrated in separate focused PRs with their own production-path tests.

The workspace-display Current State file watcher also remains deferred. Dogfood
sampling showed it can receive frequent SQLite `-wal`/`-shm` change events from a
shared production PE store and rescan candidate watch paths on the main actor.
That was not the sampled source of the blocking PE append, so this PR records it
as a follow-up instead of changing watcher semantics alongside the composition
boundary.

Broad all-history Codex prompt backfill is also deferred. If product needs
startup-time historical prompt ingestion again, it should be introduced as an
explicit runtime capability with its own readiness, storage bounds, progress,
and teardown contract rather than piggybacking on the live agent-chat projection
startup.
