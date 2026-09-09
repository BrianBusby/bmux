# Sidebar Git and Pull-Request Observation Lifecycle Audit

## Scope

Project Truth slice: `app_runtime_sidebar_git_pr_lifecycle_migration`.

This slice migrates app-scoped sidebar Git metadata observation and pull-request
refresh ownership into the app-runtime composition boundary. It does not redesign
sidebar presentation, retire provenance storage, or replace the existing
`BmuxSidebarGit` probe state machines.

The migrated boundary is:

- background local Git metadata probing for sidebar rows;
- filesystem watcher and fallback-poll ownership for sidebar Git facts;
- pull-request poll scheduling and GitHub lookup refresh ownership;
- app/window lifecycle attachment, reconciliation, and shutdown for those
  services;
- publication of observed live facts into the existing workspace sidebar
  metadata model;
- non-owning consumer access from the built-in sidebar, custom sidebar, control
  socket, and workspace-display projection.

Explicit terminal/socket reports (`report_git_branch`, `report_pr`,
`report_pwd`, command hints) remain short-lived fact inputs. They may update the
workspace metadata model, but they must not create an independent app-scoped
Git or GitHub observation owner.

## Current Lifecycle Before This Slice

`TabManager.init` is the current app/window composition point. Every
`TabManager` constructs `PullRequestProbeService`, `PullRequestPollService`,
`SidebarGitMetadataService`, and a static shared `WorkspaceGitMetadataProbeLimiter`.
Those services attach back to the `TabManager` host during `TabManager.init`,
before the first workspace is added. App startup, additional window creation,
and XCTest `TabManager()` construction therefore all instantiate observation
services unless individual tests inject fakes.

The services are retained by `TabManager`, with teardown driven by ad hoc
workspace/reset/settings paths and eventual object lifetime. There is no
explicit app-runtime shutdown call that proves all sidebar Git/PR observers,
tasks, watchers, timers, and caches have been released.

## Producer Inventory

- `BmuxGit/GitMetadataService` reads local repository facts from the filesystem:
  repository detection, branch, dirty status, index/head signatures, remotes,
  GitHub slugs, and watched paths. It does not spawn `git`; callers own caches
  and lifecycle.
- `BmuxGit/PullRequestProbeService` is the stateless PR lookup pipeline. It uses
  injected `CommandRunning` for `gh auth token` and prompt mention enrichment,
  uses ephemeral `URLSession` GitHub REST calls, and returns resolved,
  not-found, unsupported-repository, or transient-failure results.
- `BmuxSidebarGit/SidebarGitMetadataService` owns sidebar Git observation state:
  retry tasks, per-panel probe state, coalesced snapshot tasks, filesystem
  watchers, tracked signatures, fallback poll task, and watched directory
  bookkeeping. It applies directly observed branch/dirty facts to
  `SidebarGitHosting`.
- `BmuxSidebarGit/PullRequestPollService` owns sidebar PR refresh state: active
  keys, poll deadlines, refresh task, timer task, transient failure counts,
  rerun flags, repo cache, and mobile host deferral. It applies GitHub/PR facts
  to `SidebarGitHosting`.
- Shell integration and socket report commands produce explicit directory,
  branch, PR, PR-action, ports, TTY, and shell state reports. These are
  short-lived event inputs, not background observers.
- Workspace restoration, workspace creation, directory changes, panel changes,
  branch reports, and shell prompt-idle transitions trigger `TabManager`
  forwarders into the sidebar Git/PR services.
- UserDefaults sidebar detail settings toggle Git watch and PR polling behavior.
- `WorkProvenanceObservationService` separately owns PE/workspace durable
  observation and has its own Git inspection for provenance events. It is not
  the sidebar observation owner and is intentionally outside this slice except
  as a consumer of workspace-display facts. Its default pull-request owner
  resolver is no-op; tests that need owner/title enrichment inject an explicit
  resolver, and production receives PR owner/title/branch facts from the live
  workspace metadata model instead of launching a second GitHub CLI path.

## Consumer Inventory

- `WorkspaceSidebarMetadataModel` and `Workspace+DisplayMetadata` are the
  existing live in-memory authority for workspace display branch and PR facts.
  They store workspace-level and panel-level branch/PR state plus provenance
  source metadata, and post `workspaceDisplayMetadataDidChange` for
  workspace-display projection.
- The built-in workspace sidebar reads the live workspace metadata model and PE
  display-current-state fallback through `SidebarWorkspaceSnapshotBuilder`.
- The custom sidebar reads the same live workspace metadata model plus PE
  display-current-state fallback through `Workspace+CustomSidebarSnapshot` and
  `Workspace+CustomSidebarPullRequests`.
- The control socket reads `Workspace.presentedGitBranch` and
  `Workspace.sidebarPullRequestsInDisplayOrder()` for `sidebar_state`.
- Socket mutation commands apply explicit reports into the same workspace
  metadata model.
- `WorkProvenanceRuntime` observes workspace display metadata notifications and
  snapshots `Workspace.provenancePullRequestSnapshot()` plus branch and
  directory fields. PE-projected durable current state is a consumer/fallback,
  not the sidebar Git/PR observation authority.

## Refresh Triggers

- Initial workspace or panel creation schedules multi-delay Git probes.
- Workspace restoration resets existing tracking and schedules fresh probes for
  restored panel state.
- Directory reports update panel directory state, clear stale metadata when
  needed, and schedule Git/PR refresh.
- Branch reports update branch state, update watchers, and schedule PR refresh
  only when PR tracking is already active.
- Dirty state can refresh through local Git metadata snapshots and watched path
  filesystem events.
- Filesystem watcher events trigger debounced Git snapshot refresh.
- The 5-minute fallback Git poll refreshes tracked candidates.
- Shell prompt-idle transitions schedule PR refresh for active PR panels.
- PR command hints optimistically reconcile status and schedule verification.
- Pull-request polling uses selected/background cadence with jitter and mobile
  host quiet deferral.
- Sidebar settings toggles restart or stop watcher/poll work and clear relevant
  metadata according to existing policy.
- Workspace close/detach clears tracking for that workspace.

## Cache and State Ownership

- Canonical live sidebar facts remain in `WorkspaceSidebarMetadataModel` through
  `Workspace` accessors. This is the state used by built-in sidebar, custom
  sidebar, sockets, and PE workspace-display projection.
- Git snapshot coalescing, signature tracking, watcher descriptors, and fallback
  poll state are runtime observation state. They are not durable facts.
- PR repo cache entries in `PullRequestPollService` are short-lived runtime
  cache entries used for rate limiting and refresh efficiency. They are not a
  competing durable source of truth.
- PE workspace-display current state is durable projected state consumed as
  fallback/display context. It must not silently mint PR, ticket, or owner facts
  without source evidence.
- UI row ordering, label formatting, and stale badges are presentation state
  derived from the live facts and PE fallback.

## Readiness and Failure Before Migration

- There is no app-runtime lifecycle state for sidebar Git/PR observation.
- XCTest app-host `TabManager()` construction can start real Git filesystem
  probing, watchers, fallback poll tasks, `gh` calls, GitHub REST requests, and
  PE display notifications when tests exercise those paths.
- A non-Git workspace is treated as absence of Git metadata; existing service
  policy eventually stops tracking non-repository directories.
- Git metadata reader failures are represented as non-repository or missing
  facts depending on the reader result.
- Missing `gh`, unauthenticated GitHub, network failure, and GitHub errors are
  transient PR failures. Existing policy preserves valid prior PR data and marks
  it stale after repeated failures.
- A PR not associated with the current branch clears or avoids the
  branch-derived PR badge for that panel.
- One workspace/panel failure is localized by per-key state; it does not need to
  fail all sidebar observation.

## Cancellation and Teardown Before Migration

- Existing reset/settings paths cancel fallback, probe, snapshot, poll, refresh,
  and watcher work for the cases that hit those paths, but app termination and
  `TabManager` teardown do not have one explicit app-runtime stop step.
- `TabManager.closeWorkspace` clears Git probes and PR tracking for a workspace.
- Session restore resets all Git/PR tracking.
- App termination has no explicit sidebar Git/PR runtime stop step.
- Repeated `TabManager` construction can produce another independent
  observation owner.

## Migration Boundary

This PR introduces an app-runtime service that owns construction, startup,
reconciliation, readiness, degradation/failure state, and shutdown for sidebar
Git/PR observation. `TabManager` becomes the host and forwarder for a service
provided by the runtime composition boundary. Default XCTest composition uses a
non-owning compatibility reporter so explicit branch/PR report behavior remains
testable without real Git, `gh`, network, watchers, or PE side effects.

Production creates the real `SidebarGitMetadataService` and
`PullRequestPollService` only through `BmuxAppRuntimeComposition`, starts and
stops them only through `BmuxAppRuntimeServices`, and attaches/detaches
per-window sessions through app window registration.

## Lifecycle After Migration

- `BmuxAppRuntimeConfiguration` enables
  `sidebarGitPullRequestObservation` only for production app composition by
  default. XCTest-host composition leaves the capability disabled unless a test
  explicitly opts in through `.test(enabledCapabilities:)`.
- `BmuxAppRuntimeComposition` constructs exactly one
  `SidebarGitPullRequestObservationRuntimeService` for the app runtime. The
  service receives production dependencies or focused injected dependencies.
- `BmuxAppRuntimeServices` is the only production start/stop entry point. It
  attaches observation during app runtime start/window registration and detaches
  a host when the corresponding window context is removed.
- The runtime owns per-host sessions. A session owns one
  `SidebarGitMetadataService` and one `PullRequestPollService` attached to the
  host's `SidebarGitHosting` seam.
- `TabManager` stores only a forwarding bundle. Production `TabManager`
  instances receive the runtime facade and do not construct observers. Default
  compatibility instances can accept explicit branch/PR reports but do not
  launch background probes, watchers, timers, `gh`, or network work.
- `AppDelegate` promotes an early-created compatibility `TabManager` to the
  runtime facade before attaching observation. Promotion is guarded so explicit
  test-owned services are not replaced and a second observation owner is not
  created.
- Focused app-host tests that need live sidebar Git behavior build local
  `BmuxSidebarGit` services in `bmuxTests/TabManagerSidebarGitTestSupport.swift`
  with injected dependencies. This is test-target construction, not a
  production lifecycle owner.

The runtime lifecycle states are:

- `disabled`: capability not enabled by composition or dependency validation.
- `notStarted`: enabled but not started.
- `starting`: dependency validation is in progress synchronously.
- `ready`: runtime infrastructure is installed and can accept workspace events.
  Individual repositories may still be loading, have no Git metadata, or have no
  associated PR.
- `degraded`: runtime infrastructure is installed and can accept workspace
  events, but injected app-scoped validation reports a capability-level
  dependency problem. Production does not preflight GitHub CLI/auth/network at
  startup; those failures stay localized to PR refresh results.
- `failed`: app-scoped startup validation failed before host services were
  created.
- `stopping` and `stopped`: runtime-owned sessions, tasks, prompt-mention work,
  watchers, and caches are being or have been released.

## Refresh and Stale-Result Policy

- Startup reconciles all terminal panels visible to a newly attached host and
  asks the PR poll service to refresh already tracked PR state.
- Repeated `start(host:)` or window-registration calls reuse the existing host
  session. They do not construct another observer and only reconcile workspaces
  newly discovered since the last routing pass.
- Workspace creation, restoration, directory reports, branch reports, dirty
  filesystem changes, fallback polls, prompt-idle events, PR command hints, and
  settings changes continue to flow through the same `TabManager` forwarding
  methods, but production forwarding reaches the runtime facade.
- Workspace close/removal clears Git probe and PR tracking for that workspace.
  Runtime routing discards stale workspace-to-host mappings so later events for
  removed workspaces cannot create new work.
- `SidebarGitMetadataService` keeps its explicit stale-directory rejection and
  per-directory snapshot coalescing. Slow Git metadata results are applied only
  while the panel still exists and still points at the probed directory.
- `PullRequestPollService` keeps its short-lived repo cache and transient
  failure policy. Unsupported repositories or branches without matching PRs do
  not erase unrelated workspace state. Transient GitHub/`gh`/network failures
  preserve the last valid badge and mark it stale only after repeated failures.
- Prompt-mention PR enrichment is now runtime-owned and revisioned by
  `(workspace, panel, PR number, URL)` plus a generation counter. A newer
  refresh for the same key cancels and supersedes the older task, and the apply
  step rechecks the current workspace/panel/PR before writing owner/status
  metadata.

## Authoritative State Contract

- Directly observed Git facts are branch and dirty state produced by
  `GitMetadataService` and projected by `SidebarGitMetadataService` into
  `Workspace.panelGitBranches` / focused `Workspace.gitBranch`.
- GitHub/PR facts are PR number, title, owner, status, branch, URL, and staleness
  produced by `PullRequestProbeService`/`PullRequestPollService` or explicit PR
  reports and projected into `Workspace.panelPullRequests` / focused
  `Workspace.pullRequest`.
- PE workspace-display current state remains durable projected state and a UI
  fallback. It is not the source of live sidebar observation ownership.
- Built-in sidebar rows, custom sidebar snapshots, control-socket
  `sidebar_state`, and `WorkProvenanceWorkspaceSnapshot` read the same live
  `Workspace` facts where practical. Presentation differences are layered on top
  by their existing render/snapshot builders.
- UI loading/stale/unavailable conditions stay presentation-level facts. The
  runtime does not create a new durable database or a second app-global cache for
  the same branch/PR metadata.

## Shutdown Guarantees

- `BmuxAppRuntimeServices.stop()` calls the sidebar Git/PR runtime stop path.
- Runtime stop cancels submitted prompt-mention enrichment tasks, stops every
  host session, clears workspace routing, resets start bookkeeping, and is safe
  before readiness, after degraded or failed startup, during active refresh, and
  when called repeatedly.
- Per-session stop calls `stopSidebarGitMetadataObservation()` and
  `stopWorkspacePullRequestObservation()`, which cancel service-owned probe,
  snapshot, poll, fallback, watcher, and refresh tasks and release host seams.
- `TabManager` ARC teardown no longer acts as the app-scoped observation owner.
  Explicit runtime stop/detach and the test-target local helper are the shutdown
  mechanisms.

## Test Control Mechanisms

- Default XCTest composition does not construct runtime host services and does
  not create a PE database when PE capabilities are disabled.
- Focused runtime tests inject validation outcomes, fake host services, and a
  controllable command runner for prompt-mention `gh pr view` enrichment.
- Existing sidebar Git/PR tests that need real service behavior opt in through
  `makeSidebarGitObservedTabManager(...)`, which constructs local services with
  injected command runners, clocks, readers, limiters, and mobile-host deferral
  policy in the test target.
- Runtime tests observe readiness and completion through synchronous lifecycle
  state, fake service counters, and controllable continuations. They do not use
  fixed sleeps or duration assertions.
- WorkProvenance owner/title enrichment is explicit-injection only. Default
  observer construction does not spawn `gh` or use the user's GitHub auth when a
  display snapshot contains a PR URL without owner metadata.

## Boundary Guard

`scripts/check-app-runtime-composition-boundary.sh` rejects production Swift
under `Sources/` and `Packages/` that constructs the migrated runtime outside
`BmuxAppRuntimeComposition`, starts or stops it outside `BmuxAppRuntimeServices`,
or constructs the long-lived
`SidebarGitMetadataService`, `PullRequestPollService`, `PullRequestProbeService`,
or shared Git probe limiter outside runtime dependencies. It also rejects the
removed PE GitHub CLI PR-owner resolver and protects the no-op default owner
resolver policy so workspace-display projection cannot become a second PR
metadata lookup owner.

The guard intentionally still allows short-lived explicit fact report commands,
pure formatting/rendering, test-target fakes and helpers, and workspace-local
metadata calculations that do not own observation lifecycle.

## Known Duplicated or Adjacent Paths

- `WorkProvenanceObservationService` still has separate PE Git/resource
  inspection. That is durable provenance observation, not sidebar runtime
  observation, and remains out of scope. Its former default GitHub CLI PR-owner
  enrichment path has been removed from production/default construction; any
  future owner resolver must be explicitly injected and justified as durable
  evidence rather than a sidebar observation owner.
- Socket commands still apply explicit branch/PR/directory reports directly to
  the `TabManager` forwarding methods. Those are short-lived fact inputs and now
  reach the runtime facade in production.
- The compatibility reporter remains for default XCTest and any legacy
  `TabManager()` composition that has not been wired to app-runtime services. Its
  removal condition is completion of the broader app-host test migration so all
  tests needing sidebar Git/PR behavior inject either runtime services or a
  local test-owned bundle explicitly.

## Deliberately Deferred

- Notification and push-registration lifecycle migration.
- Menu-bar lifecycle migration.
- Browser/DevTools lifecycle work already delivered by PR #103.
- Sidebar visual redesign or row layout cleanup.
- Replacing `WorkspaceSidebarMetadataModel` with another durable database.
- Retiring legacy provenance storage or PE Git inspection.
- General Git abstraction cleanup beyond lifecycle seams required here.
- Changing workspace-display file watcher churn policy.
- Cross-session retrieval or Knowledge Compiler work.
- Remote shared database infrastructure.
