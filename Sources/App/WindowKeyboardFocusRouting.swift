import AppKit

/// Binds app window lookup to the existing focus owners and foreign-responder policy.
/// This routing value owns no focus state and also preserves text-editor policy
/// when no application delegate is available.
@MainActor
struct WindowKeyboardFocusRouting {
    let appDelegate: AppDelegate?
    let window: NSWindow?

    var workspaceSidebarOwnsFocus: Bool {
        guard let window else { return false }
        return appDelegate?.keyboardFocusCoordinator(for: window)?
            .workspaceChromeFocusOwner.ownsCurrentFocus(in: window) == true
    }

    func respects(_ responder: NSResponder) -> Bool {
        guard let window else { return false }
        return shouldRespectForeignFirstResponder(responder, in: window, isRightSidebarOwner: {
            appDelegate?.isRightSidebarFocusResponder($0, in: window) == true
        }, isWorkspaceSidebarOwner: {
            appDelegate?.keyboardFocusCoordinator(for: window)?
                .workspaceChromeFocusOwner.owns($0, in: window) == true
        })
    }

    /// Receives the existing application event dispatch before native focus changes.
    func recordChromeInput(_ event: NSEvent) {
        switch event.type {
        case .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown: break
        default: return
        }
        let coordinator = appDelegate?.keyboardFocusCoordinator(for: window)
            ?? window?.parent.flatMap { appDelegate?.keyboardFocusCoordinator(for: $0) }
        coordinator?.workspaceChromeFocusOwner.recordInput(event.type)
    }

    func synchronizeAfterResponderChange() {
        if let coordinator = appDelegate?.keyboardFocusCoordinator(for: window) {
            coordinator.syncAfterResponderChange()
        } else if let parent = window?.parent,
                  let coordinator = appDelegate?.keyboardFocusCoordinator(for: parent) {
            // Child-window notifications update only the explicitly registered
            // workspace popover; other focus-intent owners remain unchanged.
            coordinator.workspaceChromeFocusOwner.synchronize(responder: window?.firstResponder, in: parent)
        }
    }
}
