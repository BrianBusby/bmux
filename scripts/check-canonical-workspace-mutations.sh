#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

migrated_files=(
  "Sources/BmuxConfigExecutor+WorkspaceLaunch.swift"
  "Sources/Mobile/AgentChat/AgentChatTranscriptService.swift"
  "Sources/AppDelegate.swift"
  "Sources/RemoteTmuxController.swift"
  "Sources/ContentView.swift"
  "Sources/TerminalController.swift"
  "Sources/Workspace.swift"
  "Sources/bmuxApp.swift"
)

workspace_creation_migrated_files=(
  "Sources/TerminalController.swift"
  "Sources/TerminalController+WorkspaceCreate.swift"
)

surface_creation_migrated_files=(
  "Sources/TerminalController+ControlPaneContext.swift"
  "Sources/TerminalController+ControlSidebarContext3.swift"
  "Sources/TerminalController+ControlSurfaceContext2.swift"
  "Sources/TerminalController+ControlSystemContext2.swift"
  "Sources/TerminalController.swift"
)

mutation_pattern='\.((closeWorkspace|reorderWorkspace|clearCustomDescription|setCustomDescription|setTabColor|moveTabToTop|moveTabsToTop)\(|selectTab\(at:)'
creation_mutation_pattern='\.addWorkspace\('
surface_creation_mutation_pattern='\.newTerminal(Surface|Split)Outcome\('
ui_surface_creation_mutation_pattern='workspace\.newTerminalSurface\(inPane: paneId'
tab_manager_split_creation_mutation_pattern='return tab\.newTerminalSplit\('
session_resume_surface_creation_pattern='workspace\.newTerminalSurface\('
mobile_terminal_surface_creation_pattern='workspace\.newTerminalSurface\('
surface_context_terminal_to_right_pattern='guard let newPanel = newTerminalSurface\('
pane_swap_placeholder_surface_creation_pattern='workspace\.newTerminalSurface\('
canvas_surface_creation_pattern='newTerminalSurface\(inPane: focusedPaneId'
session_drop_surface_creation_pattern='let panel = newTerminalSurface\('
fork_new_tab_surface_creation_pattern='let forkedPanel = newTerminalSurface\('
split_tab_bar_self_surface_creation_pattern='self\.newTerminalSurface\('
split_tab_bar_new_terminal_pattern='newTerminalSurface\(inPane: pane,'
custom_layout_terminal_creation_pattern='newTerminal(Surface|Split)\('
closed_panel_restore_placeholder_pattern='placeholderPanel = newTerminalSplit\('
session_restore_anchor_surface_pattern='anchorPanelId = newTerminalSurface\(inPane: paneId'
session_restore_split_surface_pattern='let newSplitPanel = newTerminalSplit\('
session_restore_terminal_surface_pattern='guard let terminalPanel = newTerminalSurface\('
debug_terminal_creation_pattern='\.newTerminal(Surface|Split)\('
canvas_surface_close_pattern='workspace\?\.closePanel\(panelId\)'
tab_manager_close_surface_pattern='^[[:space:]]*tab\.closePanel\(surfaceId\)[[:space:]]*$'
socket_surface_reorder_pattern='\.reorderSurface\(panelId:'

violations=()
if command -v rg >/dev/null 2>&1; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    source_line="${line#*:}"
    source_line="${source_line#*:}"
    [[ "$source_line" =~ ^[[:space:]]*case[[:space:]]+\. ]] && continue
    violations+=("$line")
  done < <(rg -n -P "$mutation_pattern" "${migrated_files[@]}" || true)
else
  while IFS= read -r file; do
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      source_line="${line#*:}"
      [[ "$source_line" =~ ^[[:space:]]*case[[:space:]]+\. ]] && continue
      violations+=("$line")
    done < <(grep -nE '\.(closeWorkspace|reorderWorkspace|clearCustomDescription|setCustomDescription|setTabColor|moveTabToTop|moveTabsToTop)\(' "$file" || true)
  done < <(printf '%s\n' "${migrated_files[@]}")
fi

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$creation_mutation_pattern" "${workspace_creation_migrated_files[@]}" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$surface_creation_mutation_pattern" "${surface_creation_migrated_files[@]}" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$ui_surface_creation_mutation_pattern" "Sources/WorkspaceContentView.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$tab_manager_split_creation_mutation_pattern" "Sources/TabManager.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$session_resume_surface_creation_pattern" "Sources/SessionIndexView.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$mobile_terminal_surface_creation_pattern" "Sources/TerminalController.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$surface_context_terminal_to_right_pattern" "Sources/Workspace.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$pane_swap_placeholder_surface_creation_pattern" "Sources/TerminalController+ControlPaneContext.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$canvas_surface_creation_pattern" "Sources/Canvas/Workspace+CanvasLayout.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$session_drop_surface_creation_pattern" "Sources/Workspace.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$fork_new_tab_surface_creation_pattern" "Sources/Workspace.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$split_tab_bar_self_surface_creation_pattern" "Sources/Workspace.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$split_tab_bar_new_terminal_pattern" "Sources/Workspace.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$custom_layout_terminal_creation_pattern" "Sources/Workspace+CustomLayout.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$closed_panel_restore_placeholder_pattern" "Sources/Workspace.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$session_restore_anchor_surface_pattern" "Sources/Workspace.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$session_restore_split_surface_pattern" "Sources/Workspace.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$session_restore_terminal_surface_pattern" "Sources/Workspace.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$debug_terminal_creation_pattern" "Sources/TabManager.swift" "Sources/AppDelegate.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$canvas_surface_close_pattern" "Sources/Canvas/WorkspaceCanvasHostView.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$tab_manager_close_surface_pattern" "Sources/TabManager.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$socket_surface_reorder_pattern" \
  "Sources/TerminalController+ControlSurfaceContext3.swift" \
  "Sources/TerminalController+ControlSystemContext2.swift" \
  "Sources/TabManager.swift" || true)

if (( ${#violations[@]} > 0 )); then
  {
    echo "check-canonical-workspace-mutations: migrated workspace entrypoints must route through domain action helpers."
    echo "Use TabManager workspace ForAction helpers, or extend the domain path when a new mutation policy is needed."
    printf '  %s\n' "${violations[@]}"
  } >&2
  exit 1
fi

echo "check-canonical-workspace-mutations: ok"
