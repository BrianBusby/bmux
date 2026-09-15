import SwiftUI
import BmuxAppKitSupportUI
import Bonsplit
import BmuxWorkspaces
import BmuxTerminal

struct WorkspacePanelContentHostView: View {
    let workspace: Workspace
    let panel: any Panel
    let paneId: PaneID
    let isFocused: Bool
    let isSelectedInPane: Bool
    let isVisibleInUI: Bool
    let portalPriority: Int
    let isSplit: Bool
    let appearance: PanelAppearance
    let windowAppearance: WindowAppearanceSnapshot
    let customSidebarTabManager: TabManager?
    let hasUnreadNotification: Bool
    let onFocus: () -> Void
    let onRequestPanelFocus: () -> Void
    let onResumeAgentHibernation: () -> Void
    let onAutoResumeAgentHibernation: () -> Void
    let onTriggerFlash: () -> Void

    var body: some View {
        PanelContentView(
            panel: panel,
            workspaceId: workspace.id,
            stableWorkspaceId: workspace.stableId,
            paneId: paneId,
            isFocused: isFocused,
            isSelectedInPane: isSelectedInPane,
            isVisibleInUI: isVisibleInUI,
            portalPriority: portalPriority,
            isSplit: isSplit,
            appearance: appearance,
            windowAppearance: windowAppearance,
            customSidebarTabManager: customSidebarTabManager,
            hasUnreadNotification: hasUnreadNotification,
            terminalAgentContext: WorkspaceContentView.terminalAgentContext(panel: panel, workspace: workspace),
            workProvenanceRuntime: workspace.owningTabManager?.workProvenanceRuntime,
            onFocus: onFocus,
            onRequestPanelFocus: onRequestPanelFocus,
            onResumeAgentHibernation: onResumeAgentHibernation,
            onAutoResumeAgentHibernation: onAutoResumeAgentHibernation,
            onTriggerFlash: onTriggerFlash
        )
    }
}
