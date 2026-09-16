import SwiftUI

/// Adds a link cursor without intercepting the button's clicks or drag gestures.
struct SidebarLinkCursor: NSViewRepresentable {
    func makeNSView(context: Context) -> SidebarLinkCursorView {
        SidebarLinkCursorView()
    }

    func updateNSView(_ nsView: SidebarLinkCursorView, context: Context) {}
}
