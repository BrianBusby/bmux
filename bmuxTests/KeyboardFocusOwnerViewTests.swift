import AppKit
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite @MainActor
struct KeyboardFocusOwnerViewTests {
    @Test func ordinaryRespondersRequireAView() {
        let view = NSView()
        #expect(view.keyboardFocusOwnerView === view)
        #expect(NSResponder().keyboardFocusOwnerView == nil)
    }

    @Test func fieldEditorResolvesTheFirstViewInItsResponderChain() {
        let editor = NSTextView()
        editor.isFieldEditor = true
        let intermediary = NSResponder()
        let field = NSTextField()
        editor.nextResponder = intermediary
        intermediary.nextResponder = field

        #expect(editor.keyboardFocusOwnerView === field)
    }

    @Test func fieldEditorWithoutAViewInItsResponderChainUsesItsParent() {
        let parent = NSView()
        let editor = NSTextView()
        editor.isFieldEditor = true
        parent.addSubview(editor)
        let nonViewResponder = NSResponder()
        editor.nextResponder = nonViewResponder

        #expect(editor.keyboardFocusOwnerView === parent)
    }

    @Test func detachedFieldEditorOwnsItsOwnFocus() {
        let editor = NSTextView()
        editor.isFieldEditor = true
        editor.nextResponder = nil

        #expect(editor.keyboardFocusOwnerView === editor)
    }
}
