import AppKit

extension BrowserPanel {
    func ownsAttachedDeveloperToolsInWindow(_ window: NSWindow) -> Bool {
        guard let contentView = window.contentView,
              webView.window === window,
              webView.isDescendant(of: contentView),
              let frontendWebView = webView.bmuxInspectorFrontendWebView(),
              frontendWebView.window === window else {
            return false
        }
        return frontendWebView === contentView || frontendWebView.isDescendant(of: contentView)
    }
}
