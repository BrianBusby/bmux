import SwiftUI

/// Tracks link cursor events on macOS versions without SwiftUI pointer styles.
struct SidebarLinkCursorFallback: NSViewRepresentable {
    func makeNSView(context: Context) -> SidebarLinkCursorView {
        SidebarLinkCursorView()
    }

    func updateNSView(_ nsView: SidebarLinkCursorView, context: Context) {}
}
