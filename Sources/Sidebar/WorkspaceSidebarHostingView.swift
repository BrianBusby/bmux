import AppKit
import SwiftUI

/// Reports the lifetime of one dedicated sidebar host, independently of rendering.
@MainActor
final class WorkspaceSidebarHostingView<Content: View>: NSHostingView<Content> {
    var isFocusScopeEnabled = true
    var onAttachmentChange: (@MainActor (NSView, Bool) -> Void)?

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if window != nil, window !== newWindow { onAttachmentChange?(self, false) }
        super.viewWillMove(toWindow: newWindow)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { onAttachmentChange?(self, isFocusScopeEnabled) }
    }
}
