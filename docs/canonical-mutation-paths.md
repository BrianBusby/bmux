# Canonical Mutation Paths

This document records the bounded architectural/refactor workstream for
domain-specific canonical mutation paths. It is authored history and guidance,
not current project status. Current gates, milestones, and repository state live
in the generated project-status documents linked from `docs/README.md`.

## Purpose

bmux exposes the same workspace, surface, terminal, browser, Dock, and related
mutations through UI, shortcuts, menus, sockets, CLI, AppleScript, config launch,
session restore, and browser adapters. This workstream keeps those entrypoints
thin and routes each conceptual mutation through one domain-owned semantic path.

The goal is one semantic mutation path per domain behavior, not maximum wrapper
count.

## Architectural Contract

### Thin Adapters

Entry points such as SwiftUI/AppKit UI, keyboard shortcuts, command palette,
menus/context menus, CLI, v1/v2 socket handlers, AppleScript, config
launch/reuse, session restore adapters, Dock UI, and browser adapters should be
thin adapters.

Adapters may parse or normalize input, resolve identifiers/references, translate
transport-specific errors, perform presentation-specific behavior, and call the
appropriate domain action. They should not independently own mutation policy.

```text
UI / shortcut / menu / CLI / socket / AppleScript / config adapter
                            |
                       thin adapter
                            |
                 canonical domain action
                            |
               domain model/service primitives
                            |
          authoritative state / persistence / effects
                            |
                        UI projection
```

### One Semantic Owner Per Behavior

Introducing a `ForAction` wrapper is not sufficient by itself. For every
conceptual mutation, one semantic owner should be responsible for validation,
protection rules, state transition, ordering, history implications, persistence
effects, domain side effects, and focus/selection reconciliation when they are
semantically part of the operation.

Examples include workspace rename, workspace selection, workspace close,
workspace grouping, surface close, surface focus, surface move, terminal
creation, terminal split creation, browser creation, and Dock creation.

Adapters should not perform part of the mutation before or after the canonical
action in a way that creates a second implementation of the behavior.

### Domain-Specific Centralization

Do not solve this with a giant application-wide action router. The pattern is
shared, but ownership remains domain-specific.

```text
workspace behavior -> TabManager / Workspace domain action
surface behavior   -> Workspace / surface domain action
terminal behavior  -> terminal-domain action/helper
Dock behavior      -> Dock domain action
browser behavior   -> browser/workspace domain action
```

### Canonical Paths Own Consistency

When model mutation, persistent state, UI state, history, secondary indexes,
selection, focus, notifications, or other domain effects are part of one
operation, their ordering and invariants belong in the canonical domain path.

Avoid adapter shapes equivalent to:

```text
adapter:
    mutate model
    update persisted state
    update sidebar state
    repair focus
```

when those behaviors belong to the same domain operation.

### UI Projection

Sidebar, menu, and view state should increasingly reflect authoritative domain
state rather than independently implementing mutations to title, description,
color, pin state, workspace group membership, workspace selection, surface
selection, surface focus, or related domain state.

Do not introduce new mutable UI-owned copies of domain truth during this
refactor.

### Cross-Entrypoint Semantic Parity

Important mutations should behave consistently regardless of entrypoint. Menu,
shortcut, command palette, socket, CLI, AppleScript, and Dock UI entrypoints may
format responses differently, but the underlying mutation result should converge
on the same domain semantics.

Tests should prove behavioral parity where practical rather than only proving
that helper methods exist.

### Compatibility Shims

Compatibility shims such as legacy `createSplit` / `newSplit` forwarding paths
are acceptable during migration, but they are transitional. A retained shim
should be identified, explain why it remains, forward immediately into the
canonical path, and record a removal condition where practical. Significant
mutation behavior should not live inside the shim.

### Guard Scope

`scripts/check-canonical-workspace-mutations.sh` and related guards protect
adapter/domain-boundary bypasses. They should not ban legitimate use of internal
primitives inside the canonical implementation itself.

```text
external adapter
      |
canonical domain action
      |
internal implementation primitives
```

Guards should be scoped to migrated adapters and known architectural boundaries,
not turned into an artificial wrapper hierarchy.

### Provenance Engine Boundary

Where a bmux mutation needs to create/update provenance evidence or
Provenance-Engine-owned state, the path is:

```text
bmux canonical domain action
            |
Provenance Engine public SDK/API
```

Do not directly mutate Provenance Engine storage, make bmux another provenance
authority, or create bmux-local shadow persistence for Provenance-Engine-owned
facts merely because the mutation path is centralized.

## Completed Inventory

PR #22, `Centralize workspace mutation paths`, merged the first major slice. It
centralized workspace, surface, browser-open, and send-key/send-text mutation
behavior behind domain-level paths rather than duplicated adapter rules.

Completed areas include:

- workspace rename/title, description, color, pin, move, move-to-top,
  close/close-relative, selection, and surface focus;
- workspace group actions and membership;
- surface close, including v2 `surface.close`, v1 `close_surface`, AppleScript
  terminal close, browser close helpers, remote tmux cleanup, temporary
  placeholder disposal, and last-surface protection;
- terminal surface creation across UI, socket, session restore, canvas, session
  drop, custom layout, split tab bar, debug, and restored-terminal entrypoints;
- browser surface and split creation;
- surface move, reorder, selection, focus, pane swaps, split-off focus,
  focus-history restore, browser focus helpers, canvas socket focus,
  main-window focus restore, external-paste focus, file-drop focus, and panel
  focus requests;
- Dock focus and Dock close action helpers;
- terminal split adapter routing through `createTerminalSplitForAction`;
- guard coverage for migrated adapter bypasses in the canonical mutation check.

## Dock Creation/Split Slice

The Dock creation/split slice routes migrated Dock creation adapters through
Dock-owned action helpers.

- Dock keyboard shortcuts.
- Dock empty-pane UI creation buttons.
- Dock tab-bar new-tab callbacks.
- Socket `surface.create --placement dock`.
- Socket `pane.create --placement dock`.
- Browser new-tab helpers targeting Dock surfaces.

The low-level `DockSplitStore.newSurface` and `DockSplitStore.newSplit`
primitives remain implementation internals for the Dock semantic owner. Migrated
adapters should call `createSurfaceForAction` or `createSplitForAction`.

## Current Audit

After Dock creation/split migration, remaining direct mutation calls are
classified as follows.

### A. Canonical Implementation Internals

- `DockSplitStore.newSurface` / `DockSplitStore.newSplit` and Dock-internal
  repair/configuration paths.
- `Workspace` terminal/browser creation primitives used by
  `Workspace+SurfaceActions`.
- `Workspace.focusPanel`, `Workspace.closePanel`, and related layout primitives
  used inside workspace/surface semantic owners.
- `TabManager+WorkspaceActions` and `TabManager+WorkspaceCustomTitle` calls into
  workspace focus/title primitives.
- `TabManager` session restore, debug layout, snapshot, and reopen paths that
  operate inside the owning manager's consistency model.

### B. Intentional Exceptions

- Debug and UI-test setup helpers in `AppDelegate`.
- Remote tmux mirror title synchronization.

### C. Compatibility Shims

- Main-area `TabManager.newSurface(...)` callers remain compatibility shims for
  legacy UI/menu entrypoints.
- Legacy browser and terminal creation method names in `TabManager`/`Workspace`
  remain forwarding shims.

### D. Remaining Adapter Bypasses

- `Sources/BmuxConfigExecutor+WorkspaceLaunch.swift` still creates, retitles,
  and recolors a config-launched workspace partly outside the workspace action
  path.

## Remaining Workstream

The only known remaining category-D migration target is config workspace launch.
Do not broaden that slice into unrelated workspace creation cleanup unless the
final config-launch audit identifies another tightly-coupled adapter bypass.

## Overall Completion Criteria

This workstream can close when major workspace mutation adapters, workspace
group mutations, surface close/move/reorder/select/focus, terminal
creation/split, browser creation/split, and Dock focus/close/create/split
converge through domain actions; important cross-entrypoint behavior has
regression coverage; guardrails prevent migrated adapter bypasses;
compatibility shims are documented and thin; audited low-level calls are
classified; and authored docs distinguish this refactor from the repository's
current generated project gate.
