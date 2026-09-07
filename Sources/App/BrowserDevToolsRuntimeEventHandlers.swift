import Foundation

@MainActor
struct BrowserDevToolsRuntimeEventHandlers {
    var addressBarFocused: @MainActor (_ panelId: UUID) -> Void
    var addressBarBlurred: @MainActor (_ panelId: UUID, _ wasTracked: Bool) -> Void
    var webViewBecameFirstResponder: @MainActor (_ notification: Notification) -> Void

    static let noop = BrowserDevToolsRuntimeEventHandlers(
        addressBarFocused: { _ in },
        addressBarBlurred: { _, _ in },
        webViewBecameFirstResponder: { _ in }
    )
}
