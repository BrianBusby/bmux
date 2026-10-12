import AppKit
import BmuxAppKitSupportUI
import BmuxFoundation
import BmuxTerminalCore
import Bonsplit
import SwiftUI
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Renders both matte ancestors and the real native split-host boundary.
@MainActor
@Suite(.serialized) struct MatteTerminalBackdropCompositionTests {
    @Test(arguments: [false, true], [1.0, 0.5])
    func splitTerminalsRetainConfiguredBackdropAndMatteChrome(isDark: Bool, opacity: Double) throws {
        try checkComposition(isDark: isDark, opacity: opacity, blur: .disabled)
    }

    @Test(arguments: [false, true])
    func glassBackdropRemainsOwnedByWindow(isDark: Bool) throws {
        try checkComposition(isDark: isDark, opacity: 1, blur: .macosGlassClear)
    }

    private func checkComposition(isDark: Bool, opacity: Double, blur: GhosttyBackgroundBlur) throws {
        let scheme: ColorScheme = isDark ? .dark : .light
        let theme = MatteTheme(colorScheme: scheme)
        var config = GhosttyConfig()
        config.backgroundColor = NSColor(srgbRed: 0.08, green: 0.19, blue: 0.27, alpha: 1)
        config.backgroundOpacity = opacity
        config.backgroundBlur = blur
        let fixtureConfig = config
        let defaults = try #require(UserDefaults(suiteName: "MatteBackdrop.\(UUID())"))
        let snapshot = WindowAppearanceResolver(terminalAppearance: .init(
            backgroundColor: config.backgroundColor, backgroundOpacity: opacity,
            backgroundBlur: blur, usesHostLayerBackground: true
        )).currentFromUserDefaults(defaults: defaults, colorScheme: scheme)
        let manager = TabManager(autoWelcomeIfNeeded: false)
        let workspace = try #require(manager.selectedWorkspace)
        let first = try #require(workspace.focusedPanelId)
        _ = try #require(workspace.newTerminalSplit(from: first, orientation: .horizontal, focus: false))
        defer { for panel in workspace.panels.values { panel.close() } }
        let sentinel = Color(nsColor: NSColor(srgbRed: 0.75, green: 0.16, blue: 0.48, alpha: 1))
        let root: (Bool) -> AnyView = { isVisible in
            let terminal = WorkspaceContentView(
                workspace: workspace, isWorkspaceVisible: isVisible, isWorkspaceInputActive: false,
                isFullScreen: false, workspacePortalPriority: 0, windowAppearance: snapshot,
                onThemeRefreshRequest: nil, appearanceConfigLoader: { _, _ in fixtureConfig }
            )
            .environmentObject(TerminalNotificationStore.shared)
            .environment(\.bmuxShellTerminalOnly, true)
            return AnyView(ZStack {
                sentinel
                WindowBackdropLayer(role: .windowRoot, snapshot: snapshot)
                WorkspaceReferenceAppShell { Color.clear } content: {
                    AgentSessionFactualProjectionView(
                        result: .missingSession, isLoading: false, backgroundColor: .clear, onRefresh: {},
                        liveTerminalContent: AnyView(terminal), initialPrimaryTab: .terminal,
                        workspaceLabel: "Project", sessionTitle: "Terminal"
                    )
                }
            }
            .environment(\.colorScheme, scheme))
        }
        let host = NSHostingView(rootView: root(true))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1092, height: 593),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        defer { window.contentView = nil; window.close() }
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        let split = try #require(findSplit(in: host))
        split.adjustSubviews()
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        #expect(split.arrangedSubviews.count == 2, "The fixture must cross real NSSplitView child hosting roots")
        let image = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: image)
        let expectedTerminal = try renderedColor(ZStack {
            sentinel
            WindowBackdropLayer(role: .windowRoot, snapshot: snapshot)
        })
        let expectedPanel = try renderedColor(Color(nsColor: theme.color(.panel)))
        let expectedBase = try renderedColor(Color(nsColor: theme.color(.base)))
        for pane in split.arrangedSubviews {
            let center = pane.convert(NSPoint(x: pane.bounds.midX, y: pane.bounds.midY), to: host)
            try expect(image, at: center, in: host, equals: expectedTerminal, label: "terminal center")
            let top = pane.isFlipped ? pane.bounds.minY + 5 : pane.bounds.maxY - 5
            let tabBar = pane.convert(NSPoint(x: pane.bounds.midX, y: top), to: host)
            try expect(image, at: tabBar, in: host, equals: expectedPanel, label: "opaque tab chrome")
        }
        let splitRect = split.convert(split.bounds, to: host)
        try expect(image, at: NSPoint(x: splitRect.minX - 10, y: splitRect.midY), in: host,
                   equals: expectedPanel, label: "main panel margin")
        try expect(image, at: NSPoint(x: 50, y: host.bounds.midY), in: host,
                   equals: expectedBase, label: "sidebar base")
        if opacity < 1 || blur.isMacOSGlassStyle {
            let centers = split.arrangedSubviews.map {
                $0.convert(NSPoint(x: $0.bounds.midX, y: $0.bounds.midY), to: host)
            }
            for visible in [false, true] {
                host.rootView = root(visible)
                host.layoutSubtreeIfNeeded()
                window.displayIfNeeded()
                let updated = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: updated)
                for center in centers {
                    try expect(updated, at: center, in: host,
                               equals: visible ? expectedTerminal : expectedPanel,
                               label: visible ? "remounted terminal backdrop" : "hidden workspace has no aperture")
                }
            }
        }
    }

    private func findSplit(in view: NSView) -> NSSplitView? {
        if let split = view as? NSSplitView { return split }
        return view.subviews.lazy.compactMap { findSplit(in: $0) }.first
    }

    private func renderedColor<V: View>(_ view: V) throws -> NSColor {
        let host = NSHostingView(rootView: view.frame(width: 1, height: 1))
        host.frame = NSRect(x: 0, y: 0, width: 1, height: 1)
        host.layoutSubtreeIfNeeded()
        let image = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: image)
        return try #require(image.colorAt(x: 0, y: 0)?.usingColorSpace(.sRGB))
    }

    private func expect(_ image: NSBitmapImageRep, at point: NSPoint, in host: NSView,
                        equals expected: NSColor, label: String) throws {
        let x = Int(point.x * CGFloat(image.pixelsWide) / host.bounds.width)
        let y = Int(point.y * CGFloat(image.pixelsHigh) / host.bounds.height)
        let actual = try #require(image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
        let distance = abs(actual.redComponent - expected.redComponent)
            + abs(actual.greenComponent - expected.greenComponent)
            + abs(actual.blueComponent - expected.blueComponent)
        #expect(distance < 0.025, "\(label) must preserve its established backdrop owner; actual=\(actual), expected=\(expected)")
    }
}
