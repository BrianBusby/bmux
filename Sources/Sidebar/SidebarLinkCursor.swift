import SwiftUI

/// Lets SwiftUI own the cursor on the button itself, above its hosting view.
struct SidebarLinkCursor: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.pointerStyle(.link)
        } else {
            content.background(SidebarLinkCursorFallback())
        }
    }
}
