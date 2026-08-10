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
tab_manager_close_adapter_pattern='(plan\.workspace\.closePanel|let closed = tab\.closePanel|_ = tab\.closePanel\(surfaceId)'
socket_close_adapter_pattern='requestNonInteractiveCloseTabRecordingHistory\(tabId\)'
workspace_adjacent_selection_pattern='\.(selectNextTab|selectPreviousTab)\('
browser_socket_focus_pattern='ws\.focusPanel\((target\.surfaceId|targetId)\)'
canvas_socket_focus_pattern='ws\.focusPanel\(surfaceID\)'
browser_address_bar_direct_focus_pattern='workspace\.focusPanel\((panel|browserPanel)\.id\)'
app_delegate_external_terminal_paste_direct_focus_pattern='workspace\.focusPanel\(terminalPanel\.id\)'
drag_drop_text_direct_focus_pattern='workspace\.focusPanel\(panelId, focusIntent: focusIntent\)'
workspace_content_panel_request_direct_focus_pattern='workspace\.focusPanel\(panel\.id\)'
canvas_host_panel_request_direct_focus_pattern='workspace\?\.focusPanel\(panel\.id\)'
canvas_host_panel_callback_direct_focus_pattern='workspace\??\.focusPanel\(panelId\)'
window_dock_surface_direct_focus_pattern='(windowDock|dock)\.focusPanel\((context\.surfaceId|surfaceId|targetId|surfaceID)\)'
workspace_dock_surface_direct_focus_pattern='ws\.dockSplit\.focusPanel\(surfaceID\)'
dock_panel_view_direct_focus_pattern='store\.focusPanel\(panel\.id\)'
focus_history_host_direct_focus_pattern='tabs\.first\(where: \{ \$0\.id == workspaceId \}\)\?\.focusPanel\(panelId\)'
surface_split_off_direct_focus_pattern='ws\.focusPanel\(previousFocusedPanelId\)'
detached_workspace_creation_direct_focus_pattern='newWorkspace\.focusPanel\(detached\.panelId'
main_window_focus_controller_direct_focus_pattern='workspace\.focusPanel\((panelId|terminalPanel\.id)\)'
dock_adapter_direct_close_pattern='(windowDock|dock)\.closePanel\('
workspace_dock_direct_close_pattern='(_dockSplit\?\.closePanel\(|self\.closePanel\(panel\.id)'
browser_self_close_direct_pattern='self\.closePanel\(browserPanel\.id'
browser_surface_creation_pattern='(^|[^A-Za-z0-9_])newBrowserSurface\('
browser_split_creation_pattern='(^|[^A-Za-z0-9_])newBrowserSplit\('

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
done < <(rg -n -P "$tab_manager_close_adapter_pattern" "Sources/TabManager.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$socket_surface_reorder_pattern" \
  "Sources/TerminalController+ControlSurfaceContext3.swift" \
  "Sources/TerminalController+ControlSystemContext2.swift" \
  "Sources/TabManager.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$socket_close_adapter_pattern" \
  "Sources/TerminalController+ControlSystemContext2.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$workspace_adjacent_selection_pattern" \
  "Sources" \
  --glob "*.swift" \
  --glob "!TabManager.swift" \
  --glob "!Workspace+SurfaceNavigation.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$browser_socket_focus_pattern" \
  "Sources/TerminalController.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$canvas_socket_focus_pattern" \
  "Sources/TerminalController+ControlCanvasContext.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$browser_address_bar_direct_focus_pattern" \
  "Sources/AppDelegate.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$app_delegate_external_terminal_paste_direct_focus_pattern" \
  "Sources/AppDelegate.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$drag_drop_text_direct_focus_pattern" \
  "Sources/DragOverlayRoutingPolicy.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$workspace_content_panel_request_direct_focus_pattern" \
  "Sources/WorkspaceContentView.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$canvas_host_panel_request_direct_focus_pattern" \
  "Sources/Canvas/WorkspaceCanvasHostView.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$canvas_host_panel_callback_direct_focus_pattern" \
  "Sources/Canvas/WorkspaceCanvasHostView.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$window_dock_surface_direct_focus_pattern" \
  "Sources/TerminalController.swift" \
  "Sources/TerminalController+ControlSurfaceContext.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$workspace_dock_surface_direct_focus_pattern" \
  "Sources/TerminalController+ControlSurfaceContext.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$dock_panel_view_direct_focus_pattern" \
  "Sources/DockPanelView.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$focus_history_host_direct_focus_pattern" \
  "Sources/TabManager+FocusHistoryHosting.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$surface_split_off_direct_focus_pattern" \
  "Sources/TerminalController+MoveTabToNewWorkspace.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$detached_workspace_creation_direct_focus_pattern" \
  "Sources/TabManager+DetachedWorkspace.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$main_window_focus_controller_direct_focus_pattern" \
  "Sources/MainWindowFocusController.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$dock_adapter_direct_close_pattern" \
  "Sources/AppDelegate+WindowDock.swift" \
  "Sources/TerminalController+ControlSurfaceDock.swift" \
  "Sources/TerminalController+ControlSurfaceContext2.swift" \
  "Sources/Workspace+DockBrowserLookup.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$workspace_dock_direct_close_pattern" \
  "Sources/Workspace+DockBrowserLookup.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$browser_self_close_direct_pattern" \
  "Sources/Workspace.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  source_line="${line#*:}"
  source_line="${source_line#*:}"
  [[ "$source_line" =~ ^[[:space:]]*func[[:space:]]+newBrowserSurface\( ]] && continue
  violations+=("$line")
done < <(rg -n -P "$browser_surface_creation_pattern" \
  "Sources" \
  --glob "*.swift" \
  --glob "!Workspace.swift" \
  --glob "!Workspace+SurfaceActions.swift" || true)

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  source_line="${line#*:}"
  source_line="${source_line#*:}"
  [[ "$source_line" =~ ^[[:space:]]*func[[:space:]]+newBrowserSplit\( ]] && continue
  violations+=("$line")
done < <(rg -n -P "$browser_split_creation_pattern" \
  "Sources" \
  --glob "*.swift" \
  --glob "!Workspace.swift" \
  --glob "!Workspace+SurfaceActions.swift" || true)

if (( ${#violations[@]} > 0 )); then
  {
    echo "check-canonical-workspace-mutations: migrated workspace entrypoints must route through domain action helpers."
    echo "Use TabManager workspace ForAction helpers, or extend the domain path when a new mutation policy is needed."
    printf '  %s\n' "${violations[@]}"
  } >&2
  exit 1
fi

echo "check-canonical-workspace-mutations: ok"
