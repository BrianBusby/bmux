import AppKit
import BmuxAppKitSupportUI
import BmuxTerminalCore
import Bonsplit
import SwiftUI
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized) struct MatteTerminalInsetRenderingTests {
    @Test(arguments: [false, true], [1.0, 0.88])
    func configuredBackgroundIsPaintedUnderTerminal(isDark: Bool, opacity: Double) throws {
        var config = GhosttyConfig()
        config.backgroundColor = NSColor(srgbRed: 0.05, green: 0.12, blue: 0.2, alpha: 1)
        config.foregroundColor = .white
        config.backgroundOpacity = opacity
        let appearance = PanelAppearance.fromConfig(config, usesTransparentWindow: opacity < 1)
        try expectTerminalFill(appearance: appearance, isDark: isDark)
    }

    @Test(arguments: [false, true])
    func defaultBackgroundKeepsExactMatteInset(isDark: Bool) throws {
        let theme = MatteTheme(colorScheme: isDark ? .dark : .light)
        var config = GhosttyConfig()
        config.backgroundColor = theme.color(.inset)
        config.backgroundOpacity = 1
        try expectTerminalFill(appearance: .fromConfig(config, usesTransparentWindow: false), isDark: isDark)
    }

    private func expectTerminalFill(appearance: PanelAppearance, isDark: Bool) throws {
        let manager = TabManager(autoWelcomeIfNeeded: false)
        let panel = try #require(manager.selectedTerminalPanel)
        defer { panel.close() }
        let view = TerminalPanelView(
            panel: panel, paneId: PaneID(id: UUID()), isFocused: false,
            isVisibleInUI: true, portalPriority: 0, isSplit: false, appearance: appearance,
            hasUnreadNotification: false, terminalAgentContext: "",
            onFocus: {}, onRequestPanelFocus: {}, onRequestTerminalChatFocus: {},
            onResumeAgentHibernation: {}, onAutoResumeAgentHibernation: {}, onTriggerFlash: {}
        )
        let scheme: ColorScheme = isDark ? .dark : .light
        let host = NSHostingView(rootView: view
            .environment(\.bmuxShellTerminalOnly, true)
            .environment(\.colorScheme, scheme)
            .frame(width: 120, height: 80)
            .background(Color(nsColor: MatteTheme(colorScheme: scheme).color(.panel))))
        host.frame = NSRect(x: 0, y: 0, width: 120, height: 80)
        host.layoutSubtreeIfNeeded()
        let image = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: image)
        let actual = try #require(image.colorAt(x: image.pixelsWide / 2, y: image.pixelsHigh / 2)?.usingColorSpace(.sRGB))
        // A translucent terminal leaves backdrop painting to the existing window
        // owner. Its leaf must reveal the parent, not paint an opaque composite.
        // Full shell/split coverage separately verifies which parent is visible.
        let expectedColor = appearance.usesClearContentBackground
            ? MatteTheme(colorScheme: scheme).color(.panel) : appearance.backgroundColor
        let reference = NSHostingView(rootView: Color(nsColor: expectedColor).frame(width: 1, height: 1))
        reference.frame = NSRect(x: 0, y: 0, width: 1, height: 1)
        reference.layoutSubtreeIfNeeded()
        let expectedImage = try #require(reference.bitmapImageRepForCachingDisplay(in: reference.bounds))
        reference.cacheDisplay(in: reference.bounds, to: expectedImage)
        let expected = try #require(expectedImage.colorAt(x: 0, y: 0)?.usingColorSpace(.sRGB))
        let distance = abs(actual.redComponent - expected.redComponent)
            + abs(actual.greenComponent - expected.greenComponent)
            + abs(actual.blueComponent - expected.blueComponent)
        #expect(distance < 0.02, "Terminal interior must respect the existing content-background owner")
    }
}
