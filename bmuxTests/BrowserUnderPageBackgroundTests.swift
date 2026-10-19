import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct BrowserUnderPageBackgroundTests {
    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua], [false, true])
    func notificationUpdatesNativeUnderPageFill(appearanceName: NSAppearance.Name, boxedOpacity: Bool) throws {
        let appearance = try #require(NSAppearance(named: appearanceName))
        var result: Result<Void, Error> = .success(())
        appearance.performAsCurrentDrawingAppearance {
            result = Result { try verifyUnderPageFill(boxedOpacity: boxedOpacity) }
        }
        try result.get()
    }

    private func verifyUnderPageFill(boxedOpacity: Bool) throws {
        let panel = BrowserPanel(
            workspaceId: UUID(),
            initialURL: URL(string: "https://example.test/roof-inspection"),
            renderInitialNavigation: false
        )
        defer { panel.close() }
        #expect(panel.drawsConfiguredWebViewBackgroundForCurrentPage())
        let color = NSColor(srgbRed: 0.18, green: 0.29, blue: 0.44, alpha: 1)
        let opacity: Any = boxedOpacity ? NSNumber(value: 0.57) : 0.57 as Any
        NotificationCenter.default.post(name: .ghosttyDefaultBackgroundDidChange, object: nil, userInfo: [
            GhosttyNotificationKey.backgroundColor: color,
            GhosttyNotificationKey.backgroundOpacity: opacity,
        ])
        let actual = try #require(panel.webView.underPageBackgroundColor?.usingColorSpace(.sRGB))
        let expected = try #require(GhosttyBackgroundTheme.color(backgroundColor: color, opacity: 0.57).usingColorSpace(.sRGB))
        #expect(abs(actual.redComponent - expected.redComponent) < 0.005)
        #expect(abs(actual.greenComponent - expected.greenComponent) < 0.005)
        #expect(abs(actual.blueComponent - expected.blueComponent) < 0.005)
        #expect(actual.alphaComponent == 1)
    }
}
