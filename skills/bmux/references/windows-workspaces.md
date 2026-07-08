# Windows and Workspaces

Window/workspace lifecycle and ordering operations.

## Inspect

```bash
bmux list-windows
bmux current-window
bmux list-workspaces
bmux current-workspace
```

## Create/Focus/Close

```bash
bmux new-window
bmux focus-window --window window:2
bmux close-window --window window:2

bmux new-workspace
bmux select-workspace --workspace workspace:4
bmux close-workspace --workspace workspace:4
```

## Reorder and Move

```bash
bmux reorder-workspace --workspace workspace:4 --before workspace:2
bmux move-workspace-to-window --workspace workspace:4 --window window:1
```
