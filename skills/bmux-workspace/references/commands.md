# bmux Workspace Command Reference

Use these commands from a bmux terminal. Most commands infer the caller workspace from `BMUX_WORKSPACE_ID`, but explicit flags are safer for automation.

## Context

```bash
bmux identify --json
bmux current-workspace --json
bmux capabilities --json
bmux ping
```

## Windows and Workspaces

```bash
bmux list-windows
bmux current-window
bmux new-window
bmux focus-window --window window:2
bmux close-window --window window:2

bmux list-workspaces
bmux list-workspaces --json
bmux new-workspace --name "task" --cwd "$PWD"
bmux new-workspace --command "npm run dev"
bmux new-workspace --layout '{"root":{"type":"terminal"}}'
bmux current-workspace
bmux select-workspace --workspace workspace:2
bmux rename-workspace --workspace workspace:2 -- "new name"
bmux close-workspace --workspace workspace:2
bmux reorder-workspace --workspace workspace:4 --before workspace:2
bmux move-workspace-to-window --workspace workspace:4 --window window:1
```

## Panes and Surfaces

```bash
bmux list-panes --workspace "$BMUX_WORKSPACE_ID"
bmux list-pane-surfaces --workspace "$BMUX_WORKSPACE_ID" --pane pane:1
bmux list-panels --workspace "$BMUX_WORKSPACE_ID"
bmux tree --workspace "$BMUX_WORKSPACE_ID"

bmux new-split right --workspace "$BMUX_WORKSPACE_ID"
bmux new-split down --workspace "$BMUX_WORKSPACE_ID" --surface "$BMUX_SURFACE_ID"
bmux new-pane --workspace "$BMUX_WORKSPACE_ID" --type terminal --direction right
bmux new-pane --workspace "$BMUX_WORKSPACE_ID" --type browser --url http://localhost:3000
bmux new-surface --workspace "$BMUX_WORKSPACE_ID" --type terminal --pane pane:1
bmux new-surface --workspace "$BMUX_WORKSPACE_ID" --type browser --pane pane:1 --url http://localhost:3000

bmux focus-pane --workspace "$BMUX_WORKSPACE_ID" --pane pane:2
bmux focus-panel --workspace "$BMUX_WORKSPACE_ID" --panel surface:3
bmux close-surface --workspace "$BMUX_WORKSPACE_ID" --surface surface:3
bmux move-surface --surface surface:7 --pane pane:2 --focus true
bmux reorder-surface --surface surface:7 --before surface:3
bmux move-tab-to-new-workspace --surface surface:7 --title "browser"
```

## Input

```bash
bmux send "echo hello\n"
bmux send-key enter
bmux send --surface "$BMUX_SURFACE_ID" "git status\n"
bmux send-key --surface "$BMUX_SURFACE_ID" enter
bmux read-screen --surface "$BMUX_SURFACE_ID"
```

## Sidebar Metadata

```bash
bmux set-status build "running" --workspace "$BMUX_WORKSPACE_ID" --icon hammer --color "#ff9500"
bmux clear-status build --workspace "$BMUX_WORKSPACE_ID"
bmux list-status --workspace "$BMUX_WORKSPACE_ID"
bmux set-progress 0.5 --workspace "$BMUX_WORKSPACE_ID" --label "Building"
bmux clear-progress --workspace "$BMUX_WORKSPACE_ID"
bmux log --workspace "$BMUX_WORKSPACE_ID" --level info -- "Build started"
bmux list-log --workspace "$BMUX_WORKSPACE_ID" --limit 20
bmux clear-log --workspace "$BMUX_WORKSPACE_ID"
bmux sidebar-state --workspace "$BMUX_WORKSPACE_ID" --json
```

## Notifications and Attention

```bash
bmux notify --title "Done" --body "Task complete"
bmux list-notifications --json
bmux clear-notifications
bmux trigger-flash --workspace "$BMUX_WORKSPACE_ID" --surface "$BMUX_SURFACE_ID"
bmux surface-health --workspace "$BMUX_WORKSPACE_ID" --json
```

## Config and Docs

```bash
bmux docs api
bmux docs browser
bmux docs settings
bmux settings path
bmux settings bmux-json
bmux settings shortcuts
bmux reload-config
```

## Tagged Reloads

Use focused tests while designing or fixing a slice. Before pushing a PR update
that changes production app/runtime behavior, run focused tests plus a tagged
reload. Before dogfood or handoff of runtime behavior, run a tagged reload and
targeted CLI/socket dogfood against that tag when relevant. For test-only
stabilization, skip tagged reload unless production code changed.

```bash
./scripts/reload.sh --tag <short-tag>
BMUX_SOCKET_PATH=/tmp/bmux-debug-<short-tag>.sock bmux identify --json
```
