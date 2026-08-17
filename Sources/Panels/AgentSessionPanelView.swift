import SwiftUI

struct AgentSessionPanelView: View {
    let panel: AgentSessionPanel
    let stableWorkspaceId: UUID
    let workProvenanceRuntime: WorkProvenanceRuntime?
    let isFocused: Bool
    let isVisibleInUI: Bool
    let portalPriority: Int
    let appearance: PanelAppearance
    let onRequestPanelFocus: () -> Void

    var body: some View {
        Group {
            if isVisibleInUI {
                AgentSessionWebRenderer(
                    panel: panel,
                    stableWorkspaceId: stableWorkspaceId,
                    workProvenanceRuntime: workProvenanceRuntime,
                    isFocused: isFocused,
                    backgroundColor: appearance.contentBackgroundColor,
                    theme: AgentSessionWebTheme.resolve(appearance: appearance),
                    onRequestPanelFocus: onRequestPanelFocus
                )
                .id(panel.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(Double(portalPriority))
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
