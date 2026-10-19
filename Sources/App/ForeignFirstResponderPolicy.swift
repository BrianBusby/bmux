import AppKit

/// Whether an active terminal surface should *yield* to `firstResponder` instead of taking first
/// responder itself when reconciling focus (used by `GhosttySurfaceScrollView.ensureFocus` and the
/// find-overlay focus apply).
///
/// A terminal yields only to a *legitimate* in-window focus owner: a focused text editor
/// (`NSText` field editor), an explicitly focused workspace-sidebar control, or a
/// right-sidebar / dock / feed host. It must still belong to `window`, except an
/// explicitly registered workspace-popover responder in that window's direct child. bmux hosts terminal surfaces through a portal that reparents views between
/// windows; a focus owner can be reparented out of a window without resigning, leaving
/// `window.firstResponder` pointing at a view that no longer belongs to the window (a "stranded"
/// responder, see issue #5269). The previous guard checked responder *type* only, so it treated a
/// stranded `NSText` / sidebar responder as legitimate and the terminal never reclaimed focus —
/// making the pane unfocusable by click or by programmatic `focus-pane` until the workspace was
/// moved to a fresh window. Requiring window membership lets the terminal reclaim focus from a
/// stranded responder while still respecting a genuine in-window focus owner.
///
/// - Parameters:
///   - firstResponder: The window's current first responder.
///   - window: The window whose focus is being reconciled.
///   - isRightSidebarOwner: Predicate identifying right-sidebar / dock / feed focus hosts (injected
///     so this policy is testable without `AppDelegate`).
///   - isWorkspaceSidebarOwner: Predicate identifying an explicitly focused, attached workspace control.
/// - Returns: `true` only when `firstResponder` is a legitimate focus owner that genuinely belongs
///   to `window` or its explicitly registered native popover; `false` when the terminal
///   should reclaim first responder (including when the
///   responder is stranded in another window or detached).
///
/// ```swift
/// if respectForeignFirstResponder,
///    let firstResponder = window.firstResponder,
///    shouldRespectForeignFirstResponder(firstResponder, in: window, isRightSidebarOwner: {
///        AppDelegate.shared?.isRightSidebarFocusResponder($0, in: window) == true
///    }) {
///     return // a real in-window focus owner is active; do not steal focus
/// }
/// ```
@MainActor
func shouldRespectForeignFirstResponder(
    _ firstResponder: NSResponder,
    in window: NSWindow,
    isRightSidebarOwner: (NSResponder) -> Bool,
    isWorkspaceSidebarOwner: (NSResponder) -> Bool = { _ in false }
) -> Bool {
    // A stranded responder (detached, or reparented into another window without resigning) no longer
    // belongs to this window and must not block the terminal from reclaiming first responder.
    guard let responderWindow = (firstResponder as? NSView)?.window else { return false }
    if responderWindow === window {
        return firstResponder is NSText || isRightSidebarOwner(firstResponder)
            || isWorkspaceSidebarOwner(firstResponder)
    }
    // SwiftUI popovers can keep a main-window firstResponder proxy in their
    // attached child window. Only an explicitly registered control may use this
    // exception; generic text/sidebar responders stranded elsewhere still yield.
    return responderWindow.parent === window && isWorkspaceSidebarOwner(firstResponder)
}
