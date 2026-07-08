import AppKit

extension Workspace {
    func performSurfaceTabBarNewAgentChatAction(presentingWindow: NSWindow?) {
        guard let owningTabManager else { return }
        _ = AppDelegate.shared?.executeConfiguredBmuxAction(
            id: BmuxSurfaceTabBarBuiltInAction.newAgentChat.configID,
            tabManager: owningTabManager,
            preferredWindow: presentingWindow
        )
    }
}
