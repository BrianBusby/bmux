import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite
struct BrowserFindShortcutRoutingTests {
    @Test(arguments: [false, true])
    func inspectorCommandFFindsInOwnedContextOrFallsBackToMenu(registeredContext: Bool) throws {
        try BrowserFindShortcutSettingsFixture().withCommandF {
            let fixture = BrowserFindShortcutFixture()
            defer { fixture.close() }
            let panel = try fixture.prepare(registeredContext: registeredContext)
            let webView = try #require(panel.webView as? BmuxWebView)
            installBmuxUnitTestWKWebViewPerformKeyEquivalentOverride()
            let previousHook = bmuxUnitTestWKWebViewPerformKeyEquivalentHook
            defer { bmuxUnitTestWKWebViewPerformKeyEquivalentHook = previousHook }
            var forwardedEvents: [NSEvent] = []
            bmuxUnitTestWKWebViewPerformKeyEquivalentHook = { currentWebView, event in
                guard currentWebView === webView else { return nil }
                forwardedEvents.append(event)
                return true
            }
            #expect(fixture.window.makeFirstResponder(fixture.inspectorView))
            #expect(bmuxIsLikelyWebInspectorResponder(fixture.window.firstResponder))
            #expect(panel.searchState == nil)
            let event = try #require(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [.command],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: fixture.window.windowNumber,
                context: nil, characters: "f", charactersIgnoringModifiers: "f", isARepeat: false, keyCode: 3
            ))

            let consumed = webView.performKeyEquivalent(with: event)

            #expect(consumed)
            #expect(forwardedEvents.isEmpty)
            #expect((panel.searchState != nil) == registeredContext)
            #expect(fixture.menuInvocationCount == (registeredContext ? 0 : 1))
            #expect(!fixture.window.isVisible)
        }
    }
}
