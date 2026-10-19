import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct BrowserOmnibarArrowRoutingTests {
    @Test(arguments: [false, true])
    func restoresFocusedOmnibarBeforeDeliveringArrow(marked: Bool) throws {
        let fixture = BrowserOmnibarArrowFixture()
        defer { fixture.close() }
        let panel = try fixture.prepare()
        let webView = try #require(panel.webView as? BmuxWebView)
        let window = fixture.window
        let field = fixture.field

        #expect(window.makeFirstResponder(field))
        try #require(field.currentEditor() === fixture.editor)
        fixture.app.focusBrowserAddressBar(in: panel)
        fixture.resetEditor(marked: marked)
        #expect(window.makeFirstResponder(webView))
        #expect(window.firstResponder === webView)

        let leftArrow = String(try #require(UnicodeScalar(NSLeftArrowFunctionKey)))
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil,
            characters: leftArrow, charactersIgnoringModifiers: leftArrow,
            isARepeat: false, keyCode: 123
        ))
        #expect(fixture.app.focusedBrowserOmnibarField(for: event, in: window) === field)
        #expect(window.performKeyEquivalent(with: event))
        #expect(fixture.recordedKeyCodes == [123])
        #expect(window.firstResponder === fixture.editor)
    }
}
