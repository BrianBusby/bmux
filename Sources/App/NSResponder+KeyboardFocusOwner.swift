import AppKit

extension NSResponder {
    /// Resolves a shared field editor to the first view in its responder chain.
    /// A detached editor falls back to its parent or itself; ordinary responders
    /// own focus only when they are views. Mounted terminal Find fields are
    /// resolved by their surface before applying this generic AppKit fallback.
    @MainActor
    var keyboardFocusOwnerView: NSView? {
        if let editor = self as? NSTextView,
           editor.isFieldEditor {
            var current = editor.nextResponder
            while let next = current {
                if let view = next as? NSView {
                    return view
                }
                current = next.nextResponder
            }
            return editor.superview ?? editor
        }

        return self as? NSView
    }
}
