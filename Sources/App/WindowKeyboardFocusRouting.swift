import AppKit

/// Binds app window lookup to the existing focus owners and foreign-responder policy.
/// This routing value owns no focus state and also preserves text-editor policy
/// when no application delegate is available.
@MainActor
struct WindowKeyboardFocusRouting {
    let appDelegate: AppDelegate?
    let window: NSWindow?

    var workspaceSidebarOwnsFocus: Bool {
        guard let window, let responder = window.firstResponder else { return false }
        return appDelegate?.keyboardFocusCoordinator(for: window)?
            .workspaceSidebarFocusOwner.owns(responder, in: window) == true
    }

    func respects(_ responder: NSResponder) -> Bool {
        guard let window else { return false }
        return shouldRespectForeignFirstResponder(responder, in: window, isRightSidebarOwner: {
            appDelegate?.isRightSidebarFocusResponder($0, in: window) == true
        }, isWorkspaceSidebarOwner: {
            appDelegate?.keyboardFocusCoordinator(for: window)?
                .workspaceSidebarFocusOwner.owns($0, in: window) == true
        })
    }

    func synchronizeAfterResponderChange() {
        if let coordinator = appDelegate?.keyboardFocusCoordinator(for: window) {
            coordinator.syncAfterResponderChange()
        } else if let parent = window?.parent,
                  let coordinator = appDelegate?.keyboardFocusCoordinator(for: parent) {
            // Child-window notifications update only the explicitly registered
            // workspace popover; other focus-intent owners remain unchanged.
            coordinator.workspaceSidebarFocusOwner.synchronize(responder: parent.firstResponder, in: parent)
        }
    }
}
