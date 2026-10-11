import AppKit

/// Owns native focus inside the two explicitly registered workspace-sidebar hosts.
///
/// Membership is resolved synchronously at AppKit responder changes, before
/// SwiftUI's focus rendering. Per-key queries compare weak identities only.
/// A detached or reparented popover must receive a fresh native focus change;
/// merely reattaching its window never resurrects the previous grant.
@MainActor
final class WorkspaceSidebarFocusOwner {
    enum Scope { case rail, filterPopover }

    private weak var railHost: NSView?
    private weak var popoverHost: NSView?
    private weak var owningWindow: NSWindow?
    private weak var focusedHost: NSView?
    private weak var responder: NSResponder?
    private weak var lastNativeResponder: NSResponder?
    private weak var lastNativeWindow: NSWindow?
    private weak var hostWindow: NSWindow?
    private weak var responderWindow: NSWindow?
    // NSWindow exposes parenting only through KVO. Keep its synchronous token
    // at this AppKit seam so detach/reattach cannot preserve stale ownership.
    private var parentObservation: NSKeyValueObservation?

    func register(_ host: NSView, scope: Scope, in window: NSWindow) {
        if owningWindow !== window {
            clearFocus()
            railHost = nil
            popoverHost = nil
            parentObservation = nil
            owningWindow = window
        }
        switch scope {
        case .rail:
            guard railHost !== host else { return }
            if focusedHost === railHost { clearFocus() }
            railHost = host
        case .filterPopover:
            guard popoverHost !== host else { return }
            if focusedHost === popoverHost { clearFocus() }
            popoverHost = host
            parentObservation = host.window?.observe(\.parent, options: [.prior]) { [weak self] _, change in
                guard change.isPrior else { return }
                // AppKit window parenting is main-thread-only; revoke inline,
                // before the relationship changes, without an asynchronous gap.
                MainActor.assumeIsolated {
                    guard let self, self.focusedHost === self.popoverHost else { return }
                    self.clearFocus()
                }
            }
        }
    }

    func unregister(_ host: NSView, scope: Scope) {
        if focusedHost === host { clearFocus() }
        switch scope {
        case .rail:
            if railHost === host { railHost = nil }
        case .filterPopover:
            if popoverHost === host {
                popoverHost = nil
                parentObservation = nil
            }
        }
    }

    /// Called only by the existing native first-responder-change hook.
    func synchronize(responder: NSResponder?, in window: NSWindow) {
        // Successful makeFirstResponder calls can repeat the current value.
        // They must not resurrect a grant revoked by native host reparenting.
        guard lastNativeResponder !== responder || lastNativeWindow !== window else { return }
        lastNativeResponder = responder
        lastNativeWindow = window
        clearFocus()
        guard owningWindow === window, let view = responder as? NSView,
              let responderWindow = view.window else { return }
        let host: NSView?
        if let railHost, railHost.window === window,
           responderWindow === window, view.isDescendant(of: railHost) {
            host = railHost
        } else if let popoverHost, let popoverWindow = popoverHost.window,
                  popoverWindow.parent === window, responderWindow === popoverWindow,
                  view.isDescendant(of: popoverHost) {
            host = popoverHost
        } else {
            host = nil
        }
        guard let host else { return }
        focusedHost = host
        hostWindow = host.window
        self.responder = responder
        self.responderWindow = responderWindow
    }

    private func clearFocus() {
        focusedHost = nil
        hostWindow = nil
        responder = nil
        responderWindow = nil
    }

    func owns(_ responder: NSResponder, in window: NSWindow) -> Bool {
        guard owningWindow === window, let hostWindow,
              focusedHost?.window === hostWindow,
              hostWindow === window || hostWindow.parent === window,
              let responderWindow, responderWindow === hostWindow else { return false }
        return self.responder === responder && (responder as? NSView)?.window === responderWindow
    }
}
