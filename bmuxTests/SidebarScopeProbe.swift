import AppKit
import SwiftUI

/// Captures rendered values at the native update seam for hosting-boundary tests.
struct SidebarScopeProbe: NSViewRepresentable {
    let values: (UUID, ColorScheme, Bool, LayoutDirection, String)
    let capture: ((UUID, ColorScheme, Bool, LayoutDirection, String)) -> Void
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ nsView: NSView, context: Context) { capture(values) }
}
