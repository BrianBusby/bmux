# Remaining Patch-Audit Backlog

This document records the September 7, 2026 planning slice that moved remaining
patched-area audit findings into Project Truth. Generated Project Truth docs are
still canonical for frontier status; this file explains the grouping and source
evidence behind the new nodes.

## Delivery State Preserved

The existing Process Integrity deliveries remain historical completed work:

- PR #97, `deterministic_app_runtime_composition`, is still implemented and
  validated for WorkProvenance runtime composition, app-host test isolation, and
  deterministic PE lifecycle state.
- PR #98, `post_merge_project_truth_reconciliation`, is still implemented and
  validated for the reconcile check/apply tool and automation path.
- PR #99 recorded the first post-merge reconciliation of PR #98.
- PR #100, `app_runtime_service_lifecycle_migration`, is still implemented and
  validated, with the title narrowed to Mobile Host and Presence Lifecycle
  Migration to match the shipped service family.
- PR #101 recorded the post-merge reconciliation of PR #100 and left no active
  implementation slice selected in repo-local status.

## Captured Runtime Lifecycle Work

The remaining AppDelegate and app-host service ownership work is captured under
`app_runtime_composition_migration` instead of as one broad background-service
bucket.

`app_runtime_browser_devtools_lifecycle_migration` is selected next. Inspection
found BrowserSystemProxyWatcher startup and Browser/DevTools teardown still
running through AppDelegate, window, and panel paths. The slice is bounded to
one runtime owner, explicit production/test configuration, deterministic
readiness or degraded state where meaningful, isolated tests, complete teardown,
no second owner, production-path coverage, and a source guard.

Downstream lifecycle slices are gated separately:

- `app_runtime_sidebar_git_pr_lifecycle_migration` for sidebar Git metadata,
  pull-request observation, custom-sidebar PR state, and shared sidebar/socket
  state.
- `app_runtime_notification_push_lifecycle_migration` for user notifications,
  PhonePushClient auth/send lifecycle, push registration, and teardown.
- `app_runtime_menu_bar_presentation_lifecycle_migration` for menu-bar
  visibility, activation policy, and presentation preference observation.
- `app_runtime_residual_app_host_service_audit` for updater, global search,
  hotkey, feature flag, renderer realization, hibernation, session snapshot,
  and any other residual app-host service family after the named migrations.

## Captured Provenance Runtime Follow-Ups

Three narrower PE runtime findings are captured under
`provenance_runtime_policy_followups`:

- `workspace_display_file_watcher_churn_policy` covers repeated SQLite WAL/SHM
  events and main-actor path scanning in the workspace-display Current State
  watcher.
- `pe_shared_sqlite_writer_policy` captures the local shared PE SQLite
  multi-writer issue seen when multiple local app instances contend for the
  same production database. This is a local single-user policy decision; it does
  not imply remote hosting or a multi-user database.
- `codex_historical_import_startup_boundary_guard` keeps historical Codex
  transcript import explicit and bounded through CLI or a future maintenance
  capability, not app startup.

## Captured Legacy Provenance Retirement

`legacy_bmux_provenance_retirement` now captures transitional bmux-local
provenance surfaces including `WorkProvenanceStore`,
`BmuxLegacyProvenanceClient`, local SQLite helpers, duplicate readers, legacy
storage, and observability paths retained during PE adoption.

The first slice is an inventory and decision record. It must classify every
production, CLI, test, and documentation caller as migrate, retain temporarily,
delete, or preserve as archival/recovery behavior; identify PE SDK replacements;
confirm whether production still depends on the legacy database; decide schema
compatibility and rollback/data preservation; and define a guard against new
consumer behavior on the legacy path. Actual cleanup is a later gated slice.

## Captured Test Determinism Burn-Down

`.github/test-determinism-allowlist.txt` currently has twenty grandfathered
findings. Project Truth now tracks burn-down by reviewable subsystem:

- Swift package tests: five sleep or elapsed-duration findings.
- Swift app/runtime tests: seven findings, gated behind relevant lifecycle
  ownership work.
- Python socket and tmux compatibility tests: seven sleep-then-assert findings.
- UI tests: one Feed sidebar XCUITest finding, captured until the UI readiness
  contract is designed.

Completion requires fixing the underlying nondeterminism with observable
readiness, events, controllable clocks, deterministic polling contracts, or
injected scheduling. Removing an allowlist line alone does not count.

## Captured Mutation And Migration-Ledger Work

`config_workspace_launch_canonicalization` captures the documented category-D
bypass in `Sources/BmuxConfigExecutor+WorkspaceLaunch.swift`. The future slice
must route config-launched workspace creation, title, color, focus, and relevant
restoration behavior through the canonical workspace action path, then remove
the audit exception and extend the mutation-path guard if needed.

`monorepo_migration_ledger_disposition_closure` captures the pending PR and
local-worktree dispositions in `docs/planning/monorepo-migration-ledger.md`.
The future closure slice must rebase and preserve, recreate, close as
superseded, or archive each item based on evidence. This planning slice does not
delete local worktrees, branches, repositories, or user changes.

Open PR inspection on September 7, 2026 showed PRs #47, #37, #33, #32, #21,
#10, and #5 still matching ledger entries that need disposition. PR #54 is also
open but is not part of the monorepo migration ledger. The closure slice should
re-check GitHub before changing any disposition.

## Ordering

The selected next slice is Browser and DevTools lifecycle migration because it
reduces uncontrolled production startup and app-host test side effects while the
boundary is concrete. The broad order after that is sidebar Git/PR lifecycle,
notification and push lifecycle, menu-bar presentation lifecycle, config
workspace-launch canonicalization, test determinism burn-down, legacy provenance
retirement, monorepo ledger closure, and lower-priority PE watcher or local
SQLite policy work according to observed impact and validated dependencies.

No product or runtime implementation was included in this planning slice.
