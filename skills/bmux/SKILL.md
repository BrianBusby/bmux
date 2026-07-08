---
name: bmux
description: End-user control of bmux topology and routing (windows, workspaces, panes/surfaces, focus, moves, reorder, identify, trigger flash). Use when automation needs deterministic placement and navigation in a multi-pane bmux layout.
---

# bmux Core Control

Use this skill to control non-browser bmux topology and routing.

## Core Concepts

- Window: top-level macOS bmux window.
- Workspace: tab-like group within a window.
- Pane: split container in a workspace.
- Surface: a tab within a pane (terminal or browser panel).

## Fast Start

```bash
# identify current caller context
bmux identify --json

# list topology
bmux list-windows
bmux list-workspaces
bmux list-panes
bmux list-pane-surfaces --pane pane:1

# create/focus/move
bmux new-workspace
bmux new-split right --panel pane:1
bmux move-surface --surface surface:7 --pane pane:2 --focus true
bmux split-off --surface surface:7 right
bmux reorder-surface --surface surface:7 --before surface:3

# attention cue
bmux trigger-flash --surface surface:7
```

## Settings and Docs

Use `bmux docs settings` before changing bmux-owned settings. It prints the docs URL, schema URL, raw GitHub resources, bmux.json paths, and reload command.

```bash
bmux docs settings
bmux settings path
```

bmux-owned settings live in `~/.config/bmux/bmux.json`. Legacy `~/.config/bmux/settings.json` and `~/Library/Application Support/com.bmuxterm.app/settings.json` files are read only as fallback for missing keys. Before editing, copy any existing `bmux.json` file to a timestamped `.bak` next to it so the user can revert. Edit the user file, then reload:

```bash
bmux reload-config
```

`bmux reload-config` reloads BOTH `bmux.json` and Ghostty config (`~/.config/ghostty/config`) and refreshes terminals in place. No app restart needed.

Use bmux settings for app behavior, sidebar, notifications, browser behavior, automation, workspace colors, and bmux-owned shortcuts. Terminal rendering settings such as font, cursor style, theme, scrollback, background transparency (`background-opacity`), and blur (`background-blur`) belong in Ghostty config at `~/.config/ghostty/config`.

Open the UI when useful:

```bash
bmux settings
bmux settings bmux-json
bmux settings shortcuts
```

## Handle Model

- Default output uses short refs: `window:N`, `workspace:N`, `pane:N`, `surface:N`.
- UUIDs are still accepted as inputs.
- Request UUID output only when needed: `--id-format uuids|both`.

## Deep-Dive References

| Reference | When to Use |
|-----------|-------------|
| [references/handles-and-identify.md](references/handles-and-identify.md) | Handle syntax, self-identify, caller targeting |
| [references/windows-workspaces.md](references/windows-workspaces.md) | Window/workspace lifecycle and reorder/move |
| [references/panes-surfaces.md](references/panes-surfaces.md) | Splits, surfaces, move/reorder, focus routing |
| [references/trigger-flash-and-health.md](references/trigger-flash-and-health.md) | Flash cue and surface health checks |
| [../bmux-workspace/SKILL.md](../bmux-workspace/SKILL.md) | Current caller workspace rules and non-disruptive automation |
| [../bmux-settings/SKILL.md](../bmux-settings/SKILL.md) | Safe bmux.json settings edits and validation |
| [../bmux-browser/SKILL.md](../bmux-browser/SKILL.md) | Browser automation on surface-backed webviews |
| [../bmux-markdown/SKILL.md](../bmux-markdown/SKILL.md) | Markdown viewer panel with live file watching |
