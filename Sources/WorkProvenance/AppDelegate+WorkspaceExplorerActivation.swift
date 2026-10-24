import Foundation

@MainActor
extension AppDelegate {
    /// Selects the existing live workspace without changing Explorer navigation.
    func activateWorkspaceExplorerWorkspace(runtimeID: UUID) {
        guard let context = mainWindowContexts.values.first(where: { context in
            context.tabManager.tabs.contains(where: { $0.id == runtimeID })
        }) else { return }
        context.tabManager.selectWorkspaceIdForAction(runtimeID, notificationDismissalContext: nil)
        _ = focusMainWindow(windowId: context.windowId)
    }
}
