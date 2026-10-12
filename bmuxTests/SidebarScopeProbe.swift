import AppKit
import SwiftUI

/// Captures rendered values at the native update seam for hosting-boundary tests.
struct SidebarScopeProbe: NSViewRepresentable {
    let values: (UUID, ColorScheme, Bool, LayoutDirection, String, Bool)
    let capture: ((UUID, ColorScheme, Bool, LayoutDirection, String, Bool)) -> Void
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ nsView: NSView, context: Context) { capture(values) }
}
